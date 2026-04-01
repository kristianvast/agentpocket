import Foundation

struct ServerConfig: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var url: String
    var username: String?
    var password: String?
    var createdAt: Date
    var lastConnected: Date?

    var authorizationHeader: String? {
        guard let username, let password else { return nil }
        let credentials = "\(username):\(password)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }
}

struct AppConfig: Codable, Hashable, Sendable {
    var version: String?
    var providers: [Provider]?
    var commands: [CommandInfo]?
    var skills: [SkillInfo]?
    var agents: [AgentInfo]?
    var permissions: [PermissionRule]?
    var lsp: [LspStatus]?
    var paths: PathInfo?
    var vcs: VcsInfo?
    var mcp: [McpStatus]?
}

struct Todo: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(sessionID ?? "global")-\(index ?? -1)" }
    var sessionID: SessionID?
    var index: Int?
    var content: String
    var status: TodoStatus
    var priority: TodoPriority?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case index
        case content
        case status
        case priority
    }
}

enum TodoStatus: String, Codable, Hashable, Sendable {
    case pending
    case in_progress
    case completed
    case cancelled
}

enum TodoPriority: String, Codable, Hashable, Sendable {
    case high
    case medium
    case low
}

struct HealthResponse: Codable, Sendable {
    var healthy: Bool
    var version: String?
}

struct CommandInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var description: String?
    var shortcut: String?
    var group: String?
}

struct SkillInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var description: String?
}

struct LspStatus: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var root: String?
    var status: String?
}

struct PathInfo: Codable, Hashable, Sendable {
    var home: String?
    var state: String?
    var config: String?
    var worktree: String?
    var directory: String?
}

struct VcsInfo: Codable, Hashable, Sendable {
    var branch: String?
}

struct McpStatus: Codable, Hashable, Sendable {
    var name: String?
    var status: String?
    var tools: [McpTool]?
    var error: String?
}

struct McpTool: Codable, Hashable, Identifiable, Sendable {
    var id: String { name }
    var name: String
    var description: String?
}

struct QuestionRequest: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var sessionID: SessionID
    var question: String
    var options: [QuestionOption]?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case question
        case options
    }
}

struct QuestionOption: Codable, Hashable, Sendable {
    var label: String
    var description: String?
    var value: String?
}
