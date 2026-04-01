import Foundation

struct ServerEvent: Codable, Hashable, Sendable {
    var type: String
    var properties: AnyCodableValue
}

enum OpenCodeEvent: Codable, Hashable, Sendable {
    case serverConnected
    case serverHeartbeat
    case sessionCreated(SessionEventData)
    case sessionUpdated(SessionEventData)
    case sessionDeleted(SessionEventData)
    case sessionStatus(SessionStatusEventData)
    case messageUpdated(MessageEventData)
    case messageRemoved(MessageRemovedEventData)
    case messagePartUpdated(MessagePartEventData)
    case messagePartDelta(MessagePartDeltaEventData)
    case messagePartRemoved(MessagePartRemovedEventData)
    case permissionAsked(PermissionRequest)
    case permissionReplied(PermissionRepliedEventData)
    case questionAsked(QuestionRequest)
    case questionReplied(QuestionRepliedEventData)
    case todoUpdated(TodoEventData)
    case ptyCreated(PtyEventData)
    case ptyUpdated(PtyEventData)
    case ptyExited(PtyExitEventData)
    case ptyDeleted(PtyDeleteEventData)
    case projectUpdated(ProjectEventData)
    case lspUpdated
    case vcsBranchUpdated(VcsBranchEventData)
    case unknown(String)

    enum CodingKeys: String, CodingKey {
        case type
        case properties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let properties = try container.decodeIfPresent(AnyCodableValue.self, forKey: .properties) ?? .dictionary([:])

        switch type {
        case "server.connected":
            self = .serverConnected
        case "server.heartbeat":
            self = .serverHeartbeat
        case "session.created":
            self = .sessionCreated(try Self.decodeProperties(SessionEventData.self, from: properties))
        case "session.updated":
            self = .sessionUpdated(try Self.decodeProperties(SessionEventData.self, from: properties))
        case "session.deleted":
            self = .sessionDeleted(try Self.decodeProperties(SessionEventData.self, from: properties))
        case "session.status":
            self = .sessionStatus(try Self.decodeProperties(SessionStatusEventData.self, from: properties))
        case "message.updated":
            self = .messageUpdated(try Self.decodeProperties(MessageEventData.self, from: properties))
        case "message.removed":
            self = .messageRemoved(try Self.decodeProperties(MessageRemovedEventData.self, from: properties))
        case "message.part.updated":
            self = .messagePartUpdated(try Self.decodeProperties(MessagePartEventData.self, from: properties))
        case "message.part.delta":
            self = .messagePartDelta(try Self.decodeProperties(MessagePartDeltaEventData.self, from: properties))
        case "message.part.removed":
            self = .messagePartRemoved(try Self.decodeProperties(MessagePartRemovedEventData.self, from: properties))
        case "permission.asked":
            self = .permissionAsked(try Self.decodeProperties(PermissionRequest.self, from: properties))
        case "permission.replied":
            self = .permissionReplied(try Self.decodeProperties(PermissionRepliedEventData.self, from: properties))
        case "question.asked":
            self = .questionAsked(try Self.decodeProperties(QuestionRequest.self, from: properties))
        case "question.replied":
            self = .questionReplied(try Self.decodeProperties(QuestionRepliedEventData.self, from: properties))
        case "todo.updated":
            self = .todoUpdated(try Self.decodeProperties(TodoEventData.self, from: properties))
        case "pty.created":
            self = .ptyCreated(try Self.decodeProperties(PtyEventData.self, from: properties))
        case "pty.updated":
            self = .ptyUpdated(try Self.decodeProperties(PtyEventData.self, from: properties))
        case "pty.exited":
            self = .ptyExited(try Self.decodeProperties(PtyExitEventData.self, from: properties))
        case "pty.deleted":
            self = .ptyDeleted(try Self.decodeProperties(PtyDeleteEventData.self, from: properties))
        case "project.updated":
            self = .projectUpdated(try Self.decodeProperties(ProjectEventData.self, from: properties))
        case "lsp.updated":
            self = .lspUpdated
        case "vcs.branch.updated":
            self = .vcsBranchUpdated(try Self.decodeProperties(VcsBranchEventData.self, from: properties))
        default:
            self = .unknown(type)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .serverConnected:
            try container.encode("server.connected", forKey: .type)
            try container.encode(AnyCodableValue.dictionary([:]), forKey: .properties)
        case .serverHeartbeat:
            try container.encode("server.heartbeat", forKey: .type)
            try container.encode(AnyCodableValue.dictionary([:]), forKey: .properties)
        case .sessionCreated(let value):
            try container.encode("session.created", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .sessionUpdated(let value):
            try container.encode("session.updated", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .sessionDeleted(let value):
            try container.encode("session.deleted", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .sessionStatus(let value):
            try container.encode("session.status", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .messageUpdated(let value):
            try container.encode("message.updated", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .messageRemoved(let value):
            try container.encode("message.removed", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .messagePartUpdated(let value):
            try container.encode("message.part.updated", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .messagePartDelta(let value):
            try container.encode("message.part.delta", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .messagePartRemoved(let value):
            try container.encode("message.part.removed", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .permissionAsked(let value):
            try container.encode("permission.asked", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .permissionReplied(let value):
            try container.encode("permission.replied", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .questionAsked(let value):
            try container.encode("question.asked", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .questionReplied(let value):
            try container.encode("question.replied", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .todoUpdated(let value):
            try container.encode("todo.updated", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .ptyCreated(let value):
            try container.encode("pty.created", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .ptyUpdated(let value):
            try container.encode("pty.updated", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .ptyExited(let value):
            try container.encode("pty.exited", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .ptyDeleted(let value):
            try container.encode("pty.deleted", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .projectUpdated(let value):
            try container.encode("project.updated", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .lspUpdated:
            try container.encode("lsp.updated", forKey: .type)
            try container.encode(AnyCodableValue.dictionary([:]), forKey: .properties)
        case .vcsBranchUpdated(let value):
            try container.encode("vcs.branch.updated", forKey: .type)
            try container.encode(try Self.wrap(value), forKey: .properties)
        case .unknown(let raw):
            try container.encode(raw, forKey: .type)
            try container.encode(AnyCodableValue.dictionary([:]), forKey: .properties)
        }
    }

    private static func decodeProperties<T: Decodable>(_ type: T.Type, from value: AnyCodableValue) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func wrap<T: Encodable>(_ value: T) throws -> AnyCodableValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(AnyCodableValue.self, from: data)
    }
}

struct SessionEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var info: Session?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case info
    }
}

struct SessionStatusEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var status: SessionStatus

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case status
    }
}

struct MessageEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var info: Message

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case info
    }
}

struct MessageRemovedEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var messageID: MessageID

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case messageID = "message_id"
    }
}

struct MessagePartEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var part: MessagePart
    var time: Double?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case part
        case time
    }
}

struct MessagePartDeltaEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var messageID: MessageID
    var partID: PartID
    var field: String
    var delta: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case messageID = "message_id"
        case partID = "part_id"
        case field
        case delta
    }
}

struct MessagePartRemovedEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var messageID: MessageID
    var partID: PartID

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case messageID = "message_id"
        case partID = "part_id"
    }
}

struct PermissionRepliedEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var requestID: PermissionID
    var reply: PermissionReply

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case requestID = "request_id"
        case reply
    }
}

struct QuestionRepliedEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var requestID: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case requestID = "request_id"
    }
}

struct TodoEventData: Codable, Hashable, Sendable {
    var sessionID: SessionID
    var todos: [Todo]

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case todos
    }
}

struct PtyEventData: Codable, Hashable, Sendable {
    var info: PtyInfo
}

struct PtyExitEventData: Codable, Hashable, Sendable {
    var id: PtyID
    var exitCode: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case exitCode = "exit_code"
    }
}

struct PtyDeleteEventData: Codable, Hashable, Sendable {
    var id: PtyID
}

struct ProjectEventData: Codable, Hashable, Sendable {
    var id: ProjectID
    var name: String?
}

struct VcsBranchEventData: Codable, Hashable, Sendable {
    var branch: String
}
