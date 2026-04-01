import SwiftUI

struct MessageTimeline: View {
    let sessionID: String
    @Environment(AppState.self) private var appState
    @State private var isLoadingOlder = false
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if isLoadingOlder {
                        ProgressView()
                            .padding()
                            .tint(Brand.cyan)
                    } else {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task {
                                    await loadOlderMessages()
                                }
                            }
                    }
                    
                    Spacer(minLength: 20)
                    
                    let messages = appState.sessionStore.activeMessages[sessionID] ?? []
                    ForEach(messages) { messageWithParts in
                        MessageBubble(
                            sessionID: sessionID,
                            messageWithParts: messageWithParts
                        )
                        .id(messageWithParts.message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .onChange(of: appState.sessionStore.activeMessages[sessionID]?.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let messages = appState.sessionStore.activeMessages[sessionID],
              let last = messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.message.id, anchor: .bottom)
        }
    }
    
    private func loadOlderMessages() async {
        guard let messages = appState.sessionStore.activeMessages[sessionID],
              let first = messages.first,
              !isLoadingOlder else { return }
        
        isLoadingOlder = true
        await appState.loadMessages(for: sessionID, before: first.message.id)
        isLoadingOlder = false
    }
}
