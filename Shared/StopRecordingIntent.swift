import AppIntents

struct StopRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Recording"
    static let description: IntentDescription = "Stops the current voice recording and sends it to the agent"

    func perform() async throws -> some IntentResult {
        // LiveActivityIntent.perform() runs in the main app process, not the widget extension.
        // NotificationCenter.default is in-process only, which is exactly what we want.
        await MainActor.run {
            NotificationCenter.default.post(name: SharedConstants.stopRecordingNotification, object: nil)
        }
        return .result()
    }
}

struct OpenConversationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open Conversation"
    static let description: IntentDescription = "Opens the conversation in the app"

    @Parameter(title: "Conversation ID")
    var conversationID: String

    init() {
        self.conversationID = ""
    }

    init(conversationID: String) {
        self.conversationID = conversationID
    }

    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
