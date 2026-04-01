import SwiftUI

struct PromptInputView: View {
    let sessionID: String
    @Binding var showModelPicker: Bool
    @Environment(AppState.self) private var appState
    
    @State private var text = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Brand.border)
            
            VStack(spacing: 8) {
                HStack {
                    Button {
                        showModelPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(appState.sessionStore.sessions[sessionID]?.model.name ?? "Select Model")
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                        }
                        .font(.caption.bold())
                        .foregroundColor(Brand.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Brand.surface)
                        .cornerRadius(12)
                    }
                    
                    if let agents = appState.agents, agents.count > 1 {
                        Menu {
                            ForEach(agents) { agent in
                                Button(agent.name) {
                                    
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "cpu")
                                Text("Agent")
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                            }
                            .font(.caption.bold())
                            .foregroundColor(Brand.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Brand.surface)
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                HStack(alignment: .bottom, spacing: 12) {
                    Button {
                        
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 20))
                            .foregroundColor(Brand.textSecondary)
                    }
                    .padding(.bottom, 8)
                    
                    TextField("Message...", text: $text, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($isFocused)
                        .padding(10)
                        .background(Brand.background)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Brand.border, lineWidth: 1)
                        )
                        .disabled(isBusy)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    if isBusy {
                        Button {
                            appState.abortSession(sessionID: sessionID)
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.red)
                        }
                        .padding(.bottom, 4)
                    } else {
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Brand.textMuted : Brand.cyan)
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.bottom, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Brand.surface)
        }
        .onAppear {
            if !isBusy {
                isFocused = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private var isBusy: Bool {
        appState.sessionStatuses[sessionID] == .busy
    }
    
    private func sendMessage() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        
        appState.sendMessage(trimmed, sessionID: sessionID)
        text = ""
        isFocused = false
    }
}
