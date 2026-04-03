import SwiftUI

struct MessageTimeline: View {
    let conversationID: ConversationID
    @Environment(AppState.self) private var appState

    private var messages: [Message] {
        appState.conversationStore.messages[conversationID] ?? []
    }

    private var isLoading: Bool {
        appState.loadingMessages.contains(conversationID)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.spacingMD) {
                    if isLoading && messages.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonMessageRow()
                        }
                    }

                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .padding()
                .animation(Theme.springAnimation, value: messages.count)
            }
            .onChange(of: messages.count) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation(Theme.springAnimation) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: appState.conversationStore.streamingText.count) { _, _ in
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}
