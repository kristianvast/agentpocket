import SwiftUI

struct MessageBubble: View {
    let message: Message
    var streamingText: [ContentID: String] = [:]
    
    var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                ForEach(message.content) { content in
                    contentView(for: content)
                }
            }
            .padding(12)
            .background(isUser ? Theme.surface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isUser ? Theme.cyanAccent.opacity(0.3) : Theme.surface, lineWidth: 1)
            )
            
            if !isUser { Spacer() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "You" : "Agent") said")
    }
    
    @ViewBuilder
    private func contentView(for content: MessageContent) -> some View {
        switch content.data {
        case .text(let textContent):
            if let streaming = streamingText[content.id] {
                StreamingTextView(text: streaming)
            } else {
                MarkdownRenderer(text: textContent.text)
            }
            
        case .audio(let audioContent):
            AudioMessageView(content: audioContent)
            
        case .image(let imageContent):
            if let data = imageContent.data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let url = imageContent.url {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: 250)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
        case .file(let fileContent):
            HStack {
                Image(systemName: "doc.fill")
                Text(fileContent.path.components(separatedBy: "/").last ?? "File")
            }
            .padding(8)
            .background(Theme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
        case .tool(let toolContent):
            ToolCallView(content: toolContent)
            
        case .reasoning(let reasoningContent):
            ThinkingBlock(
                reasoningContent: reasoningContent,
                streamingText: streamingText[content.id]
            )
            
        case .error(let errorContent):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(errorContent.message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(8)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct ThinkingBlock: View {
    let reasoningContent: ReasoningContent
    let streamingText: String?
    
    @State private var isExpanded: Bool = false
    
    private var isStreaming: Bool {
        streamingText != nil
    }
    
    private var displayText: String {
        if let streaming = streamingText {
            return streaming
        }
        return reasoningContent.text
    }
    
    private var headerText: String {
        if isStreaming {
            return "Thinking..."
        }
        if let tokens = reasoningContent.tokenCount {
            return "Reasoned for \(tokens) tokens"
        }
        return "Reasoning"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Theme.quickAnimation) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(Theme.cyanAccent)
                    
                    Text(headerText)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textMuted)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded || isStreaming {
                HStack(alignment: .top, spacing: Theme.spacingSM) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.cyanAccent.opacity(0.4))
                        .frame(width: 3)
                    
                    if reasoningContent.isRedacted {
                        Text("Content not available")
                            .font(Theme.captionFont)
                            .italic()
                            .foregroundStyle(Theme.textMuted.opacity(0.6))
                    } else {
                        Text(displayText)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textMuted)
                            .textSelection(.enabled)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(Theme.spacingSM)
        .background(Theme.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
        .onChange(of: isStreaming) { _, streaming in
            if streaming {
                isExpanded = true
            }
        }
        .onAppear {
            if isStreaming {
                isExpanded = true
            }
        }
    }
}
