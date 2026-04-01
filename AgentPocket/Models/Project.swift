import Foundation

struct Project: Codable, Identifiable, Hashable, Sendable {
    var id: ProjectID
    var worktree: String
    var name: String?
    var iconUrl: String?
    var iconColor: String?
    var commands: ProjectCommands?
    var sandboxes: [String]?
    var time: ProjectTime?

    enum CodingKeys: String, CodingKey {
        case id
        case worktree
        case name
        case iconUrl = "icon_url"
        case iconColor = "icon_color"
        case commands
        case sandboxes
        case time
    }
}

struct ProjectCommands: Codable, Hashable, Sendable {
    var start: String?
}

struct ProjectTime: Codable, Hashable, Sendable {
    var created: Double?
    var updated: Double?
    var initialized: Double?
}

struct Workspace: Codable, Identifiable, Hashable, Sendable {
    var id: WorkspaceID
    var type: String
    var branch: String?
    var name: String?
    var directory: String?
    var projectID: ProjectID

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case branch
        case name
        case directory
        case projectID = "project_id"
    }
}
