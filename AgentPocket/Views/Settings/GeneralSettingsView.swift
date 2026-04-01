import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var showClearDataAlert = false

    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()

            List {
                Section {
                    Toggle("Face ID Lock", isOn: $appLockEnabled)
                        .tint(Brand.cyan)
                    Toggle("Sound Effects", isOn: $soundEnabled)
                        .tint(Brand.cyan)
                    HStack {
                        Text("Theme")
                        Spacer()
                        Text("Dark")
                            .foregroundColor(Brand.textSecondary)
                    }
                } header: {
                    Text("Preferences")
                        .foregroundColor(Brand.textSecondary)
                }
                .listRowBackground(Brand.surface)
                .foregroundColor(Brand.textPrimary)

                if let activeServerID = appState.serverStore.activeServerID,
                   let server = appState.serverStore.servers.first(where: { $0.id == activeServerID }) {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(server.name)
                                .font(.headline)
                            Text(String(describing: server.url))
                                .font(.subheadline)
                                .foregroundColor(Brand.textSecondary)
                        }
                        .padding(.vertical, 4)

                        HStack {
                            Text("Status")
                            Spacer()
                            Text(appState.isConnected ? "Connected" : "Disconnected")
                                .foregroundColor(appState.isConnected ? Brand.emerald : Brand.textMuted)
                        }

                        Button("Disconnect") {
                            appState.disconnect()
                        }
                        .foregroundColor(.red)
                    } header: {
                        Text("Current Server")
                            .foregroundColor(Brand.textSecondary)
                    }
                    .listRowBackground(Brand.surface)
                    .foregroundColor(Brand.textPrimary)
                }

                Section {
                    Button("Clear All Data", role: .destructive) {
                        showClearDataAlert = true
                    }
                } header: {
                    Text("Danger Zone")
                        .foregroundColor(Brand.textSecondary)
                }
                .listRowBackground(Brand.surface)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear All Data?", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will remove all saved servers and settings. This action cannot be undone.")
        }
    }

    // MARK: - Actions

    private func clearAllData() {
        appState.disconnect()
        for server in appState.serverStore.servers {
            appState.serverStore.delete(server)
        }
        appLockEnabled = false
        soundEnabled = true
    }
}
