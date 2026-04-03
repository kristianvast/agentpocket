import SwiftUI

struct ConversationView: View {
    let conversation: Conversation
    @Environment(AppState.self) private var appState
    @State private var error: (any Error)?

    var body: some View {
        VStack(spacing: 0) {
            MessageTimeline(conversationID: conversation.id)

            PromptBar(conversationID: conversation.id)
        }
        .navigationTitle(conversation.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
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
