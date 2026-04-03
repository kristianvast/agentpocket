import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    private var biometryName: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Biometrics"
        @unknown default: return "Biometrics"
        }
    }

    private var biometryIcon: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "lock.fill"
        @unknown default: return "lock.fill"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Bindable(appState.serverManager).requireFaceID) {
                        Label {
                            Text("Require \(biometryName)")
                        } icon: {
                            Image(systemName: biometryIcon)
                                .foregroundStyle(Theme.cyanAccent)
                        }
                    }
                    .tint(Theme.cyanAccent)
                } header: {
                    Text("Security")
                } footer: {
                    Text("When enabled, \(biometryName) is required to open AgentPocket.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.cyanAccent)
                }
            }
        }
    }
}
