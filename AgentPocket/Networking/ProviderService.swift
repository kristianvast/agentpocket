import Foundation

struct ProviderService: Sendable {
    let client: HTTPClient

    func list() async throws -> ProviderListResponse {
        try await client.get(path: "/provider")
    }

    func authMethods() async throws -> [String: [ProviderAuthMethod]] {
        try await client.get(path: "/provider/auth")
    }

    func oauthAuthorize(providerID: String, method: Int, inputs: [String: String]?) async throws -> ProviderAuthorization? {
        try await client.post(path: "/provider/\(providerID)/oauth/authorize", body: OAuthAuthorizeRequest(method: method, inputs: inputs))
    }

    func oauthCallback(providerID: String, method: Int, code: String?) async throws -> Bool {
        let response: APIBoolResponse = try await client.post(path: "/provider/\(providerID)/oauth/callback", body: OAuthCallbackRequest(method: method, code: code))
        return response.value
    }
}

struct ProviderListResponse: Codable {
    var all: [Provider]?
    var `default`: [String: String]?
    var connected: [String]?
}

struct ProviderAuthMethod: Codable, Hashable {
    var type: String?
    var name: String?
}

struct ProviderAuthorization: Codable {
    var url: String?
}

private struct OAuthAuthorizeRequest: Encodable {
    var method: Int
    var inputs: [String: String]?
}

private struct OAuthCallbackRequest: Encodable {
    var method: Int
    var code: String?
}
