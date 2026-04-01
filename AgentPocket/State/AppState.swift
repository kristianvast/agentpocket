import Foundation
import SwiftUI

@Observable
@MainActor
final class AppState {
    var client: OpenCodeClient?
    var serverStore = ServerStore()
    var sessionStore = SessionStore()

    var isConnected = false
    var connectionError: String?
    var isConnecting = false

    var pendingPermissions: [PermissionRequest] = []
    var pendingQuestions: [QuestionRequest] = []
    var todos: [SessionID: [Todo]] = [:]

    var projects: [Project] = []
    var currentProject: Project?
    var workspaces: [Workspace] = []

    var agents: [AgentInfo] = []
    var commands: [CommandInfo] = []
    var skills: [SkillInfo] = []

    var providers: [Provider] = []
    var connectedProviderIDs: [String] = []
    var defaultModels: [String: String] = [:]

    var sessionStatuses: [SessionID: SessionStatus] = [:]
    var ptyList: [PtyInfo] = []

    var currentBranch: String?

    private var eventTask: Task<Void, Never>?
    private var eventReducer = EventReducer()

    var activeServer: ServerConfig? {
        guard let id = serverStore.activeServerID else { return nil }
        return serverStore.servers.first { $0.id == id }
    }

    func connect(to server: ServerConfig) async {
        isConnecting = true
        connectionError = nil

        let auth = server.authorizationHeader
        let newClient = OpenCodeClient(baseURL: server.url, authorization: auth)

        do {
            _ = try await newClient.checkHealth()
            client = newClient
            isConnected = true
            serverStore.activeServerID = server.id
            serverStore.markConnected(id: server.id)

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
        client = nil
        isConnected = false
        sessionStore.clear()
        pendingPermissions = []
        pendingQuestions = []
        todos = [:]
        projects = []
        providers = []
        ptyList = []
        sessionStatuses = [:]
    }

    func loadInitialData() async {
        guard let client else { return }

        async let sessionsResult = client.sessions.list()
        async let projectsResult = client.projects()
        async let providersResult = client.providers.list()
        async let agentsResult = client.agents()
        async let commandsResult = client.commands()
        async let skillsResult = client.skills()
        async let ptyResult = client.pty.list()
        async let vcsResult = client.vcsInfo()

        do {
            let (sessions, projects, providerResponse, agents, commands, skills, ptys, vcs) = try await (
                sessionsResult, projectsResult, providersResult, agentsResult, commandsResult, skillsResult, ptyResult, vcsResult
            )

            sessionStore.sessions = sessions
            self.projects = projects
            self.providers = providerResponse.all ?? []
            self.connectedProviderIDs = providerResponse.connected ?? []
            self.defaultModels = providerResponse.default ?? [:]
            self.agents = agents
            self.commands = commands
            self.skills = skills
            self.ptyList = ptys
            self.currentBranch = vcs.branch

            if let current = try? await client.currentProject() {
                self.currentProject = current
            }
        } catch {
            connectionError = "Failed to load initial data: \(error.localizedDescription)"
        }
    }

    func startEventStream() {
        guard let client else { return }

        eventTask?.cancel()
        eventTask = Task { [weak self] in
            do {
                for try await event in client.eventStream.events() {
                    guard let self, !Task.isCancelled else { break }
                    self.eventReducer.reduce(event: event, state: self)
                }
            } catch {
                if !Task.isCancelled {
                    self?.connectionError = "Event stream disconnected"
                    self?.isConnected = false
                }
            }
        }
    }

    func createSession() async throws -> Session {
        guard let client else { throw OpenCodeError.notConnected }
        let session = try await client.sessions.create()
        sessionStore.sessions.insert(session, at: 0)
        return session
    }

    func deleteSession(id: SessionID) async throws {
        guard let client else { throw OpenCodeError.notConnected }
        _ = try await client.sessions.delete(id: id)
        sessionStore.sessions.removeAll { $0.id == id }
        sessionStore.messages.removeValue(forKey: id)
    }

    func loadMessages(for sessionID: SessionID) async throws {
        guard let client else { throw OpenCodeError.notConnected }
        let messagesWithParts = try await client.sessions.messages(id: sessionID)
        sessionStore.setMessages(messagesWithParts, for: sessionID)
    }

    func sendMessage(sessionID: SessionID, text: String, model: ModelReference?, agent: String?) async {
        guard let client else { return }
        let parts = [PromptPart(type: "text", text: text, file: nil)]
        let stream = client.sessions.sendMessage(sessionID: sessionID, parts: parts, model: model, agent: agent)
        do {
            for try await _ in stream {
            }
        } catch {
        }
    }

    func abortSession(id: SessionID) async throws {
        guard let client else { throw OpenCodeError.notConnected }
        _ = try await client.sessions.abort(id: id)
    }

    func forkSession(id: SessionID, messageID: MessageID?) async throws -> Session {
        guard let client else { throw OpenCodeError.notConnected }
        return try await client.sessions.fork(id: id, messageID: messageID)
    }

    func revertSession(id: SessionID, messageID: MessageID) async throws -> Session {
        guard let client else { throw OpenCodeError.notConnected }
        return try await client.sessions.revert(id: id, messageID: messageID)
    }

    func unrevertSession(id: SessionID) async throws -> Session {
        guard let client else { throw OpenCodeError.notConnected }
        return try await client.sessions.unrevert(id: id)
    }

    func replyToPermission(id: PermissionID, reply: PermissionReply) async throws {
        guard let client else { throw OpenCodeError.notConnected }
        _ = try await client.permissions.reply(id: id, reply: reply)
    }

    func replyToQuestion(id: String, answers: [String]) async throws {
        guard let client else { throw OpenCodeError.notConnected }
        _ = try await client.questions.reply(id: id, answers: answers)
    }

    func rejectQuestion(id: String) async throws {
        guard let client else { throw OpenCodeError.notConnected }
        _ = try await client.questions.reject(id: id)
    }

    func createPTY(title: String? = nil) async throws -> PtyInfo {
        guard let client else { throw OpenCodeError.notConnected }
        let pty = try await client.pty.create(command: nil, args: nil, cwd: nil, title: title)
        ptyList.append(pty)
        return pty
    }

    func removePTY(id: PtyID) async throws {
        guard let client else { throw OpenCodeError.notConnected }
        _ = try await client.pty.remove(id: id)
        ptyList.removeAll { $0.id == id }
    }

    func createPTYWebSocket(ptyID: PtyID) -> PTYWebSocket? {
        client?.createPTYWebSocket(ptyID: ptyID)
    }
}

extension OpenCodeError {
    static let notConnected = OpenCodeError.networkError(
        NSError(
            domain: "AgentPocket",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Not connected to server"]
        )
    )
}
