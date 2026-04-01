import SwiftUI

// MARK: - Streaming Text View
struct StreamingTextView: View {
    let text: String
    let isStreaming: Bool
    
    @State private var cursorVisible = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isStreaming {
                streamingContent
            } else {
                MarkdownRenderer(text: text)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isStreaming)
        .task(id: isStreaming) {
            await manageCursorBlink()
        }
    }
    
    // MARK: - Subviews
    private var streamingContent: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(text)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(Brand.textPrimary)
                .lineSpacing(4)
                .textSelection(.enabled)
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Brand.cyan)
                .frame(width: 3, height: 18)
                .opacity(cursorVisible ? 1 : 0)
                .padding(.bottom, 2)
        }
        .transition(.opacity)
    }
    
    // MARK: - Actions
    private func manageCursorBlink() async {
        guard isStreaming else { return }
        
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.1)) {
                    cursorVisible.toggle()
                }
            }
        }
    }
}
