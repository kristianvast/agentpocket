import SwiftUI

struct StatusIndicator: View {
    let status: ConversationStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityLabel(accessibilityText)
    }

    private var color: Color {
        switch status {
        case .idle: return .gray
        case .streaming: return Theme.cyanAccent
        case .toolRunning: return .yellow
        case .waitingPermission: return .orange
        case .error: return .red
        }
    }

    private var accessibilityText: String {
        switch status {
        case .idle: return "Status: idle"
        case .streaming: return "Status: streaming response"
        case .toolRunning: return "Status: running tool"
        case .waitingPermission: return "Status: waiting for permission"
        case .error: return "Status: error"
        }
    }
}
