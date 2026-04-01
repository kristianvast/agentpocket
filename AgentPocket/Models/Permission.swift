import Foundation

typealias PermissionID = String

struct PermissionRule: Codable, Hashable, Sendable {
    var permission: String
    var pattern: String
    var action: PermissionAction
}

enum PermissionAction: String, Codable, Hashable, Sendable {
    case allow
    case deny
    case ask
}

struct PermissionRequest: Codable, Identifiable, Hashable, Sendable {
    var id: PermissionID
    var sessionID: SessionID
    var permission: String
    var patterns: [String]
    var metadata: [String: AnyCodableValue]?
    var always: [String]?
    var tool: PermissionTool?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case permission
        case patterns
        case metadata
        case always
        case tool
    }
}

struct PermissionTool: Codable, Hashable, Sendable {
    var messageID: MessageID
    var callID: String

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case callID = "call_id"
    }
}

enum PermissionReply: String, Codable, Hashable, Sendable {
    case once
    case always
    case reject
}
