import Foundation

// MARK: - Server Type

enum ServerType: String, Codable, Hashable, Sendable, CaseIterable {
    case openCode = "opencode"
    case openClaw = "openclaw"
    case hermes = "hermes"

    var displayName: String {
        switch self {
        case .openCode: return "OpenCode"
        case .openClaw: return "OpenClaw"
        case .hermes: return "Hermes"
        }
    }

    var iconSystemName: String {
        switch self {
        case .openCode: return "chevron.left.forwardslash.chevron.right"
        case .openClaw: return "hand.raised.fingers.spread"
        case .hermes: return "brain.head.profile"
        }
    }
}

// MARK: - Capabilities

struct AgentCapabilities: Codable, Hashable, Sendable {
    var supportsStreaming: Bool = true
    var supportsTools: Bool = false
    var supportsPermissions: Bool = false
    var supportsFileAccess: Bool = false
    var supportsTerminal: Bool = false
    var supportsAudioInput: Bool = false
    var supportsImageInput: Bool = false
    var supportsConversationHistory: Bool = true
    var supportsMCP: Bool = false
    var supportsMemory: Bool = false
}

// MARK: - Server Events

enum ServerEvent: Sendable {
    case connected
    case disconnected(Error?)
    case conversationCreated(Conversation)
    case conversationUpdated(Conversation)
    case conversationDeleted(ConversationID)
    case messageCreated(ConversationID, Message)
    case messageUpdated(ConversationID, Message)
    case messageDeleted(ConversationID, MessageID)
    case contentDelta(ConversationID, MessageID, ContentID, String)
    case contentUpdated(ConversationID, MessageID, MessageContent)
    case toolStatusChanged(ConversationID, MessageID, ContentID, ToolStatus)
    case permissionRequested(PermissionRequest)
    case permissionResolved(PermissionID)
    case statusChanged(ConversationID, ConversationStatus)
    case heartbeat
}

// MARK: - Agent Server Protocol

@MainActor
protocol AgentServer: AnyObject, Sendable {
    var serverType: ServerType { get }
    var capabilities: AgentCapabilities { get }
    var isConnected: Bool { get }

    // Lifecycle
    func connect() async throws
    func disconnect()

    // Projects
    func listProjects() async throws -> [Project]
    func listConversations(projectDirectory: String) async throws -> [Conversation]

    // Conversations
    func listConversations() async throws -> [Conversation]
    func createConversation() async throws -> Conversation
    func deleteConversation(id: ConversationID) async throws

    // Messages
    func listMessages(conversationID: ConversationID) async throws -> [Message]
    func sendMessage(
        conversationID: ConversationID,
        content: [MessageContent]
    ) -> AsyncThrowingStream<ServerEvent, Error>
    func abortMessage(conversationID: ConversationID) async throws

    // Events
    func eventStream() -> AsyncThrowingStream<ServerEvent, Error>

    // Optional — permissions
    func replyToPermission(id: PermissionID, allow: Bool) async throws

    // Optional — tools/files/terminal are server-specific extensions
}

// MARK: - Default Implementations

extension AgentServer {
    func listProjects() async throws -> [Project] {
        []
    }

    func listConversations(projectDirectory: String) async throws -> [Conversation] {
        try await listConversations()
    }

    func replyToPermission(id: PermissionID, allow: Bool) async throws {
        throw AgentPocketError.unsupported("Permissions not supported by \(serverType.displayName)")
    }
}

// MARK: - Error Types

enum AgentPocketError: Error, LocalizedError {
    case notConnected
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)
    case decodingError(Error)
    case invalidURL
    case unsupported(String)
    case authenticationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to server"
        case .serverError(let code, let message):
            return "Server error \(code): \(message ?? "Unknown")"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid server URL"
        case .unsupported(let feature):
            return feature
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        }
    }
}
