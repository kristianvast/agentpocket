import SwiftUI

struct ConversationListView: View {
    @Environment(AppState.self) private var appState
    @State private var error: (any Error)?
    @State private var hasAnimated = false

    private var activeProject: Project? {
        appState.projectStore.activeProject
    }

    var body: some View {
        List(selection: Bindable(appState.conversationStore).activeConversationID) {
            if appState.isLoadingConversations {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonSessionRow()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                ForEach(Array(appState.conversationStore.conversations.enumerated()), id: \.element.id) { index, conversation in
                    NavigationLink(value: conversation.id) {
                        SessionRow(conversation: conversation, status: appState.conversationStore.statuses[conversation.id])
                            .opacity(hasAnimated ? 1 : 0)
                            .offset(x: hasAnimated ? 0 : -12)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.05),
                                value: hasAnimated
                            )
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: Theme.radiusSM)
                            .fill(Theme.surface.opacity(0.5))
                            .padding(.vertical, 2)
                    )
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(activeProject?.displayName ?? "Sessions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticManager.impact(.light)
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
                        .foregroundStyle(Theme.cyanAccent)
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appState.conversationStore.activeConversationID = nil
                    appState.projectStore.activeProjectID = nil
                } label: {
                    HStack(spacing: Theme.spacingXS) {
                        Image(systemName: "chevron.left")
                            .font(.caption.bold())
                        Text("Projects")
                            .font(Theme.captionFont)
                    }
                    .foregroundStyle(Theme.cyanAccent)
                }
            }
        }
        .overlay {
            if !appState.isLoadingConversations && appState.conversationStore.conversations.isEmpty {
                ContentUnavailableView {
                    Label("No Sessions", systemImage: "bubble.left.and.bubble.right")
                        .foregroundStyle(Theme.textMuted)
                } description: {
                    Text("Start a new session to chat with the agent.")
                        .foregroundStyle(Theme.textMuted)
                } actions: {
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
                        Text("New Session")
                            .font(Theme.headlineFont)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.cyanAccent)
                    .foregroundStyle(.black)
                }
            }
        }
        .refreshable {
            if let project = activeProject {
                await appState.loadConversationsForProject(project)
            }
        }
        .errorAlert(error: $error)
        .onAppear {
            guard !hasAnimated else { return }
            // Small delay so the list layout is ready before animating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.4)) {
                    hasAnimated = true
                }
            }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let conversation: Conversation
    var status: ConversationStatus?

    private var resolvedStatus: ConversationStatus {
        status ?? conversation.status
    }

    private var hasSummary: Bool {
        guard let s = conversation.metadata.summary else { return false }
        return s.additions > 0 || s.deletions > 0 || s.files > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            // Title + status
            HStack(alignment: .center) {
                Text(conversation.title ?? "New Session")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                if resolvedStatus != .idle {
                    SessionStatusBadge(status: resolvedStatus)
                }
            }

            // Metadata row
            HStack(spacing: Theme.spacingMD) {
                // Diff summary
                if hasSummary, let summary = conversation.metadata.summary {
                    HStack(spacing: Theme.spacingSM) {
                        if summary.additions > 0 {
                            Text("+\(summary.additions)")
                                .font(.system(.caption2, design: .monospaced, weight: .medium))
                                .foregroundStyle(Theme.emerald)
                        }
                        if summary.deletions > 0 {
                            Text("-\(summary.deletions)")
                                .font(.system(.caption2, design: .monospaced, weight: .medium))
                                .foregroundStyle(Color(hex: "#EF4444"))
                        }
                        if summary.files > 0 {
                            Text("\(summary.files) file\(summary.files == 1 ? "" : "s")")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }

                    Circle()
                        .fill(Theme.textMuted.opacity(0.3))
                        .frame(width: 3, height: 3)
                }

                // Model name
                if let model = conversation.metadata.modelName, !model.isEmpty {
                    Text(model)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)

                    Circle()
                        .fill(Theme.textMuted.opacity(0.3))
                        .frame(width: 3, height: 3)
                }

                // Time
                Text(conversation.updatedAt, style: .relative)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textMuted)

                Spacer()
            }
        }
        .padding(.vertical, Theme.spacingXS)
    }
}

// MARK: - Session Status Badge

struct SessionStatusBadge: View {
    let status: ConversationStatus
    @State private var isPulsing = false

    private var color: Color {
        switch status {
        case .idle: return .gray
        case .streaming: return Theme.cyanAccent
        case .toolRunning: return .yellow
        case .waitingPermission: return Theme.orange
        case .error: return .red
        }
    }

    private var label: String {
        switch status {
        case .idle: return "idle"
        case .streaming: return "streaming"
        case .toolRunning: return "running"
        case .waitingPermission: return "waiting"
        case .error: return "error"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0.6 : 1.0)

            Text(label)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
        .onAppear {
            if status == .streaming || status == .toolRunning {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
}

// MARK: - Skeleton Session Row

struct SkeletonSessionRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                SkeletonView(width: 180, height: 18)
                Spacer()
            }
            HStack(spacing: Theme.spacingSM) {
                SkeletonView(width: 40, height: 12)
                SkeletonView(width: 40, height: 12)
                SkeletonView(width: 60, height: 12)
                Spacer()
            }
        }
        .padding(.vertical, Theme.spacingXS)
    }
}
