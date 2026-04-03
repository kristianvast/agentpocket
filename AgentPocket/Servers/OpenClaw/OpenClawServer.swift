import Foundation

@MainActor
final class OpenClawServer: AgentServer {
    let serverType: ServerType = .openClaw
    let capabilities = AgentCapabilities(
        supportsStreaming: true,
        supportsTools: true,
        supportsPermissions: true,
        supportsFileAccess: false,
        supportsTerminal: false,
        supportsAudioInput: true,
        supportsImageInput: true,
        supportsConversationHistory: true,
        supportsMCP: false,
        supportsMemory: false
    )

    private(set) var isConnected = false

    private let config: ServerConfig
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var webSocketClient: WebSocketClient?
    private var eventContinuations: [UUID: AsyncThrowingStream<ServerEvent, Error>.Continuation] = [:]

    private var conversations: [ConversationID: Conversation] = [:]
    private var messages: [ConversationID: [Message]] = [:]

    init(config: ServerConfig) {
        self.config = config
        self.httpClient = HTTPClient(baseURL: config.url, authorizationHeader: config.authorizationHeader)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func connect() async throws {
        guard let wsURL = makeWebSocketURL(from: config.url) else {
            throw AgentPocketError.invalidURL
        }

        let socket = WebSocketClient(url: wsURL, authorizationHeader: config.authorizationHeader)
        webSocketClient = socket

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false

            socket.onConnect = { [weak self] in
                guard let self, !resumed else { return }
                resumed = true
                self.isConnected = true
                self.broadcast(.connected)
                continuation.resume()
            }

            socket.onDisconnect = { [weak self] error in
                guard let self else { return }
                self.isConnected = false
                self.broadcast(.disconnected(error))
                guard !resumed else { return }
                resumed = true
                continuation.resume(throwing: self.mapError(error ?? AgentPocketError.notConnected))
            }

            socket.onMessage = { [weak self] incoming in
                guard let self else { return }
                Task { @MainActor in
                    self.handleIncomingWebSocketMessage(incoming)
                }
            }

            socket.connect()

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard let self, !resumed else { return }
                resumed = true
                self.isConnected = false
                continuation.resume(throwing: AgentPocketError.notConnected)
            }
        }
    }

    func disconnect() {
        webSocketClient?.disconnect()
        webSocketClient = nil
        isConnected = false
        broadcast(.disconnected(nil))
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
            metadata: ConversationMetadata(serverType: .openClaw)
        )
        conversations[id] = conversation
        messages[id] = []
        broadcast(.conversationCreated(conversation))
        return conversation
    }

    func deleteConversation(id: ConversationID) async throws {
        conversations.removeValue(forKey: id)
        messages.removeValue(forKey: id)
        broadcast(.conversationDeleted(id))
    }

    func listMessages(conversationID: ConversationID) async throws -> [Message] {
        messages[conversationID] ?? []
    }

    func sendMessage(conversationID: ConversationID, content: [MessageContent]) -> AsyncThrowingStream<ServerEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if conversations[conversationID] == nil {
                        let conversation = Conversation(id: conversationID, metadata: ConversationMetadata(serverType: .openClaw))
                        conversations[conversationID] = conversation
                        messages[conversationID] = []
                        continuation.yield(.conversationCreated(conversation))
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

                    if isConnected, let socket = webSocketClient {
                        let socketPayload = OpenClawSendSocketMessageRequest(
                            type: "chat.message",
                            data: OpenClawSendSocketData(conversationID: conversationID, content: prompt)
                        )
                        let json = try encoder.encode(socketPayload)
                        let text = String(decoding: json, as: UTF8.self)
                        try await socket.send(text)
                    }

                    let fallbackRequest = OpenClawChatCompletionsRequest(
                        model: "default",
                        stream: true,
                        messages: [OpenClawChatMessage(role: "user", content: prompt)]
                    )
                    let stream = httpClient.postStreaming(path: "/v1/chat/completions", body: fallbackRequest)

                    var assembled = ""

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

                        guard let data = payloadText.data(using: .utf8) else { continue }
                        guard let chunk = try? decoder.decode(OpenClawChatCompletionChunk.self, from: data) else { continue }

                        if let delta = chunk.choices.first?.delta?.content, !delta.isEmpty {
                            assembled.append(delta)
                            continuation.yield(.contentDelta(conversationID, assistantMessageID, assistantContentID, delta))
                        }
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
                    continuation.finish(throwing: mapError(error))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func abortMessage(conversationID: ConversationID) async throws {
        if let socket = webSocketClient, isConnected {
            let request = OpenClawAbortSocketRequest(
                type: "chat.abort",
                data: OpenClawAbortSocketData(conversationID: conversationID)
            )
            let data = try encoder.encode(request)
            try await socket.send(String(decoding: data, as: UTF8.self))
        }
    }

    func eventStream() -> AsyncThrowingStream<ServerEvent, Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            eventContinuations[id] = continuation

            if isConnected {
                continuation.yield(.connected)
            }

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.eventContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    func replyToPermission(id: PermissionID, allow: Bool) async throws {
        guard let socket = webSocketClient, isConnected else {
            throw AgentPocketError.notConnected
        }
        let request = OpenClawPermissionReplySocketRequest(
            type: "exec.approval.respond",
            data: OpenClawPermissionReplySocketData(permissionID: id, allow: allow)
        )
        let data = try encoder.encode(request)
        try await socket.send(String(decoding: data, as: UTF8.self))
        broadcast(.permissionResolved(id))
    }

    private func handleIncomingWebSocketMessage(_ message: WebSocketMessage) {
        let data: Data
        switch message {
        case .text(let text):
            data = Data(text.utf8)
        case .binary(let binary):
            data = binary
        }

        guard let envelope = try? decoder.decode(OpenClawSocketEnvelope.self, from: data) else {
            return
        }

        let type = envelope.type.lowercased()
        let payload = envelope.data

        switch type {
        case "chat.typing":
            if let conversationID = payload?.conversationID {
                broadcast(.statusChanged(conversationID, .streaming))
            }

        case "chat.message":
            if let rawMessage = payload?.message {
                let conversationID = rawMessage.conversationID ?? payload?.conversationID ?? ""
                let mapped = rawMessage.asMessage(defaultConversationID: conversationID)
                appendMessage(mapped)
                broadcast(.messageCreated(conversationID, mapped))
            }

        case "agent.event":
            if let conversationID = payload?.conversationID,
               let messageID = payload?.messageID,
               let contentID = payload?.contentID,
               let delta = payload?.delta {
                broadcast(.contentDelta(conversationID, messageID, contentID, delta))
            }

            if let conversationID = payload?.conversationID,
               let messageID = payload?.messageID,
               let toolCall = payload?.toolCall {
                let toolContent = toolCall.asToolContent()
                let toolMessage = Message(
                    id: messageID,
                    conversationID: conversationID,
                    role: .assistant,
                    content: [toolContent],
                    createdAt: .now,
                    metadata: MessageMetadata()
                )
                appendMessage(toolMessage)
                broadcast(.messageUpdated(conversationID, toolMessage))
                if case .tool(let toolData) = toolContent.data {
                    broadcast(.toolStatusChanged(conversationID, messageID, toolContent.id, toolData.status))
                }
            }

        case "exec.approval.requested":
            if let permission = payload?.permission {
                broadcast(.permissionRequested(permission.asPermissionRequest()))
            }

        default:
            break
        }
    }

    private func appendMessage(_ message: Message) {
        var list = messages[message.conversationID] ?? []
        if let index = list.firstIndex(where: { $0.id == message.id }) {
            list[index] = message
        } else {
            list.append(message)
        }
        messages[message.conversationID] = list
        updateConversationTimestamp(message.conversationID)
    }

    private func replaceMessage(_ message: Message) {
        appendMessage(message)
    }

    private func updateConversationTimestamp(_ conversationID: ConversationID) {
        guard var conversation = conversations[conversationID] else { return }
        conversation.updatedAt = .now
        conversations[conversationID] = conversation
        broadcast(.conversationUpdated(conversation))
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

    private func makeWebSocketURL(from baseURL: String) -> URL? {
        guard var components = URLComponents(string: baseURL) else {
            return nil
        }

        if components.scheme == "https" {
            components.scheme = "wss"
        } else if components.scheme == "http" {
            components.scheme = "ws"
        }

        let normalized = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = normalized + "/ws"
        return components.url
    }

    private func broadcast(_ event: ServerEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func mapError(_ error: Error) -> Error {
        if let error = error as? AgentPocketError { return error }
        return AgentPocketError.networkError(error)
    }
}
