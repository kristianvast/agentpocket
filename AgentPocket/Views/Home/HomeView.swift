import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddServer = false
    @State private var serverHealth: [UUID: Bool] = [:]
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.background.ignoresSafeArea()

                if appState.serverStore.servers.isEmpty {
                    emptyStateView
                } else {
                    serverListView
                }

                if appState.isConnecting {
                    ConnectionOverlay()
                }
            }
            .navigationTitle("AgentPocket")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddServer = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Brand.cyan)
                    }
                }
            }
            .sheet(isPresented: $showAddServer) {
                ServerFormView(server: nil)
            }
            .onAppear {
                checkServerHealth()
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(Brand.textMuted)
            Text("No Servers")
                .font(.title2.bold())
                .foregroundColor(Brand.textPrimary)
            Text("Add your first OpenCode server to get started.")
                .font(.body)
                .foregroundColor(Brand.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showAddServer = true
            } label: {
                Text("Add Server")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Brand.gradient)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }

    private var serverListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(appState.serverStore.servers) { server in
                    serverCard(for: server)
                }

                if appState.isConnected {
                    recentSessionsSection
                }
            }
            .padding()
        }
        .refreshable {
            await refreshData()
        }
    }

    private func serverCard(for server: ServerConfig) -> some View {
        Button {
            appState.connect(to: server)
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(serverHealth[server.id] == true ? Brand.emerald : Brand.textMuted)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.headline)
                        .foregroundColor(Brand.textPrimary)
                    Text(String(describing: server.url))
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let lastConnected = server.lastConnected {
                    Text(lastConnected, style: .relative)
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                }
            }
            .padding()
            .background(Brand.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Brand.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.title3.bold())
                .foregroundColor(Brand.textPrimary)
                .padding(.top, 16)

            ForEach(appState.sessionStore.sessions.prefix(5)) { session in
                SessionRowView(session: session)
            }

            Button {
                appState.createSession()
            } label: {
                HStack {
                    Image(systemName: "plus.bubble")
                    Text("New Session")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Brand.gradient)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func checkServerHealth() {
        for server in appState.serverStore.servers {
            Task {
                do {
                    let urlString = String(describing: server.url)
                    guard let url = URL(string: urlString)?.appendingPathComponent("health") else { return }
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse {
                        await MainActor.run {
                            serverHealth[server.id] = (200...299).contains(httpResponse.statusCode)
                        }
                    }
                } catch {
                    await MainActor.run {
                        serverHealth[server.id] = false
                    }
                }
            }
        }
    }

    private func refreshData() async {
        isRefreshing = true
        checkServerHealth()
        try? await Task.sleep(for: .seconds(1))
        isRefreshing = false
    }
}
