import SwiftUI
import WormaCeptor

/// Android's `CrashItem`: a red-tinted outlined card with an icon chip, the exception, message, location and age.
struct CrashRowCard: View {
    let row: WormaCeptorCrashRow

    private var isSevere: Bool {
        CrashFormat.isSevere(row.exceptionType)
    }

    private var when: String {
        CrashFormat.relative(row.timestampMs)
    }

    var body: some View {
        HStack(alignment: .top, spacing: InspectorTheme.Spacing.md) {
            Image(systemName: isSevere ? "ladybug.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: InspectorTheme.IconSize.sm, weight: .semibold))
                .foregroundColor(CrashFormat.statusRed)
                .frame(width: InspectorTheme.Spacing.xxl, height: InspectorTheme.Spacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                        .fill(CrashFormat.statusRed.opacity(InspectorTheme.Alpha.light))
                )
            VStack(alignment: .leading, spacing: 0) {
                Text(row.exceptionType)
                    .font(InspectorFont.titleSmall)
                    .foregroundColor(InspectorTheme.error)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.bottom, InspectorTheme.Spacing.xs)
                if let message = row.message, !message.isEmpty {
                    Text(message)
                        .font(InspectorFont.body)
                        .foregroundColor(InspectorTheme.textPrimary.opacity(InspectorTheme.Alpha.prominent))
                        .lineLimit(2)
                        .padding(.bottom, InspectorTheme.Spacing.sm)
                }
                if let location = row.location {
                    Text(location)
                        .font(Font.caption2.monospaced())
                        .foregroundColor(InspectorTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, InspectorTheme.Spacing.sm)
                        .padding(.vertical, InspectorTheme.Spacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                                .fill(InspectorTheme.surfaceHigh.opacity(InspectorTheme.Alpha.intense))
                        )
                        .padding(.bottom, InspectorTheme.Spacing.xs)
                }
                Text(when)
                    .font(InspectorFont.label)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .inspectorCard(
            fill: CrashFormat.statusRed.opacity(InspectorTheme.Alpha.subtle),
            border: CrashFormat.statusRed.opacity(InspectorTheme.Alpha.moderate),
            padding: InspectorTheme.Spacing.lg
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [isSevere ? "Critical crash" : "Crash", row.exceptionType, row.message, row.location, when]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
    }
}

enum CrashFormat {
    /// Android's `Status.red` (Red 500): card tint, border and icon, never text.
    static let statusRed = Color(rgb: 0xEF4444)

    /// Android's `IsSevereExceptionUseCase` list plus the iOS signals that mean the same (bad access, a trap).
    private static let severeTypes = [
        "NullPointerException", "OutOfMemoryError", "StackOverflowError", "SecurityException",
        "IllegalStateException", "AssertionError", "SIGSEGV", "SIGBUS", "SIGTRAP",
    ]

    static func isSevere(_ exceptionType: String) -> Bool {
        severeTypes.contains { exceptionType.range(of: $0, options: .caseInsensitive) != nil }
    }

    static func date(_ epochMillis: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
    }

    /// Android's `FormatCrashRelativeTimeUseCase`: "Just now", "5 min ago", "3 hr ago", "2 days ago", then a date.
    static func relative(_ epochMillis: Int64, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date(epochMillis))
        let minute: TimeInterval = 60
        let hour = 60 * minute
        let day = 24 * hour
        switch seconds {
        case ..<minute: return "Just now"
        case ..<hour: return "\(Int(seconds / minute)) min ago"
        case ..<day: return "\(Int(seconds / hour)) hr ago"
        case ..<(7 * day):
            let days = Int(seconds / day)
            return days > 1 ? "\(days) days ago" : "\(days) day ago"
        default: return absolute.string(from: date(epochMillis))
        }
    }

    static func full(_ epochMillis: Int64) -> String {
        fullFormatter.string(from: date(epochMillis))
    }

    private static let absolute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd HH:mm")
        return formatter
    }()

    private static let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

#if DEBUG
#Preview("Crash row") {
    VStack(spacing: InspectorTheme.Spacing.sm) {
        ForEach(PreviewSamples.crashRows, id: \.id) { CrashRowCard(row: $0) }
    }
    .padding()
    .inspectorScreen()
}
#endif
