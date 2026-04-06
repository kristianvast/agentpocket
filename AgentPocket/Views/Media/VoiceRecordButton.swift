import SwiftUI

struct VoiceRecordButton: View {
    @Binding var isRecording: Bool
    var onRecordComplete: (Data) -> Void

    @State private var recorder = AudioRecorder()
    @State private var dragOffset: CGFloat = 0
    @State private var showPermissionAlert = false
    @State private var gestureActive = false
    @State private var wasCancelling = false
    @State private var pulsing = false

    private let cancelThreshold: CGFloat = -100

    private var isCancelling: Bool {
        dragOffset < cancelThreshold
    }

    private var cancelProgress: Double {
        min(1.0, abs(min(0, dragOffset)) / abs(cancelThreshold))
    }

    private var dampenedMicOffset: CGFloat {
        min(0, dragOffset * 0.3)
    }

    var body: some View {
        Group {
            if isRecording {
                recordingBar
            } else {
                micIcon
            }
        }
        .alert("Microphone Access Denied", isPresented: $showPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Enable microphone access in Settings to record voice messages.")
        }
        .onChange(of: recorder.permissionDenied) { _, denied in
            if denied { showPermissionAlert = true }
        }
    }

    // MARK: - Mic Button (idle state)

    private var micIcon: some View {
        Image(systemName: "mic.circle.fill")
            .font(.system(size: 30))
            .foregroundStyle(Theme.cyanAccent)
            .contentShape(Circle().inset(by: -12))
            .gesture(recordGesture)
    }

    // MARK: - Recording Bar (active state)

    private var recordingBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulsing ? 1.4 : 1.0)
                    .opacity(pulsing ? 0.4 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulsing)

                Text(formatDuration(recorder.duration))
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Spacer()

            if isCancelling {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Release to cancel")
                        .font(.system(.caption, weight: .semibold))
                }
                .foregroundStyle(.red)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.compact.left")
                        .font(.caption2)
                        .opacity(0.6 + cancelProgress * 0.4)
                        .offset(x: -cancelProgress * 4)
                    Text("Slide to cancel")
                        .font(.system(.caption, weight: .medium))
                }
                .foregroundStyle(Theme.textMuted.opacity(0.5 + cancelProgress * 0.5))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Spacer()

            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isCancelling ? .red : Theme.cyanAccent)
                .padding(8)
                .background(
                    Circle()
                        .fill(isCancelling ? Color.red.opacity(0.12) : Theme.cyanAccent.opacity(0.12))
                )
                .scaleEffect(isCancelling ? 0.85 : 1.1)
                .offset(x: dampenedMicOffset)
        }
        .padding(.leading, Theme.spacingMD)
        .padding(.trailing, Theme.spacingSM)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(isCancelling ? Color.red.opacity(0.06) : Theme.surface)
        )
        .gesture(recordGesture)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isCancelling)
        .animation(.spring(response: 0.2), value: dragOffset)
        .onAppear { pulsing = true }
        .onDisappear { pulsing = false }
    }

    // MARK: - Gesture

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isRecording && !gestureActive {
                    gestureActive = true
                    startRecording()
                }
                dragOffset = value.translation.width

                let nowCancelling = isCancelling
                if nowCancelling && !wasCancelling {
                    HapticManager.impact(.heavy)
                } else if !nowCancelling && wasCancelling {
                    HapticManager.selection()
                }
                wasCancelling = nowCancelling
            }
            .onEnded { value in
                gestureActive = false
                finishRecording(offset: value.translation.width)
            }
    }

    // MARK: - Actions

    private func startRecording() {
        HapticManager.impact(.medium)
        Task {
            await recorder.startRecording()
            if recorder.permissionDenied {
                gestureActive = false
                return
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isRecording = true
            }
        }
    }

    private func finishRecording(offset: CGFloat) {
        dragOffset = 0
        wasCancelling = false

        guard isRecording else { return }

        if offset < cancelThreshold {
            recorder.cancelRecording()
            HapticManager.notification(.warning)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isRecording = false
            }
        } else if recorder.duration < 0.4 {
            recorder.cancelRecording()
            HapticManager.notification(.error)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isRecording = false
            }
        } else {
            recorder.stopRecording()
            if let data = recorder.audioData {
                onRecordComplete(data)
                HapticManager.notification(.success)
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isRecording = false
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
