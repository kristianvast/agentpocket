import XCTest
@testable import AgentPocket

final class HermesServerTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - ServerType

    func testHermesServerType() {
        XCTAssertEqual(ServerType.hermes.rawValue, "hermes")
        XCTAssertEqual(ServerType.hermes.displayName, "Hermes")
    }

    func testHermesIconName() {
        XCTAssertEqual(ServerType.hermes.iconSystemName, "brain.head.profile")
    }

    // MARK: - Config for Hermes

    func testHermesConfigCreation() {
        let config = ServerConfig(
            name: "Hermes Local",
            url: "http://localhost:8080",
            serverType: .hermes,
            auth: .none
        )
        XCTAssertEqual(config.serverType, .hermes)
        XCTAssertEqual(config.url, "http://localhost:8080")
        XCTAssertNil(config.authorizationHeader)
    }

    func testHermesConfigWithBasicAuth() {
        let config = ServerConfig(
            name: "Hermes Prod",
            url: "https://hermes.example.com",
            serverType: .hermes,
            auth: .basic(username: "admin", password: "secret")
        )
        let header = config.authorizationHeader!
        XCTAssertTrue(header.hasPrefix("Basic "))
        let base64 = String(header.dropFirst(6))
        let decoded = Data(base64Encoded: base64).flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(decoded, "admin:secret")
    }

    func testHermesConfigCodableRoundTrip() throws {
        let config = ServerConfig(
            name: "Hermes Server",
            url: "https://hermes.test",
            serverType: .hermes,
            auth: .deviceToken("dev-tok"),
            isDefault: false
        )
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(ServerConfig.self, from: data)

        XCTAssertEqual(decoded.serverType, .hermes)
        XCTAssertEqual(decoded.name, "Hermes Server")
        XCTAssertEqual(decoded.auth, .deviceToken("dev-tok"))
    }

    // MARK: - Hermes Model Mapping

    func testHermesConversationMapping() throws {
        let conversation = Conversation(
            id: "hermes-conv-1",
            title: "Hermes Chat",
            status: .idle,
            metadata: ConversationMetadata(
                serverType: .hermes,
                agentName: "hermes-default",
                modelName: "llama-3-70b"
            )
        )
        let data = try encoder.encode(conversation)
        let decoded = try decoder.decode(Conversation.self, from: data)

        XCTAssertEqual(decoded.id, "hermes-conv-1")
        XCTAssertEqual(decoded.metadata.serverType, .hermes)
        XCTAssertEqual(decoded.metadata.modelName, "llama-3-70b")
    }

    func testHermesMessageWithTextContent() throws {
        let message = Message(
            id: "h-msg-1",
            conversationID: "hermes-conv-1",
            role: .assistant,
            content: [
                MessageContent(id: "hc1", type: .text, data: .plainText("Hermes response")),
            ],
            metadata: MessageMetadata(agentName: "hermes-default", modelID: "llama-3")
        )
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.id, "h-msg-1")
        XCTAssertEqual(decoded.role, .assistant)

        if case .text(let tc) = decoded.content.first?.data {
            XCTAssertEqual(tc.text, "Hermes response")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testHermesMessageWithReasoningContent() throws {
        let reasoning = ReasoningContent(text: "Let me think about this...", isRedacted: false, tokenCount: 200)
        let message = Message(
            id: "h-msg-2",
            conversationID: "hermes-conv-1",
            role: .assistant,
            content: [
                MessageContent(id: "hc2", type: .reasoning, data: .reasoning(reasoning)),
            ]
        )
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)

        if case .reasoning(let rc) = decoded.content.first?.data {
            XCTAssertEqual(rc.text, "Let me think about this...")
            XCTAssertFalse(rc.isRedacted)
            XCTAssertEqual(rc.tokenCount, 200)
        } else {
            XCTFail("Expected reasoning content")
        }
    }

    // MARK: - Hermes Error Mapping

    func testHermesErrorContent() throws {
        let errorContent = ErrorContent(name: "HermesError", message: "Model not available", isRetryable: true)
        let message = Message(
            id: "h-err-1",
            conversationID: "hermes-conv-1",
            role: .assistant,
            content: [MessageContent(id: "ec1", type: .error, data: .error(errorContent))]
        )
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)

        if case .error(let ec) = decoded.content.first?.data {
            XCTAssertEqual(ec.name, "HermesError")
            XCTAssertEqual(ec.message, "Model not available")
            XCTAssertTrue(ec.isRetryable)
        } else {
            XCTFail("Expected error content")
        }
    }

    // MARK: - Hermes Conversation Status

    func testHermesStatusTransitions() throws {
        var conversation = Conversation(id: "h-conv", status: .idle, metadata: ConversationMetadata(serverType: .hermes))

        conversation.status = .streaming
        XCTAssertEqual(conversation.status, .streaming)

        conversation.status = .error
        XCTAssertEqual(conversation.status, .error)

        conversation.status = .idle
        XCTAssertEqual(conversation.status, .idle)
    }

    func testHermesStatusCodable() throws {
        let statuses: [ConversationStatus] = [.idle, .streaming, .error]
        for status in statuses {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(ConversationStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - Permission Request for Hermes

    func testPermissionRequestRoundTrip() throws {
        let request = PermissionRequest(
            id: "perm-h1",
            conversationID: "hermes-conv",
            toolName: "execute_code",
            description: "Run Python script",
            input: "print('hello')"
        )
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(PermissionRequest.self, from: data)

        XCTAssertEqual(decoded.id, "perm-h1")
        XCTAssertEqual(decoded.toolName, "execute_code")
        XCTAssertEqual(decoded.description, "Run Python script")
        XCTAssertEqual(decoded.input, "print('hello')")
    }

    // MARK: - ServerEvent for Hermes

    func testHermesDisconnectedEvent() {
        let error = AgentPocketError.networkError(URLError(.timedOut))
        let event = ServerEvent.disconnected(error)
        if case .disconnected(let err) = event {
            XCTAssertNotNil(err)
        } else {
            XCTFail("Expected disconnected event")
        }
    }

    func testHermesStatusChangedEvent() {
        let event = ServerEvent.statusChanged("hermes-conv", .error)
        if case .statusChanged(let cid, let status) = event {
            XCTAssertEqual(cid, "hermes-conv")
            XCTAssertEqual(status, .error)
        } else {
            XCTFail("Expected statusChanged event")
        }
    }

    func testHermesMessageDeletedEvent() {
        let event = ServerEvent.messageDeleted("hermes-conv", "msg-1")
        if case .messageDeleted(let cid, let mid) = event {
            XCTAssertEqual(cid, "hermes-conv")
            XCTAssertEqual(mid, "msg-1")
        } else {
            XCTFail("Expected messageDeleted event")
        }
    }
}
