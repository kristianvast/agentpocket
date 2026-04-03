import AVFoundation
import Foundation

// MARK: - AudioPlayer

@MainActor
@Observable
final class AudioPlayer: NSObject {

    // MARK: - State

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var error: AudioPlayerError?

    // MARK: - Private

    private var player: AVAudioPlayer?
    private var timer: Timer?

    // MARK: - Playback

    func play(data: Data) {
        stop()
        error = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.delegate = self
            player = audioPlayer

            duration = audioPlayer.duration
            currentTime = 0

            guard audioPlayer.play() else {
                self.error = .playbackFailed
                cleanup()
                return
            }

            isPlaying = true
            startTimer()
        } catch {
            self.error = .decodingFailed(error.localizedDescription)
            cleanup()
        }
    }

    func play(url: URL) {
        stop()
        error = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            player = audioPlayer

            duration = audioPlayer.duration
            currentTime = 0

            guard audioPlayer.play() else {
                self.error = .playbackFailed
                cleanup()
                return
            }

            isPlaying = true
            startTimer()
        } catch {
            self.error = .decodingFailed(error.localizedDescription)
            cleanup()
        }
    }

    func pause() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func resume() {
        guard let player, !isPlaying else { return }
        guard player.play() else {
            error = .playbackFailed
            return
        }
        isPlaying = true
        startTimer()
    }

    func stop() {
        player?.stop()
        isPlaying = false
        currentTime = 0
        stopTimer()
        deactivateSession()
        cleanup()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(0, time), player.duration)
        player.currentTime = clamped
        currentTime = clamped
    }

    // MARK: - Convenience

    func togglePlayback(data: Data) {
        if isPlaying {
            pause()
        } else if player != nil {
            resume()
        } else {
            play(data: data)
        }
    }

    // MARK: - Private Helpers

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player, self.isPlaying else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanup() {
        player = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
            self.deactivateSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor in
            self.error = .decodingFailed(error?.localizedDescription ?? "Unknown decoding error")
            self.stop()
        }
    }
}

// MARK: - AudioPlayerError

enum AudioPlayerError: LocalizedError, Hashable {
    case playbackFailed
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            "Audio playback failed."
        case .decodingFailed(let detail):
            "Audio decoding failed: \(detail)"
        }
    }
}
