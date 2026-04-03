import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var isUnlocked = false
    @State private var showAuthError = false

    var body: some View {
        Group {
            if isUnlocked {
                mainContent
            } else {
                lockedView
            }
        }
        .onAppear {
            authenticate()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !appState.serverManager.hasCompletedOnboarding {
            OnboardingView()
        } else if appState.isConnected {
            if appState.projectStore.activeProjectID != nil {
                // Project selected → show sessions + chat
                NavigationSplitView {
                    ConversationListView()
                } detail: {
                    if let activeConversation = appState.conversationStore.activeConversation {
                        ConversationView(conversation: activeConversation)
                    } else {
                        VStack(spacing: Theme.spacingMD) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.textMuted.opacity(0.5))
                            Text("Select a session")
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }
                .overlay {
                    if !appState.pendingPermissions.isEmpty {
                        PermissionSheet()
                    }
                }
            } else {
                // Connected but no project selected → show project list
                ProjectListView()
            }
        } else {
            ServerListView()
        }
    }

    private var lockedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundStyle(Theme.cyanAccent)
            
            Text("AgentPocket is Locked")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            
            Button("Unlock with Face ID") {
                authenticate()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.cyanAccent)
            .foregroundStyle(.black)
            
            if showAuthError {
                Text("Authentication failed")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func authenticate() {
        guard appState.serverManager.requireFaceID else {
            isUnlocked = true
            autoConnect()
            return
        }

        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock AgentPocket") { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                        self.autoConnect()
                    } else {
                        self.showAuthError = true
                    }
                }
            }
        } else {
            isUnlocked = true
            autoConnect()
        }
    }

    private func autoConnect() {
        if let activeServer = appState.serverManager.activeServer {
            Task {
                await appState.connect(to: activeServer)
            }
        }
    }
}
