import SwiftUI

struct ReasoningView: View {
    let data: ReasoningPartData
    let messageID: String
    let partID: String
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(Brand.textSecondary)
                    
                    Text(isStreaming ? "Thinking..." : "Thought Process")
                        .font(.subheadline.italic())
                        .foregroundColor(Brand.textSecondary)
                    
                    if isStreaming {
                        StatusIndicator(isAnimating: true)
                    } else if let duration = durationString {
                        Text("(\(duration))")
                            .font(.caption)
                            .foregroundColor(Brand.textMuted)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 8)
            }
            
            if isExpanded {
                VStack(alignment: .leading) {
                    if let streamingText = appState.sessionStore.getStreamingText(for: messageID, partID: partID) {
                        Text(streamingText)
                            .font(.subheadline.italic())
                            .foregroundColor(Brand.textMuted)
                    } else {
                        Text(data.text)
                            .font(.subheadline.italic())
                            .foregroundColor(Brand.textMuted)
                    }
                }
                .padding(.leading, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    Rectangle()
                        .fill(Brand.border)
                        .frame(width: 2)
                        .padding(.leading, 6),
                    alignment: .leading
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    private var isStreaming: Bool {
        data.time?.end == nil
    }
    
    private var durationString: String? {
        guard let start = data.time?.start, let end = data.time?.end else { return nil }
        let duration = end.timeIntervalSince(start)
        return String(format: "%.1fs", duration)
    }
}
