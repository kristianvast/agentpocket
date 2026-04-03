import XCTest
@testable import AgentPocket

final class OpenCodeServerTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - ServerType

    func testOpenCodeServerType() {
        XCTAssertEqual(ServerType.openCode.rawValue, "opencode")
        XCTAssertEqual(ServerType.openCode.displayName, "OpenCode")
    }

    func testOpenCodeIconName() {
        XCTAssertEqual(ServerType.openCode.iconSystemName, "chevron.left.forwardslash.chevron.right")
    }

    // MARK: - Config for OpenCode

    func testOpenCodeConfigCreation() {
        let config = ServerConfig(
            name: "Local OpenCode",
            url: "http://localhost:3000",
            serverType: .openCode,
            auth: .bearerToken("oc-token")
        )
        XCTAssertEqual(config.serverType, .openCode)
        XCTAssertEqual(config.url, "http://localhost:3000")
        XCTAssertEqual(config.authorizationHeader, "Bearer oc-token")
    }

    func testOpenCodeConfigCodableRoundTrip() throws {
        let config = ServerConfig(
            name: "OpenCode Server",
            url: "https://tunnel.trycloudflare.com",
            serverType: .openCode,
            auth: .bearerToken("token-123"),
            isDefault: true
        )
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(ServerConfig.self, from: data)

        XCTAssertEqual(decoded.serverType, .openCode)
        XCTAssertEqual(decoded.name, "OpenCode Server")
        XCTAssertEqual(decoded.url, "https://tunnel.trycloudflare.com")
        XCTAssertTrue(decoded.isDefault)
    }

    // MARK: - OpenCode Capabilities

    func testDefaultCapabilities() {
        let caps = AgentCapabilities()
        XCTAssertTrue(caps.supportsStreaming)
        XCTAssertFalse(caps.supportsTools)
        XCTAssertFalse(caps.supportsPermissions)
        XCTAssertFalse(caps.supportsFileAccess)
        XCTAssertFalse(caps.supportsTerminal)
        XCTAssertFalse(caps.supportsAudioInput)
        XCTAssertFalse(caps.supportsImageInput)
        XCTAssertTrue(caps.supportsConversationHistory)
        XCTAssertFalse(caps.supportsMCP)
        XCTAssertFalse(caps.supportsMemory)
    }

    func testOpenCodeFullCapabilities() {
        let caps = AgentCapabilities(
            supportsStreaming: true,
            supportsTools: true,
            supportsPermissions: true,
            supportsFileAccess: true,
            supportsTerminal: true,
            supportsAudioInput: true,
            supportsImageInput: true,
            supportsConversationHistory: true,
            supportsMCP: true,
            supportsMemory: false
        )
        XCTAssertTrue(caps.supportsTools)
        XCTAssertTrue(caps.supportsPermissions)
        XCTAssertTrue(caps.supportsFileAccess)
        XCTAssertTrue(caps.supportsTerminal)
        XCTAssertTrue(caps.supportsMCP)
    }

    func testCapabilitiesCodableRoundTrip() throws {
        let caps = AgentCapabilities(
            supportsStreaming: true,
            supportsTools: true,
            supportsPermissions: true,
            supportsFileAccess: true,
            supportsTerminal: true,
            supportsAudioInput: false,
            supportsImageInput: true,
            supportsConversationHistory: true,
            supportsMCP: true,
            supportsMemory: false
        )
        let data = try encoder.encode(caps)
        let decoded = try decoder.decode(AgentCapabilities.self, from: data)

        XCTAssertEqual(decoded.supportsTools, true)
        XCTAssertEqual(decoded.supportsPermissions, true)
        XCTAssertEqual(decoded.supportsAudioInput, false)
        XCTAssertEqual(decoded.supportsImageInput, true)
        XCTAssertEqual(decoded.supportsMCP, true)
    }

    // MARK: - OpenCode Model Mapping

    func testOpenCodeConversationMapping() throws {
        let json: [String: Any] = [
            "id": "ses_abc123",
            "title": "Coding session",
            "createdAt": 1_000_000.0,
            "updatedAt": 1_000_100.0,
            "status": "streaming",
            "metadata": [
                "serverType": "opencode",
                "agentName": "coder",
                "modelName": "claude-3-opus",
                "totalTokens": 10_000,
                "totalCost": 0.25,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let conversation = try decoder.decode(Conversation.self, from: data)

        XCTAssertEqual(conversation.id, "ses_abc123")
        XCTAssertEqual(conversation.title, "Coding session")
        XCTAssertEqual(conversation.status, .streaming)
        XCTAssertEqual(conversation.metadata.serverType, .openCode)
        XCTAssertEqual(conversation.metadata.agentName, "coder")
    }

    func testOpenCodeMessageMapping() throws {
        let json: [String: Any] = [
            "id": "msg_001",
            "conversationID": "ses_abc",
            "role": "assistant",
            "content": [
                [
                    "id": "cnt_001",
                    "type": "text",
                    "data": [
                        "type": "text",
                        "payload": ["text": "Here is the code fix"],
                    ],
                ] as [String: Any],
            ],
            "createdAt": 1_000_000.0,
            "metadata": [
                "agentName": "coder",
                "modelID": "claude-3-opus",
                "inputTokens": 500,
                "outputTokens": 150,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let message = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(message.id, "msg_001")
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content.count, 1)
        XCTAssertEqual(message.metadata.agentName, "coder")
        XCTAssertEqual(message.metadata.inputTokens, 500)
    }

    func testOpenCodeToolContentMapping() throws {
        let toolContent = ToolContent(
            toolID: "call_abc",
            name: "read_file",
            status: .completed,
            input: "{\"path\": \"/src/main.swift\"}",
            output: "file contents here",
            error: nil,
            duration: 0.5
        )
        let data = try encoder.encode(toolContent)
        let decoded = try decoder.decode(ToolContent.self, from: data)

        XCTAssertEqual(decoded.toolID, "call_abc")
        XCTAssertEqual(decoded.name, "read_file")
        XCTAssertEqual(decoded.status, .completed)
        XCTAssertEqual(decoded.duration, 0.5)
    }

    // MARK: - ServerEvent Cases

    func testServerEventConversationCreated() {
        let conv = Conversation(id: "c1", title: "New")
        let event = ServerEvent.conversationCreated(conv)
        if case .conversationCreated(let c) = event {
            XCTAssertEqual(c.id, "c1")
        } else {
            XCTFail("Expected conversationCreated")
        }
    }

    func testServerEventContentDelta() {
        let event = ServerEvent.contentDelta("c1", "m1", "cnt1", "new text")
        if case .contentDelta(let cid, let mid, let cntid, let delta) = event {
            XCTAssertEqual(cid, "c1")
            XCTAssertEqual(mid, "m1")
            XCTAssertEqual(cntid, "cnt1")
            XCTAssertEqual(delta, "new text")
        } else {
            XCTFail("Expected contentDelta")
        }
    }

    func testServerEventToolStatusChanged() {
        let event = ServerEvent.toolStatusChanged("c1", "m1", "cnt1", .running)
        if case .toolStatusChanged(_, _, _, let status) = event {
            XCTAssertEqual(status, .running)
        } else {
            XCTFail("Expected toolStatusChanged")
        }
    }

    func testServerEventPermissionRequested() {
        let req = PermissionRequest(id: "p1", conversationID: "c1", toolName: "bash", description: "Run command")
        let event = ServerEvent.permissionRequested(req)
        if case .permissionRequested(let r) = event {
            XCTAssertEqual(r.id, "p1")
            XCTAssertEqual(r.toolName, "bash")
        } else {
            XCTFail("Expected permissionRequested")
        }
    }

    func testServerEventHeartbeat() {
        let event = ServerEvent.heartbeat
        if case .heartbeat = event {
        } else {
            XCTFail("Expected heartbeat")
        }
    }
}
