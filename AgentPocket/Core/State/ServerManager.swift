import Foundation
import Observation

@MainActor
@Observable
final class ServerManager {
    var servers: [ServerConfig] = []
    var activeServerID: ServerID?
    var hasCompletedOnboarding: Bool = false

    private let defaults: UserDefaults
    private let storageKey = "agentpocket_servers_v2"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var activeServer: ServerConfig? {
        guard let id = activeServerID else { return nil }
        return servers.first { $0.id == id }
    }

    func add(_ server: ServerConfig) {
        servers.removeAll { $0.id == server.id }
        servers.append(server)
        if activeServerID == nil {
            activeServerID = server.id
        }
        save()
    }

    func update(_ server: ServerConfig) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[index] = server
        save()
    }

    func delete(id: ServerID) {
        servers.removeAll { $0.id == id }
        if activeServerID == id {
            activeServerID = servers.first?.id
        }
        save()
    }

    func markConnected(id: ServerID) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[index].lastConnected = Date()
        activeServerID = id
        save()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        save()
    }

    func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            servers = []
            activeServerID = nil
            hasCompletedOnboarding = false
            return
        }

        if let state = try? decoder.decode(PersistedState.self, from: data) {
            servers = state.servers
            activeServerID = state.activeServerID
            hasCompletedOnboarding = state.hasCompletedOnboarding ?? false
        } else {
            servers = []
            activeServerID = nil
            hasCompletedOnboarding = false
        }
    }

    func save() {
        let state = PersistedState(servers: servers, activeServerID: activeServerID, hasCompletedOnboarding: hasCompletedOnboarding)
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private struct PersistedState: Codable {
    var servers: [ServerConfig]
    var activeServerID: ServerID?
    var hasCompletedOnboarding: Bool?
}
