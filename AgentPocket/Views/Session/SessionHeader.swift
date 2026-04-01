import SwiftUI

struct SessionHeader: View {
    let sessionID: String
    @Binding var selectedTab: SessionView.SessionTab
    @Binding var showSidebar: Bool
    @Binding var showSettings: Bool
    @Binding var showModelPicker: Bool
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    showSidebar = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(Brand.textPrimary)
                }
                
                Text(appState.sessionStore.sessions[sessionID]?.title ?? "Session")
                    .font(.headline)
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                if let branch = appState.currentBranch {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                        Text(branch)
                    }
                    .font(.caption)
                    .foregroundColor(Brand.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Brand.surface)
                    .cornerRadius(4)
                }
                
                Button {
                    showModelPicker = true
                } label: {
                    Text(appState.sessionStore.sessions[sessionID]?.model.name ?? appState.defaultModels.first?.name ?? "Model")
                        .font(.caption.bold())
                        .foregroundColor(Brand.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Brand.gradient, lineWidth: 1)
                        )
                }
                
                ContextUsageView(sessionID: sessionID)
                
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundColor(Brand.textPrimary)
                }
            }
            .padding(.horizontal)
            
            Picker("Tab", selection: $selectedTab) {
                Text("Chat").tag(SessionView.SessionTab.chat)
                Text("Files").tag(SessionView.SessionTab.files)
                Text("Terminal").tag(SessionView.SessionTab.terminal)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Brand.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Brand.border),
            alignment: .bottom
        )
    }
}
