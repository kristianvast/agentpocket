import Foundation

struct ConfigService: Sendable {
    let client: HTTPClient

    func get() async throws -> AppConfig {
        try await client.get(path: "/config")
    }

    func update(config: AppConfig) async throws -> AppConfig {
        try await client.put(path: "/config", body: config)
    }

    func providers() async throws -> ConfigProvidersResponse {
        try await client.get(path: "/config/providers")
    }
}

struct ConfigProvidersResponse: Codable {
    var providers: [Provider]?
    var `default`: [String: String]?
}
