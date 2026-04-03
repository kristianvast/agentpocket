import XCTest
@testable import AgentPocket

final class ServerConfigTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - ServerConfig Codable

    func testServerConfigRoundTrip() throws {
        let id = UUID()
        let config = ServerConfig(
            id: id,
            name: "My Server",
            url: "https://example.com",
            serverType: .openCode,
            auth: .bearerToken("tok-123"),
            lastConnected: Date(timeIntervalSince1970: 1_000_000),
            isDefault: true
        )

        let data = try encoder.encode(config)
        let decoded = try decoder.decode(ServerConfig.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.name, "My Server")
        XCTAssertEqual(decoded.url, "https://example.com")
        XCTAssertEqual(decoded.serverType, .openCode)
        XCTAssertEqual(decoded.isDefault, true)
    }

    func testServerConfigDefaults() {
        let config = ServerConfig(name: "Test", url: "https://test.com", serverType: .hermes)
        XCTAssertEqual(config.auth, .none)
        XCTAssertNil(config.lastConnected)
        XCTAssertFalse(config.isDefault)
    }

    // MARK: - Authorization Header

    func testAuthorizationHeaderNone() {
        let config = ServerConfig(name: "S", url: "http://x", serverType: .openCode, auth: .none)
        XCTAssertNil(config.authorizationHeader)
    }

    func testAuthorizationHeaderBearer() {
        let config = ServerConfig(name: "S", url: "http://x", serverType: .openCode, auth: .bearerToken("my-token"))
        XCTAssertEqual(config.authorizationHeader, "Bearer my-token")
    }

    func testAuthorizationHeaderBasic() {
        let config = ServerConfig(name: "S", url: "http://x", serverType: .openCode, auth: .basic(username: "user", password: "pass"))
        let expected = "Basic " + Data("user:pass".utf8).base64EncodedString()
        XCTAssertEqual(config.authorizationHeader, expected)
    }

    func testAuthorizationHeaderBasicSpecialCharacters() {
        let config = ServerConfig(name: "S", url: "http://x", serverType: .openCode, auth: .basic(username: "admin@org", password: "p@ss:word!"))
        let expected = "Basic " + Data("admin@org:p@ss:word!".utf8).base64EncodedString()
        XCTAssertEqual(config.authorizationHeader, expected)
    }

    func testAuthorizationHeaderDeviceToken() {
        let config = ServerConfig(name: "S", url: "http://x", serverType: .openCode, auth: .deviceToken("device-tok-abc"))
        XCTAssertEqual(config.authorizationHeader, "Bearer device-tok-abc")
    }

    // MARK: - ServerAuth Codable

    func testServerAuthNoneRoundTrip() throws {
        let auth = ServerAuth.none
        let data = try encoder.encode(auth)
        let decoded = try decoder.decode(ServerAuth.self, from: data)
        XCTAssertEqual(decoded, .none)
    }

    func testServerAuthBearerRoundTrip() throws {
        let auth = ServerAuth.bearerToken("secret-token")
        let data = try encoder.encode(auth)
        let decoded = try decoder.decode(ServerAuth.self, from: data)
        XCTAssertEqual(decoded, .bearerToken("secret-token"))
    }

    func testServerAuthBasicRoundTrip() throws {
        let auth = ServerAuth.basic(username: "admin", password: "hunter2")
        let data = try encoder.encode(auth)
        let decoded = try decoder.decode(ServerAuth.self, from: data)
        XCTAssertEqual(decoded, .basic(username: "admin", password: "hunter2"))
    }

    func testServerAuthDeviceRoundTrip() throws {
        let auth = ServerAuth.deviceToken("dev-abc")
        let data = try encoder.encode(auth)
        let decoded = try decoder.decode(ServerAuth.self, from: data)
        XCTAssertEqual(decoded, .deviceToken("dev-abc"))
    }

    func testServerAuthEncodesTypeField() throws {
        let auth = ServerAuth.bearerToken("tok")
        let data = try encoder.encode(auth)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["type"] as? String, "bearer")
        XCTAssertEqual(json?["token"] as? String, "tok")
    }

    func testServerAuthBasicEncodesUsernamePassword() throws {
        let auth = ServerAuth.basic(username: "u", password: "p")
        let data = try encoder.encode(auth)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["type"] as? String, "basic")
        XCTAssertEqual(json?["username"] as? String, "u")
        XCTAssertEqual(json?["password"] as? String, "p")
    }

    func testServerAuthNoneEncodesOnlyType() throws {
        let auth = ServerAuth.none
        let data = try encoder.encode(auth)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["type"] as? String, "none")
        XCTAssertNil(json?["token"])
        XCTAssertNil(json?["username"])
    }

    func testServerAuthDeviceEncodesTypeAndToken() throws {
        let auth = ServerAuth.deviceToken("abc")
        let data = try encoder.encode(auth)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["type"] as? String, "device")
        XCTAssertEqual(json?["token"] as? String, "abc")
    }

    func testServerAuthDecodesFromJSON() throws {
        let json: [String: Any] = ["type": "bearer", "token": "decoded-tok"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let auth = try decoder.decode(ServerAuth.self, from: data)
        XCTAssertEqual(auth, .bearerToken("decoded-tok"))
    }

    func testServerAuthInvalidTypeThrows() {
        let json: [String: Any] = ["type": "oauth2", "token": "x"]
        let data = try! JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try decoder.decode(ServerAuth.self, from: data))
    }

    // MARK: - ServerType

    func testServerTypeRawValues() {
        XCTAssertEqual(ServerType.openCode.rawValue, "opencode")
        XCTAssertEqual(ServerType.openClaw.rawValue, "openclaw")
        XCTAssertEqual(ServerType.hermes.rawValue, "hermes")
    }

    func testServerTypeDisplayName() {
        XCTAssertEqual(ServerType.openCode.displayName, "OpenCode")
        XCTAssertEqual(ServerType.openClaw.displayName, "OpenClaw")
        XCTAssertEqual(ServerType.hermes.displayName, "Hermes")
    }

    func testServerTypeIconSystemName() {
        XCTAssertFalse(ServerType.openCode.iconSystemName.isEmpty)
        XCTAssertFalse(ServerType.openClaw.iconSystemName.isEmpty)
        XCTAssertFalse(ServerType.hermes.iconSystemName.isEmpty)
    }

    func testServerTypeCaseIterable() {
        XCTAssertEqual(ServerType.allCases.count, 3)
        XCTAssertTrue(ServerType.allCases.contains(.openCode))
        XCTAssertTrue(ServerType.allCases.contains(.openClaw))
        XCTAssertTrue(ServerType.allCases.contains(.hermes))
    }

    func testServerTypeCodable() throws {
        for serverType in ServerType.allCases {
            let data = try encoder.encode(serverType)
            let decoded = try decoder.decode(ServerType.self, from: data)
            XCTAssertEqual(decoded, serverType)
        }
    }

    // MARK: - ServerConfig with All Server Types

    func testServerConfigForEachType() throws {
        for serverType in ServerType.allCases {
            let config = ServerConfig(name: serverType.displayName, url: "https://\(serverType.rawValue).test", serverType: serverType)
            let data = try encoder.encode(config)
            let decoded = try decoder.decode(ServerConfig.self, from: data)
            XCTAssertEqual(decoded.serverType, serverType)
            XCTAssertEqual(decoded.name, serverType.displayName)
        }
    }
}
