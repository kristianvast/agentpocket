import SwiftUI

// MARK: - PreviewContent

enum PreviewContent {
    case audio(data: Data, duration: TimeInterval)
    case image(UIImage)
}

// MARK: - MediaPreview

struct MediaPreview: View {
    let content: PreviewContent
    var onSend: () -> Void
    var onDiscard: () -> Void
    
    @State private var audioPlayer = AudioPlayer()
    
    var body: some View {
        VStack(spacing: Theme.spacingMD) {
            switch content {
            case .audio(let data, let duration):
                audioPreview(data: data, duration: duration)
            case .image(let image):
                imagePreview(image: image)
            }
            
            HStack {
                Button(action: {
                    HapticManager.impact(.light)
                    onDiscard()
                }) {
                    Image(systemName: "trash")
                        .font(Theme.titleFont)
                        .foregroundColor(.red)
                        .padding(Theme.spacingSM)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.notification(.success)
                    onSend()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.cyanAccent)
                }
            }
        }
        .padding(Theme.spacingMD)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMD)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    // MARK: - Audio Preview
    
    @ViewBuilder
    private func audioPreview(data: Data, duration: TimeInterval) -> some View {
        HStack(spacing: Theme.spacingMD) {
            Button(action: {
                audioPlayer.togglePlayback(data: data)
            }) {
                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.cyanAccent)
            }
            
            HStack(spacing: 3) {
                let heights = waveformHeights(for: data, count: 20)
                ForEach(0..<heights.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.cyanAccent.opacity(0.7))
                        .frame(width: 4, height: heights[index])
                }
            }
            .frame(height: 40)
            
            Spacer()
            
            Text(formatDuration(duration))
                .font(Theme.monoFont)
                .foregroundColor(Theme.textMuted)
        }
        .padding(Theme.spacingSM)
        .background(Theme.background)
        .cornerRadius(Theme.radiusSM)
    }
    
    // MARK: - Image Preview
    
    @ViewBuilder
    private func imagePreview(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .cornerRadius(Theme.radiusSM)
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func waveformHeights(for data: Data, count: Int) -> [CGFloat] {
        let bytes = [UInt8](data.prefix(min(data.count, 1024)))
        guard !bytes.isEmpty else { return Array(repeating: 10, count: count) }
        
        var heights: [CGFloat] = []
        let step = max(1, bytes.count / count)
        
        for i in 0..<count {
            let byteIndex = (i * step) % bytes.count
            let byte = bytes[byteIndex]
            let normalized = CGFloat(byte) / 255.0
            heights.append(10 + (normalized * 24))
        }
        return heights
    }
}
