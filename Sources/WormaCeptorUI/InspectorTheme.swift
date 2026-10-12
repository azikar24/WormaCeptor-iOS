import SwiftUI
import UIKit
import WormaCeptor

/// Tokens mirroring Android's `core/ui` theme (`theme/Theme.kt`, `theme/tokens/*.kt`), so both platforms read as one
/// product. Colors that carry text keep Android's hue but use a shade that reaches 4.5:1 on the backgrounds.
enum InspectorTheme {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    enum Border {
        static let thin: CGFloat = 0.5
        static let regular: CGFloat = 1
        static let thick: CGFloat = 2
        static let bold: CGFloat = 3
    }

    enum Alpha {
        static let hint = 0.04
        static let subtle = 0.08
        static let light = 0.12
        static let soft = 0.16
        static let medium = 0.20
        static let moderate = 0.32
        static let strong = 0.40
        static let bold = 0.50
        static let intense = 0.60
        static let heavy = 0.72
        static let prominent = 0.87
    }

    enum IconSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
    }

    static let minTouchTarget: CGFloat = 44
    static let badgeFillOpacity = Alpha.subtle

    // MARK: Colors

    /// Brand teal, Android's primary.
    static let brand = dynamic(light: 0x0F766E, dark: 0x2DD4BF)
    /// Android's accentSubtle: brand at about 7% (light) / 8% (dark).
    static let brandSubtle = brand.opacity(0.08)
    static let background = dynamic(light: 0xFFFFFF, dark: 0x0A0A0A)
    static let surface = dynamic(light: 0xFAFAFA, dark: 0x141414)
    static let surfaceHigh = dynamic(light: 0xF0F0F0, dark: 0x1F1F1F)
    static let textPrimary = dynamic(light: 0x0A0A0A, dark: 0xFAFAFA)
    /// Android's textSecondary is #6B6B6B (5.3:1 on white); dark keeps Android's #8A8A8A.
    static let secondaryText = dynamic(light: 0x6B6B6B, dark: 0x8A8A8A)
    static let outline = dynamic(light: 0x9CA3AF, dark: 0x525252)
    static let outlineVariant = dynamic(light: 0x9CA3AF, dark: 0x525252)
    static let error = dynamic(light: 0xDC2626, dark: 0xF87171)
    static let warning = dynamic(light: 0xB45309, dark: 0xFBBF24)
    /// Android marks mocked rows with accentSecondary, indigo.
    static let mocked = dynamic(light: 0x4F46E5, dark: 0x7986CB)
    static let favorite = Color(rgb: 0xF59E0B)

    /// Android's status colors (2xx green, 3xx blue, 4xx amber, 5xx/failed red, pending grey).
    static func color(for tone: WormaCeptorStatusTone) -> Color {
        switch tone {
        case .success: return dynamic(light: 0x047857, dark: 0x34D399)
        case .redirect: return dynamic(light: 0x1D4ED8, dark: 0x60A5FA)
        case .warning: return dynamic(light: 0xB45309, dark: 0xFBBF24)
        case .error: return dynamic(light: 0xB91C1C, dark: 0xF87171)
        default: return dynamic(light: 0x4B5563, dark: 0x9CA3AF)
        }
    }

    /// Android's `FeatureColors` method colors.
    static func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return dynamic(light: 0x1D4ED8, dark: 0x60A5FA)
        case "POST": return dynamic(light: 0x047857, dark: 0x34D399)
        case "PUT": return dynamic(light: 0xB45309, dark: 0xFBBF24)
        case "PATCH": return dynamic(light: 0x6D28D9, dark: 0xA78BFA)
        case "DELETE": return dynamic(light: 0xB91C1C, dark: 0xF87171)
        case "HEAD": return dynamic(light: 0x0E7490, dark: 0x22D3EE)
        case "OPTIONS": return dynamic(light: 0x4F46E5, dark: 0x818CF8)
        case "CONNECT": return dynamic(light: 0x0F766E, dark: 0x2DD4BF)
        default: return dynamic(light: 0x4B5563, dark: 0x9CA3AF)
        }
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light) })
    }

    fileprivate static func uiColor(_ rgb: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(InspectorTheme.uiColor(rgb))
    }
}

/// Android's type scale mapped to the nearest Dynamic Type style, so text still scales with the user's setting.
enum InspectorFont {
    static let titleLarge = Font.title2.weight(.semibold)
    static let titleMedium = Font.callout.weight(.semibold)
    static let titleSmall = Font.subheadline.weight(.semibold)
    static let body = Font.subheadline
    static let bodyMedium = Font.subheadline.weight(.medium)
    static let bodySmall = Font.caption
    static let label = Font.caption.weight(.medium)
    static let labelSmall = Font.caption2.weight(.medium)
    static let badge = Font.caption2.weight(.bold)
    static let code = Font.caption.monospaced()
    static let codeSmall = Font.caption2.monospaced().weight(.bold)
    static let overline = Font.caption2.weight(.bold)
    static let metricValue = Font.title3.weight(.semibold).monospacedDigit()
    static let headline = Font.title3.weight(.semibold)
}

/// Android's motion tokens (`Dimensions.kt` durations, standard easing `cubic-bezier(0.2, 0, 0, 1)`).
enum InspectorMotion {
    static let ultraFast = 0.10
    static let fast = 0.15
    static let medium = 0.20
    static let normal = 0.25
    static let page = 0.30
    static let slow = 0.35
    static let verySlow = 0.50

    static func standard(_ duration: Double) -> Animation {
        .timingCurve(0.2, 0, 0, 1, duration: duration)
    }

    static func decelerate(_ duration: Double) -> Animation {
        .timingCurve(0, 0, 0, 1, duration: duration)
    }

    /// Android's expandFadeIn / shrinkFadeOut.
    static let expand = AnyTransition.opacity.combined(with: .move(edge: .top))
    /// Compose MediumBouncy spring at medium stiffness.
    static let bouncy = Animation.spring(response: 0.16, dampingFraction: 0.5)
}

extension View {
    /// Runs `animation` unless Reduce Motion is on.
    func inspectorAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ReduceMotionAnimation(animation: animation, value: value))
    }
}

private struct ReduceMotionAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// `withAnimation` that respects Reduce Motion.
func withInspectorAnimation<Result>(_ animation: Animation, _ body: () throws -> Result) rethrows -> Result {
    if UIAccessibility.isReduceMotionEnabled {
        return try body()
    }
    return try withAnimation(animation, body)
}

/// Labels for the numbers the screens show.
enum InspectorFormat {
    static func duration(_ milliseconds: KotlinLong?) -> String? {
        guard let value = milliseconds?.int64Value else { return nil }
        if value < 1000 { return "\(value) ms" }
        return String(format: "%.2f s", Double(value) / 1000)
    }

    static func bytes(_ count: Int64) -> String {
        if count == 0 { return "None" }
        return ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    static func time(_ epochMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
        return date.formatted(date: .omitted, time: .standard)
    }
}
