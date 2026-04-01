import SwiftUI

struct ProvidersSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedProvider: Provider?

    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()

            List {
                if !connectedProviders.isEmpty {
                    Section {
                        ForEach(connectedProviders) { provider in
                            providerRow(for: provider, isConnected: true)
                        }
                    } header: {
                        Text("Connected")
                            .foregroundColor(Brand.textSecondary)
                    }
                    .listRowBackground(Brand.surface)
                }

                if !availableProviders.isEmpty {
                    Section {
                        ForEach(availableProviders) { provider in
                            providerRow(for: provider, isConnected: false)
                        }
                    } header: {
                        Text("Available")
                            .foregroundColor(Brand.textSecondary)
                    }
                    .listRowBackground(Brand.surface)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Providers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedProvider) { provider in
            providerInfoSheet(for: provider)
        }
    }

    // MARK: - Computed Properties

    private var connectedProviders: [Provider] {
        appState.providers.filter { appState.connectedProviderIDs.contains($0.id) }
    }

    private var availableProviders: [Provider] {
        appState.providers.filter { !appState.connectedProviderIDs.contains($0.id) }
    }

    // MARK: - Subviews

    private func providerRow(for provider: Provider, isConnected: Bool) -> some View {
        Button {
            selectedProvider = provider
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)
                        .foregroundColor(Brand.textPrimary)
                }

                Spacer()

                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Brand.emerald)
                }
            }
        }
    }

    private func providerInfoSheet(for provider: Provider) -> some View {
        NavigationStack {
            ZStack {
                Brand.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    Image(systemName: "network")
                        .font(.system(size: 48))
                        .foregroundColor(Brand.cyan)
                        .padding(.top, 32)

                    Text(provider.name)
                        .font(.title.bold())
                        .foregroundColor(Brand.textPrimary)

                    VStack(spacing: 12) {
                        HStack {
                            Text("Status")
                                .foregroundColor(Brand.textSecondary)
                            Spacer()
                            Text(appState.connectedProviderIDs.contains(provider.id) ? "Connected" : "Not Connected")
                                .foregroundColor(appState.connectedProviderIDs.contains(provider.id) ? Brand.emerald : Brand.textMuted)
                                .bold()
                        }
                        .padding()
                        .background(Brand.surface)
                        .cornerRadius(12)

                        HStack {
                            Text("Available Models")
                                .foregroundColor(Brand.textSecondary)
                            Spacer()
                            Text("\(provider.models.count)")
                                .foregroundColor(Brand.textPrimary)
                                .bold()
                        }
                        .padding()
                        .background(Brand.surface)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Provider Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedProvider = nil
                    }
                    .foregroundColor(Brand.cyan)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
