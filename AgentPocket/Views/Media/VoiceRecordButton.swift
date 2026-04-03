import SwiftUI

// MARK: - VoiceRecordButton

struct VoiceRecordButton: View {
    @Binding var isRecording: Bool
    var onRecordComplete: (Data) -> Void
    
    @State private var recorder = AudioRecorder()
    @State private var dragOffset: CGSize = .zero
    @State private var isPressing = false
    @State private var showPermissionAlert = false
    
    private let cancelThreshold: CGFloat = -60
    
    var body: some View {
        HStack {
            if isRecording {
                recordingView
            } else {
                micButton
            }
        }
        .onChange(of: recorder.permissionDenied) { _, denied in
            if denied {
                showPermissionAlert = true
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
            Text("Please enable microphone access in Settings to record voice messages.")
        }
    }
    
    // MARK: - Views
    
    private var micButton: some View {
        Image(systemName: "mic.circle.fill")
            .font(.system(size: 30))
            .foregroundStyle(Theme.cyanAccent)
            .scaleEffect(isPressing ? 0.8 : 1.0)
            .animation(Theme.springAnimation, value: isPressing)
            .gesture(
                LongPressGesture(minimumDuration: 0.3)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .first(let pressing):
                            if !isPressing {
                                isPressing = pressing
                            }
                        case .second(_, let drag):
                            if !isRecording {
                                startRecording()
                            }
                            if let drag = drag {
                                dragOffset = drag.translation
                            }
                        }
                    }
                    .onEnded { value in
                        switch value {
                        case .second(_, let drag):
                            finishRecording(translation: drag?.translation ?? .zero)
                        default:
                            isPressing = false
                            if isRecording {
                                finishRecording(translation: .zero)
                            }
                        }
                    }
            )
    }
    
    private var recordingView: some View {
        HStack(spacing: Theme.spacingMD) {
            if let error = recorder.error {
                Text(error.localizedDescription)
                    .font(Theme.captionFont)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                waveformView
                
                Spacer()
                
                if isCancelling {
                    Text("Release to Cancel")
                        .font(Theme.captionFont.bold())
                        .foregroundStyle(.red)
                        .transition(.opacity)
                } else {
                    Text(formatDuration(recorder.duration))
                        .font(Theme.monoFont)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            
            Image(systemName: isCancelling ? "trash.circle.fill" : "stop.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(isCancelling ? .red : Theme.emerald)
                .offset(y: dragOffset.height < 0 ? dragOffset.height : 0)
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.vertical, Theme.spacingSM)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLG))
        .animation(Theme.springAnimation, value: isCancelling)
        .animation(Theme.springAnimation, value: recorder.error)
    }
    
    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                WaveformBar(index: index, duration: recorder.duration)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var isCancelling: Bool {
        dragOffset.height < cancelThreshold
    }
    
    private func startRecording() {
        HapticManager.impact(.medium)
        Task {
            await recorder.startRecording()
            if !recorder.permissionDenied {
                isRecording = true
            }
        }
    }
    
    private func finishRecording(translation: CGSize) {
        isPressing = false
        dragOffset = .zero
        
        guard isRecording else { return }
        
        if translation.height < cancelThreshold {
            recorder.cancelRecording()
            HapticManager.notification(.warning)
            isRecording = false
        } else {
            Task {
                recorder.stopRecording()
                if let data = recorder.audioData {
                    onRecordComplete(data)
                }
                HapticManager.notification(.success)
                isRecording = false
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - WaveformBar

struct WaveformBar: View {
    let index: Int
    let duration: TimeInterval
    
    var body: some View {
        let phase = duration * 10 + Double(index) * 0.5
        let height = 10 + (sin(phase) + 1) * 8
        
        RoundedRectangle(cornerRadius: 2)
            .fill(Theme.cyanAccent)
            .frame(width: 3, height: CGFloat(height))
            .animation(.linear(duration: 0.1), value: height)
    }
}
