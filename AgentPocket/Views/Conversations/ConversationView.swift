import SwiftUI

struct ConversationView: View {
    let conversation: Conversation
    @Environment(AppState.self) private var appState
    @State private var error: (any Error)?

    private var subtitle: String? {
        var parts: [String] = []
        if let model = conversation.metadata.modelName, !model.isEmpty {
            parts.append(model)
        }
        if let agent = conversation.metadata.agentName, !agent.isEmpty {
            parts.append(agent)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            MessageTimeline(conversationID: conversation.id)

            PromptBar(conversationID: conversation.id)
        }
        .navigationTitle(conversation.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let subtitle {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(conversation.title ?? "Chat")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)

                        Text(subtitle)
                            .font(.system(.caption2))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
        }
        .background(Theme.background)
        .task(id: conversation.id) {
            do {
                try await appState.loadMessages(for: conversation.id)
            } catch {
                self.error = error
            }
        }
        .errorAlert(error: $error)
    }
}
