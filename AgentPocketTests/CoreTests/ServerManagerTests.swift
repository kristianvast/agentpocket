import XCTest
@testable import AgentPocket

@MainActor
final class ServerManagerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var manager: ServerManager!

    override func setUp() {
        super.setUp()
        suiteName = "ServerManagerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        manager = ServerManager(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults.standard.removeSuite(named: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateEmpty() {
        XCTAssertTrue(manager.servers.isEmpty)
        XCTAssertNil(manager.activeServerID)
        XCTAssertNil(manager.activeServer)
    }

    // MARK: - Add

    func testAddServer() {
        let config = makeConfig(name: "Server 1")
        manager.add(config)

        XCTAssertEqual(manager.servers.count, 1)
        XCTAssertEqual(manager.servers.first?.name, "Server 1")
    }

    func testAddServerSetsActiveIfNone() {
        let config = makeConfig(name: "First")
        manager.add(config)
        XCTAssertEqual(manager.activeServerID, config.id)
    }

    func testAddSecondServerDoesNotChangeActive() {
        let first = makeConfig(name: "First")
        let second = makeConfig(name: "Second")
        manager.add(first)
        manager.add(second)

        XCTAssertEqual(manager.activeServerID, first.id)
        XCTAssertEqual(manager.servers.count, 2)
    }

    func testAddDuplicateIDReplacesExisting() {
        let id = UUID()
        let original = ServerConfig(id: id, name: "Original", url: "http://a", serverType: .openCode)
        let updated = ServerConfig(id: id, name: "Updated", url: "http://b", serverType: .openCode)

        manager.add(original)
        manager.add(updated)

        XCTAssertEqual(manager.servers.count, 1)
        XCTAssertEqual(manager.servers.first?.name, "Updated")
        XCTAssertEqual(manager.servers.first?.url, "http://b")
    }

    // MARK: - Update

    func testUpdateServer() {
        var config = makeConfig(name: "Old Name")
        manager.add(config)

        config.name = "New Name"
        manager.update(config)

        XCTAssertEqual(manager.servers.first?.name, "New Name")
    }

    func testUpdateNonExistentServerIsNoOp() {
        let config = makeConfig(name: "Ghost")
        manager.update(config)
        XCTAssertTrue(manager.servers.isEmpty)
    }

    // MARK: - Delete

    func testDeleteServer() {
        let config = makeConfig(name: "ToDelete")
        manager.add(config)
        manager.delete(id: config.id)

        XCTAssertTrue(manager.servers.isEmpty)
    }

    func testDeleteActiveServerSwitchesToFirst() {
        let first = makeConfig(name: "First")
        let second = makeConfig(name: "Second")
        manager.add(first)
        manager.add(second)
        manager.activeServerID = first.id

        manager.delete(id: first.id)

        XCTAssertEqual(manager.servers.count, 1)
        XCTAssertEqual(manager.activeServerID, second.id)
    }

    func testDeleteLastServerClearsActive() {
        let config = makeConfig(name: "Only")
        manager.add(config)
        manager.delete(id: config.id)

        XCTAssertNil(manager.activeServerID)
    }

    func testDeleteNonExistentIDIsNoOp() {
        let config = makeConfig(name: "Exists")
        manager.add(config)
        manager.delete(id: UUID())

        XCTAssertEqual(manager.servers.count, 1)
    }

    // MARK: - Mark Connected

    func testMarkConnectedUpdatesDate() {
        let config = makeConfig(name: "Server")
        manager.add(config)

        XCTAssertNil(manager.servers.first?.lastConnected)

        manager.markConnected(id: config.id)

        XCTAssertNotNil(manager.servers.first?.lastConnected)
    }

    func testMarkConnectedSetsActiveServer() {
        let first = makeConfig(name: "First")
        let second = makeConfig(name: "Second")
        manager.add(first)
        manager.add(second)

        manager.markConnected(id: second.id)
        XCTAssertEqual(manager.activeServerID, second.id)
    }

    // MARK: - Active Server

    func testActiveServerReturnsCorrectConfig() {
        let config = makeConfig(name: "Active")
        manager.add(config)
        manager.activeServerID = config.id

        XCTAssertEqual(manager.activeServer?.id, config.id)
        XCTAssertEqual(manager.activeServer?.name, "Active")
    }

    func testActiveServerNilWhenIDNotFound() {
        manager.activeServerID = UUID()
        XCTAssertNil(manager.activeServer)
    }

    // MARK: - Persistence

    func testPersistenceAcrossInstances() {
        let config = makeConfig(name: "Persisted")
        manager.add(config)
        manager.activeServerID = config.id

        let newManager = ServerManager(defaults: defaults)

        XCTAssertEqual(newManager.servers.count, 1)
        XCTAssertEqual(newManager.servers.first?.name, "Persisted")
        XCTAssertEqual(newManager.activeServerID, config.id)
    }

    func testPersistenceWithMultipleServers() {
        let configs = (0..<3).map { makeConfig(name: "Server \($0)") }
        configs.forEach { manager.add($0) }

        let newManager = ServerManager(defaults: defaults)
        XCTAssertEqual(newManager.servers.count, 3)
    }

    func testPersistencePreservesAuthTypes() throws {
        let bearerConfig = ServerConfig(name: "Bearer", url: "http://a", serverType: .openCode, auth: .bearerToken("tok"))
        let basicConfig = ServerConfig(name: "Basic", url: "http://b", serverType: .hermes, auth: .basic(username: "u", password: "p"))
        let deviceConfig = ServerConfig(name: "Device", url: "http://c", serverType: .openClaw, auth: .deviceToken("dev"))

        manager.add(bearerConfig)
        manager.add(basicConfig)
        manager.add(deviceConfig)

        let newManager = ServerManager(defaults: defaults)

        let bearer = newManager.servers.first { $0.name == "Bearer" }
        XCTAssertEqual(bearer?.auth, .bearerToken("tok"))

        let basic = newManager.servers.first { $0.name == "Basic" }
        XCTAssertEqual(basic?.auth, .basic(username: "u", password: "p"))

        let device = newManager.servers.first { $0.name == "Device" }
        XCTAssertEqual(device?.auth, .deviceToken("dev"))
    }

    func testLoadFromCorruptedDataResetsToEmpty() {
        defaults.set(Data("not-valid-json".utf8), forKey: "agentpocket_servers_v2")

        let newManager = ServerManager(defaults: defaults)
        XCTAssertTrue(newManager.servers.isEmpty)
        XCTAssertNil(newManager.activeServerID)
    }

    func testLoadFromMissingKeyResetsToEmpty() {
        defaults.removeObject(forKey: "agentpocket_servers_v2")

        let newManager = ServerManager(defaults: defaults)
        XCTAssertTrue(newManager.servers.isEmpty)
        XCTAssertNil(newManager.activeServerID)
    }

    // MARK: - Helpers

    private func makeConfig(name: String) -> ServerConfig {
        ServerConfig(name: name, url: "https://\(name.lowercased()).test", serverType: .openCode)
    }
}
