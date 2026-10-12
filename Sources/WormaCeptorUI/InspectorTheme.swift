import SwiftUI
import UIKit
import WormaCeptor

/// Tokens mirroring Android's `WormaCeptorDesignSystem`: a 4 pt grid and the status colors.
enum InspectorTheme {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    enum Radius {
        static let sm: CGFloat = 6
    }

    static let minTouchTarget: CGFloat = 44
    static let badgeFillOpacity = 0.16

    /// Android's StatusGreen/Blue/Amber/Red/Grey, one shade darker in light mode and lighter in dark mode so status
    /// text keeps 4.5:1 contrast on the system backgrounds.
    static func color(for tone: WormaCeptorStatusTone) -> Color {
        switch tone {
        case .success: return dynamic(light: 0x047857, dark: 0x34D399)
        case .redirect: return dynamic(light: 0x1D4ED8, dark: 0x60A5FA)
        case .warning: return dynamic(light: 0xB45309, dark: 0xFBBF24)
        case .error: return dynamic(light: 0xB91C1C, dark: 0xF87171)
        default: return dynamic(light: 0x4B5563, dark: 0x9CA3AF)
        }
    }

    /// Secondary labels. The system's secondary label color is under 4.5:1 on white, so this is one step darker
    /// (lighter in dark mode).
    static let secondaryText = dynamic(light: 0x4B5563, dark: 0x9CA3AF)

    /// Android marks mocked rows with its secondary accent.
    static let mocked = dynamic(light: 0x0E7490, dark: 0x67E8F9)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light) })
    }

    private static func uiColor(_ rgb: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
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

/// A small tinted label: the status code, MOCK, a method.
struct InspectorBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundColor(color)
            .padding(.horizontal, InspectorTheme.Spacing.xs + InspectorTheme.Spacing.xxs)
            .padding(.vertical, InspectorTheme.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.sm)
                    .fill(color.opacity(InspectorTheme.badgeFillOpacity))
            )
    }
}

#Preview("Badges") {
    VStack(spacing: InspectorTheme.Spacing.sm) {
        InspectorBadge(text: "200", color: InspectorTheme.color(for: .success))
        InspectorBadge(text: "304", color: InspectorTheme.color(for: .redirect))
        InspectorBadge(text: "404", color: InspectorTheme.color(for: .warning))
        InspectorBadge(text: "500", color: InspectorTheme.color(for: .error))
        InspectorBadge(text: "...", color: InspectorTheme.color(for: .neutral))
        InspectorBadge(text: "MOCK", color: InspectorTheme.mocked)
    }
    .padding()
}
