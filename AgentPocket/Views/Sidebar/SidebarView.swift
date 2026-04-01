import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                if appState.sessionStore.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredSessions: [Session] {
        if searchText.isEmpty {
            return appState.sessionStore.sessions
        }
        return appState.sessionStore.sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Sessions")
                    .font(.title2.bold())
                    .foregroundColor(Brand.textPrimary)
                Spacer()
                Text("\(appState.sessionStore.sessions.count)")
                    .font(.caption.bold())
                    .foregroundColor(Brand.background)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Brand.textSecondary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Brand.textMuted)
                TextField("Search sessions...", text: $searchText)
                    .foregroundColor(Brand.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(8)
            .background(Brand.surface)
            .cornerRadius(8)
            .padding(.horizontal)

            Button {
                appState.createSession()
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("New Session")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Brand.gradient)
                .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()
                .background(Brand.border)
        }
        .background(Brand.background)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(Brand.textMuted)
            Text("No Sessions")
                .font(.headline)
                .foregroundColor(Brand.textPrimary)
            Text("Create a new session to start chatting with your AI agent.")
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var sessionListView: some View {
        List {
            ForEach(filteredSessions) { session in
                SessionRowView(session: session)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onTapGesture {
                        appState.sessionStore.activeSessionID = session.id
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            appState.deleteSession(session.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            archiveSession(session)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(Brand.teal)
                    }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshSessions()
        }
    }

    // MARK: - Actions

    private func archiveSession(_ session: Session) {
    }

    private func refreshSessions() async {
        try? await Task.sleep(for: .seconds(1))
    }
}
