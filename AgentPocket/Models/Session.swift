import Foundation

typealias SessionID = String
typealias ProjectID = String
typealias WorkspaceID = String

struct Session: Codable, Identifiable, Hashable, Sendable {
    let id: SessionID
    var slug: String
    var projectID: ProjectID
    var workspaceID: WorkspaceID?
    var parentID: SessionID?
    var directory: String
    var title: String
    var version: String
    var summary: SessionSummary?
    var share: SessionShare?
    var revert: SessionRevert?
    var time: SessionTime

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case projectID = "project_id"
        case workspaceID = "workspace_id"
        case parentID = "parent_id"
        case directory
        case title
        case version
        case summary
        case share
        case revert
        case time
    }
}

struct SessionSummary: Codable, Hashable, Sendable {
    var additions: Int
    var deletions: Int
    var files: Int
    var diffs: [FileDiff]?
}

struct SessionShare: Codable, Hashable, Sendable {
    var url: String
}

struct SessionRevert: Codable, Hashable, Sendable {
    var messageID: MessageID?
    var partID: String?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case partID = "part_id"
    }
}

struct SessionTime: Codable, Hashable, Sendable {
    var created: Double
    var updated: Double?
    var compacting: Double?
    var archived: Double?
}

enum SessionStatusType: String, Codable, Hashable, Sendable {
    case idle
    case busy
}

struct SessionStatus: Codable, Hashable, Sendable {
    var type: SessionStatusType
    var attempt: Int?
    var message: String?
    var next: Double?
}
