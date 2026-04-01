import SwiftUI

struct ModelsSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedProviderID: String = "All"

    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if !appState.providers.isEmpty {
                    Picker("Provider", selection: $selectedProviderID) {
                        Text("All").tag("All")
                        ForEach(appState.providers) { provider in
                            Text(provider.name).tag(provider.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Brand.surface)
                }

                List {
                    ForEach(filteredProviders) { provider in
                        Section {
                            ForEach(filteredModels(for: provider)) { model in
                                modelRow(for: model)
                            }
                        } header: {
                            Text(provider.name)
                                .foregroundColor(Brand.textSecondary)
                        }
                        .listRowBackground(Brand.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search models")
    }

    // MARK: - Computed Properties

    private var filteredProviders: [Provider] {
        let providers = selectedProviderID == "All"
            ? appState.providers
            : appState.providers.filter { $0.id == selectedProviderID }

        if searchText.isEmpty {
            return providers.filter { !$0.models.isEmpty }
        }

        return providers.filter { provider in
            !filteredModels(for: provider).isEmpty
        }
    }

    // MARK: - Subviews

    private func filteredModels(for provider: Provider) -> [Model] {
        if searchText.isEmpty {
            return provider.models
        }
        return provider.models.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func modelRow(for model: Model) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.name)
                .font(.headline)
                .foregroundColor(Brand.textPrimary)

            HStack(spacing: 12) {
                if let cost = model.cost {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle")
                        Text("\(cost.input, specifier: "%.2f") / \(cost.output, specifier: "%.2f")")
                    }
                    .font(.caption)
                    .foregroundColor(Brand.textSecondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    if model.capabilities?.reasoning == true {
                        capabilityBadge("Reasoning", color: Brand.cyan)
                    }
                    if model.capabilities?.attachment == true {
                        capabilityBadge("Vision", color: Brand.emerald)
                    }
                    if model.capabilities?.tool_call == true {
                        capabilityBadge("Tools", color: Brand.teal)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func capabilityBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}
