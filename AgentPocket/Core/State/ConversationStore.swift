import Foundation
import Observation

@MainActor
@Observable
final class ConversationStore {
    var conversations: [Conversation] = []
    var activeConversationID: ConversationID?
    var messages: [ConversationID: [Message]] = [:]
    var streamingText: [String: String] = [:]
    var statuses: [ConversationID: ConversationStatus] = [:]

    var activeConversation: Conversation? {
        guard let id = activeConversationID else { return nil }
        return conversations.first { $0.id == id }
    }

    var activeMessages: [Message] {
        guard let id = activeConversationID else { return [] }
        return messages[id] ?? []
    }

    func setMessages(_ msgs: [Message], for conversationID: ConversationID) {
        messages[conversationID] = msgs
    }

    func updateConversation(_ conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx] = conversation
        }
    }

    func addOrUpdateMessage(_ message: Message, for conversationID: ConversationID) {
        if messages[conversationID] == nil {
            messages[conversationID] = []
        }
        if let idx = messages[conversationID]?.firstIndex(where: { $0.id == message.id }) {
            // Preserve existing content if new message has no content (v2 metadata-only update)
            if message.content.isEmpty {
                messages[conversationID]?[idx].metadata = message.metadata
                messages[conversationID]?[idx].createdAt = message.createdAt
            } else {
                messages[conversationID]?[idx] = message
            }
        } else {
            messages[conversationID]?.append(message)
        }
    }

    func removeMessage(messageID: MessageID, conversationID: ConversationID) {
        messages[conversationID]?.removeAll { $0.id == messageID }
    }

    func updateContent(_ content: MessageContent, messageID: MessageID, conversationID: ConversationID) {
        guard let msgIdx = messages[conversationID]?.firstIndex(where: { $0.id == messageID }) else { return }
        if let contentIdx = messages[conversationID]?[msgIdx].content.firstIndex(where: { $0.id == content.id }) {
            messages[conversationID]?[msgIdx].content[contentIdx] = content
        } else {
            messages[conversationID]?[msgIdx].content.append(content)
        }
    }

    func applyDelta(conversationID: ConversationID, messageID: MessageID, contentID: ContentID, delta: String) {
        let key = "\(messageID):\(contentID)"
        if streamingText[key] == nil {
            if let msgIdx = messages[conversationID]?.firstIndex(where: { $0.id == messageID }),
               let contentIdx = messages[conversationID]?[msgIdx].content.firstIndex(where: { $0.id == contentID }),
               case .text(let data) = messages[conversationID]?[msgIdx].content[contentIdx].data {
                streamingText[key] = data.text + delta
            } else {
                streamingText[key] = delta
            }
        } else {
            streamingText[key]?.append(delta)
        }
    }

    func getStreamingText(messageID: MessageID, contentID: ContentID) -> String? {
        streamingText["\(messageID):\(contentID)"]
    }

    func clearStreamingText(messageID: MessageID, contentID: ContentID) {
        streamingText.removeValue(forKey: "\(messageID):\(contentID)")
    }

    func clear() {
        conversations = []
        activeConversationID = nil
        messages = [:]
        streamingText = [:]
        statuses = [:]
    }
}
