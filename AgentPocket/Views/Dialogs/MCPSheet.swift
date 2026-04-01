import SwiftUI

struct MCPSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var mcpStatus: McpStatus?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @State private var newServerName = ""
    @State private var newServerCommand = ""
    @State private var newServerArgs = ""
    @State private var isAddingServer = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Brand.cyan)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(Brand.error)
                        Text(error)
                            .foregroundColor(Brand.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadStatus() }
                        }
                        .buttonStyle(Brand.brandButton())
                    }
                    .padding()
                    Spacer()
                } else if let status = mcpStatus {
                    List {
                        // MARK: - Servers
                        Section(header: Text("Connected Servers").foregroundColor(Brand.textSecondary)) {
                            if status.servers.isEmpty {
                                Text("No MCP servers configured.")
                                    .foregroundColor(Brand.textMuted)
                                    .font(.subheadline)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(status.servers, id: \.name) { server in
                                    McpServerRow(server: server)
                                }
                            }
                        }
                        
                        // MARK: - Add Server
                        Section(header: Text("Add Server").foregroundColor(Brand.textSecondary)) {
                            VStack(spacing: 12) {
                                TextField("Server Name", text: $newServerName)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Brand.surfaceLight)
                                    .cornerRadius(8)
                                    .foregroundColor(Brand.textPrimary)
                                
                                TextField("Command (e.g. npx)", text: $newServerCommand)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Brand.surfaceLight)
                                    .cornerRadius(8)
                                    .foregroundColor(Brand.textPrimary)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                
                                TextField("Arguments (space separated)", text: $newServerArgs)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Brand.surfaceLight)
                                    .cornerRadius(8)
                                    .foregroundColor(Brand.textPrimary)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                
                                Button(action: addServer) {
                                    if isAddingServer {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Add Server")
                                            .font(.headline)
                                    }
                                }
                                .buttonStyle(Brand.brandButton())
                                .disabled(newServerName.isEmpty || newServerCommand.isEmpty || isAddingServer)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Brand.background)
                }
            }
            .background(Brand.background)
            .navigationTitle("MCP Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Brand.cyan)
                }
            }
            .task {
                await loadStatus()
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadStatus() async {
        isLoading = true
        errorMessage = nil
        
        do {
            mcpStatus = try await appState.client?.mcp.status()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func addServer() {
        isAddingServer = true
        
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                isAddingServer = false
                newServerName = ""
                newServerCommand = ""
                newServerArgs = ""
                Task { await loadStatus() }
            }
        }
    }
}

struct McpServerRow: View {
    let server: McpStatus.Server
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(server.name)
                    .font(.headline)
                    .foregroundColor(Brand.textPrimary)
                
                Spacer()
                
                // MARK: - Status Badge
                Text(server.status.rawValue.uppercased())
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            if let error = server.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Brand.error)
                    .padding(8)
                    .background(Brand.error.opacity(0.1))
                    .cornerRadius(4)
            }
            
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(Brand.textMuted)
                    .font(.caption)
                
                Text("\(server.tools.count) tools")
                    .font(.caption)
                    .foregroundColor(Brand.textSecondary)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Brand.surface)
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch server.status {
        case .connected: return Brand.success
        case .connecting: return Brand.warning
        case .disconnected: return Brand.textMuted
        case .error: return Brand.error
        }
    }
}
