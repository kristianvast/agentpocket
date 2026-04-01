import SwiftUI

// MARK: - Brand Design System

enum Brand {
    // MARK: Primary Gradient Colors
    static let cyan = Color(red: 0.133, green: 0.827, blue: 0.933)       // #22D3EE
    static let teal = Color(red: 0.176, green: 0.831, blue: 0.749)       // #2DD4BF
    static let emerald = Color(red: 0.204, green: 0.827, blue: 0.600)    // #34D399

    // MARK: Background Colors
    static let background = Color(hue: 220/360, saturation: 0.20, brightness: 0.04)  // Deepest dark
    static let surface = Color(hue: 220/360, saturation: 0.20, brightness: 0.07)      // Card/surface
    static let surfaceLight = Color(hue: 220/360, saturation: 0.15, brightness: 0.12) // Elevated surface
    static let border = Color.white.opacity(0.08)                                      // Subtle borders
    static let borderLight = Color.white.opacity(0.15)                                 // Prominent borders

    // MARK: Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textMuted = Color.white.opacity(0.50)
    static let textSubtle = Color.white.opacity(0.35)

    // MARK: Semantic Colors
    static let success = Color(red: 0.204, green: 0.827, blue: 0.600)    // Emerald
    static let error = Color(red: 0.937, green: 0.267, blue: 0.267)      // Red
    static let warning = Color(red: 0.961, green: 0.620, blue: 0.043)    // Amber
    static let info = Color(red: 0.133, green: 0.827, blue: 0.933)       // Cyan

    // MARK: Status Colors
    static let statusRunning = cyan
    static let statusCompleted = success
    static let statusError = error
    static let statusPending = textMuted

    // MARK: Gradient
    static let gradient = LinearGradient(
        colors: [cyan, teal, emerald],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let gradientVertical = LinearGradient(
        colors: [cyan, teal, emerald],
        startPoint: .top,
        endPoint: .bottom
    )

    static let gradientSubtle = LinearGradient(
        colors: [cyan.opacity(0.3), teal.opacity(0.3), emerald.opacity(0.3)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: Typography
    static let monoFont = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
    static let monoLarge = Font.system(.title3, design: .monospaced)

    // MARK: Spacing
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusTiny: CGFloat = 6
    static let padding: CGFloat = 16
    static let paddingSmall: CGFloat = 8
    static let paddingTiny: CGFloat = 4
}

// MARK: - View Modifiers

struct BrandCardModifier: ViewModifier {
    var padding: CGFloat = Brand.padding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.cornerRadius)
                    .stroke(Brand.border, lineWidth: 1)
            )
    }
}

struct BrandGlowModifier: ViewModifier {
    var radius: CGFloat = 40

    func body(content: Content) -> some View {
        content
            .background(
                Brand.gradient
                    .blur(radius: radius)
                    .opacity(0.15)
            )
    }
}

struct BrandGradientForegroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(Brand.gradient)
            .mask(content)
    }
}

struct BrandButtonModifier: ViewModifier {
    var isProminent: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isProminent
                    ? AnyShapeStyle(Brand.gradient)
                    : AnyShapeStyle(Brand.surfaceLight)
            )
            .foregroundStyle(Brand.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadiusSmall))
    }
}

// MARK: - View Extensions

extension View {
    func brandCard(padding: CGFloat = Brand.padding) -> some View {
        modifier(BrandCardModifier(padding: padding))
    }

    func brandGlow(radius: CGFloat = 40) -> some View {
        modifier(BrandGlowModifier(radius: radius))
    }

    func brandGradientForeground() -> some View {
        modifier(BrandGradientForegroundModifier())
    }

    func brandButton(prominent: Bool = false) -> some View {
        modifier(BrandButtonModifier(isProminent: prominent))
    }
}

// MARK: - Color Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
