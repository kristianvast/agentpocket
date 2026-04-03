import SwiftUI

enum Theme {
    static let background = Color(hex: "#0D1117")
    static let surface = Color(hex: "#161B22")
    static let cyanAccent = Color(hex: "#22D3EE")
    static let emerald = Color(hex: "#10B981")
    static let textPrimary = Color.white.opacity(0.87)
    static let textMuted = Color.white.opacity(0.45)
    static let orange = Color(hex: "#F97316")

    static let titleFont = Font.title2.bold()
    static let headlineFont = Font.headline
    static let bodyFont = Font.body
    static let captionFont = Font.caption
    static let monoFont = Font.system(.caption, design: .monospaced)

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
    static let quickAnimation = Animation.easeInOut(duration: 0.2)

    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
