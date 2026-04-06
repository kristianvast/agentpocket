import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget Configuration

struct AgentLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AgentActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded presentation
                DynamicIslandExpandedRegion(.leading) {
                    phaseIcon(for: context.state.phase)
                        .font(.title2)
                        .foregroundStyle(phaseColor(for: context.state.phase))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatDuration(context.state.recordingDuration))
                        .font(.system(.body, design: .monospaced, weight: .medium))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    phaseLabel(for: context.state)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottomContent(context: context)
                }
            } compactLeading: {
                phaseIcon(for: context.state.phase)
                    .font(.caption)
                    .foregroundStyle(phaseColor(for: context.state.phase))
            } compactTrailing: {
                compactTrailingContent(for: context.state)
            } minimal: {
                phaseIcon(for: context.state.phase)
                    .font(.caption2)
                    .foregroundStyle(phaseColor(for: context.state.phase))
            }
        }
    }

    // MARK: - Phase Helpers

    @ViewBuilder
    private func phaseIcon(for phase: AgentActivityAttributes.ContentState.Phase) -> some View {
        switch phase {
        case .recording:
            Image(systemName: "mic.fill")
        case .processing:
            Image(systemName: "arrow.up.circle")
        case .responding:
            Image(systemName: "brain")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private func phaseColor(for phase: AgentActivityAttributes.ContentState.Phase) -> Color {
        switch phase {
        case .recording: return .red
        case .processing: return .orange
        case .responding: return Color(red: 0.133, green: 0.827, blue: 0.933) // cyan
        case .completed: return Color(red: 0.063, green: 0.725, blue: 0.506) // emerald
        case .error: return .red
        }
    }

    @ViewBuilder
    private func phaseLabel(for state: AgentActivityAttributes.ContentState) -> some View {
        switch state.phase {
        case .recording:
            Text("Recording")
        case .processing:
            Text("Sending to agent...")
        case .responding:
            Text("Agent responding")
        case .completed:
            Text("Response ready")
        case .error:
            Text(state.errorMessage ?? "Error")
        }
    }

    @ViewBuilder
    private func compactTrailingContent(for state: AgentActivityAttributes.ContentState) -> some View {
        switch state.phase {
        case .recording:
            Text(formatDuration(state.recordingDuration))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
        case .processing:
            ProgressView()
                .tint(.white)
        case .responding, .completed:
            Image(systemName: "text.bubble.fill")
                .font(.caption)
                .foregroundStyle(.white)
        case .error:
            Image(systemName: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func expandedBottomContent(context: ActivityViewContext<AgentActivityAttributes>) -> some View {
        let state = context.state
        switch state.phase {
        case .recording:
            HStack {
                HStack(spacing: 2) {
                    ForEach(0..<16, id: \.self) { i in
                        let height = 8.0 + sin(state.recordingDuration * 8 + Double(i) * 0.6) * 6.0
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.red.opacity(0.8))
                            .frame(width: 2.5, height: max(4, height))
                    }
                }
                .frame(height: 20)

                Spacer()

                Button(intent: StopRecordingIntent()) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.caption2)
                        Text("Stop")
                            .font(.system(.caption, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.red, in: Capsule())
                }
                .buttonStyle(.plain)
            }

        case .processing:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.orange)
                Text("Processing audio...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

        case .responding:
            VStack(alignment: .leading, spacing: 4) {
                Text(state.responseText.isEmpty ? "Thinking..." : state.responseText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.87))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .completed:
            VStack(alignment: .leading, spacing: 6) {
                Text(state.responseText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.87))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let openIntent = OpenConversationIntent(conversationID: context.attributes.conversationID)
                Button(intent: openIntent) {
                    HStack(spacing: 4) {
                        Text("Open full response")
                            .font(.system(.caption2, weight: .medium))
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color(red: 0.133, green: 0.827, blue: 0.933))
                }
                .buttonStyle(.plain)
            }

        case .error:
            Text(state.errorMessage ?? "Something went wrong")
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Lock Screen Live Activity View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<AgentActivityAttributes>

    private var state: AgentActivityAttributes.ContentState { context.state }

    var body: some View {
        VStack(spacing: 0) {
        HStack {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(phaseColor)

                Text(context.attributes.conversationTitle.isEmpty
                    ? context.attributes.serverName
                    : context.attributes.conversationTitle)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.87))
                    .lineLimit(1)

                Spacer()

                phaseBadge
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

        contentSection
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .background(Color(red: 0.05, green: 0.067, blue: 0.09))
    }

    // MARK: - Phase Badge

    @ViewBuilder
    private var phaseBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(phaseColor)
                .frame(width: 6, height: 6)

            Text(phaseText)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(phaseColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(phaseColor.opacity(0.15), in: Capsule())
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        switch state.phase {
        case .recording:
            recordingContent
        case .processing:
            processingContent
        case .responding:
            respondingContent
        case .completed:
            completedContent
        case .error:
            errorContent
        }
    }

    private var recordingContent: some View {
        HStack {
            HStack(spacing: 2.5) {
                ForEach(0..<20, id: \.self) { i in
                    let height = 10.0 + sin(state.recordingDuration * 8 + Double(i) * 0.5) * 8.0
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 3, height: max(4, height))
                }
            }
            .frame(height: 26)

            Spacer()

            Text(formatDuration(state.recordingDuration))
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(.white)

            Button(intent: StopRecordingIntent()) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }

    private var processingContent: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.orange)
            Text("Sending \(formatDuration(state.recordingDuration)) recording to agent...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
    }

    private var respondingContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(state.responseText.isEmpty ? "Agent is thinking..." : state.responseText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.87))
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var completedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.responseText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.87))
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)

            let openIntent = OpenConversationIntent(conversationID: context.attributes.conversationID)
            Button(intent: openIntent) {
                HStack(spacing: 4) {
                    Text("Open full response")
                        .font(.system(.caption, weight: .medium))
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .foregroundStyle(Color(red: 0.133, green: 0.827, blue: 0.933))
            }
            .buttonStyle(.plain)
        }
    }

    private var errorContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(state.errorMessage ?? "Recording failed")
                .font(.subheadline)
                .foregroundStyle(.red.opacity(0.87))
            Spacer()
        }
    }

    // MARK: - Helpers

    private var phaseColor: Color {
        switch state.phase {
        case .recording: return .red
        case .processing: return .orange
        case .responding: return Color(red: 0.133, green: 0.827, blue: 0.933)
        case .completed: return Color(red: 0.063, green: 0.725, blue: 0.506)
        case .error: return .red
        }
    }

    private var phaseText: String {
        switch state.phase {
        case .recording: return "recording"
        case .processing: return "sending"
        case .responding: return "responding"
        case .completed: return "done"
        case .error: return "error"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
