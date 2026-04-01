import SwiftUI

// MARK: - Status Indicator
struct StatusIndicator: View {
    enum Status {
        case connected
        case connecting
        case disconnected
        case error
        case idle
    }
    
    let status: Status
    var size: CGFloat = 8
    
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .scaleEffect(isPulsing ? 2.5 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onChange(of: status, initial: true) { _, newStatus in
                updateAnimation(for: newStatus)
            }
            .accessibilityLabel("Status: \(String(describing: status))")
    }
    
    // MARK: - Helpers
    private var color: Color {
        switch status {
        case .connected: return Brand.success
        case .connecting: return Brand.warning
        case .disconnected: return Brand.textMuted
        case .error: return Brand.error
        case .idle: return Brand.textSubtle
        }
    }
    
    private var shouldPulse: Bool {
        status == .connecting
    }
    
    private func updateAnimation(for currentStatus: Status) {
        if currentStatus == .connecting {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                isPulsing = false
            }
        }
    }
}
