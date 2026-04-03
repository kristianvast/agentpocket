import Foundation

// MARK: - OpenClaw Socket Models

struct OpenClawSocketEnvelope: Codable, Sendable {
    let type: String
    let data: OpenClawSocketData?
}

struct OpenClawSocketData: Codable, Sendable {
    let conversationID: String?
    let messageID: String?
    let contentID: String?
    let role: String?
    let text: String?
    let delta: String?
    let status: String?
    let toolCall: OpenClawToolCall?
    let permission: OpenClawPermission?
    let message: OpenClawSocketMessage?
}

struct OpenClawSocketMessage: Codable, Sendable {
    let id: String
    let conversationID: String?
    let role: String
    let content: String?
    let createdAt: OpenCodeFlexibleDate?

    func asMessage(defaultConversationID: ConversationID) -> Message {
        Message(
            id: id,
            conversationID: conversationID ?? defaultConversationID,
            role: Self.mapRole(role),
            content: [
                MessageContent(
                    type: .text,
                    data: .text(TextContent(text: content ?? ""))
                )
            ],
            createdAt: createdAt?.value ?? .now,
            metadata: MessageMetadata()
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

struct OpenClawToolCall: Codable, Sendable {
    let id: String?
    let name: String?
    let input: String?
    let output: String?
    let status: String?

    func asToolContent() -> MessageContent {
        let contentID = id ?? UUID().uuidString
        return MessageContent(
            id: contentID,
            type: .tool,
            data: .tool(ToolContent(
                toolID: id ?? contentID,
                name: name ?? "tool",
                status: Self.mapStatus(status),
                input: input,
                output: output,
                error: nil,
                duration: nil
            ))
        )
    }

    private static func mapStatus(_ raw: String?) -> ToolStatus {
        guard let raw else { return .pending }
        switch raw.lowercased() {
        case "running", "in_progress": return .running
        case "completed", "done", "success": return .completed
        case "failed", "error": return .failed
        default: return .pending
        }
    }
}

struct OpenClawPermission: Codable, Sendable {
    let id: String
    let conversationID: String?
    let toolName: String?
    let description: String?
    let input: String?

    func asPermissionRequest() -> PermissionRequest {
        PermissionRequest(
            id: id,
            conversationID: conversationID ?? "",
            toolName: toolName ?? "tool",
            description: description ?? "Permission requested",
            input: input,
            createdAt: .now
        )
    }
}

// MARK: - OpenClaw WebSocket Requests

struct OpenClawSendSocketMessageRequest: Encodable, Sendable {
    let type: String
    let data: OpenClawSendSocketData
}

struct OpenClawSendSocketData: Encodable, Sendable {
    let conversationID: String
    let content: String
}

struct OpenClawPermissionReplySocketRequest: Encodable, Sendable {
    let type: String
    let data: OpenClawPermissionReplySocketData
}

struct OpenClawPermissionReplySocketData: Encodable, Sendable {
    let permissionID: String
    let allow: Bool
}

struct OpenClawAbortSocketRequest: Encodable, Sendable {
    let type: String
    let data: OpenClawAbortSocketData
}

struct OpenClawAbortSocketData: Encodable, Sendable {
    let conversationID: String
}

// MARK: - OpenClaw HTTP Fallback Models

struct OpenClawChatCompletionsRequest: Encodable, Sendable {
    let model: String
    let stream: Bool
    let messages: [OpenClawChatMessage]
}

struct OpenClawChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct OpenClawChatCompletionChunk: Decodable, Sendable {
    let choices: [OpenClawChoice]
}

struct OpenClawChoice: Decodable, Sendable {
    let delta: OpenClawDelta?
    let finishReason: String?
}

struct OpenClawDelta: Decodable, Sendable {
    let content: String?
}
