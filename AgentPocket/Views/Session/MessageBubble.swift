import SwiftUI

struct MessageBubble: View {
    let sessionID: String
    let messageWithParts: MessageWithParts
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            if isUser {
                userBubble
            } else {
                assistantContent
            }
            
            if let error = messageWithParts.message.error {
                errorBanner(error)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .contextMenu {
            Button {
                UIPasteboard.general.string = extractText()
            } label: {
                Label("Copy Text", systemImage: "doc.on.doc")
            }
            
            Button {
                appState.forkSession(sessionID: sessionID, fromMessageID: messageWithParts.message.id)
            } label: {
                Label("Fork from Here", systemImage: "arrow.triangle.branch")
            }
            
            Text(messageWithParts.message.timestamp.formatted())
        }
    }
    
    // MARK: - Subviews
    
    private var isUser: Bool {
        messageWithParts.message.role == .user
    }
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(messageWithParts.parts) { part in
                switch part.content {
                case .text(let data):
                    Text(data.text)
                        .foregroundColor(Brand.textPrimary)
                case .file(let data):
                    HStack {
                        Image(systemName: "doc.fill")
                        Text(data.filename)
                    }
                    .font(.caption)
                    .foregroundColor(Brand.cyan)
                    .padding(8)
                    .background(Brand.background)
                    .cornerRadius(8)
                default:
                    EmptyView()
                }
            }
        }
        .padding(12)
        .background(Brand.surfaceLight)
        .cornerRadius(16)
        .cornerRadius(4, corners: [.bottomRight])
    }
    
    private var assistantContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(messageWithParts.parts) { part in
                switch part.content {
                case .text(let data):
                    if let streamingText = appState.sessionStore.getStreamingText(for: messageWithParts.message.id, partID: part.id) {
                        StreamingTextView(text: streamingText)
                    } else {
                        MarkdownRenderer(text: data.text)
                    }
                case .tool(let data):
                    ToolCallView(data: data)
                case .reasoning(let data):
                    ReasoningView(data: data, messageID: messageWithParts.message.id, partID: part.id)
                case .file(let data):
                    HStack {
                        Image(systemName: "paperclip")
                        Text(data.filename)
                    }
                    .font(.caption)
                    .foregroundColor(Brand.textSecondary)
                case .stepStart:
                    Divider().background(Brand.border)
                case .stepFinish(let data):
                    Text("Step completed • \(data.tokens) tokens • \(data.cost)")
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                case .patch(let data):
                    HStack {
                        Image(systemName: "doc.badge.gearshape")
                        Text("\(data.fileCount) files changed")
                        Text("+\(data.additions)").foregroundColor(Brand.emerald)
                        Text("-\(data.deletions)").foregroundColor(.red)
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Brand.surface)
                    .cornerRadius(8)
                case .agent(let data):
                    HStack {
                        Image(systemName: "cpu")
                        Text(data.agentName)
                    }
                    .font(.caption.bold())
                    .foregroundColor(Brand.teal)
                case .subtask(let data):
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                        Text(data.title)
                    }
                    .font(.caption)
                    .foregroundColor(Brand.textSecondary)
                case .snapshot, .compaction, .retry:
                    Circle()
                        .fill(Brand.border)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func errorBanner(_ error: MessageError) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            VStack(alignment: .leading) {
                Text(error.name)
                    .font(.caption.bold())
                Text(error.message)
                    .font(.caption)
            }
        }
        .foregroundColor(.red)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private func extractText() -> String {
        messageWithParts.parts.compactMap { part in
            if case .text(let data) = part.content {
                return data.text
            }
            return nil
        }.joined(separator: "\n")
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
