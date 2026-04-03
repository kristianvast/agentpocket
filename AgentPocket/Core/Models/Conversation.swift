import Foundation

// MARK: - Conversation

struct Conversation: Codable, Identifiable, Hashable, Sendable {
    let id: ConversationID
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var status: ConversationStatus
    var metadata: ConversationMetadata

    init(
        id: ConversationID,
        title: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        status: ConversationStatus = .idle,
        metadata: ConversationMetadata = ConversationMetadata()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.metadata = metadata
    }
}

// MARK: - Status

enum ConversationStatus: String, Codable, Hashable, Sendable {
    case idle
    case streaming
    case toolRunning = "tool_running"
    case waitingPermission = "waiting_permission"
    case error
}

// MARK: - Metadata

struct ConversationMetadata: Codable, Hashable, Sendable {
    var serverType: ServerType?
    var agentName: String?
    var modelName: String?
    var totalTokens: Int?
    var totalCost: Double?

    init(
        serverType: ServerType? = nil,
        agentName: String? = nil,
        modelName: String? = nil,
        totalTokens: Int? = nil,
        totalCost: Double? = nil
    ) {
        self.serverType = serverType
        self.agentName = agentName
        self.modelName = modelName
        self.totalTokens = totalTokens
        self.totalCost = totalCost
    }
}
