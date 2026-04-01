import SwiftUI

struct SessionView: View {
    let sessionID: String
    @Environment(AppState.self) private var appState
    
    @State private var selectedTab: SessionTab = .chat
    @State private var showSidebar = false
    @State private var showSettings = false
    @State private var showModelPicker = false
    
    enum SessionTab {
        case chat, files, terminal
    }
    
    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                SessionHeader(
                    sessionID: sessionID,
                    selectedTab: $selectedTab,
                    showSidebar: $showSidebar,
                    showSettings: $showSettings,
                    showModelPicker: $showModelPicker
                )
                
                ZStack {
                    switch selectedTab {
                    case .chat:
                        MessageTimeline(sessionID: sessionID)
                    case .files:
                        FileTreeView(sessionID: sessionID)
                    case .terminal:
                        TerminalContainerView(sessionID: sessionID)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                PromptInputView(
                    sessionID: sessionID,
                    showModelPicker: $showModelPicker
                )
            }
            
            if !appState.isConnected {
                ConnectionOverlay()
            }
            
            if let todos = appState.todos[sessionID], !todos.isEmpty {
                VStack {
                    TodoProgressView(todos: todos)
                        .padding()
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showSidebar) {
            Color.clear
        }
        .sheet(isPresented: $showSettings) {
            Color.clear
        }
        .sheet(isPresented: .init(
            get: { !appState.pendingPermissions.isEmpty },
            set: { _ in }
        )) {
            PermissionSheet()
        }
        .sheet(isPresented: .init(
            get: { !appState.pendingQuestions.isEmpty },
            set: { _ in }
        )) {
            QuestionSheet()
        }
        .sheet(isPresented: $showModelPicker) {
            Color.clear
        }
        .task {
            await appState.loadMessages(for: sessionID)
        }
    }
}
