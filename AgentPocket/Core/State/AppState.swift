import Foundation
import SwiftUI

@Observable
@MainActor
final class AppState {
    var serverManager = ServerManager()
    var conversationStore = ConversationStore()

    var activeServer: (any AgentServer)?
    var isConnected = false
    var isConnecting = false
    var connectionError: String?

    var pendingPermissions: [PermissionRequest] = []
    private(set) var isLoadingConversations = false
    private(set) var loadingMessages: Set<ConversationID> = []

    private var eventTask: Task<Void, Never>?

    func connect(to config: ServerConfig) async {
        isConnecting = true
        connectionError = nil

        let server = ServerFactory.create(for: config)

        do {
            try await server.connect()
            activeServer = server
            isConnected = true
            serverManager.markConnected(id: config.id)
            await loadInitialData()
            startEventStream()
        } catch {
            connectionError = error.localizedDescription
            isConnected = false
        }

        isConnecting = false
    }

    func disconnect() {
        eventTask?.cancel()
        eventTask = nil
        activeServer?.disconnect()
        activeServer = nil
        isConnected = false
        conversationStore.clear()
        pendingPermissions = []
    }

    func loadInitialData() async {
        guard let server = activeServer else { return }

        isLoadingConversations = true
        do {
            let conversations = try await server.listConversations()
            conversationStore.conversations = conversations
        } catch {
            connectionError = "Failed to load conversations: \(error.localizedDescription)"
        }
        isLoadingConversations = false
    }

    func startEventStream() {
        guard let server = activeServer else { return }

        eventTask?.cancel()
        eventTask = Task { [weak self] in
            do {
                for try await event in server.eventStream() {
                    guard let self, !Task.isCancelled else { break }
                    self.handleEvent(event)
                }
            } catch {
                if !Task.isCancelled {
                    self?.connectionError = "Event stream disconnected"
                    self?.isConnected = false
                }
            }
        }
    }

    private func handleEvent(_ event: ServerEvent) {
        switch event {
        case .connected:
            isConnected = true
            connectionError = nil

        case .disconnected:
            isConnected = false

        case .conversationCreated(let conversation):
            if !conversationStore.conversations.contains(where: { $0.id == conversation.id }) {
                conversationStore.conversations.insert(conversation, at: 0)
            }

        case .conversationUpdated(let conversation):
            conversationStore.updateConversation(conversation)

        case .conversationDeleted(let id):
            conversationStore.conversations.removeAll { $0.id == id }
            conversationStore.messages.removeValue(forKey: id)

        case .messageCreated(let convID, let message),
             .messageUpdated(let convID, let message):
            conversationStore.addOrUpdateMessage(message, for: convID)

        case .messageDeleted(let convID, let msgID):
            conversationStore.removeMessage(messageID: msgID, conversationID: convID)

        case .contentDelta(let convID, let msgID, let contentID, let delta):
            conversationStore.applyDelta(
                conversationID: convID,
                messageID: msgID,
                contentID: contentID,
                delta: delta
            )

        case .contentUpdated(let convID, let msgID, let content):
            conversationStore.updateContent(content, messageID: msgID, conversationID: convID)

        case .toolStatusChanged(let convID, let msgID, let contentID, let status):
            if let msgIdx = conversationStore.messages[convID]?.firstIndex(where: { $0.id == msgID }),
               let contentIdx = conversationStore.messages[convID]?[msgIdx].content.firstIndex(where: { $0.id == contentID }),
               case .tool(var toolData) = conversationStore.messages[convID]?[msgIdx].content[contentIdx].data {
                toolData.status = status
                conversationStore.messages[convID]?[msgIdx].content[contentIdx].data = .tool(toolData)
            }

        case .permissionRequested(let request):
            if !pendingPermissions.contains(where: { $0.id == request.id }) {
                pendingPermissions.append(request)
            }

        case .permissionResolved(let id):
            pendingPermissions.removeAll { $0.id == id }

        case .statusChanged(let convID, let status):
            conversationStore.statuses[convID] = status

        case .heartbeat:
            break
        }
    }

    func createConversation() async throws -> Conversation {
        guard let server = activeServer else { throw AgentPocketError.notConnected }
        let conversation = try await server.createConversation()
        conversationStore.conversations.insert(conversation, at: 0)
        return conversation
    }

    func deleteConversation(id: ConversationID) async throws {
        guard let server = activeServer else { throw AgentPocketError.notConnected }
        try await server.deleteConversation(id: id)
        conversationStore.conversations.removeAll { $0.id == id }
        conversationStore.messages.removeValue(forKey: id)
    }

    func loadMessages(for conversationID: ConversationID) async throws {
        guard let server = activeServer else { throw AgentPocketError.notConnected }
        loadingMessages.insert(conversationID)
        defer { loadingMessages.remove(conversationID) }
        let msgs = try await server.listMessages(conversationID: conversationID)
        conversationStore.setMessages(msgs, for: conversationID)
    }

    func sendMessage(conversationID: ConversationID, content: [MessageContent]) async {
        guard let server = activeServer else { return }
        let stream = server.sendMessage(conversationID: conversationID, content: content)
        do {
            for try await event in stream {
                handleEvent(event)
            }
        } catch {
            let errorContent = MessageContent(
                type: .error,
                data: .error(ErrorContent(
                    name: "SendError",
                    message: error.localizedDescription,
                    isRetryable: true
                ))
            )
            let errorMessage = Message(
                id: UUID().uuidString,
                conversationID: conversationID,
                role: .assistant,
                content: [errorContent]
            )
            conversationStore.addOrUpdateMessage(errorMessage, for: conversationID)
        }
    }

    func abortMessage(conversationID: ConversationID) async throws {
        guard let server = activeServer else { throw AgentPocketError.notConnected }
        try await server.abortMessage(conversationID: conversationID)
    }

    func replyToPermission(id: PermissionID, allow: Bool) async throws {
        guard let server = activeServer else { throw AgentPocketError.notConnected }
        try await server.replyToPermission(id: id, allow: allow)
    }
}
