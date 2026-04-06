import ActivityKit
import Foundation

struct AgentActivityAttributes: ActivityAttributes {
    var serverName: String
    var conversationTitle: String
    var conversationID: String

    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case recording
            case processing
            case responding
            case completed
            case error
        }

        var phase: Phase
        var recordingDuration: TimeInterval
        var responseText: String
        var errorMessage: String?

        static func recording(duration: TimeInterval = 0) -> ContentState {
            ContentState(phase: .recording, recordingDuration: duration, responseText: "")
        }

        static func processing(duration: TimeInterval) -> ContentState {
            ContentState(phase: .processing, recordingDuration: duration, responseText: "")
        }

        static func responding(text: String, duration: TimeInterval) -> ContentState {
            let truncated = text.count > SharedConstants.maxResponseTextLength
                ? String(text.prefix(SharedConstants.maxResponseTextLength)) + "\u{2026}"
                : text
            return ContentState(phase: .responding, recordingDuration: duration, responseText: truncated)
        }

        static func completed(text: String, duration: TimeInterval) -> ContentState {
            let truncated = text.count > SharedConstants.maxResponseTextLength
                ? String(text.prefix(SharedConstants.maxResponseTextLength)) + "\u{2026}"
                : text
            return ContentState(phase: .completed, recordingDuration: duration, responseText: truncated)
        }

        static func error(_ message: String) -> ContentState {
            ContentState(phase: .error, recordingDuration: 0, responseText: "", errorMessage: message)
        }
    }
}
