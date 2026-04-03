import XCTest
@testable import AgentPocket

final class ConversationTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Conversation Codable

    func testConversationRoundTrip() throws {
        let conversation = Conversation(
            id: "conv-1",
            title: "Test Chat",
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_000_100),
            status: .streaming,
            metadata: ConversationMetadata(
                serverType: .openCode,
                agentName: "claude",
                modelName: "gpt-4",
                totalTokens: 5000,
                totalCost: 0.10
            )
        )

        let data = try encoder.encode(conversation)
        let decoded = try decoder.decode(Conversation.self, from: data)

        XCTAssertEqual(decoded.id, "conv-1")
        XCTAssertEqual(decoded.title, "Test Chat")
        XCTAssertEqual(decoded.status, .streaming)
        XCTAssertEqual(decoded.metadata.serverType, .openCode)
        XCTAssertEqual(decoded.metadata.agentName, "claude")
        XCTAssertEqual(decoded.metadata.modelName, "gpt-4")
        XCTAssertEqual(decoded.metadata.totalTokens, 5000)
        XCTAssertEqual(decoded.metadata.totalCost, 0.10)
    }

    func testConversationDefaults() {
        let conversation = Conversation(id: "c1")
        XCTAssertNil(conversation.title)
        XCTAssertEqual(conversation.status, .idle)
        XCTAssertNil(conversation.metadata.serverType)
        XCTAssertNil(conversation.metadata.agentName)
        XCTAssertNil(conversation.metadata.totalTokens)
    }

    func testConversationIdentifiable() {
        let c1 = Conversation(id: "a")
        let c2 = Conversation(id: "b")
        XCTAssertNotEqual(c1.id, c2.id)
    }

    func testConversationHashable() {
        let c1 = Conversation(id: "x")
        let c2 = Conversation(id: "x")
        XCTAssertEqual(c1, c2)

        var set: Set<Conversation> = [c1, c2]
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - ConversationStatus

    func testAllStatuses() {
        XCTAssertEqual(ConversationStatus.idle.rawValue, "idle")
        XCTAssertEqual(ConversationStatus.streaming.rawValue, "streaming")
        XCTAssertEqual(ConversationStatus.toolRunning.rawValue, "tool_running")
        XCTAssertEqual(ConversationStatus.waitingPermission.rawValue, "waiting_permission")
        XCTAssertEqual(ConversationStatus.error.rawValue, "error")
    }

    func testStatusCodableRoundTrip() throws {
        let statuses: [ConversationStatus] = [.idle, .streaming, .toolRunning, .waitingPermission, .error]
        for status in statuses {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(ConversationStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    func testStatusDecodesFromSnakeCaseString() throws {
        let json = Data("\"tool_running\"".utf8)
        let decoded = try decoder.decode(ConversationStatus.self, from: json)
        XCTAssertEqual(decoded, .toolRunning)
    }

    func testStatusDecodesWaitingPermission() throws {
        let json = Data("\"waiting_permission\"".utf8)
        let decoded = try decoder.decode(ConversationStatus.self, from: json)
        XCTAssertEqual(decoded, .waitingPermission)
    }

    func testInvalidStatusThrows() {
        let json = Data("\"nonexistent\"".utf8)
        XCTAssertThrowsError(try decoder.decode(ConversationStatus.self, from: json))
    }

    // MARK: - ConversationMetadata

    func testMetadataRoundTrip() throws {
        let metadata = ConversationMetadata(
            serverType: .hermes,
            agentName: "hermes-agent",
            modelName: "llama-3",
            totalTokens: 1234,
            totalCost: 0.0
        )
        let data = try encoder.encode(metadata)
        let decoded = try decoder.decode(ConversationMetadata.self, from: data)

        XCTAssertEqual(decoded.serverType, .hermes)
        XCTAssertEqual(decoded.agentName, "hermes-agent")
        XCTAssertEqual(decoded.modelName, "llama-3")
        XCTAssertEqual(decoded.totalTokens, 1234)
        XCTAssertEqual(decoded.totalCost, 0.0)
    }

    func testMetadataAllNilDefaults() throws {
        let metadata = ConversationMetadata()
        let data = try encoder.encode(metadata)
        let decoded = try decoder.decode(ConversationMetadata.self, from: data)

        XCTAssertNil(decoded.serverType)
        XCTAssertNil(decoded.agentName)
        XCTAssertNil(decoded.modelName)
        XCTAssertNil(decoded.totalTokens)
        XCTAssertNil(decoded.totalCost)
    }

    func testMetadataPartialFields() throws {
        let metadata = ConversationMetadata(serverType: .openClaw, totalCost: 1.50)
        let data = try encoder.encode(metadata)
        let decoded = try decoder.decode(ConversationMetadata.self, from: data)

        XCTAssertEqual(decoded.serverType, .openClaw)
        XCTAssertNil(decoded.agentName)
        XCTAssertEqual(decoded.totalCost, 1.50)
    }

    // MARK: - Conversation Mutability

    func testConversationTitleMutation() {
        var conversation = Conversation(id: "c1", title: "Old")
        conversation.title = "New Title"
        XCTAssertEqual(conversation.title, "New Title")
    }

    func testConversationStatusMutation() {
        var conversation = Conversation(id: "c1")
        XCTAssertEqual(conversation.status, .idle)
        conversation.status = .streaming
        XCTAssertEqual(conversation.status, .streaming)
    }
}
