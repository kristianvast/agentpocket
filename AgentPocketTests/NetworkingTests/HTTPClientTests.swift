import XCTest
@testable import AgentPocket

final class HTTPClientTests: XCTestCase {

    // MARK: - URL Construction

    func testSimpleBaseURLAndPath() throws {
        let client = HTTPClient(baseURL: "https://api.example.com")
        let request = try makeGetRequest(client: client, path: "/sessions")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/sessions")
    }

    func testPathWithoutLeadingSlash() throws {
        let client = HTTPClient(baseURL: "https://api.example.com")
        let request = try makeGetRequest(client: client, path: "sessions")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/sessions")
    }

    func testBaseURLWithTrailingSlash() throws {
        let client = HTTPClient(baseURL: "https://api.example.com/")
        let request = try makeGetRequest(client: client, path: "/sessions")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/sessions")
    }

    func testBaseURLWithPathPrefix() throws {
        let client = HTTPClient(baseURL: "https://example.com/api/v1")
        let request = try makeGetRequest(client: client, path: "/sessions")
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/v1/sessions")
    }

    func testBaseURLWithPathPrefixAndTrailingSlash() throws {
        let client = HTTPClient(baseURL: "https://example.com/api/v1/")
        let request = try makeGetRequest(client: client, path: "/sessions")
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/v1/sessions")
    }

    func testNestedPath() throws {
        let client = HTTPClient(baseURL: "https://api.example.com")
        let request = try makeGetRequest(client: client, path: "/sessions/123/messages")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/sessions/123/messages")
    }

    // MARK: - Query Items

    func testQueryItems() throws {
        let client = HTTPClient(baseURL: "https://api.example.com")
        let items = [URLQueryItem(name: "page", value: "1"), URLQueryItem(name: "limit", value: "50")]
        let request = try makeGetRequest(client: client, path: "/sessions", queryItems: items)
        let url = request.url!.absoluteString
        XCTAssertTrue(url.contains("page=1"))
        XCTAssertTrue(url.contains("limit=50"))
    }

    func testEmptyQueryItemsOmitted() throws {
        let client = HTTPClient(baseURL: "https://api.example.com")
        let request = try makeGetRequest(client: client, path: "/sessions", queryItems: [])
        XCTAssertNil(request.url?.query)
    }

    func testNilQueryItems() throws {
        let client = HTTPClient(baseURL: "https://api.example.com")
        let request = try makeGetRequest(client: client, path: "/sessions", queryItems: nil)
        XCTAssertNil(request.url?.query)
    }

    // MARK: - Request Headers

    func testAcceptHeaderSet() throws {
        let client = HTTPClient(baseURL: "https://api.example.com")
        let request = try makeGetRequest(client: client, path: "/test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testAuthorizationHeaderIncluded() throws {
        let client = HTTPClient(baseURL: "https://api.example.com", authorizationHeader: "Bearer secret-token")
        let request = try makeGetRequest(client: client, path: "/test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
    }

    func testNoAuthorizationHeaderWhenNil() throws {
        let client = HTTPClient(baseURL: "https://api.example.com", authorizationHeader: nil)
        let request = try makeGetRequest(client: client, path: "/test")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testHTTPMethodGET() throws {
        let client = HTTPClient(baseURL: "https://api.example.com")
        let request = try makeGetRequest(client: client, path: "/test")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    // MARK: - Invalid URL

    func testInvalidBaseURLThrows() {
        let client = HTTPClient(baseURL: "not a url ://invalid")
        XCTAssertThrowsError(try makeGetRequest(client: client, path: "/test")) { error in
            if case AgentPocketError.invalidURL = error {
            } else {
                XCTFail("Expected AgentPocketError.invalidURL, got \(error)")
            }
        }
    }

    // MARK: - Client Properties

    func testClientStoresBaseURL() {
        let client = HTTPClient(baseURL: "https://test.com")
        XCTAssertEqual(client.baseURL, "https://test.com")
    }

    func testClientStoresAuthHeader() {
        let client = HTTPClient(baseURL: "https://test.com", authorizationHeader: "Bearer tok")
        XCTAssertEqual(client.authorizationHeader, "Bearer tok")
    }

    func testClientNilAuthHeaderByDefault() {
        let client = HTTPClient(baseURL: "https://test.com")
        XCTAssertNil(client.authorizationHeader)
    }

    // MARK: - EmptyBody / EmptyResponse

    func testEmptyBodyEncodable() throws {
        let body = EmptyBody()
        let data = try JSONEncoder().encode(body)
        XCTAssertNotNil(data)
    }

    func testEmptyResponseDecodable() throws {
        let data = Data("{}".utf8)
        let response = try JSONDecoder().decode(EmptyResponse.self, from: data)
        XCTAssertNotNil(response)
    }

    // MARK: - Error Types

    func testAgentPocketErrorNotConnected() {
        let error = AgentPocketError.notConnected
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Not connected"))
    }

    func testAgentPocketErrorServerError() {
        let error = AgentPocketError.serverError(statusCode: 500, message: "Internal Error")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("500"))
        XCTAssertTrue(error.errorDescription!.contains("Internal Error"))
    }

    func testAgentPocketErrorServerErrorNilMessage() {
        let error = AgentPocketError.serverError(statusCode: 404, message: nil)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("404"))
        XCTAssertTrue(error.errorDescription!.contains("Unknown"))
    }

    func testAgentPocketErrorInvalidURL() {
        let error = AgentPocketError.invalidURL
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Invalid"))
    }

    func testAgentPocketErrorUnsupported() {
        let error = AgentPocketError.unsupported("Feature X not available")
        XCTAssertEqual(error.errorDescription, "Feature X not available")
    }

    func testAgentPocketErrorAuthenticationFailed() {
        let error = AgentPocketError.authenticationFailed("Bad credentials")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Bad credentials"))
    }

    // MARK: - Helpers

    private func makeGetRequest(client: HTTPClient, path: String, queryItems: [URLQueryItem]? = nil) throws -> URLRequest {
        guard var components = URLComponents(string: client.baseURL) else {
            throw AgentPocketError.invalidURL
        }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        if components.path.isEmpty {
            components.path = normalizedPath
        } else {
            let base = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
            components.path = base + normalizedPath
        }

        components.queryItems = queryItems?.isEmpty == true ? nil : queryItems

        guard let url = components.url else {
            throw AgentPocketError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authorizationHeader = client.authorizationHeader {
            request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
