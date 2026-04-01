import SwiftUI
import SwiftTerm

struct TerminalContainerView: View {
    let ptyID: PtyID
    
    @Environment(AppState.self) private var appState
    @State private var webSocket: PTYWebSocket?
    @State private var isConnected = false
    
    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()
            
            if let webSocket = webSocket {
                TerminalRepresentable(
                    ptyID: ptyID,
                    webSocket: webSocket,
                    appState: appState
                )
            }
            
            if !isConnected {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Brand.cyan)
                    Text("Connecting to terminal...")
                        .foregroundColor(Brand.textSecondary)
                        .font(.subheadline)
                }
                .padding(24)
                .background(Brand.surface)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.3), radius: 10)
            }
        }
        .onAppear {
            connect()
        }
        .onDisappear {
            disconnect()
        }
    }
    
    // MARK: - Actions
    
    private func connect() {
        let ws = appState.createPTYWebSocket(ptyID: ptyID)
        
        ws.onData = { [weak ws] data in
            if !isConnected {
                isConnected = true
            }
        }
        
        ws.connect()
        self.webSocket = ws
    }
    
    private func disconnect() {
        webSocket?.disconnect()
        webSocket = nil
        isConnected = false
    }
}

struct TerminalRepresentable: UIViewRepresentable {
    let ptyID: PtyID
    let webSocket: PTYWebSocket
    let appState: AppState
    
    func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        terminalView.backgroundColor = UIColor(Brand.background)
        terminalView.nativeForegroundColor = UIColor(Brand.textPrimary)
        terminalView.nativeBackgroundColor = UIColor(Brand.background)
        
        context.coordinator.terminalView = terminalView
        
        webSocket.onData = { data in
            let bytes = [UInt8](data)
            DispatchQueue.main.async {
                terminalView.feed(byteArray: bytes)
            }
        }
        
        return terminalView
    }
    
    func updateUIView(_ uiView: TerminalView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(ptyID: ptyID, webSocket: webSocket, appState: appState)
    }
    
    class Coordinator: NSObject, TerminalViewDelegate {
        let ptyID: PtyID
        let webSocket: PTYWebSocket
        let appState: AppState
        weak var terminalView: TerminalView?
        
        init(ptyID: PtyID, webSocket: PTYWebSocket, appState: AppState) {
            self.ptyID = ptyID
            self.webSocket = webSocket
            self.appState = appState
        }
        
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            Task {
                do {
                    try await appState.client?.pty.update(id: ptyID, title: nil, size: [newCols, newRows])
                } catch {
                    print("Failed to update PTY size: \(error)")
                }
            }
        }
        
        func setTerminalTitle(source: TerminalView, title: String) {
            Task {
                do {
                    try await appState.client?.pty.update(id: ptyID, title: title, size: nil)
                } catch {
                    print("Failed to update PTY title: \(error)")
                }
            }
        }
        
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        }
        
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            if let string = String(bytes: data, encoding: .utf8) {
                webSocket.sendInput(string)
            }
        }
        
        func scrolled(source: TerminalView, position: Double) {
        }
    }
}
