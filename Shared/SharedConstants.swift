import Foundation

enum SharedConstants {
    static let appGroupID = "group.ai.agentpocket"
    static let recordURLScheme = "agentpocket"
    static let recordURLString = "agentpocket://record"
    static let stopRecordingNotification = Notification.Name("agentpocket.stopRecording")

    static let maxRecordingDuration: TimeInterval = 300
    static let activityDismissalDelay: TimeInterval = 300
    // 4KB ActivityKit ContentState budget — leave room for other fields
    static let maxResponseTextLength = 2048
}
