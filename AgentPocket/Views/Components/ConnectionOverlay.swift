import SwiftUI

// MARK: - Connection Overlay
struct ConnectionOverlay: View {
    enum State {
        case connecting
        case disconnected(String?)
        case error(String)
    }
    
    let state: State
    var onRetry: (() -> Void)?
    var onGoHome: (() -> Void)?
    
    var body: some View {
        ZStack {
            Brand.background
                .opacity(0.95)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
            
            VStack(spacing: 32) {
                iconView
                textView
                actionButtons
            }
            .padding(32)
        }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var iconView: some View {
        Group {
            switch state {
            case .connecting:
                ProgressView()
                    .controlSize(.extraLarge)
                    .tint(Brand.cyan)
            case .disconnected, .error:
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Brand.error)
                    .symbolEffect(.bounce, value: true)
            }
        }
        .frame(height: 64)
    }
    
    private var textView: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Brand.textPrimary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        if case .connecting = state {
            // No buttons while connecting
        } else {
            HStack(spacing: 16) {
                if let onGoHome {
                    Button("Home", action: onGoHome)
                        .brandButton()
                }
                
                if let onRetry {
                    Button("Retry", action: onRetry)
                        .brandButton(prominent: true)
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Helpers
    private var title: String {
        switch state {
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .error: return "Connection Error"
        }
    }
    
    private var subtitle: String? {
        switch state {
        case .connecting: return "Establishing secure connection to server"
        case .disconnected(let msg): return msg ?? "The server connection was lost."
        case .error(let msg): return msg
        }
    }
}
