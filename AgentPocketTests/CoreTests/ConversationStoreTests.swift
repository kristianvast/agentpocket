import XCTest
@testable import AgentPocket

@MainActor
final class ConversationStoreTests: XCTestCase {

    private var store: ConversationStore!

    override func setUp() {
        super.setUp()
        store = ConversationStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateEmpty() {
        XCTAssertTrue(store.conversations.isEmpty)
        XCTAssertNil(store.activeConversationID)
        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertTrue(store.streamingText.isEmpty)
        XCTAssertTrue(store.statuses.isEmpty)
    }

    // MARK: - Active Conversation

    func testActiveConversationNilWhenNoID() {
        store.conversations = [Conversation(id: "c1")]
        XCTAssertNil(store.activeConversation)
    }

    func testActiveConversationNilWhenIDNotFound() {
        store.conversations = [Conversation(id: "c1")]
        store.activeConversationID = "c999"
        XCTAssertNil(store.activeConversation)
    }

    func testActiveConversationReturnsCorrect() {
        let c1 = Conversation(id: "c1", title: "First")
        let c2 = Conversation(id: "c2", title: "Second")
        store.conversations = [c1, c2]
        store.activeConversationID = "c2"

        XCTAssertEqual(store.activeConversation?.id, "c2")
        XCTAssertEqual(store.activeConversation?.title, "Second")
    }

    // MARK: - Active Messages

    func testActiveMessagesEmptyWhenNoActiveConversation() {
        XCTAssertTrue(store.activeMessages.isEmpty)
    }

    func testActiveMessagesReturnsCorrectConversation() {
        let msg = makeMessage(id: "m1", conversationID: "c1")
        store.messages["c1"] = [msg]
        store.messages["c2"] = [makeMessage(id: "m2", conversationID: "c2")]
        store.activeConversationID = "c1"

        XCTAssertEqual(store.activeMessages.count, 1)
        XCTAssertEqual(store.activeMessages.first?.id, "m1")
    }

    // MARK: - Set Messages

    func testSetMessagesReplacesExisting() {
        let old = [makeMessage(id: "old", conversationID: "c1")]
        store.messages["c1"] = old

        let new = [makeMessage(id: "new1", conversationID: "c1"), makeMessage(id: "new2", conversationID: "c1")]
        store.setMessages(new, for: "c1")

        XCTAssertEqual(store.messages["c1"]?.count, 2)
        XCTAssertEqual(store.messages["c1"]?.first?.id, "new1")
    }

    // MARK: - Add Or Update Message

    func testAddNewMessage() {
        let msg = makeMessage(id: "m1", conversationID: "c1")
        store.addOrUpdateMessage(msg, for: "c1")

        XCTAssertEqual(store.messages["c1"]?.count, 1)
        XCTAssertEqual(store.messages["c1"]?.first?.id, "m1")
    }

    func testAddMessageCreatesArrayIfMissing() {
        XCTAssertNil(store.messages["c1"])
        store.addOrUpdateMessage(makeMessage(id: "m1", conversationID: "c1"), for: "c1")
        XCTAssertNotNil(store.messages["c1"])
    }

    func testUpdateExistingMessage() {
        let original = Message(
            id: "m1",
            conversationID: "c1",
            role: .user,
            content: [MessageContent(id: "cnt", type: .text, data: .plainText("old"))]
        )
        store.addOrUpdateMessage(original, for: "c1")

        let updated = Message(
            id: "m1",
            conversationID: "c1",
            role: .assistant,
            content: [MessageContent(id: "cnt", type: .text, data: .plainText("new"))]
        )
        store.addOrUpdateMessage(updated, for: "c1")

        XCTAssertEqual(store.messages["c1"]?.count, 1)
        XCTAssertEqual(store.messages["c1"]?.first?.role, .assistant)
    }

    func testAddMultipleMessages() {
        store.addOrUpdateMessage(makeMessage(id: "m1", conversationID: "c1"), for: "c1")
        store.addOrUpdateMessage(makeMessage(id: "m2", conversationID: "c1"), for: "c1")
        store.addOrUpdateMessage(makeMessage(id: "m3", conversationID: "c1"), for: "c1")

        XCTAssertEqual(store.messages["c1"]?.count, 3)
    }

    // MARK: - Remove Message

    func testRemoveMessage() {
        store.addOrUpdateMessage(makeMessage(id: "m1", conversationID: "c1"), for: "c1")
        store.addOrUpdateMessage(makeMessage(id: "m2", conversationID: "c1"), for: "c1")

        store.removeMessage(messageID: "m1", conversationID: "c1")

        XCTAssertEqual(store.messages["c1"]?.count, 1)
        XCTAssertEqual(store.messages["c1"]?.first?.id, "m2")
    }

    func testRemoveNonExistentMessageIsNoOp() {
        store.addOrUpdateMessage(makeMessage(id: "m1", conversationID: "c1"), for: "c1")
        store.removeMessage(messageID: "m999", conversationID: "c1")
        XCTAssertEqual(store.messages["c1"]?.count, 1)
    }

    // MARK: - Update Content

    func testUpdateExistingContent() {
        let content = MessageContent(id: "cnt-1", type: .text, data: .plainText("original"))
        let msg = Message(id: "m1", conversationID: "c1", role: .assistant, content: [content])
        store.addOrUpdateMessage(msg, for: "c1")

        let updatedContent = MessageContent(id: "cnt-1", type: .text, data: .plainText("modified"))
        store.updateContent(updatedContent, messageID: "m1", conversationID: "c1")

        let storedContent = store.messages["c1"]?.first?.content.first
        if case .text(let tc) = storedContent?.data {
            XCTAssertEqual(tc.text, "modified")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testUpdateContentAppendsIfNewID() {
        let content = MessageContent(id: "cnt-1", type: .text, data: .plainText("first"))
        let msg = Message(id: "m1", conversationID: "c1", role: .assistant, content: [content])
        store.addOrUpdateMessage(msg, for: "c1")

        let newContent = MessageContent(id: "cnt-2", type: .text, data: .plainText("second"))
        store.updateContent(newContent, messageID: "m1", conversationID: "c1")

        XCTAssertEqual(store.messages["c1"]?.first?.content.count, 2)
    }

    // MARK: - Update Conversation

    func testUpdateConversation() {
        store.conversations = [Conversation(id: "c1", title: "Old")]
        let updated = Conversation(id: "c1", title: "New Title")
        store.updateConversation(updated)

        XCTAssertEqual(store.conversations.first?.title, "New Title")
    }

    func testUpdateNonExistentConversationIsNoOp() {
        store.conversations = [Conversation(id: "c1")]
        store.updateConversation(Conversation(id: "c999", title: "Ghost"))
        XCTAssertEqual(store.conversations.count, 1)
        XCTAssertNil(store.conversations.first?.title)
    }

    // MARK: - Apply Delta

    func testApplyDeltaCreatesNewStreamingText() {
        store.applyDelta(conversationID: "c1", messageID: "m1", contentID: "cnt1", delta: "Hello")

        let text = store.getStreamingText(messageID: "m1", contentID: "cnt1")
        XCTAssertEqual(text, "Hello")
    }

    func testApplyDeltaAppendsToExisting() {
        store.applyDelta(conversationID: "c1", messageID: "m1", contentID: "cnt1", delta: "Hello")
        store.applyDelta(conversationID: "c1", messageID: "m1", contentID: "cnt1", delta: " World")

        let text = store.getStreamingText(messageID: "m1", contentID: "cnt1")
        XCTAssertEqual(text, "Hello World")
    }

    func testApplyDeltaPrependsExistingMessageText() {
        let content = MessageContent(id: "cnt1", type: .text, data: .plainText("Before: "))
        let msg = Message(id: "m1", conversationID: "c1", role: .assistant, content: [content])
        store.addOrUpdateMessage(msg, for: "c1")

        store.applyDelta(conversationID: "c1", messageID: "m1", contentID: "cnt1", delta: "After")

        let text = store.getStreamingText(messageID: "m1", contentID: "cnt1")
        XCTAssertEqual(text, "Before: After")
    }

    func testApplyDeltaMultipleContents() {
        store.applyDelta(conversationID: "c1", messageID: "m1", contentID: "cnt1", delta: "A")
        store.applyDelta(conversationID: "c1", messageID: "m1", contentID: "cnt2", delta: "B")

        XCTAssertEqual(store.getStreamingText(messageID: "m1", contentID: "cnt1"), "A")
        XCTAssertEqual(store.getStreamingText(messageID: "m1", contentID: "cnt2"), "B")
    }

    // MARK: - Get Streaming Text

    func testGetStreamingTextNilWhenNotSet() {
        XCTAssertNil(store.getStreamingText(messageID: "m1", contentID: "cnt1"))
    }

    func testGetStreamingTextReturnsCorrectKey() {
        store.streamingText["m1:cnt1"] = "found"
        store.streamingText["m2:cnt2"] = "other"

        XCTAssertEqual(store.getStreamingText(messageID: "m1", contentID: "cnt1"), "found")
        XCTAssertEqual(store.getStreamingText(messageID: "m2", contentID: "cnt2"), "other")
    }

    // MARK: - Clear Streaming Text

    func testClearStreamingText() {
        store.applyDelta(conversationID: "c1", messageID: "m1", contentID: "cnt1", delta: "text")
        XCTAssertNotNil(store.getStreamingText(messageID: "m1", contentID: "cnt1"))

        store.clearStreamingText(messageID: "m1", contentID: "cnt1")
        XCTAssertNil(store.getStreamingText(messageID: "m1", contentID: "cnt1"))
    }

    func testClearStreamingTextForOneDoesNotAffectOthers() {
        store.applyDelta(conversationID: "c1", messageID: "m1", contentID: "cnt1", delta: "A")
        store.applyDelta(conversationID: "c1", messageID: "m1", contentID: "cnt2", delta: "B")

        store.clearStreamingText(messageID: "m1", contentID: "cnt1")

        XCTAssertNil(store.getStreamingText(messageID: "m1", contentID: "cnt1"))
        XCTAssertEqual(store.getStreamingText(messageID: "m1", contentID: "cnt2"), "B")
    }

    // MARK: - Clear All

    func testClearResetsEverything() {
        store.conversations = [Conversation(id: "c1")]
        store.activeConversationID = "c1"
        store.messages["c1"] = [makeMessage(id: "m1", conversationID: "c1")]
        store.streamingText["m1:cnt1"] = "text"
        store.statuses["c1"] = .streaming

        store.clear()

        XCTAssertTrue(store.conversations.isEmpty)
        XCTAssertNil(store.activeConversationID)
        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertTrue(store.streamingText.isEmpty)
        XCTAssertTrue(store.statuses.isEmpty)
    }

    // MARK: - Helpers

    private func makeMessage(id: MessageID, conversationID: ConversationID) -> Message {
        Message(
            id: id,
            conversationID: conversationID,
            role: .user,
            content: [MessageContent(type: .text, data: .plainText("test"))]
        )
    }
}
