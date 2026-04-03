import Foundation

@MainActor
final class OpenCodeServer: AgentServer {
    let serverType: ServerType = .openCode
    let capabilities = AgentCapabilities(
        supportsStreaming: true,
        supportsTools: true,
        supportsPermissions: true,
        supportsFileAccess: true,
        supportsTerminal: true,
        supportsAudioInput: false,
        supportsImageInput: true,
        supportsConversationHistory: true,
        supportsMCP: true,
        supportsMemory: false
    )

    private(set) var isConnected = false

    private let config: ServerConfig
    private let httpClient: HTTPClient
    private let sseClient: SSEClient
    private let decoder: JSONDecoder

    init(config: ServerConfig) {
        self.config = config
        self.httpClient = HTTPClient(baseURL: config.url, authorizationHeader: config.authorizationHeader)
        self.sseClient = SSEClient(baseURL: config.url, path: "/event", authorizationHeader: config.authorizationHeader)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func connect() async throws {
        do {
            _ = try await listConversations()
            isConnected = true
        } catch let error as AgentPocketError {
            throw error
        } catch {
            throw AgentPocketError.networkError(error)
        }
    }

    func disconnect() {
        isConnected = false
    }

    func listProjects() async throws -> [Project] {
        let response: OpenCodeProjectListResponse = try await httpClient.get(path: "/project")
        return response.projects.map { $0.asProject() }
    }

    func listConversations() async throws -> [Conversation] {
        let response: OpenCodeSessionListResponse = try await httpClient.get(path: "/session")
        return response.sessions.map { $0.asConversation() }
    }

    func listConversations(projectDirectory: String) async throws -> [Conversation] {
        let response: OpenCodeSessionListResponse = try await httpClient.get(
            path: "/session",
            queryItems: [URLQueryItem(name: "directory", value: projectDirectory)]
        )
        return response.sessions.map { $0.asConversation() }
    }

    func createConversation() async throws -> Conversation {
        let response: OpenCodeSessionCreateResponse = try await httpClient.post(path: "/session", body: EmptyBody())
        return response.session.asConversation()
    }

    func deleteConversation(id: ConversationID) async throws {
        let _: EmptyResponse = try await httpClient.delete(path: "/session/\(id)")
    }

    func listMessages(conversationID: ConversationID) async throws -> [Message] {
        let response: OpenCodeMessageListResponse = try await httpClient.get(path: "/session/\(conversationID)/message")
        return response.messages.map { $0.asMessage(conversationID: conversationID) }
    }

    func sendMessage(conversationID: ConversationID, content: [MessageContent]) -> AsyncThrowingStream<ServerEvent, Error> {
        let request = OpenCodeSendMessageRequest(parts: content.map { OpenCodeOutgoingPart.from($0) })

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let stream = httpClient.postStreaming(path: "/session/\(conversationID)/message", body: request)

                    for try await lineData in stream {
                        if Task.isCancelled { break }
                        guard !lineData.isEmpty else { continue }

                        let text = String(decoding: lineData, as: UTF8.self)
                        if text == "[DONE]" {
                            continuation.yield(.statusChanged(conversationID, .idle))
                            break
                        }

                        let payloadData: Data
                        if text.hasPrefix("data:") {
                            let trimmed = String(text.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            payloadData = Data(trimmed.utf8)
                        } else {
                            payloadData = lineData
                        }

                        if let mapped = try mapEventPayload(payloadData, fallbackConversationID: conversationID) {
                            continuation.yield(mapped)
                        } else if let response = try? decoder.decode(OpenCodePromptResponse.self, from: payloadData) {
                            let message = Message(
                                id: response.info.id,
                                conversationID: response.info.sessionID ?? conversationID,
                                role: OpenCodeMessage.mapRole(response.info.role),
                                content: response.parts.map { $0.asContent() },
                                createdAt: response.info.time?.created.map { Date(timeIntervalSince1970: $0 / 1000) } ?? .now,
                                metadata: MessageMetadata(
                                    agentName: response.info.agent,
                                    modelID: response.info.modelID,
                                    providerID: response.info.providerID,
                                    inputTokens: response.info.tokens?.input,
                                    outputTokens: response.info.tokens?.output,
                                    cost: response.info.cost,
                                    finishReason: response.info.finish
                                )
                            )
                            continuation.yield(.messageUpdated(conversationID, message))
                        }
                    }

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
        let _: EmptyResponse = try await httpClient.post(path: "/session/\(conversationID)/abort", body: EmptyBody())
    }

    func eventStream() -> AsyncThrowingStream<ServerEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.connected)
                    for try await sseEvent in sseClient.events() {
                        if Task.isCancelled { break }

                        if let mapped = try mapEventPayload(sseEvent.rawData, fallbackConversationID: "") {
                            continuation.yield(mapped)
                        } else if sseEvent.type == "heartbeat" {
                            continuation.yield(.heartbeat)
                        }
                    }
                    continuation.yield(.disconnected(nil))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.yield(.disconnected(error))
                    continuation.finish(throwing: mapError(error))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func replyToPermission(id: PermissionID, allow: Bool) async throws {
        let request = OpenCodePermissionReplyRequest(allow: allow)
        let _: EmptyResponse = try await httpClient.post(path: "/permission/\(id)", body: request)
    }

    private func mapEventPayload(_ data: Data, fallbackConversationID: ConversationID) throws -> ServerEvent? {
        if data.isEmpty { return nil }

        if let envelope = try? decoder.decode(OpenCodeEventEnvelope.self, from: data),
           let type = envelope.eventType?.lowercased() {
            switch type {
            case "session.created":
                if let session = envelope.eventSession {
                    return .conversationCreated(session.asConversation())
                }

            case "session.updated":
                if let session = envelope.eventSession {
                    return .conversationUpdated(session.asConversation())
                }

            case "session.deleted":
                if let sessionID = envelope.eventSessionID {
                    return .conversationDeleted(sessionID)
                }

            case "message.created", "message.updated":
                // Try legacy full message first
                if let message = envelope.eventMessage {
                    let conversationID = message.sessionID ?? envelope.eventSessionID ?? fallbackConversationID
                    return type == "message.created"
                        ? .messageCreated(conversationID, message.asMessage(conversationID: conversationID))
                        : .messageUpdated(conversationID, message.asMessage(conversationID: conversationID))
                }
                // v2: message info only (no parts) — create message with empty content
                if let info = envelope.eventMessageInfoV2 {
                    let conversationID = info.sessionID ?? envelope.eventSessionID ?? fallbackConversationID
                    let message = Message(
                        id: info.id,
                        conversationID: conversationID,
                        role: OpenCodeMessage.mapRole(info.role),
                        content: [],
                        createdAt: info.time?.created.map { Date(timeIntervalSince1970: $0 / 1000) } ?? .now,
                        metadata: MessageMetadata(
                            agentName: info.agent,
                            modelID: info.modelID,
                            providerID: info.providerID,
                            inputTokens: info.tokens?.input,
                            outputTokens: info.tokens?.output,
                            cost: info.cost,
                            finishReason: info.finish
                        )
                    )
                    return type == "message.created"
                        ? .messageCreated(conversationID, message)
                        : .messageUpdated(conversationID, message)
                }

            case "message.part.updated":
                if let part = envelope.eventPart {
                    let conversationID = envelope.eventSessionID ?? part.sessionID ?? fallbackConversationID
                    if let messageID = part.messageID ?? envelope.eventMessageID ?? part.id?.components(separatedBy: ":").first {
                        let content = part.asContent()
                        return .contentUpdated(conversationID, messageID, content)
                    }
                }

            case "message.deleted", "message.removed":
                if let conversationID = envelope.eventSessionID ?? (fallbackConversationID.isEmpty ? nil : fallbackConversationID),
                   let messageID = envelope.eventMessageID {
                    return .messageDeleted(conversationID, messageID)
                }

            case "message.part.delta", "text.delta", "message.delta":
                let conversationID = envelope.eventSessionID ?? fallbackConversationID
                if let messageID = envelope.eventMessageID,
                   let contentID = envelope.eventContentID,
                   let delta = envelope.eventDelta {
                    return .contentDelta(conversationID, messageID, contentID, delta)
                }

            case "tool.updated", "tool.status":
                let conversationID = envelope.eventSessionID ?? fallbackConversationID
                if let messageID = envelope.eventMessageID,
                   let contentID = envelope.eventContentID {
                    let status = mapToolStatus(envelope.eventStatus)
                    return .toolStatusChanged(conversationID, messageID, contentID, status)
                }

            case "permission.asked":
                if let permission = envelope.eventPermission {
                    return .permissionRequested(permission.asPermissionRequest())
                }

            case "permission.resolved":
                if let permissionID = envelope.eventPermissionID {
                    return .permissionResolved(permissionID)
                }

            case "session.status", "status.changed":
                if let conversationID = envelope.eventSessionID {
                    return .statusChanged(conversationID, OpenCodeSession.mapStatus(envelope.eventStatus))
                }

            case "heartbeat":
                return .heartbeat

            default:
                break
            }
            return nil
        }

        if let text = String(data: data, encoding: .utf8), text.lowercased() == "heartbeat" {
            return .heartbeat
        }

        return nil
    }

    private func mapToolStatus(_ status: String?) -> ToolStatus {
        guard let status else { return .pending }
        switch status.lowercased() {
        case "running", "in_progress": return .running
        case "completed", "complete", "done", "success": return .completed
        case "failed", "error": return .failed
        default: return .pending
        }
    }

    private func mapError(_ error: Error) -> Error {
        if let error = error as? AgentPocketError { return error }
        return AgentPocketError.networkError(error)
    }
}
