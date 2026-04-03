import SwiftUI

struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var name = ""
    @State private var url = ""
    @State private var serverType: ServerType = .openCode
    @State private var authType: ServerAuth.AuthType = .none
    @State private var token = ""
    @State private var username = ""
    @State private var password = ""
    
    @State private var isTesting = false
    @State private var testResult: Result<Bool, Error>? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Name", text: $name)
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    Picker("Type", selection: $serverType) {
                        ForEach(ServerType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                
                Section("Authentication") {
                    Picker("Auth Type", selection: $authType) {
                        Text("None").tag(ServerAuth.AuthType.none)
                        Text("Bearer Token").tag(ServerAuth.AuthType.bearer)
                        Text("Basic Auth").tag(ServerAuth.AuthType.basic)
                        Text("Device Token").tag(ServerAuth.AuthType.device)
                    }
                    
                    switch authType {
                    case .none:
                        EmptyView()
                    case .bearer, .device:
                        SecureField("Token", text: $token)
                    case .basic:
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password)
                    }
                }
                
                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Image(systemName: "wire.circle")
                            Text("Test Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(url.isEmpty || isTesting)
                    
                    if let result = testResult {
                        switch result {
                        case .success:
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Connected successfully")
                            }
                            .foregroundStyle(Theme.emerald)
                        case .failure(let error):
                            HStack(alignment: .top) {
                                Image(systemName: "xmark.circle.fill")
                                Text(error.localizedDescription)
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveServer()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
    }
    
    private func createConfig() -> ServerConfig {
        let auth: ServerAuth
        switch authType {
        case .none:
            auth = .none
        case .bearer:
            auth = .bearerToken(token)
        case .basic:
            auth = .basic(username: username, password: password)
        case .device:
            auth = .deviceToken(token)
        }
        
        return ServerConfig(
            name: name.isEmpty ? "Test Server" : name,
            url: url,
            serverType: serverType,
            auth: auth
        )
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        
        let config = createConfig()
        let server = ServerFactory.create(for: config)
        
        Task {
            do {
                try await server.connect()
                server.disconnect()
                await MainActor.run {
                    isTesting = false
                    testResult = .success(true)
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error)
                }
            }
        }
    }
    
    private func saveServer() {
        let config = createConfig()
        appState.serverManager.add(config)
        dismiss()
    }
}
