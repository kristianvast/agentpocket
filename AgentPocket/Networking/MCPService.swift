import Foundation

struct MCPService: Sendable {
    let client: HTTPClient

    func status() async throws -> [String: McpStatus] {
        try await client.get(path: "/mcp")
    }

    func add(name: String, config: [String: AnyCodableValue]) async throws -> [String: McpStatus] {
        try await client.post(path: "/mcp", body: MCPAddRequest(name: name, config: config))
    }

    func connect(name: String) async throws -> Bool {
        let response: APIBoolResponse = try await client.post(path: "/mcp/\(name)/connect", body: EmptyBody())
        return response.value
    }

    func disconnect(name: String) async throws -> Bool {
        let response: APIBoolResponse = try await client.post(path: "/mcp/\(name)/disconnect", body: EmptyBody())
        return response.value
    }
}

private struct MCPAddRequest: Encodable {
    var name: String
    var config: [String: AnyCodableValue]
}
