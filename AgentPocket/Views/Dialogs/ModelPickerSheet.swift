import SwiftUI

struct ModelPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let currentSelection: ModelReference?
    let onSelect: (ModelReference) -> Void
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Brand.textMuted)
                    TextField("Search models...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(Brand.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Brand.textMuted)
                        }
                    }
                }
                .padding(10)
                .background(Brand.surfaceLight)
                .cornerRadius(10)
                .padding()
                
                // MARK: - List
                List {
                    ForEach(filteredProviders, id: \.name) { provider in
                        Section(header: Text(provider.name).foregroundColor(Brand.textSecondary)) {
                            ForEach(provider.models, id: \.id) { model in
                                ModelRow(
                                    model: model,
                                    provider: provider,
                                    isSelected: isModelSelected(model, provider: provider),
                                    onSelect: {
                                        onSelect(ModelReference(provider: provider.name, model: model.id))
                                        dismiss()
                                    }
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Brand.background)
            }
            .background(Brand.background)
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Brand.cyan)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredProviders: [Provider] {
        if searchText.isEmpty {
            return appState.providers
        }
        
        return appState.providers.compactMap { provider in
            let filteredModels = provider.models.filter { model in
                model.name.localizedCaseInsensitiveContains(searchText) ||
                model.id.localizedCaseInsensitiveContains(searchText)
            }
            
            if filteredModels.isEmpty {
                return nil
            }
            
            var newProvider = provider
            newProvider.models = filteredModels
            return newProvider
        }
    }
    
    // MARK: - Actions
    
    private func isModelSelected(_ model: Model, provider: Provider) -> Bool {
        guard let current = currentSelection else { return false }
        return current.provider == provider.name && current.model == model.id
    }
}

struct ModelRow: View {
    let model: Model
    let provider: Provider
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundColor(Brand.textPrimary)
                    
                    Text(model.id)
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                    
                    HStack(spacing: 8) {
                        if let inputCost = model.inputCostPerM {
                            CostBadge(label: "IN", cost: inputCost)
                        }
                        if let outputCost = model.outputCostPerM {
                            CostBadge(label: "OUT", cost: outputCost)
                        }
                        
                        Spacer()
                        
                        if model.supportsReasoning == true {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(Brand.cyan)
                                .font(.caption)
                        }
                        if model.supportsImages == true {
                            Image(systemName: "photo")
                                .foregroundColor(Brand.teal)
                                .font(.caption)
                        }
                        if model.supportsTools == true {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(Brand.emerald)
                                .font(.caption)
                        }
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Brand.cyan)
                        .font(.headline)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Brand.surface)
    }
}

struct CostBadge: View {
    let label: String
    let cost: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Brand.textMuted)
            Text("$\(String(format: "%.2f", cost))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Brand.textSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Brand.surfaceLight)
        .cornerRadius(4)
    }
}
