import SwiftUI

struct MessageTimeline: View {
    let conversationID: ConversationID
    @Environment(AppState.self) private var appState
    @State private var initialLoadDone = false

    private var messages: [Message] {
        appState.conversationStore.messages[conversationID] ?? []
    }

    private var isLoading: Bool {
        appState.loadingMessages.contains(conversationID)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.spacingMD) {
                    if isLoading && messages.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonMessageRow()
                        }
                    }

                    ForEach(messages) { message in
                        let streamingText = appState.conversationStore.streamingTextForMessage(message.id)
                        MessageBubble(message: message, streamingText: streamingText)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { oldCount, newCount in
                if !initialLoadDone {
                    guard newCount > 0 else { return }
                    initialLoadDone = true
                    DispatchQueue.main.async {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                } else if newCount > oldCount {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
