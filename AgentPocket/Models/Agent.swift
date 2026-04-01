import Foundation

struct AgentInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var description: String?
    var mode: AgentMode?
    var model: ModelReference?
    var prompt: String?
    var permission: [PermissionRule]?
    var temperature: Double?
    var color: String?
    var hidden: Bool?
}

enum AgentMode: String, Codable, Hashable, Sendable {
    case subagent
    case primary
    case all
}
