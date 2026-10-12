import SwiftUI
import WormaCeptor

/// Android's `ToolColors` for the log, WebSocket, leak, location and push tools. Each keeps Android's hue; light
/// mode uses a darker shade and dark mode a lighter one so text on the inspector backgrounds reaches 4.5:1.
enum MiscToolColors {
    enum LogLevel {
        static let verbose = InspectorTheme.dynamic(light: 0x4B5563, dark: 0x9CA3AF)
        static let debug = InspectorTheme.dynamic(light: 0x1D4ED8, dark: 0x60A5FA)
        static let info = InspectorTheme.dynamic(light: 0x047857, dark: 0x34D399)
        static let warn = InspectorTheme.dynamic(light: 0xB45309, dark: 0xFBBF24)
        static let error = InspectorTheme.dynamic(light: 0xB91C1C, dark: 0xF87171)
        static let assert = InspectorTheme.dynamic(light: 0xAD1457, dark: 0xF48FB1)

        static func color(_ level: WormaCeptorLogLevel) -> Color {
            switch level {
            case .verbose: return verbose
            case .debug: return debug
            case .info: return info
            case .warn: return warn
            case .error: return error
            default: return assert
            }
        }
    }

    enum WebSocket {
        static let connecting = InspectorTheme.dynamic(light: 0xC2410C, dark: 0xFB923C)
        static let open = InspectorTheme.dynamic(light: 0x2E7D32, dark: 0x81C784)
        static let closing = InspectorTheme.dynamic(light: 0xBF360C, dark: 0xFF8A65)
        static let closed = InspectorTheme.dynamic(light: 0x616161, dark: 0xBDBDBD)

        static func color(_ state: WormaCeptorWebSocketState) -> Color {
            switch state {
            case .connecting: return connecting
            case .open: return open
            case .closing: return closing
            default: return closed
            }
        }
    }

    enum Leak {
        static let critical = InspectorTheme.dynamic(light: 0xC62828, dark: 0xEF9A9A)
        static let high = InspectorTheme.dynamic(light: 0xBF360C, dark: 0xFF8A65)
        static let medium = InspectorTheme.dynamic(light: 0x8A6100, dark: 0xFFD54F)
        static let low = InspectorTheme.dynamic(light: 0x006064, dark: 0x4DD0E1)

        static func color(_ severity: String) -> Color {
            switch severity.uppercased() {
            case "CRITICAL": return critical
            case "HIGH": return high
            case "MEDIUM": return medium
            default: return low
            }
        }
    }

    /// Android's monitoring dot: green while watching, grey when idle. A dot, not text, so Android's values.
    static let monitoring = Color(rgb: 0x4CAF50)
    static let idle = Color(rgb: 0x9E9E9E)

    /// Android's `Location.enabled`, for the active badge and the status card.
    static let locationActive = InspectorTheme.dynamic(light: 0x2E7D32, dark: 0x81C784)
    static let locationWarning = InspectorTheme.dynamic(light: 0xB45309, dark: 0xFFB74D)

    enum PushPriority {
        static let low = InspectorTheme.dynamic(light: 0x546E7A, dark: 0x90A4AE)
        static let `default` = InspectorTheme.dynamic(light: 0x0277BD, dark: 0x4FC3F7)
        static let high = InspectorTheme.dynamic(light: 0xBF360C, dark: 0xFFB74D)
        static let max = InspectorTheme.dynamic(light: 0xC62828, dark: 0xEF5350)

        static func color(_ priority: WormaCeptorPushPriority) -> Color {
            switch priority {
            case .low: return low
            case .high: return high
            case .max: return max
            default: return `default`
            }
        }
    }
}
