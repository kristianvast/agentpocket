import Foundation
import SwiftUI

@Observable
@MainActor
final class SessionStore {
    var sessions: [Session] = []
    var activeSessionID: SessionID?
    var messages: [SessionID: [MessageWithParts]] = [:]
    var streamingText: [String: String] = [:]

    var activeSession: Session? {
        guard let id = activeSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    var activeMessages: [MessageWithParts] {
        guard let id = activeSessionID else { return [] }
        return messages[id] ?? []
    }

    func setMessages(_ msgs: [MessageWithParts], for sessionID: SessionID) {
        messages[sessionID] = msgs
    }

    func updateSession(_ session: Session) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        }
    }

    func addOrUpdateMessage(_ message: Message, for sessionID: SessionID) {
        if messages[sessionID] == nil {
            messages[sessionID] = []
        }
        if let idx = messages[sessionID]?.firstIndex(where: { $0.info.id == message.id }) {
            messages[sessionID]?[idx].info = message
        } else {
            messages[sessionID]?.append(MessageWithParts(info: message, parts: []))
        }
    }

    func addOrUpdatePart(_ part: MessagePart, for sessionID: SessionID) {
        guard let msgIdx = messages[sessionID]?.firstIndex(where: { $0.info.id == part.messageID }) else { return }
        if let partIdx = messages[sessionID]?[msgIdx].parts.firstIndex(where: { $0.id == part.id }) {
            messages[sessionID]?[msgIdx].parts[partIdx] = part
        } else {
            messages[sessionID]?[msgIdx].parts.append(part)
        }
    }

    func removePart(partID: PartID, messageID: MessageID, sessionID: SessionID) {
        guard let msgIdx = messages[sessionID]?.firstIndex(where: { $0.info.id == messageID }) else { return }
        messages[sessionID]?[msgIdx].parts.removeAll { $0.id == partID }
    }

    func removeMessage(messageID: MessageID, sessionID: SessionID) {
        messages[sessionID]?.removeAll { $0.info.id == messageID }
    }

    func applyDelta(sessionID: SessionID, messageID: MessageID, partID: PartID, field: String, delta: String) {
        let key = "\(messageID):\(partID)"
        if streamingText[key] == nil {
            if let msgIdx = messages[sessionID]?.firstIndex(where: { $0.info.id == messageID }),
               let partIdx = messages[sessionID]?[msgIdx].parts.firstIndex(where: { $0.id == partID }),
               case .text(let data) = messages[sessionID]?[msgIdx].parts[partIdx].content {
                streamingText[key] = data.text + delta
            } else {
                streamingText[key] = delta
            }
        } else {
            streamingText[key]?.append(delta)
        }
    }

    func getStreamingText(messageID: MessageID, partID: PartID) -> String? {
        streamingText["\(messageID):\(partID)"]
    }

    func clearStreamingText(messageID: MessageID, partID: PartID) {
        streamingText.removeValue(forKey: "\(messageID):\(partID)")
    }

    func clear() {
        sessions = []
        activeSessionID = nil
        messages = [:]
        streamingText = [:]
    }
}
