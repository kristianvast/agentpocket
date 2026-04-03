import SwiftUI

struct ConnectionOverlay: View {
    let serverName: String
    let serverType: ServerType
    let error: String?
    let onRetry: (() -> Void)?
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Theme.background.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: Theme.spacingLG) {
                if let error = error {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    
                    Text("Connection Failed")
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.textPrimary)
                    
                    Text(error)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: Theme.spacingMD) {
                        Button("Cancel", action: onCancel)
                            .buttonStyle(.bordered)
                            .tint(Theme.textMuted)
                        
                        if let onRetry = onRetry {
                            Button("Retry", action: onRetry)
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.cyanAccent)
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.top, Theme.spacingSM)
                } else {
                    Image(systemName: serverType.iconSystemName)
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.cyanAccent)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .opacity(isAnimating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                        .onAppear {
                            isAnimating = true
                        }
                    
                    HStack(spacing: 2) {
                        Text("Connecting to \(serverName)")
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Text("...")
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                    }
                    
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                        .tint(Theme.textMuted)
                        .padding(.top, Theme.spacingSM)
                }
            }
            .padding(Theme.spacingXL)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLG))
            .shadow(radius: 20)
            .padding(Theme.spacingLG)
        }
        .transition(.opacity)
    }
}
