import SwiftUI

struct TerminalTabBar: View {
    @Environment(AppState.self) private var appState
    @Binding var activePtyID: PtyID?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.ptyList, id: \.id) { pty in
                    TerminalTab(
                        pty: pty,
                        isActive: pty.id == activePtyID,
                        onSelect: { activePtyID = pty.id },
                        onClose: { closePty(pty.id) }
                    )
                }
                
                Button(action: createNewPty) {
                    Image(systemName: "plus")
                        .foregroundColor(Brand.textPrimary)
                        .padding(8)
                        .background(Brand.surfaceLight)
                        .clipShape(Circle())
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Brand.surface)
    }
    
    // MARK: - Actions
    
    private func createNewPty() {
        Task {
            do {
                let newPty = try await appState.client?.pty.create(
                    command: nil,
                    args: nil,
                    cwd: nil,
                    env: nil,
                    size: [80, 24]
                )
                if let newPty = newPty {
                    await MainActor.run {
                        appState.ptyList.append(newPty)
                        activePtyID = newPty.id
                    }
                }
            } catch {
                print("Failed to create PTY: \(error)")
            }
        }
    }
    
    private func closePty(_ id: PtyID) {
        Task {
            do {
                try await appState.client?.pty.close(id: id)
                await MainActor.run {
                    appState.ptyList.removeAll { $0.id == id }
                    if activePtyID == id {
                        activePtyID = appState.ptyList.last?.id
                    }
                }
            } catch {
                print("Failed to close PTY: \(error)")
            }
        }
    }
}

struct TerminalTab: View {
    let pty: PtyInfo
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(pty.title ?? "Terminal")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(isActive ? Brand.textPrimary : Brand.textSecondary)
                .lineLimit(1)
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(Brand.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Brand.surfaceLight : Color.clear)
        .cornerRadius(8)
        .overlay(
            VStack {
                Spacer()
                if isActive {
                    Rectangle()
                        .fill(Brand.gradient)
                        .frame(height: 2)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
