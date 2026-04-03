import SwiftUI

struct ConversationListView: View {
    @Environment(AppState.self) private var appState
    @State private var error: (any Error)?

    var body: some View {
        List(selection: Bindable(appState.conversationStore).activeConversationID) {
            ForEach(appState.conversationStore.conversations) { conversation in
                NavigationLink(value: conversation.id) {
                    VStack(alignment: .leading) {
                        Text(conversation.title ?? "New Conversation")
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        HStack {
                            Text(conversation.updatedAt, style: .time)
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textMuted)

                            Spacer()

                            if conversation.status != .idle {
                                StatusIndicator(status: conversation.status)
                            }
                        }
                    }
                    .padding(.vertical, Theme.spacingXS)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let conversation = appState.conversationStore.conversations[index]
                    Task {
                        do {
                            try await appState.deleteConversation(id: conversation.id)
                        } catch {
                            self.error = error
                        }
                    }
                }
            }
        }
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        do {
                            let newConv = try await appState.createConversation()
                            appState.conversationStore.activeConversationID = newConv.id
                        } catch {
                            self.error = error
                        }
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button("Disconnect") {
                    appState.disconnect()
                }
                .foregroundStyle(.red)
            }
        }
        .overlay {
            if appState.isLoadingConversations {
                ProgressView()
                    .tint(Theme.cyanAccent)
            } else if appState.conversationStore.conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a new conversation to chat with the agent.")
                )
            }
        }
        .errorAlert(error: $error)
    }
}
