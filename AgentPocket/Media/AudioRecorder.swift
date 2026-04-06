import AVFoundation
import Foundation

// MARK: - AudioRecorder

@MainActor
@Observable
final class AudioRecorder: NSObject {

    // MARK: - State

    private(set) var isRecording = false
    private(set) var duration: TimeInterval = 0
    private(set) var audioData: Data?
    private(set) var permissionDenied = false
    private(set) var error: AudioRecorderError?
    private(set) var didHitMaxDuration = false

    var backgroundMode = false

    // MARK: - Private

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?
    private var maxDurationTimer: Timer?
    private var interruptionObserver: (any NSObjectProtocol)?

    // MARK: - Configuration

    static let maxDuration: TimeInterval = 300

    private static let sampleRate: Double = 16_000
    private static let channels: Int = 1
    private static let bitDepth: Int = 16

    private var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: Self.channels,
            AVLinearPCMBitDepthKey: Self.bitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            permissionDenied = !granted
            return granted
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        self.permissionDenied = !granted
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    // MARK: - Recording

    func startRecording() async {
        error = nil
        audioData = nil
        didHitMaxDuration = false

        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSTemporaryDirectory())
            let freeSpace = (systemAttributes[.systemFreeSize] as? Int64) ?? 0
            guard freeSpace > 50_000_000 else {
                error = .insufficientDiskSpace
                return
            }
        } catch {
            self.error = .insufficientDiskSpace
            return
        }

        guard await requestPermission() else {
            error = .permissionDenied
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]
            if backgroundMode {
                options.insert(.mixWithOthers)
            }
            try session.setCategory(.playAndRecord, mode: .default, options: options)
            try session.setActive(true)
            setupInterruptionHandling()

            let url = makeTemporaryFileURL()
            fileURL = url

            let audioRecorder = try AVAudioRecorder(url: url, settings: recordingSettings)
            audioRecorder.delegate = self
            recorder = audioRecorder

            guard audioRecorder.record() else {
                error = .recordingFailed
                cleanup()
                return
            }

            isRecording = true
            duration = 0
            startTimer()

            if backgroundMode {
                startMaxDurationTimer()
            }
        } catch {
            self.error = .sessionSetupFailed(error.localizedDescription)
            cleanup()
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        recorder?.stop()
        stopTimer()
        stopMaxDurationTimer()
        removeInterruptionObserver()
        isRecording = false

        if let url = fileURL, let data = try? Data(contentsOf: url) {
            audioData = data
            duration = recorder?.currentTime ?? duration
        }

        if !backgroundMode {
            deactivateSession()
        }
        cleanup()
    }

    func cancelRecording() {
        guard isRecording else { return }

        recorder?.stop()
        recorder?.deleteRecording()
        stopTimer()
        stopMaxDurationTimer()
        removeInterruptionObserver()
        isRecording = false
        audioData = nil
        duration = 0

        deactivateSession()
        cleanup()
    }

    func reset() {
        audioData = nil
        duration = 0
        error = nil
        didHitMaxDuration = false
    }

    func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Audio Content

    func makeAudioContent() -> AudioContent? {
        guard let data = audioData else { return nil }
        return AudioContent(
            data: data,
            mimeType: "audio/wav",
            duration: duration
        )
    }

    // MARK: - Private Helpers

    private func makeTemporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
        let filename = "recording_\(UUID().uuidString).wav"
        return directory.appendingPathComponent(filename)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording, let recorder = self.recorder else { return }
                self.duration = recorder.currentTime
                if self.duration >= Self.maxDuration {
                    self.didHitMaxDuration = true
                    self.stopRecording()
                    return
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startMaxDurationTimer() {
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: SharedConstants.maxRecordingDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopRecording()
            }
        }
    }

    private func stopMaxDurationTimer() {
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
    }

    private func setupInterruptionHandling() {
        removeInterruptionObserver()

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            if isRecording {
                stopRecording()
            }
        case .ended:
            break
        @unknown default:
            break
        }
    }

    private func removeInterruptionObserver() {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
    }

    private func cleanup() {
        recorder = nil
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
            fileURL = nil
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.error = .recordingFailed
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        Task { @MainActor in
            self.error = .encodingFailed(error?.localizedDescription ?? "Unknown encoding error")
        }
    }
}

// MARK: - AudioRecorderError

enum AudioRecorderError: LocalizedError, Hashable {
    case permissionDenied
    case recordingFailed
    case sessionSetupFailed(String)
    case encodingFailed(String)
    case insufficientDiskSpace

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone access denied. Enable it in Settings."
        case .recordingFailed:
            "Recording failed to start."
        case .sessionSetupFailed(let detail):
            "Audio session setup failed: \(detail)"
        case .encodingFailed(let detail):
            "Audio encoding failed: \(detail)"
        case .insufficientDiskSpace:
            "Not enough disk space to record audio"
        }
    }
}
