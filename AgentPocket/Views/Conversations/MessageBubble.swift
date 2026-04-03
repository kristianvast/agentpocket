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
            DisclosureGroup("Reasoning") {
                Text(reasoningContent.text)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            .tint(Theme.cyanAccent)
            
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
