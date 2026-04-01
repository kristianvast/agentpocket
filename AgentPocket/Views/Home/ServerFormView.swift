import SwiftUI

struct ServerFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let server: ServerConfig?

    @State private var name: String = ""
    @State private var urlString: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.background.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Server Name", text: $name)
                            .foregroundColor(Brand.textPrimary)
                        TextField("Server URL", text: $urlString)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(Brand.textPrimary)
                    } header: {
                        Text("Server Details")
                            .foregroundColor(Brand.textSecondary)
                    }
                    .listRowBackground(Brand.surface)

                    Section {
                        TextField("Username (Optional)", text: $username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .foregroundColor(Brand.textPrimary)
                        SecureField("Password (Optional)", text: $password)
                            .foregroundColor(Brand.textPrimary)
                    } header: {
                        Text("Authentication")
                            .foregroundColor(Brand.textSecondary)
                    }
                    .listRowBackground(Brand.surface)

                    if let server = server {
                        Section {
                            Button(role: .destructive) {
                                deleteServer(server)
                            } label: {
                                Text("Delete Server")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .listRowBackground(Brand.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(server == nil ? "Add Server" : "Edit Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Brand.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveServer()
                    }
                    .foregroundColor(Brand.cyan)
                    .disabled(name.isEmpty || urlString.isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let server = server {
                    name = server.name
                    urlString = String(describing: server.url)
                    username = server.username ?? ""
                    password = server.password ?? ""
                }
            }
        }
    }

    // MARK: - Actions

    private func saveServer() {
        guard let url = URL(string: urlString) else {
            errorMessage = "Please enter a valid URL."
            showError = true
            return
        }

        if let existingServer = server {
            let updated = ServerConfig(
                id: existingServer.id,
                name: name,
                url: url,
                username: username.isEmpty ? nil : username,
                password: password.isEmpty ? nil : password,
                lastConnected: existingServer.lastConnected
            )
            appState.serverStore.update(updated)
        } else {
            let newServer = ServerConfig(
                id: UUID(),
                name: name,
                url: url,
                username: username.isEmpty ? nil : username,
                password: password.isEmpty ? nil : password,
                lastConnected: nil
            )
            appState.serverStore.add(newServer)
        }
        dismiss()
    }

    private func deleteServer(_ server: ServerConfig) {
        appState.serverStore.delete(server)
        dismiss()
    }
}
