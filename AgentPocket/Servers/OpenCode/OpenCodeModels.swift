import Foundation

// MARK: - OpenCode Session Models

struct OpenCodeSessionListResponse: Decodable, Sendable {
    let sessions: [OpenCodeSession]

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let sessions = try? container.decode([OpenCodeSession].self) {
            self.sessions = sessions
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sessions =
            (try? container.decode([OpenCodeSession].self, forKey: .sessions))
            ?? (try? container.decode([OpenCodeSession].self, forKey: .data))
            ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case sessions
        case data
    }
}

struct OpenCodeSessionCreateResponse: Decodable, Sendable {
    let session: OpenCodeSession

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let session = try? container.decode(OpenCodeSession.self) {
            self.session = session
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let session = try? container.decode(OpenCodeSession.self, forKey: .session) {
            self.session = session
            return
        }
        if let session = try? container.decode(OpenCodeSession.self, forKey: .data) {
            self.session = session
            return
        }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Missing session payload"))
    }

    private enum CodingKeys: String, CodingKey {
        case session
        case data
    }
}

struct OpenCodeSession: Codable, Sendable, Hashable {
    let id: String
    let title: String?
    let createdAt: OpenCodeFlexibleDate?
    let updatedAt: OpenCodeFlexibleDate?
    let status: String?
    let agentName: String?
    let modelName: String?
    let totalTokens: Int?
    let totalCost: Double?

    func asConversation() -> Conversation {
        Conversation(
            id: id,
            title: title,
            createdAt: createdAt?.value ?? .now,
            updatedAt: updatedAt?.value ?? createdAt?.value ?? .now,
            status: Self.mapStatus(status),
            metadata: ConversationMetadata(
                serverType: .openCode,
                agentName: agentName,
                modelName: modelName,
                totalTokens: totalTokens,
                totalCost: totalCost
            )
        )
    }

    static func mapStatus(_ raw: String?) -> ConversationStatus {
        guard let raw else { return .idle }
        switch raw.lowercased() {
        case "streaming", "running": return .streaming
        case "tool_running", "tool-running", "tool": return .toolRunning
        case "waiting_permission", "waiting-permission", "permission": return .waitingPermission
        case "error", "failed": return .error
        default: return .idle
        }
    }
}

// MARK: - OpenCode Message Models

struct OpenCodeMessageListResponse: Decodable, Sendable {
    let messages: [OpenCodeMessage]

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let messages = try? container.decode([OpenCodeMessage].self) {
            self.messages = messages
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.messages =
            (try? container.decode([OpenCodeMessage].self, forKey: .messages))
            ?? (try? container.decode([OpenCodeMessage].self, forKey: .data))
            ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case messages
        case data
    }
}

struct OpenCodeMessage: Codable, Sendable, Hashable {
    let id: String
    let sessionID: String?
    let role: String
    let createdAt: OpenCodeFlexibleDate?
    let parts: [OpenCodeMessagePart]
    let agentName: String?
    let modelID: String?
    let providerID: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let cost: Double?
    let finishReason: String?

    func asMessage(conversationID fallbackConversationID: ConversationID) -> Message {
        Message(
            id: id,
            conversationID: sessionID ?? fallbackConversationID,
            role: Self.mapRole(role),
            content: parts.map { $0.asContent() },
            createdAt: createdAt?.value ?? .now,
            metadata: MessageMetadata(
                agentName: agentName,
                modelID: modelID,
                providerID: providerID,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cost: cost,
                finishReason: finishReason
            )
        )
    }

    private static func mapRole(_ raw: String) -> MessageRole {
        switch raw.lowercased() {
        case "assistant", "agent": return .assistant
        case "system": return .system
        default: return .user
        }
    }
}

struct OpenCodeMessagePart: Codable, Sendable, Hashable {
    let id: String?
    let type: String
    let text: String?
    let name: String?
    let toolID: String?
    let status: String?
    let input: String?
    let output: String?
    let error: String?
    let duration: Double?
    let path: String?
    let mimeType: String?
    let content: String?
    let language: String?
    let size: Int?
    let isRedacted: Bool?
    let tokenCount: Int?

    func asContent() -> MessageContent {
        let contentID = id ?? UUID().uuidString
        switch type.lowercased() {
        case "text", "text_delta", "message":
            return MessageContent(id: contentID, type: .text, data: .text(TextContent(text: text ?? content ?? "")))
        case "reasoning":
            return MessageContent(
                id: contentID,
                type: .reasoning,
                data: .reasoning(ReasoningContent(text: text ?? content ?? "", isRedacted: isRedacted ?? false, tokenCount: tokenCount))
            )
        case "file":
            return MessageContent(
                id: contentID,
                type: .file,
                data: .file(FileContent(path: path ?? "", mimeType: mimeType, content: content, language: language, size: size))
            )
        case "tool", "tool_call", "tool_use":
            return MessageContent(
                id: contentID,
                type: .tool,
                data: .tool(ToolContent(
                    toolID: toolID ?? contentID,
                    name: name ?? "tool",
                    status: Self.mapToolStatus(status),
                    input: input,
                    output: output,
                    error: error,
                    duration: duration
                ))
            )
        case "error":
            return MessageContent(
                id: contentID,
                type: .error,
                data: .error(ErrorContent(name: name ?? "ServerError", message: error ?? text ?? content ?? "Unknown error", isRetryable: true))
            )
        default:
            return MessageContent(id: contentID, type: .text, data: .text(TextContent(text: text ?? content ?? "")))
        }
    }

    private static func mapToolStatus(_ raw: String?) -> ToolStatus {
        guard let raw else { return .pending }
        switch raw.lowercased() {
        case "running", "in_progress": return .running
        case "completed", "complete", "done", "success": return .completed
        case "failed", "error": return .failed
        default: return .pending
        }
    }
}

// MARK: - OpenCode Requests

struct OpenCodeSendMessageRequest: Encodable, Sendable {
    let content: [OpenCodeOutgoingPart]
}

struct OpenCodeOutgoingPart: Encodable, Sendable {
    let type: String
    let text: String?
    let url: String?
    let mimeType: String?
    let path: String?
    let content: String?

    static func from(_ input: MessageContent) -> OpenCodeOutgoingPart {
        switch input.data {
        case .text(let value):
            return .init(type: "text", text: value.text, url: nil, mimeType: nil, path: nil, content: nil)
        case .image(let value):
            return .init(type: "image", text: value.caption, url: value.url, mimeType: value.mimeType, path: nil, content: nil)
        case .audio(let value):
            return .init(type: "audio", text: value.transcript, url: value.url, mimeType: value.mimeType, path: nil, content: nil)
        case .file(let value):
            return .init(type: "file", text: nil, url: nil, mimeType: value.mimeType, path: value.path, content: value.content)
        case .reasoning(let value):
            return .init(type: "reasoning", text: value.text, url: nil, mimeType: nil, path: nil, content: nil)
        case .tool(let value):
            return .init(type: "tool", text: value.input, url: nil, mimeType: nil, path: nil, content: nil)
        case .error(let value):
            return .init(type: "text", text: "\(value.name): \(value.message)", url: nil, mimeType: nil, path: nil, content: nil)
        }
    }
}

struct OpenCodePermissionReplyRequest: Encodable, Sendable {
    let allow: Bool
}

// MARK: - OpenCode Event Models

struct OpenCodeEventEnvelope: Decodable, Sendable {
    let type: String?
    let event: String?
    let data: OpenCodeEventData?
    let session: OpenCodeSession?
    let message: OpenCodeMessage?
    let permission: OpenCodePermission?
    let sessionID: String?
    let messageID: String?
    let contentID: String?
    let permissionID: String?
    let delta: String?
    let status: String?

    var eventType: String? {
        type ?? event ?? data?.type
    }

    var eventSession: OpenCodeSession? {
        session ?? data?.session
    }

    var eventMessage: OpenCodeMessage? {
        message ?? data?.message
    }

    var eventPermission: OpenCodePermission? {
        permission ?? data?.permission
    }

    var eventSessionID: String? {
        sessionID ?? data?.sessionID ?? eventSession?.id ?? eventMessage?.sessionID
    }

    var eventMessageID: String? {
        messageID ?? data?.messageID ?? eventMessage?.id
    }

    var eventContentID: String? {
        contentID ?? data?.contentID
    }

    var eventPermissionID: String? {
        permissionID ?? data?.permissionID ?? eventPermission?.id
    }

    var eventDelta: String? {
        delta ?? data?.delta
    }

    var eventStatus: String? {
        status ?? data?.status
    }
}

struct OpenCodeEventData: Decodable, Sendable {
    let type: String?
    let session: OpenCodeSession?
    let message: OpenCodeMessage?
    let permission: OpenCodePermission?
    let sessionID: String?
    let messageID: String?
    let contentID: String?
    let permissionID: String?
    let delta: String?
    let status: String?
}

struct OpenCodePermission: Codable, Sendable, Hashable {
    let id: String
    let sessionID: String?
    let toolName: String?
    let description: String?
    let input: String?
    let createdAt: OpenCodeFlexibleDate?

    func asPermissionRequest() -> PermissionRequest {
        PermissionRequest(
            id: id,
            conversationID: sessionID ?? "",
            toolName: toolName ?? "tool",
            description: description ?? "Permission requested",
            input: input,
            createdAt: createdAt?.value ?? .now
        )
    }
}

// MARK: - Shared

struct OpenCodeFlexibleDate: Codable, Hashable, Sendable {
    let value: Date

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let seconds = try? container.decode(Double.self) {
            self.value = Date(timeIntervalSince1970: seconds)
            return
        }
        if let secondsInt = try? container.decode(Int.self) {
            self.value = Date(timeIntervalSince1970: TimeInterval(secondsInt))
            return
        }
        if let raw = try? container.decode(String.self), let date = OpenCodeFlexibleDate.parse(raw) {
            self.value = date
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date format")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.timeIntervalSince1970)
    }

    private static func parse(_ input: String) -> Date? {
        if let interval = TimeInterval(input) {
            return Date(timeIntervalSince1970: interval)
        }
        if let date = ISO8601DateFormatter.full.date(from: input) {
            return date
        }
        return ISO8601DateFormatter.fractional.date(from: input)
    }
}

private extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
