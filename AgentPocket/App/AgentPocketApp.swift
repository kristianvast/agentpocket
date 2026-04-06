import SwiftUI

@main
struct AgentPocketApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == SharedConstants.recordURLScheme else { return }

        if url.host == "record" {
            appState.pendingAutoRecord = true

            if appState.isConnected {
                Task {
                    await appState.triggerAutoRecordIfPending()
                }
            }
        }
    }
}
