import SwiftUI

struct ForkSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let session: Session
    
    @State private var selectedMessageID: String?
    @State private var isForking = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fork Session")
                        .font(.title2.bold())
                        .foregroundColor(Brand.textPrimary)
                    
                    Text("Select a message to fork from. A new session will be created with history up to that point.")
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.surface)
                
                Divider()
                    .background(Brand.border)
                
                // MARK: - Error
                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(Brand.error)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.error.opacity(0.1))
                }
                
                // MARK: - List
                List {
                    ForEach(session.messages, id: \.id) { message in
                        MessageRow(
                            message: message,
                            isSelected: message.id == selectedMessageID,
                            onSelect: { selectedMessageID = message.id }
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Brand.background)
                
                // MARK: - Actions
                VStack {
                    Button(action: forkSession) {
                        if isForking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Fork from Selected Message")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(Brand.brandButton())
                    .disabled(selectedMessageID == nil || isForking)
                }
                .padding()
                .background(Brand.surface)
            }
            .background(Brand.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Brand.textMuted)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func forkSession() {
        guard let messageID = selectedMessageID else { return }
        
        isForking = true
        errorMessage = nil
        
        Task {
            do {
                let newSession = try await appState.forkSession(id: session.id, messageID: messageID)
                await MainActor.run {
                    appState.activeSessionID = newSession.id
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isForking = false
                }
            }
        }
    }
}

struct MessageRow: View {
    let message: Message
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // MARK: - Role Icon
                Circle()
                    .fill(roleColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: roleIcon)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    )
                
                // MARK: - Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(message.role.capitalized)
                            .font(.subheadline.bold())
                            .foregroundColor(Brand.textPrimary)
                        
                        Spacer()
                        
                        Text(formatDate(message.createdAt))
                            .font(.caption)
                            .foregroundColor(Brand.textMuted)
                    }
                    
                    Text(previewText)
                        .font(.subheadline)
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // MARK: - Selection
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Brand.cyan)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(Brand.border)
                        .font(.title3)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(isSelected ? Brand.surfaceLight : Brand.background)
        .listRowSeparatorTint(Brand.border)
    }
    
    // MARK: - Computed Properties
    
    private var roleColor: Color {
        switch message.role {
        case "user": return Brand.cyan
        case "assistant": return Brand.teal
        case "system": return Brand.emerald
        default: return Brand.textMuted
        }
    }
    
    private var roleIcon: String {
        switch message.role {
        case "user": return "person.fill"
        case "assistant": return "sparkles"
        case "system": return "gearshape.fill"
        default: return "circle.fill"
        }
    }
    
    private var previewText: String {
        for part in message.content {
            if case .text(let text) = part {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "No text content"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}
