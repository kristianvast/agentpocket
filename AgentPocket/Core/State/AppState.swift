import Foundation
import SwiftUI
import UIKit

@Observable
@MainActor
final class AppState {
    var serverManager = ServerManager()
    var projectStore = ProjectStore()
    var conversationStore = ConversationStore()

    var activeServer: (any AgentServer)?
    var isConnected = false
    var isConnecting = false
    var connectionError: String?

    var pendingPermissions: [PermissionRequest] = []
    private(set) var isLoadingConversations = false
    private(set) var isLoadingProjects = false
    private(set) var loadingMessages: Set<ConversationID> = []

    var pendingAutoRecord = false
    var activityManager = AgentActivityManager()
    private(set) var isAutoRecording = false

    private var eventTask: Task<Void, Never>?
    private var autoRecorder = AudioRecorder()
    private var stopRecordingTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    init() {
        observeStopRecording()
    }

    func connect(to config: ServerConfig) async {
        isConnecting = true
        connectionError = nil

        let server = ServerFactory.create(for: config)

        do {
            try await server.connect()
            activeServer = server
            isConnected = true
            serverManager.markConnected(id: config.id)
            await loadProjects()
            startEventStream()

            if pendingAutoRecord {
                await triggerAutoRecordIfPending()
            }
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
        projectStore.clear()
        conversationStore.clear()
        pendingPermissions = []

        if isAutoRecording {
            cancelAutoRecord()
        }
    }

    func loadProjects() async {
        guard let server = activeServer else { return }

        isLoadingProjects = true
        do {
            let projects = try await server.listProjects()
            projectStore.setProjects(projects)
        } catch {
            projectStore.setProjects([])
        }
        isLoadingProjects = false
    }

    func selectProject(_ project: Project) async {
        projectStore.activeProjectID = project.id

        if conversationStore.loadedProjectID == project.id && !conversationStore.conversations.isEmpty {
            Task {
                await refreshConversationsForProject(project)
            }
            return
        }

        await loadConversationsForProject(project)
    }

    func loadConversationsForProject(_ project: Project) async {
        guard let server = activeServer else { return }

        isLoadingConversations = true
        do {
            let conversations = try await server.listConversations(forProject: project)
            conversationStore.setConversations(conversations, forProject: project.id)
        } catch {
            connectionError = "Failed to load sessions: \(error.localizedDescription)"
        }
        isLoadingConversations = false
    }

    private func refreshConversationsForProject(_ project: Project) async {
        guard let server = activeServer else { return }
        do {
            let conversations = try await server.listConversations(forProject: project)
            conversationStore.setConversations(conversations, forProject: project.id)
        } catch {
            // Silent fail on background refresh
        }
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
             if status == .idle {
                 conversationStore.flushAllDeltaBuffers()
                 conversationStore.clearStreamingTextForConversation(convID)
             }

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
        conversationStore.cleanupAbortedState(conversationID: conversationID)
    }

    func replyToPermission(id: PermissionID, allow: Bool) async throws {
        guard let server = activeServer else { throw AgentPocketError.notConnected }
        try await server.replyToPermission(id: id, allow: allow)
    }

    // MARK: - Auto-Record (Widget → Lock Screen Flow)

    func triggerAutoRecordIfPending() async {
        guard pendingAutoRecord else { return }
        pendingAutoRecord = false

        guard isConnected else { return }

        if projectStore.activeProjectID == nil, let first = projectStore.projects.first {
            await selectProject(first)
        }

        if conversationStore.activeConversationID == nil {
            if let latest = conversationStore.conversations.first {
                conversationStore.activeConversationID = latest.id
            } else {
                do {
                    let newConv = try await createConversation()
                    conversationStore.activeConversationID = newConv.id
                } catch {
                    return
                }
            }
        }

        guard let conversationID = conversationStore.activeConversationID else { return }

        await startAutoRecord(conversationID: conversationID)
    }

    private func startAutoRecord(conversationID: ConversationID) async {
        isAutoRecording = true
        autoRecorder.backgroundMode = true

        await autoRecorder.startRecording()

        guard autoRecorder.isRecording else {
            isAutoRecording = false
            autoRecorder.backgroundMode = false
            return
        }

        let serverName = serverManager.activeServer?.name ?? "Agent"
        let conversationTitle = conversationStore.activeConversation?.title ?? "New Session"

        activityManager.startRecording(
            serverName: serverName,
            conversationTitle: conversationTitle,
            conversationID: conversationID
        )
    }

    private func handleStopRecording() async {
        guard isAutoRecording else { return }

        autoRecorder.stopRecording()
        isAutoRecording = false

        guard let audioData = autoRecorder.audioData,
              let conversationID = conversationStore.activeConversationID else {
            activityManager.fail(message: "No audio recorded")
            autoRecorder.backgroundMode = false
            autoRecorder.deactivateSession()
            return
        }

        await sendAudioWithBackgroundTask(data: audioData, conversationID: conversationID)
    }

    private func cancelAutoRecord() {
        autoRecorder.cancelRecording()
        autoRecorder.backgroundMode = false
        isAutoRecording = false
        activityManager.endActivity()
    }

    private func sendAudioWithBackgroundTask(data: Data, conversationID: ConversationID) async {
        activityManager.transitionToProcessing()

        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor in
                self?.activityManager.fail(message: "Background time expired")
                self?.endBackgroundTask()
            }
        }

        let audioContent = MessageContent(
            type: .audio,
            data: .audio(AudioContent(data: data, mimeType: "audio/wav"))
        )

        let userMessage = Message(
            id: UUID().uuidString,
            conversationID: conversationID,
            role: .user,
            content: [audioContent]
        )
        conversationStore.addOrUpdateMessage(userMessage, for: conversationID)

        guard let server = activeServer else {
            activityManager.fail(message: "Not connected to server")
            endBackgroundTask()
            return
        }

        var responseText = ""
        let stream = server.sendMessage(conversationID: conversationID, content: [audioContent])

        do {
            for try await event in stream {
                handleEvent(event)

                if case .contentDelta(_, _, _, let delta) = event {
                    responseText += delta
                    activityManager.updateResponse(text: responseText)
                }
            }
            activityManager.complete(finalText: responseText)
        } catch {
            activityManager.fail(message: error.localizedDescription)

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

        autoRecorder.backgroundMode = false
        autoRecorder.deactivateSession()
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func observeStopRecording() {
        stopRecordingTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(named: SharedConstants.stopRecordingNotification)
            for await _ in notifications {
                guard !Task.isCancelled else { break }
                await self?.handleStopRecording()
            }
        }
    }
}
