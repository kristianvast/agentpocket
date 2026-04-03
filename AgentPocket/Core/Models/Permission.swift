import Foundation

// MARK: - Permission Request

struct PermissionRequest: Codable, Identifiable, Hashable, Sendable {
    let id: PermissionID
    var conversationID: ConversationID
    var toolName: String
    var description: String
    var input: String?
    var createdAt: Date

    init(
        id: PermissionID,
        conversationID: ConversationID,
        toolName: String,
        description: String,
        input: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.conversationID = conversationID
        self.toolName = toolName
        self.description = description
        self.input = input
        self.createdAt = createdAt
    }
}
