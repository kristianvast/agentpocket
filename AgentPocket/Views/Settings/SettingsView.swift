import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.background.ignoresSafeArea()

                List {
                    Section {
                        NavigationLink(destination: GeneralSettingsView()) {
                            settingRow(icon: "gearshape", color: Brand.cyan, title: "General")
                        }
                        NavigationLink(destination: ProvidersSettingsView()) {
                            HStack {
                                settingRow(icon: "network", color: Brand.emerald, title: "Providers")
                                Spacer()
                                Text("\(appState.connectedProviderIDs.count)")
                                    .font(.caption.bold())
                                    .foregroundColor(Brand.background)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Brand.emerald)
                                    .clipShape(Capsule())
                            }
                        }
                        NavigationLink(destination: ModelsSettingsView()) {
                            settingRow(icon: "cpu", color: Brand.teal, title: "Models")
                        }
                    }
                    .listRowBackground(Brand.surface)

                    Section {
                        NavigationLink(destination: aboutView) {
                            settingRow(icon: "info.circle", color: Brand.textSecondary, title: "About")
                        }
                    }
                    .listRowBackground(Brand.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Subviews

    private func settingRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .foregroundColor(Brand.textPrimary)
        }
    }

    private var aboutView: some View {
        ZStack {
            Brand.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Brand.gradient)
                Text("AgentPocket")
                    .font(.title.bold())
                    .foregroundColor(Brand.textPrimary)
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .foregroundColor(Brand.textSecondary)
                }
                Spacer()
            }
            .padding(.top, 64)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
