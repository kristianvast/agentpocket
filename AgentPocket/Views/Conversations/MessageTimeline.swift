import SwiftUI

struct MessageTimeline: View {
    let conversationID: ConversationID
    @Environment(AppState.self) private var appState
    @State private var initialLoadDone = false
    @State private var scrollTrigger = false

    private var messages: [Message] {
        appState.conversationStore.messages[conversationID] ?? []
    }

    private var isLoading: Bool {
        appState.loadingMessages.contains(conversationID)
    }

    private var isStreaming: Bool {
        appState.conversationStore.statuses[conversationID] == .streaming ||
        appState.conversationStore.statuses[conversationID] == .toolRunning
    }

    private var lastMessageStreamingText: String? {
        guard let lastMessage = messages.last else { return nil }
        let streaming = appState.conversationStore.streamingTextForMessage(lastMessage.id)
        return streaming.values.first
    }

    private var shouldShowThinkingIndicator: Bool {
        guard isStreaming else { return false }
        guard let lastMessage = messages.last else { return true }
        if lastMessage.role == .user { return true }
        if lastMessage.role == .assistant {
            let hasContent = !lastMessage.content.isEmpty
            let hasStreaming = !appState.conversationStore.streamingTextForMessage(lastMessage.id).isEmpty
            return !hasContent && !hasStreaming
        }
        return false
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
                        let streamingText = appState.conversationStore.streamingTextForMessage(message.id)
                        MessageBubble(message: message, streamingText: streamingText)
                            .id(message.id)
                    }
                    
                    if shouldShowThinkingIndicator {
                        ThinkingIndicatorView()
                            .id("thinking-indicator")
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
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
            .onChange(of: lastMessageStreamingText) { _, _ in
                if isStreaming {
                    scrollTrigger.toggle()
                }
            }
            .onChange(of: scrollTrigger) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: shouldShowThinkingIndicator) { _, showing in
                if showing {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("thinking-indicator", anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct ThinkingIndicatorView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.cyanAccent)
                        .frame(width: 6, height: 6)
                        .opacity(animating ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.surface, lineWidth: 1)
            )
            
            Spacer()
        }
        .onAppear { animating = true }
    }
}
