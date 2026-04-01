import SwiftUI

struct CommandPaletteSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let onSelectCommand: (CommandInfo) -> Void
    let onSelectAgent: (AgentInfo) -> Void
    let onSelectSkill: (SkillInfo) -> Void
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Brand.textMuted)
                    TextField("Search commands, agents, skills...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(Brand.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isSearchFocused)
                    
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
                    if !filteredCommands.isEmpty {
                        Section(header: Text("Commands").foregroundColor(Brand.textSecondary)) {
                            ForEach(filteredCommands, id: \.name) { command in
                                CommandRow(command: command) {
                                    onSelectCommand(command)
                                    dismiss()
                                }
                            }
                        }
                    }
                    
                    if !filteredAgents.isEmpty {
                        Section(header: Text("Agents").foregroundColor(Brand.textSecondary)) {
                            ForEach(filteredAgents, id: \.name) { agent in
                                AgentRow(agent: agent) {
                                    onSelectAgent(agent)
                                    dismiss()
                                }
                            }
                        }
                    }
                    
                    if !filteredSkills.isEmpty {
                        Section(header: Text("Skills").foregroundColor(Brand.textSecondary)) {
                            ForEach(filteredSkills, id: \.name) { skill in
                                SkillRow(skill: skill) {
                                    onSelectSkill(skill)
                                    dismiss()
                                }
                            }
                        }
                    }
                    
                    if filteredCommands.isEmpty && filteredAgents.isEmpty && filteredSkills.isEmpty {
                        Text("No results found")
                            .foregroundColor(Brand.textMuted)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Brand.background)
            }
            .background(Brand.background)
            .navigationTitle("Command Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Brand.cyan)
                }
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredCommands: [CommandInfo] {
        if searchText.isEmpty {
            return appState.commands
        }
        return appState.commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredAgents: [AgentInfo] {
        if searchText.isEmpty {
            return appState.agents
        }
        return appState.agents.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredSkills: [SkillInfo] {
        if searchText.isEmpty {
            return appState.skills
        }
        return appState.skills.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct CommandRow: View {
    let command: CommandInfo
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(command.name)
                            .font(.headline)
                            .foregroundColor(Brand.textPrimary)
                        
                        if let shortcut = command.shortcut {
                            Text(shortcut)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Brand.surfaceLight)
                                .cornerRadius(4)
                                .foregroundColor(Brand.textMuted)
                        }
                    }
                    
                    Text(command.description)
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Brand.textMuted)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Brand.surface)
    }
}

struct AgentRow: View {
    let agent: AgentInfo
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(Brand.teal)
                        
                        Text(agent.name)
                            .font(.headline)
                            .foregroundColor(Brand.textPrimary)
                    }
                    
                    Text(agent.description)
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Brand.textMuted)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Brand.surface)
    }
}

struct SkillRow: View {
    let skill: SkillInfo
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(Brand.emerald)
                        
                        Text(skill.name)
                            .font(.headline)
                            .foregroundColor(Brand.textPrimary)
                    }
                    
                    Text(skill.description)
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Brand.textMuted)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Brand.surface)
    }
}
