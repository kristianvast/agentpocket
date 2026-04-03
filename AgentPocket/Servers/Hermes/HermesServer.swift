import Foundation

@MainActor
final class HermesServer: AgentServer {
    let serverType: ServerType = .hermes
    let capabilities = AgentCapabilities(
        supportsStreaming: true,
        supportsTools: true,
        supportsPermissions: false,
        supportsFileAccess: false,
        supportsTerminal: false,
        supportsAudioInput: true,
        supportsImageInput: true,
        supportsConversationHistory: true,
        supportsMCP: false,
        supportsMemory: true
    )

    private(set) var isConnected = false

    private let config: ServerConfig
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    private var conversations: [ConversationID: Conversation] = [:]
    private var messages: [ConversationID: [Message]] = [:]
    private var previousResponseIDs: [ConversationID: String] = [:]

    init(config: ServerConfig) {
        self.config = config
        self.httpClient = HTTPClient(baseURL: config.url, authorizationHeader: config.authorizationHeader)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func connect() async throws {
        do {
            let health: HermesHealthResponse = try await httpClient.get(path: "/health")
            if let status = health.status, status.lowercased() == "ok" || status.lowercased() == "healthy" {
                isConnected = true
            } else {
                throw AgentPocketError.serverError(statusCode: 503, message: "Server health check failed: \(health.status ?? "unknown")")
            }
        } catch {
            throw mapError(error)
        }
    }

    func disconnect() {
        isConnected = false
    }

    func listConversations() async throws -> [Conversation] {
        Array(conversations.values).sorted { $0.updatedAt > $1.updatedAt }
    }

    func createConversation() async throws -> Conversation {
        let id = UUID().uuidString
        let conversation = Conversation(
            id: id,
            title: nil,
            createdAt: .now,
            updatedAt: .now,
            status: .idle,
            metadata: ConversationMetadata(serverType: .hermes)
        )
        conversations[id] = conversation
        messages[id] = []
        return conversation
    }

    func deleteConversation(id: ConversationID) async throws {
        conversations.removeValue(forKey: id)
        messages.removeValue(forKey: id)
        previousResponseIDs.removeValue(forKey: id)
    }

    func listMessages(conversationID: ConversationID) async throws -> [Message] {
        messages[conversationID] ?? []
    }

    func sendMessage(conversationID: ConversationID, content: [MessageContent]) -> AsyncThrowingStream<ServerEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if conversations[conversationID] == nil {
                        let created = Conversation(id: conversationID, metadata: ConversationMetadata(serverType: .hermes))
                        conversations[conversationID] = created
                        messages[conversationID] = []
                        continuation.yield(.conversationCreated(created))
                    }

                    let userMessage = Message(
                        id: UUID().uuidString,
                        conversationID: conversationID,
                        role: .user,
                        content: content,
                        createdAt: .now,
                        metadata: MessageMetadata()
                    )
                    appendMessage(userMessage)
                    continuation.yield(.messageCreated(conversationID, userMessage))

                    let assistantMessageID = UUID().uuidString
                    let assistantContentID = UUID().uuidString
                    let assistantMessage = Message(
                        id: assistantMessageID,
                        conversationID: conversationID,
                        role: .assistant,
                        content: [MessageContent(id: assistantContentID, type: .text, data: .text(TextContent(text: "")))],
                        createdAt: .now,
                        metadata: MessageMetadata()
                    )
                    appendMessage(assistantMessage)
                    continuation.yield(.messageCreated(conversationID, assistantMessage))
                    continuation.yield(.statusChanged(conversationID, .streaming))

                    let prompt = flattenText(content)
                    let request = HermesResponsesRequest(
                        model: "default",
                        input: prompt,
                        stream: true,
                        previousResponseID: previousResponseIDs[conversationID]
                    )

                    let stream = httpClient.postStreaming(path: "/v1/responses", body: request)

                    var assembled = ""
                    var responseID: String?

                    for try await lineData in stream {
                        if Task.isCancelled { break }

                        let rawLine = String(decoding: lineData, as: UTF8.self)
                        let payloadText: String
                        if rawLine.hasPrefix("data:") {
                            payloadText = String(rawLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        } else {
                            payloadText = rawLine
                        }

                        if payloadText == "[DONE]" {
                            break
                        }

                        guard let payloadData = payloadText.data(using: .utf8),
                              let event = try? decoder.decode(HermesResponseStreamEvent.self, from: payloadData) else {
                            continue
                        }

                        responseID = event.response?.id ?? event.responseID ?? responseID

                        switch event.type {
                        case "response.output_text.delta", "response.delta", "output_text.delta":
                            if let delta = event.delta, !delta.isEmpty {
                                assembled.append(delta)
                                continuation.yield(.contentDelta(conversationID, assistantMessageID, assistantContentID, delta))
                            }

                        case "response.output_item.added", "response.output_item.updated":
                            if let item = event.item,
                               item.type == "tool_call" {
                                let toolContentID = item.id ?? UUID().uuidString
                                let toolMessage = Message(
                                    id: assistantMessageID,
                                    conversationID: conversationID,
                                    role: .assistant,
                                    content: [
                                        MessageContent(
                                            id: toolContentID,
                                            type: .tool,
                                            data: .tool(ToolContent(
                                                toolID: item.id ?? toolContentID,
                                                name: item.name ?? "tool",
                                                status: mapToolStatus(item.status),
                                                input: item.arguments,
                                                output: item.output,
                                                error: nil,
                                                duration: nil
                                            ))
                                        )
                                    ],
                                    createdAt: assistantMessage.createdAt,
                                    metadata: MessageMetadata()
                                )
                                replaceMessage(toolMessage)
                                continuation.yield(.messageUpdated(conversationID, toolMessage))
                            }

                        default:
                            break
                        }
                    }

                    if let responseID {
                        previousResponseIDs[conversationID] = responseID
                    }

                    let updatedAssistant = Message(
                        id: assistantMessageID,
                        conversationID: conversationID,
                        role: .assistant,
                        content: [MessageContent(id: assistantContentID, type: .text, data: .text(TextContent(text: assembled)))],
                        createdAt: assistantMessage.createdAt,
                        metadata: MessageMetadata()
                    )
                    replaceMessage(updatedAssistant)
                    continuation.yield(.messageUpdated(conversationID, updatedAssistant))
                    continuation.yield(.statusChanged(conversationID, .idle))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    do {
                        try await streamWithChatCompletionsFallback(
                            conversationID: conversationID,
                            content: content,
                            continuation: continuation
                        )
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: mapError(error))
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func abortMessage(conversationID: ConversationID) async throws {
        guard let responseID = previousResponseIDs[conversationID] else { return }
        let _: EmptyResponse = try await httpClient.post(path: "/v1/responses/\(responseID)/cancel", body: EmptyBody())
    }

    func eventStream() -> AsyncThrowingStream<ServerEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.connected)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    guard !Task.isCancelled else { break }
                    continuation.yield(.heartbeat)
                }
                continuation.yield(.disconnected(nil))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func streamWithChatCompletionsFallback(
        conversationID: ConversationID,
        content: [MessageContent],
        continuation: AsyncThrowingStream<ServerEvent, Error>.Continuation
    ) async throws {
        let prompt = flattenText(content)
        let fallbackRequest = HermesChatCompletionsRequest(
            model: "default",
            stream: true,
            messages: [HermesChatCompletionMessage(role: "user", content: prompt)]
        )
        let stream = httpClient.postStreaming(path: "/v1/chat/completions", body: fallbackRequest)

        let assistantMessageID = UUID().uuidString
        let assistantContentID = UUID().uuidString
        var assembled = ""

        let initialAssistant = Message(
            id: assistantMessageID,
            conversationID: conversationID,
            role: .assistant,
            content: [MessageContent(id: assistantContentID, type: .text, data: .text(TextContent(text: "")))],
            createdAt: .now,
            metadata: MessageMetadata()
        )
        appendMessage(initialAssistant)
        continuation.yield(.messageCreated(conversationID, initialAssistant))
        continuation.yield(.statusChanged(conversationID, .streaming))

        for try await lineData in stream {
            let rawLine = String(decoding: lineData, as: UTF8.self)
            let payloadText: String
            if rawLine.hasPrefix("data:") {
                payloadText = String(rawLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else {
                payloadText = rawLine
            }

            if payloadText == "[DONE]" { break }
            guard let data = payloadText.data(using: .utf8),
                  let chunk = try? decoder.decode(HermesChatCompletionChunk.self, from: data),
                  let delta = chunk.choices.first?.delta?.content,
                  !delta.isEmpty else {
                continue
            }

            assembled.append(delta)
            continuation.yield(.contentDelta(conversationID, assistantMessageID, assistantContentID, delta))
        }

        let finalAssistant = Message(
            id: assistantMessageID,
            conversationID: conversationID,
            role: .assistant,
            content: [MessageContent(id: assistantContentID, type: .text, data: .text(TextContent(text: assembled)))],
            createdAt: initialAssistant.createdAt,
            metadata: MessageMetadata()
        )
        replaceMessage(finalAssistant)
        continuation.yield(.messageUpdated(conversationID, finalAssistant))
        continuation.yield(.statusChanged(conversationID, .idle))
    }

    private func appendMessage(_ message: Message) {
        var list = messages[message.conversationID] ?? []
        if let index = list.firstIndex(where: { $0.id == message.id }) {
            list[index] = message
        } else {
            list.append(message)
        }
        messages[message.conversationID] = list
        if var conversation = conversations[message.conversationID] {
            conversation.updatedAt = .now
            conversations[message.conversationID] = conversation
        }
    }

    private func replaceMessage(_ message: Message) {
        appendMessage(message)
    }

    private func flattenText(_ content: [MessageContent]) -> String {
        content.compactMap { part in
            switch part.data {
            case .text(let value):
                return value.text
            case .reasoning(let value):
                return value.text
            case .error(let value):
                return "\(value.name): \(value.message)"
            case .file(let value):
                return value.content
            case .audio(let value):
                return value.transcript
            case .image(let value):
                return value.caption
            case .tool(let value):
                return value.input
            }
        }.joined(separator: "\n")
    }

    private func mapToolStatus(_ status: String?) -> ToolStatus {
        guard let status else { return .pending }
        switch status.lowercased() {
        case "running", "in_progress": return .running
        case "completed", "done", "success": return .completed
        case "failed", "error": return .failed
        default: return .pending
        }
    }

    private func mapError(_ error: Error) -> Error {
        if let error = error as? AgentPocketError { return error }
        return AgentPocketError.networkError(error)
    }
}
