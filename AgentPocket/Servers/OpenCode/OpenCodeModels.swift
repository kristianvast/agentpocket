import Foundation

// MARK: - OpenCode Project Models

struct OpenCodeProjectListResponse: Decodable, Sendable {
    let projects: [OpenCodeProject]

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let projects = try? container.decode([OpenCodeProject].self) {
            self.projects = projects
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.projects =
            (try? container.decode([OpenCodeProject].self, forKey: .projects))
            ?? (try? container.decode([OpenCodeProject].self, forKey: .data))
            ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case projects
        case data
    }
}

struct OpenCodeProject: Codable, Sendable, Hashable {
    let id: String
    let worktree: String
    let vcs: String?
    let name: String?
    let icon: OpenCodeProjectIcon?
    let time: OpenCodeProjectTime?
    let sandboxes: [String]?

    func asProject() -> Project {
        Project(
            id: id,
            worktree: worktree,
            name: name,
            icon: icon.map { ProjectIcon(url: $0.url, color: $0.color) },
            time: ProjectTime(
                created: time?.created.map { Date(timeIntervalSince1970: $0 / 1000) } ?? .now,
                updated: time?.updated.map { Date(timeIntervalSince1970: $0 / 1000) } ?? .now,
                initialized: time?.initialized.map { Date(timeIntervalSince1970: $0 / 1000) }
            )
        )
    }
}

struct OpenCodeProjectIcon: Codable, Sendable, Hashable {
    let url: String?
    let override: String?
    let color: String?

    enum CodingKeys: String, CodingKey {
        case url
        case override = "override"
        case color
    }
}

struct OpenCodeProjectTime: Codable, Sendable, Hashable {
    let created: Double?
    let updated: Double?
    let initialized: Double?
}

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

struct OpenCodeSessionTime: Codable, Sendable, Hashable {
    let created: Double?
    let updated: Double?
    let compacting: Double?
    let archived: Double?
}

struct OpenCodeSessionSummary: Codable, Sendable, Hashable {
    let additions: Int?
    let deletions: Int?
    let files: Int?
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

    // v2 fields from OpenCode API
    let projectID: String?
    let directory: String?
    let slug: String?
    let version: String?
    let parentID: String?
    let time: OpenCodeSessionTime?
    let summary: OpenCodeSessionSummary?

    var resolvedCreatedAt: Date {
        if let ms = time?.created {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        return createdAt?.value ?? .now
    }

    var resolvedUpdatedAt: Date {
        if let ms = time?.updated {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        return updatedAt?.value ?? createdAt?.value ?? .now
    }

    func asConversation() -> Conversation {
        Conversation(
            id: id,
            title: title,
            createdAt: resolvedCreatedAt,
            updatedAt: resolvedUpdatedAt,
            status: Self.mapStatus(status),
            metadata: ConversationMetadata(
                serverType: .openCode,
                agentName: agentName,
                modelName: modelName,
                totalTokens: totalTokens,
                totalCost: totalCost,
                projectID: projectID,
                directory: directory,
                slug: slug,
                version: version,
                summary: summary.map {
                    SessionSummary(
                        additions: $0.additions ?? 0,
                        deletions: $0.deletions ?? 0,
                        files: $0.files ?? 0
                    )
                }
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
        // Try v2 format: bare array of {info, parts}
        if let container = try? decoder.singleValueContainer(),
           let v2 = try? container.decode([OpenCodePromptResponse].self) {
            self.messages = v2.map { OpenCodeMessage.fromV2($0) }
            return
        }

        // Try old format: bare array of flat messages
        if let container = try? decoder.singleValueContainer(),
           let messages = try? container.decode([OpenCodeMessage].self) {
            self.messages = messages
            return
        }

        // Keyed: { messages: [...] } or { data: [...] }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let v2 = try? container.decode([OpenCodePromptResponse].self, forKey: .messages) {
            self.messages = v2.map { OpenCodeMessage.fromV2($0) }
        } else if let v2 = try? container.decode([OpenCodePromptResponse].self, forKey: .data) {
            self.messages = v2.map { OpenCodeMessage.fromV2($0) }
        } else {
            self.messages =
                (try? container.decode([OpenCodeMessage].self, forKey: .messages))
                ?? (try? container.decode([OpenCodeMessage].self, forKey: .data))
                ?? []
        }
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

    static func fromV2(_ response: OpenCodePromptResponse) -> OpenCodeMessage {
        OpenCodeMessage(
            id: response.info.id,
            sessionID: response.info.sessionID,
            role: response.info.role,
            createdAt: response.info.time?.created.map { OpenCodeFlexibleDate(value: Date(timeIntervalSince1970: $0 / 1000)) },
            parts: response.parts,
            agentName: response.info.agent,
            modelID: response.info.modelID,
            providerID: response.info.providerID,
            inputTokens: response.info.tokens?.input,
            outputTokens: response.info.tokens?.output,
            cost: response.info.cost,
            finishReason: response.info.finish
        )
    }

    static func mapRole(_ raw: String) -> MessageRole {
        switch raw.lowercased() {
        case "assistant", "agent": return .assistant
        case "system": return .system
        default: return .user
        }
    }
}

struct OpenCodeMessagePart: Codable, Sendable, Hashable {
    let id: String?
    let messageID: String?
    let sessionID: String?
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
    let parts: [OpenCodeOutgoingPart]
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

// MARK: - OpenCode v2 Message Info (from events and REST API)

struct OpenCodeMessageInfoV2: Decodable, Sendable {
    let id: String
    let role: String
    let sessionID: String?
    let modelID: String?
    let providerID: String?
    let time: OpenCodeTimeV2?
    let cost: Double?
    let tokens: OpenCodeTokensV2?
    let agent: String?
    let finish: String?
    let parentID: String?
}

struct OpenCodeTimeV2: Decodable, Sendable {
    let created: Double?
    let completed: Double?
}

struct OpenCodeTokensV2: Decodable, Sendable {
    let input: Int?
    let output: Int?
    let reasoning: Int?
}

struct OpenCodePromptResponse: Decodable, Sendable {
    let info: OpenCodeMessageInfoV2
    let parts: [OpenCodeMessagePart]
}

// MARK: - OpenCode Event Properties (v2 envelope)

struct OpenCodeEventProperties: Decodable, Sendable {
    let sessionID: String?
    let messageID: String?
    let partID: String?
    let field: String?
    let delta: String?
    let status: OpenCodeEventStatusPayload?
    let part: OpenCodeMessagePart?
    let time: Double?

    // info is polymorphic — session for session.* events, message for message.* events
    let sessionInfo: OpenCodeSession?
    let messageInfo: OpenCodeMessageInfoV2?

    enum CodingKeys: String, CodingKey {
        case sessionID, messageID, partID, field, delta, status, part, time, info
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        messageID = try container.decodeIfPresent(String.self, forKey: .messageID)
        partID = try container.decodeIfPresent(String.self, forKey: .partID)
        field = try container.decodeIfPresent(String.self, forKey: .field)
        delta = try container.decodeIfPresent(String.self, forKey: .delta)
        status = try container.decodeIfPresent(OpenCodeEventStatusPayload.self, forKey: .status)
        part = try container.decodeIfPresent(OpenCodeMessagePart.self, forKey: .part)
        time = try container.decodeIfPresent(Double.self, forKey: .time)

        // Try message info first (has required `role` field, more restrictive)
        if let msg = try? container.decode(OpenCodeMessageInfoV2.self, forKey: .info) {
            messageInfo = msg
            sessionInfo = nil
        } else {
            messageInfo = nil
            sessionInfo = try? container.decode(OpenCodeSession.self, forKey: .info)
        }
    }
}

struct OpenCodeEventStatusPayload: Decodable, Sendable {
    let type: String?
}

struct OpenCodeEventEnvelope: Decodable, Sendable {
    let type: String?
    let event: String?
    let properties: OpenCodeEventProperties?
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
        properties?.sessionInfo ?? session ?? data?.session
    }

    var eventMessage: OpenCodeMessage? {
        message ?? data?.message
    }

    var eventMessageInfoV2: OpenCodeMessageInfoV2? {
        properties?.messageInfo
    }

    var eventPermission: OpenCodePermission? {
        permission ?? data?.permission
    }

    var eventSessionID: String? {
        properties?.sessionID ?? sessionID ?? data?.sessionID ?? eventSession?.id ?? eventMessage?.sessionID ?? eventMessageInfoV2?.sessionID
    }

    var eventMessageID: String? {
        properties?.messageID ?? messageID ?? data?.messageID ?? eventMessage?.id ?? eventMessageInfoV2?.id
    }

    var eventContentID: String? {
        properties?.partID ?? contentID ?? data?.contentID
    }

    var eventPermissionID: String? {
        permissionID ?? data?.permissionID ?? eventPermission?.id
    }

    var eventDelta: String? {
        properties?.delta ?? delta ?? data?.delta
    }

    var eventStatus: String? {
        properties?.status?.type ?? status ?? data?.status
    }

    var eventPart: OpenCodeMessagePart? {
        properties?.part
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

    init(value: Date) {
        self.value = value
    }

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
    nonisolated(unsafe) static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
