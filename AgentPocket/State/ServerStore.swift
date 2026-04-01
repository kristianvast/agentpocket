import Foundation
import Observation

@MainActor
@Observable
final class ServerStore {
    var servers: [ServerConfig] = []
    var activeServerID: UUID?

    private let defaults: UserDefaults
    private let key = "agentpocket_servers"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
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
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else {
            return
        }
        servers[index] = server
        save()
    }

    func delete(id: UUID) {
        servers.removeAll { $0.id == id }
        if activeServerID == id {
            activeServerID = servers.first?.id
        }
        save()
    }

    func markConnected(id: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else {
            return
        }
        servers[index].lastConnected = Date()
        activeServerID = id
        save()
    }

    func load() {
        guard let data = defaults.data(forKey: key) else {
            servers = []
            activeServerID = nil
            return
        }

        if let state = try? decoder.decode(PersistedState.self, from: data) {
            servers = state.servers
            activeServerID = state.activeServerID
        } else if let savedServers = try? decoder.decode([ServerConfig].self, from: data) {
            servers = savedServers
            activeServerID = savedServers.first?.id
        } else {
            servers = []
            activeServerID = nil
        }
    }

    func save() {
        let state = PersistedState(servers: servers, activeServerID: activeServerID)
        guard let data = try? encoder.encode(state) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

private struct PersistedState: Codable {
    var servers: [ServerConfig]
    var activeServerID: UUID?
}
