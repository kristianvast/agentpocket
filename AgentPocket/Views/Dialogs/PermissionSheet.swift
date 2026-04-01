import SwiftUI

struct PermissionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let request: PermissionRequest
    
    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Header
            VStack(spacing: 16) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 48))
                    .foregroundColor(Brand.warning)
                
                Text("Permission Required")
                    .font(.title2.bold())
                    .foregroundColor(Brand.textPrimary)
                
                Text(request.permission.description)
                    .font(.body)
                    .foregroundColor(Brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 32)
            
            // MARK: - Details
            VStack(alignment: .leading, spacing: 16) {
                if let toolName = request.tool?.callID {
                    DetailRow(title: "Tool", value: toolName)
                }
                
                if !request.permission.patterns.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Requested Access:")
                            .font(.subheadline.bold())
                            .foregroundColor(Brand.textPrimary)
                        
                        ForEach(request.permission.patterns, id: \.self) { pattern in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(Brand.cyan)
                                    .padding(.top, 6)
                                
                                Text(pattern)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(Brand.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .background(Brand.surfaceLight)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // MARK: - Actions
            VStack(spacing: 12) {
                Button(action: { reply(.allowOnce) }) {
                    Text("Allow Once")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Brand.cyan)
                        .cornerRadius(12)
                }
                
                Button(action: { reply(.allowAlways) }) {
                    Text("Allow Always")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Brand.gradient)
                        .cornerRadius(12)
                }
                
                Button(action: { reply(.deny) }) {
                    Text("Deny")
                        .font(.headline)
                        .foregroundColor(Brand.error)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Brand.error, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Brand.background)
        .interactiveDismissDisabled()
    }
    
    // MARK: - Actions
    
    private func reply(_ action: PermissionReply.Action) {
        Task {
            do {
                try await appState.replyToPermission(id: request.id, reply: PermissionReply(action: action))
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to reply to permission: \(error)")
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(Brand.textPrimary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(Brand.textSecondary)
            
            Spacer()
        }
    }
}
