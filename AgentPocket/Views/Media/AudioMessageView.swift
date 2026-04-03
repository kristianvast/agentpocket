import SwiftUI

// MARK: - AudioMessageView

struct AudioMessageView: View {
    let content: AudioContent
    @State private var player = AudioPlayer()
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack(spacing: Theme.spacingMD) {
                Button {
                    if let data = content.data {
                        player.togglePlayback(data: data)
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.cyanAccent)
                }
                
                VStack(spacing: Theme.spacingXS) {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let duration = player.duration > 0 ? player.duration : (content.duration ?? 1)
                        let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                        let playedWidth = width * CGFloat(progress)
                        
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Theme.cyanAccent.opacity(0.3))
                                .frame(width: width)
                            
                            Rectangle()
                                .fill(Theme.cyanAccent)
                                .frame(width: playedWidth)
                        }
                        .mask {
                            HStack(spacing: 2) {
                                let barCount = 30
                                let barWidth = (width - CGFloat(barCount - 1) * 2) / CGFloat(barCount)
                                ForEach(0..<barCount, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 2)
                                        .frame(width: max(1, barWidth), height: deterministicHeight(for: index))
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let ratio = location.x / width
                            let targetTime = duration * TimeInterval(ratio)
                            player.seek(to: targetTime)
                        }
                    }
                    .frame(height: 30)
                    
                    HStack {
                        Text(formatTime(player.currentTime))
                        Spacer()
                        Text(formatTime(player.duration > 0 ? player.duration : (content.duration ?? 0)))
                    }
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textMuted)
                }
            }
            
            if let error = player.error {
                Text(error.localizedDescription)
                    .font(Theme.captionFont)
                    .foregroundStyle(.red)
            }
        }
        .padding(Theme.spacingMD)
        .background(Theme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        .onDisappear {
            player.stop()
        }
    }
    
    // MARK: - Helpers
    
    private func deterministicHeight(for index: Int) -> CGFloat {
        let hash = abs(content.data?.hashValue ?? index)
        let seed = (hash &+ index) ^ (index &* 31)
        let normalized = Double(seed % 100) / 100.0
        return CGFloat(10 + normalized * 20)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
