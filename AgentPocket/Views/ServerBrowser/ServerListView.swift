import SwiftUI

struct ServerListView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAddServer = false
    @State private var showingSettings = false
    @State private var connectingServer: ServerConfig?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.spacingMD) {
                    ForEach(appState.serverManager.servers) { server in
                        ServerCard(server: server) {
                            connectingServer = server
                            Task {
                                await appState.connect(to: server)
                            }
                        }
                        .contextMenu {
                            Button {
                                
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                appState.serverManager.delete(id: server.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(Theme.spacingMD)
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddServer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                AddServerView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .overlay {
                if appState.serverManager.servers.isEmpty {
                    ContentUnavailableView(
                        "No Servers",
                        systemImage: "server.rack",
                        description: Text("Add an OpenCode, OpenClaw, or Hermes server to get started.")
                    )
                }
            }
            .overlay {
                if appState.isConnecting || appState.connectionError != nil {
                    if let server = connectingServer ?? appState.serverManager.activeServer {
                        ConnectionOverlay(
                            serverName: server.name,
                            serverType: server.serverType,
                            error: appState.connectionError,
                            onRetry: {
                                Task {
                                    await appState.connect(to: server)
                                }
                            },
                            onCancel: {
                                appState.isConnecting = false
                                appState.connectionError = nil
                            }
                        )
                    }
                }
            }
        }
    }
}

struct ServerCard: View {
    let server: ServerConfig
    let action: () -> Void
    
    @Environment(AppState.self) private var appState
    @State private var isPulsing = false

    var iconColor: Color {
        switch server.serverType {
        case .openCode: return Theme.cyanAccent
        case .openClaw: return Theme.emerald
        case .hermes: return Theme.orange
        }
    }

    var isActive: Bool {
        appState.serverManager.activeServerID == server.id && appState.isConnected
    }

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            HStack(spacing: Theme.spacingMD) {
                Image(systemName: server.serverType.iconSystemName)
                    .font(.system(size: 32))
                    .foregroundStyle(iconColor)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text(server.name)
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textPrimary)
                    
                    Text(server.url)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                    
                    Text(server.serverType.displayName)
                        .font(Theme.captionFont.bold())
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.background)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                Circle()
                    .fill(isActive ? Theme.emerald : Theme.textMuted.opacity(0.5))
                    .frame(width: 12, height: 12)
                    .opacity(isActive && isPulsing ? 0.5 : 1.0)
                    .scaleEffect(isActive && isPulsing ? 1.2 : 1.0)
                    .animation(isActive ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default, value: isPulsing)
                    .onAppear {
                        if isActive {
                            isPulsing = true
                        }
                    }
                    .onChange(of: isActive) { _, newValue in
                        isPulsing = newValue
                    }
            }
            .padding(Theme.spacingMD)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMD)
                    .stroke(Theme.textMuted.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.quickAnimation, value: configuration.isPressed)
    }
}
