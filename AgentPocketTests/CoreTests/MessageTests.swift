import XCTest
@testable import AgentPocket

final class MessageTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Message Codable

    func testMessageRoundTrip() throws {
        let message = Message(
            id: "msg-1",
            conversationID: "conv-1",
            role: .user,
            content: [
                MessageContent(id: "c1", type: .text, data: .plainText("Hello")),
            ],
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            metadata: MessageMetadata(agentName: "claude", modelID: "gpt-4")
        )

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.id, "msg-1")
        XCTAssertEqual(decoded.conversationID, "conv-1")
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.content.count, 1)
        XCTAssertEqual(decoded.metadata.agentName, "claude")
        XCTAssertEqual(decoded.metadata.modelID, "gpt-4")
    }

    func testMessageDefaultMetadata() {
        let message = Message(id: "m1", conversationID: "c1", role: .assistant, content: [])
        XCTAssertNil(message.metadata.agentName)
        XCTAssertNil(message.metadata.modelID)
        XCTAssertNil(message.metadata.cost)
        XCTAssertNil(message.metadata.inputTokens)
        XCTAssertNil(message.metadata.outputTokens)
    }

    func testMessageIdentifiable() {
        let m1 = Message(id: "a", conversationID: "c", role: .user, content: [])
        let m2 = Message(id: "b", conversationID: "c", role: .user, content: [])
        XCTAssertNotEqual(m1.id, m2.id)
        XCTAssertEqual(m1.id, "a")
    }

    func testMessageHashable() {
        let m1 = Message(id: "x", conversationID: "c", role: .user, content: [])
        let m2 = Message(id: "x", conversationID: "c", role: .user, content: [])
        XCTAssertEqual(m1, m2)

        var set: Set<Message> = [m1, m2]
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - MessageRole

    func testAllRoles() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
    }

    func testRoleCodable() throws {
        for role in [MessageRole.user, .assistant, .system] {
            let data = try encoder.encode(role)
            let decoded = try decoder.decode(MessageRole.self, from: data)
            XCTAssertEqual(decoded, role)
        }
    }

    // MARK: - MessageContent

    func testMessageContentDefaultID() {
        let content = MessageContent(type: .text, data: .plainText("test"))
        XCTAssertFalse(content.id.isEmpty)
    }

    func testMessageContentCodableRoundTrip() throws {
        let content = MessageContent(id: "cnt-1", type: .text, data: .plainText("hello"))
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(MessageContent.self, from: data)
        XCTAssertEqual(decoded.id, "cnt-1")
        XCTAssertEqual(decoded.type, .text)
    }

    // MARK: - ContentData Text

    func testContentDataTextRoundTrip() throws {
        let content = ContentData.text(TextContent(text: "Hello world"))
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(ContentData.self, from: data)

        if case .text(let textContent) = decoded {
            XCTAssertEqual(textContent.text, "Hello world")
        } else {
            XCTFail("Expected .text variant")
        }
    }

    func testContentDataPlainTextConvenience() {
        let content = ContentData.plainText("shortcut")
        if case .text(let tc) = content {
            XCTAssertEqual(tc.text, "shortcut")
        } else {
            XCTFail("Expected .text variant")
        }
    }

    // MARK: - ContentData Audio

    func testContentDataAudioRoundTrip() throws {
        let audio = AudioContent(
            data: Data([0x01, 0x02, 0x03]),
            url: "https://example.com/audio.wav",
            mimeType: "audio/wav",
            duration: 5.5,
            transcript: "Hello"
        )
        let content = ContentData.audio(audio)
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(ContentData.self, from: data)

        if case .audio(let ac) = decoded {
            XCTAssertEqual(ac.data, Data([0x01, 0x02, 0x03]))
            XCTAssertEqual(ac.url, "https://example.com/audio.wav")
            XCTAssertEqual(ac.mimeType, "audio/wav")
            XCTAssertEqual(ac.duration, 5.5)
            XCTAssertEqual(ac.transcript, "Hello")
        } else {
            XCTFail("Expected .audio variant")
        }
    }

    func testAudioContentDefaults() {
        let audio = AudioContent()
        XCTAssertNil(audio.data)
        XCTAssertNil(audio.url)
        XCTAssertEqual(audio.mimeType, "audio/wav")
        XCTAssertNil(audio.duration)
        XCTAssertNil(audio.transcript)
    }

    // MARK: - ContentData Image

    func testContentDataImageRoundTrip() throws {
        let image = ImageContent(
            data: Data([0xFF, 0xD8]),
            url: "https://example.com/img.jpg",
            mimeType: "image/png",
            width: 800,
            height: 600,
            caption: "screenshot"
        )
        let content = ContentData.image(image)
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(ContentData.self, from: data)

        if case .image(let ic) = decoded {
            XCTAssertEqual(ic.data, Data([0xFF, 0xD8]))
            XCTAssertEqual(ic.mimeType, "image/png")
            XCTAssertEqual(ic.width, 800)
            XCTAssertEqual(ic.height, 600)
            XCTAssertEqual(ic.caption, "screenshot")
        } else {
            XCTFail("Expected .image variant")
        }
    }

    func testImageContentDefaults() {
        let image = ImageContent()
        XCTAssertNil(image.data)
        XCTAssertNil(image.url)
        XCTAssertEqual(image.mimeType, "image/jpeg")
        XCTAssertNil(image.width)
        XCTAssertNil(image.height)
        XCTAssertNil(image.caption)
    }

    // MARK: - ContentData File

    func testContentDataFileRoundTrip() throws {
        let file = FileContent(path: "/src/main.swift", mimeType: "text/x-swift", content: "print(\"hi\")", language: "swift", size: 42)
        let content = ContentData.file(file)
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(ContentData.self, from: data)

        if case .file(let fc) = decoded {
            XCTAssertEqual(fc.path, "/src/main.swift")
            XCTAssertEqual(fc.mimeType, "text/x-swift")
            XCTAssertEqual(fc.content, "print(\"hi\")")
            XCTAssertEqual(fc.language, "swift")
            XCTAssertEqual(fc.size, 42)
        } else {
            XCTFail("Expected .file variant")
        }
    }

    // MARK: - ContentData Tool

    func testContentDataToolRoundTrip() throws {
        let tool = ToolContent(
            toolID: "tool-1",
            name: "bash",
            status: .completed,
            input: "ls -la",
            output: "file.txt",
            error: nil,
            duration: 1.2
        )
        let content = ContentData.tool(tool)
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(ContentData.self, from: data)

        if case .tool(let tc) = decoded {
            XCTAssertEqual(tc.toolID, "tool-1")
            XCTAssertEqual(tc.name, "bash")
            XCTAssertEqual(tc.status, .completed)
            XCTAssertEqual(tc.input, "ls -la")
            XCTAssertEqual(tc.output, "file.txt")
            XCTAssertNil(tc.error)
            XCTAssertEqual(tc.duration, 1.2)
        } else {
            XCTFail("Expected .tool variant")
        }
    }

    func testToolStatusAllCases() {
        XCTAssertEqual(ToolStatus.pending.rawValue, "pending")
        XCTAssertEqual(ToolStatus.running.rawValue, "running")
        XCTAssertEqual(ToolStatus.completed.rawValue, "completed")
        XCTAssertEqual(ToolStatus.failed.rawValue, "failed")
    }

    // MARK: - ContentData Reasoning

    func testContentDataReasoningRoundTrip() throws {
        let reasoning = ReasoningContent(text: "thinking...", isRedacted: true, tokenCount: 500)
        let content = ContentData.reasoning(reasoning)
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(ContentData.self, from: data)

        if case .reasoning(let rc) = decoded {
            XCTAssertEqual(rc.text, "thinking...")
            XCTAssertTrue(rc.isRedacted)
            XCTAssertEqual(rc.tokenCount, 500)
        } else {
            XCTFail("Expected .reasoning variant")
        }
    }

    func testReasoningContentDefaults() {
        let reasoning = ReasoningContent(text: "test")
        XCTAssertFalse(reasoning.isRedacted)
        XCTAssertNil(reasoning.tokenCount)
    }

    // MARK: - ContentData Error

    func testContentDataErrorRoundTrip() throws {
        let errorContent = ErrorContent(name: "RateLimitError", message: "Too many requests", isRetryable: true)
        let content = ContentData.error(errorContent)
        let data = try encoder.encode(content)
        let decoded = try decoder.decode(ContentData.self, from: data)

        if case .error(let ec) = decoded {
            XCTAssertEqual(ec.name, "RateLimitError")
            XCTAssertEqual(ec.message, "Too many requests")
            XCTAssertTrue(ec.isRetryable)
        } else {
            XCTFail("Expected .error variant")
        }
    }

    func testErrorContentDefaultNotRetryable() {
        let errorContent = ErrorContent(name: "Fatal", message: "boom")
        XCTAssertFalse(errorContent.isRetryable)
    }

    // MARK: - ContentData JSON Structure

    func testContentDataEncodesTypeAndPayloadKeys() throws {
        let content = ContentData.plainText("test")
        let data = try encoder.encode(content)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "text")
        XCTAssertNotNil(json?["payload"])
    }

    func testContentDataDecodesFromTypePayloadJSON() throws {
        let json: [String: Any] = [
            "type": "error",
            "payload": [
                "name": "TestError",
                "message": "something broke",
                "isRetryable": false,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try decoder.decode(ContentData.self, from: data)

        if case .error(let ec) = decoded {
            XCTAssertEqual(ec.name, "TestError")
            XCTAssertEqual(ec.message, "something broke")
        } else {
            XCTFail("Expected .error variant")
        }
    }

    func testContentDataInvalidTypeThrows() {
        let json: [String: Any] = [
            "type": "unknown_type",
            "payload": ["text": "x"],
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try decoder.decode(ContentData.self, from: data))
    }

    // MARK: - ContentType

    func testContentTypeRawValues() {
        XCTAssertEqual(ContentType.text.rawValue, "text")
        XCTAssertEqual(ContentType.audio.rawValue, "audio")
        XCTAssertEqual(ContentType.image.rawValue, "image")
        XCTAssertEqual(ContentType.file.rawValue, "file")
        XCTAssertEqual(ContentType.tool.rawValue, "tool")
        XCTAssertEqual(ContentType.reasoning.rawValue, "reasoning")
        XCTAssertEqual(ContentType.error.rawValue, "error")
    }

    // MARK: - MessageMetadata

    func testMessageMetadataRoundTrip() throws {
        let metadata = MessageMetadata(
            agentName: "agent",
            modelID: "model-1",
            providerID: "provider-1",
            inputTokens: 100,
            outputTokens: 200,
            cost: 0.05,
            finishReason: "stop"
        )
        let data = try encoder.encode(metadata)
        let decoded = try decoder.decode(MessageMetadata.self, from: data)

        XCTAssertEqual(decoded.agentName, "agent")
        XCTAssertEqual(decoded.modelID, "model-1")
        XCTAssertEqual(decoded.providerID, "provider-1")
        XCTAssertEqual(decoded.inputTokens, 100)
        XCTAssertEqual(decoded.outputTokens, 200)
        XCTAssertEqual(decoded.cost, 0.05)
        XCTAssertEqual(decoded.finishReason, "stop")
    }

    func testMessageMetadataAllNilFields() throws {
        let metadata = MessageMetadata()
        let data = try encoder.encode(metadata)
        let decoded = try decoder.decode(MessageMetadata.self, from: data)

        XCTAssertNil(decoded.agentName)
        XCTAssertNil(decoded.modelID)
        XCTAssertNil(decoded.providerID)
        XCTAssertNil(decoded.inputTokens)
        XCTAssertNil(decoded.outputTokens)
        XCTAssertNil(decoded.cost)
        XCTAssertNil(decoded.finishReason)
    }

    // MARK: - Message with Multiple Content

    func testMessageMultipleContentItems() throws {
        let contents: [MessageContent] = [
            MessageContent(id: "c1", type: .text, data: .plainText("Hello")),
            MessageContent(id: "c2", type: .image, data: .image(ImageContent(mimeType: "image/png"))),
            MessageContent(id: "c3", type: .tool, data: .tool(ToolContent(toolID: "t1", name: "bash", status: .running))),
        ]
        let message = Message(id: "m1", conversationID: "conv", role: .assistant, content: contents)

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.content.count, 3)
        XCTAssertEqual(decoded.content[0].type, .text)
        XCTAssertEqual(decoded.content[1].type, .image)
        XCTAssertEqual(decoded.content[2].type, .tool)
    }
}
