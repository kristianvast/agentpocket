import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @State private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    @State private var isUnlocked = false
    @State private var showOnboarding = false
    @State private var showSettings = false
    @State private var showSidebar = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()

            if appLockEnabled && !isUnlocked {
                lockScreen
            } else if let activeSession = appState.sessionStore.activeSession {
                sessionContent(activeSession)
            } else {
                HomeView()
            }
        }
        .environment(appState)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: showOnboardingBinding) {
            onboardingView
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(appState)
        }
        .sheet(isPresented: $showSidebar) {
            SidebarView()
                .environment(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionNewSession)) { _ in
            handleNewSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionSettings)) { _ in
            showSettings = true
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            handleMemoryWarning()
        }
        .onAppear {
            showOnboarding = !hasCompletedOnboarding
            if appLockEnabled {
                authenticateWithBiometrics()
            }
            autoConnectLastServer()
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")
                .font(.system(size: 48))
                .foregroundStyle(Brand.cyan)

            Text("AgentPocket is Locked")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Brand.textPrimary)

            Button("Unlock with Face ID") {
                authenticateWithBiometrics()
            }
            .brandButton(prominent: true)
        }
    }

    private func sessionContent(_ session: Session) -> some View {
        SessionView(sessionID: session.id)
            .overlay {
                if appState.isConnecting {
                    ConnectionOverlay(state: .connecting)
                } else if !appState.isConnected, let error = appState.connectionError {
                    ConnectionOverlay(
                        state: .error(error),
                        onRetry: { reconnect() },
                        onGoHome: { goHome() }
                    )
                }
            }
    }

    private var showOnboardingBinding: Binding<Bool> {
        Binding(
            get: { showOnboarding && !hasCompletedOnboarding },
            set: { showOnboarding = $0 }
        )
    }

    private var onboardingView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(Brand.gradient)
                Text("AgentPocket")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Brand.textPrimary)
                Text("Your AI coding assistant, natively on iOS")
                    .font(.subheadline)
                    .foregroundStyle(Brand.textMuted)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "bubble.left.and.bubble.right",
                    title: "Chat with AI",
                    subtitle: "Full conversation with tool execution"
                )
                featureRow(
                    icon: "terminal",
                    title: "Built-in Terminal",
                    subtitle: "Native terminal emulator"
                )
                featureRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Browse & Edit Files",
                    subtitle: "Syntax-highlighted file viewer"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            Button("Get Started") {
                hasCompletedOnboarding = true
                showOnboarding = false
            }
            .brandButton(prominent: true)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.background.ignoresSafeArea())
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Brand.cyan)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Brand.textMuted)
            }
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isUnlocked = true
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock AgentPocket") { success, _ in
            DispatchQueue.main.async {
                if success {
                    isUnlocked = true
                }
            }
        }
    }

    private func autoConnectLastServer() {
        guard let activeID = appState.serverStore.activeServerID,
              let server = appState.serverStore.servers.first(where: { $0.id == activeID })
        else {
            return
        }

        Task {
            await appState.connect(to: server)
        }
    }

    private func reconnect() {
        guard let server = appState.activeServer else { return }
        Task {
            await appState.connect(to: server)
        }
    }

    private func goHome() {
        appState.disconnect()
        appState.sessionStore.activeSessionID = nil
    }

    private func handleNewSession() {
        Task {
            if let session = try? await appState.createSession() {
                appState.sessionStore.activeSessionID = session.id
            }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if appLockEnabled && !isUnlocked {
                authenticateWithBiometrics()
            }
            if appState.isConnected {
                appState.startEventStream()
            }
        case .background:
            if appLockEnabled {
                isUnlocked = false
            }
        default:
            break
        }
    }

    private func handleMemoryWarning() {
        appState.sessionStore.streamingText.removeAll()
    }
}
