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
    var loadedProjectID: ProjectID?
    private var deltaBuffer: [String: String] = [:]
    private let deltaThrottler = Throttler(delay: 0.1)

    var activeConversation: Conversation? {
        guard let id = activeConversationID else { return nil }
        return conversations.first { $0.id == id }
    }

    var activeMessages: [Message] {
        guard let id = activeConversationID else { return [] }
        return messages[id] ?? []
    }

    func setConversations(_ convs: [Conversation], forProject projectID: ProjectID) {
        conversations = convs
        loadedProjectID = projectID
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
        if deltaBuffer[key] == nil {
            if let msgIdx = messages[conversationID]?.firstIndex(where: { $0.id == messageID }),
               let contentIdx = messages[conversationID]?[msgIdx].content.firstIndex(where: { $0.id == contentID }),
               case .text(let data) = messages[conversationID]?[msgIdx].content[contentIdx].data {
                deltaBuffer[key] = data.text + delta
            } else {
                deltaBuffer[key] = delta
            }
        } else {
            deltaBuffer[key]?.append(delta)
        }

        deltaThrottler.throttle { [self] in
            self.flushAllDeltaBuffers()
        }
    }

    private func flushDeltaBuffer(for key: String) {
        guard let buffered = deltaBuffer[key] else { return }
        streamingText[key] = buffered
    }

    func flushAllDeltaBuffers() {
        deltaThrottler.cancel()
        for (key, value) in deltaBuffer {
            streamingText[key] = value
        }
    }

    func cleanupAbortedState(conversationID: ConversationID) {
        flushAllDeltaBuffers()

        if let msgs = messages[conversationID] {
            for (msgIdx, message) in msgs.enumerated() {
                for (contentIdx, content) in message.content.enumerated() {
                    if case .tool(var toolData) = content.data,
                       toolData.status == .pending || toolData.status == .running {
                        toolData.status = .failed
                        toolData.error = "Aborted by user"
                        messages[conversationID]?[msgIdx].content[contentIdx].data = .tool(toolData)
                    }
                }
            }
        }

        let messageIDs = Set((messages[conversationID] ?? []).map(\.id))
        let keysToRemove = streamingText.keys.filter { key in
            messageIDs.contains(String(key.split(separator: ":").first ?? ""))
        }

        for key in keysToRemove {
            streamingText.removeValue(forKey: key)
            deltaBuffer.removeValue(forKey: key)
        }

        statuses[conversationID] = .idle
    }

    func getStreamingText(messageID: MessageID, contentID: ContentID) -> String? {
        streamingText["\(messageID):\(contentID)"]
    }

    func streamingTextForMessage(_ messageID: MessageID) -> [ContentID: String] {
        let prefix = "\(messageID):"
        var result: [ContentID: String] = [:]
        for (key, value) in streamingText where key.hasPrefix(prefix) {
            let contentID = String(key.dropFirst(prefix.count))
            result[contentID] = value
        }
        return result
    }

    func clearStreamingText(messageID: MessageID, contentID: ContentID) {
        let key = "\(messageID):\(contentID)"
        streamingText.removeValue(forKey: key)
        deltaBuffer.removeValue(forKey: key)
    }

    func clear() {
        conversations = []
        activeConversationID = nil
        messages = [:]
        streamingText = [:]
        statuses = [:]
        deltaBuffer = [:]
        deltaThrottler.cancel()
    }
}
