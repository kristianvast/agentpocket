import XCTest
@testable import AgentPocket

final class SSEClientTests: XCTestCase {

    // MARK: - SSEEvent

    func testSSEEventStoresTypeAndData() {
        let event = SSEEvent(type: "message", data: "hello", rawData: Data("hello".utf8))
        XCTAssertEqual(event.type, "message")
        XCTAssertEqual(event.data, "hello")
        XCTAssertEqual(event.rawData, Data("hello".utf8))
    }

    func testSSEEventNilType() {
        let event = SSEEvent(type: nil, data: "payload", rawData: Data("payload".utf8))
        XCTAssertNil(event.type)
        XCTAssertEqual(event.data, "payload")
    }

    func testSSEEventEmptyData() {
        let event = SSEEvent(type: "ping", data: "", rawData: Data())
        XCTAssertEqual(event.data, "")
        XCTAssertTrue(event.rawData.isEmpty)
    }

    func testSSEEventMultilineData() {
        let multiline = "line1\nline2\nline3"
        let event = SSEEvent(type: "data", data: multiline, rawData: Data(multiline.utf8))
        XCTAssertTrue(event.data.contains("\n"))
        XCTAssertEqual(event.data.components(separatedBy: "\n").count, 3)
    }

    func testSSEEventRawDataMatchesStringData() {
        let text = "{\"id\": 123, \"type\": \"update\"}"
        let event = SSEEvent(type: "event", data: text, rawData: Data(text.utf8))
        XCTAssertEqual(String(data: event.rawData, encoding: .utf8), text)
    }

    // MARK: - SSE Line Parsing

    func testParseDataLine() {
        let line = "data: Hello, world!"
        let value = parseSSEValue(line: line, prefix: "data:")
        XCTAssertEqual(value, "Hello, world!")
    }

    func testParseEventLine() {
        let line = "event: message_delta"
        let value = parseSSEValue(line: line, prefix: "event:")
        XCTAssertEqual(value, "message_delta")
    }

    func testParseLineTrimsWhitespace() {
        let line = "data:   lots of spaces   "
        let value = parseSSEValue(line: line, prefix: "data:")
        XCTAssertEqual(value, "lots of spaces")
    }

    func testParseLineNoWhitespace() {
        let line = "data:no-space"
        let value = parseSSEValue(line: line, prefix: "data:")
        XCTAssertEqual(value, "no-space")
    }

    func testParseNonMatchingPrefixReturnsNil() {
        let line = "id: 42"
        let value = parseSSEValue(line: line, prefix: "data:")
        XCTAssertNil(value)
    }

    func testParseEmptyAfterPrefix() {
        let line = "data:"
        let value = parseSSEValue(line: line, prefix: "data:")
        XCTAssertEqual(value, "")
    }

    // MARK: - SSE Multi-line Accumulation

    func testMultipleDataLinesJoinedWithNewline() {
        let lines = ["data: line1", "data: line2", "data: line3"]
        var dataLines: [String] = []

        for line in lines {
            if let value = parseSSEValue(line: line, prefix: "data:") {
                dataLines.append(value)
            }
        }

        let payload = dataLines.joined(separator: "\n")
        XCTAssertEqual(payload, "line1\nline2\nline3")
    }

    func testEmptyLineTriggersEventDispatch() {
        let lines = ["event: update", "data: {\"id\": 1}", "", "event: heartbeat", "data: ping", ""]
        var events: [(type: String?, data: String)] = []
        var currentType: String?
        var dataLines: [String] = []

        for line in lines {
            if line.isEmpty {
                if !dataLines.isEmpty {
                    events.append((type: currentType, data: dataLines.joined(separator: "\n")))
                    dataLines.removeAll()
                    currentType = nil
                }
                continue
            }
            if let value = parseSSEValue(line: line, prefix: "event:") {
                currentType = value
            } else if let value = parseSSEValue(line: line, prefix: "data:") {
                dataLines.append(value)
            }
        }

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].type, "update")
        XCTAssertEqual(events[0].data, "{\"id\": 1}")
        XCTAssertEqual(events[1].type, "heartbeat")
        XCTAssertEqual(events[1].data, "ping")
    }

    func testDataOnlyEventWithoutEventType() {
        let lines = ["data: standalone-message", ""]
        var events: [(type: String?, data: String)] = []
        var currentType: String?
        var dataLines: [String] = []

        for line in lines {
            if line.isEmpty {
                if !dataLines.isEmpty {
                    events.append((type: currentType, data: dataLines.joined(separator: "\n")))
                    dataLines.removeAll()
                    currentType = nil
                }
                continue
            }
            if let value = parseSSEValue(line: line, prefix: "event:") {
                currentType = value
            } else if let value = parseSSEValue(line: line, prefix: "data:") {
                dataLines.append(value)
            }
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events[0].type)
        XCTAssertEqual(events[0].data, "standalone-message")
    }

    func testConsecutiveEmptyLinesDoNotCreateEmptyEvents() {
        let lines = ["data: msg", "", "", ""]
        var events: [(type: String?, data: String)] = []
        var dataLines: [String] = []
        var currentType: String?

        for line in lines {
            if line.isEmpty {
                if !dataLines.isEmpty {
                    events.append((type: currentType, data: dataLines.joined(separator: "\n")))
                    dataLines.removeAll()
                    currentType = nil
                }
                continue
            }
            if let value = parseSSEValue(line: line, prefix: "data:") {
                dataLines.append(value)
            }
        }

        XCTAssertEqual(events.count, 1)
    }

    // MARK: - SSEClient Initialization

    func testSSEClientStoresProperties() {
        let client = SSEClient(baseURL: "https://api.test.com", path: "/events", authorizationHeader: "Bearer tok")
        XCTAssertEqual(client.baseURL, "https://api.test.com")
        XCTAssertEqual(client.path, "/events")
        XCTAssertEqual(client.authHeader, "Bearer tok")
    }

    func testSSEClientNilAuth() {
        let client = SSEClient(baseURL: "https://api.test.com", path: "/events")
        XCTAssertNil(client.authHeader)
    }

    // MARK: - JSON Data Parsing

    func testParseJSONFromSSEData() throws {
        let jsonString = "{\"conversationId\":\"c1\",\"messageId\":\"m1\",\"delta\":\"hello\"}"
        let event = SSEEvent(type: "content_delta", data: jsonString, rawData: Data(jsonString.utf8))

        let json = try JSONSerialization.jsonObject(with: event.rawData) as? [String: Any]
        XCTAssertEqual(json?["conversationId"] as? String, "c1")
        XCTAssertEqual(json?["messageId"] as? String, "m1")
        XCTAssertEqual(json?["delta"] as? String, "hello")
    }

    // MARK: - Helpers

    private func parseSSEValue(line: String, prefix: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
}
