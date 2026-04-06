import ActivityKit
import Foundation

@MainActor
@Observable
final class AgentActivityManager {

    private(set) var currentActivity: Activity<AgentActivityAttributes>?
    private(set) var recordingDuration: TimeInterval = 0

    private var durationTimer: Timer?

    var isActive: Bool { currentActivity != nil }

    func startRecording(serverName: String, conversationTitle: String, conversationID: String) {
        guard !ActivityAuthorizationInfo().areActivitiesEnabled else {
            startRecordingActivity(serverName: serverName, conversationTitle: conversationTitle, conversationID: conversationID)
            return
        }
        startRecordingActivity(serverName: serverName, conversationTitle: conversationTitle, conversationID: conversationID)
    }

    func transitionToProcessing() {
        let state = AgentActivityAttributes.ContentState.processing(duration: recordingDuration)
        updateActivity(with: state)
        stopDurationTimer()
    }

    func updateResponse(text: String) {
        let state = AgentActivityAttributes.ContentState.responding(text: text, duration: recordingDuration)
        updateActivity(with: state)
    }

    func complete(finalText: String) {
        let state = AgentActivityAttributes.ContentState.completed(text: finalText, duration: recordingDuration)
        updateActivity(with: state)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(SharedConstants.activityDismissalDelay))
            self?.endActivity()
        }
    }

    func fail(message: String) {
        let state = AgentActivityAttributes.ContentState.error(message)
        updateActivity(with: state)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            self?.endActivity()
        }
    }

    func endActivity() {
        stopDurationTimer()
        guard let activity = currentActivity else { return }

        let finalState = AgentActivityAttributes.ContentState.completed(
            text: "",
            duration: recordingDuration
        )

        let activityToEnd = activity
        currentActivity = nil
        recordingDuration = 0

        Task.detached {
            await activityToEnd.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    // MARK: - Private

    private func startRecordingActivity(serverName: String, conversationTitle: String, conversationID: String) {
        let attributes = AgentActivityAttributes(
            serverName: serverName,
            conversationTitle: conversationTitle,
            conversationID: conversationID
        )

        let initialState = AgentActivityAttributes.ContentState.recording()

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            recordingDuration = 0
            startDurationTimer()
        } catch {
            // ActivityKit not available — continue without Live Activity
        }
    }

    private func updateActivity(with state: AgentActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        let activityToUpdate = activity
        Task.detached {
            await activityToUpdate.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recordingDuration += 1.0
                let state = AgentActivityAttributes.ContentState.recording(duration: self.recordingDuration)
                self.updateActivity(with: state)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
