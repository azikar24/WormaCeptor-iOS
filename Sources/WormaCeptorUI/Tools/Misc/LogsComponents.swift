import SwiftUI
import WormaCeptor

/// Android's `LevelFilterChips`: one toggle per level in the level's color, with its line count.
struct LogLevelChips: View {
    let entries: [WormaCeptorLogEntry]
    @Binding var selected: Set<Int32>

    var body: some View {
        let counts = Dictionary(grouping: entries, by: { $0.level.ordinal }).mapValues(\.count)
        InspectorChipRow {
            ForEach(LogLevels.all, id: \.ordinal) { level in
                InspectorChip(
                    label: LogLevels.letter(level),
                    isSelected: selected.contains(level.ordinal),
                    color: LogLevels.color(level),
                    count: counts[level.ordinal],
                    shape: .filter
                ) {
                    if selected.contains(level.ordinal) {
                        selected.remove(level.ordinal)
                    } else {
                        selected.insert(level.ordinal)
                    }
                }
                .accessibilityLabel("\(LogLevels.title(level)), \(counts[level.ordinal] ?? 0) lines")
            }
        }
    }
}

/// Android's logs `StatsBar`: capture state and PID on the left, the entry count on the right.
struct LogsStatsBar: View {
    let isCapturing: Bool
    let total: Int
    let shown: Int

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.md) {
            HStack(spacing: InspectorTheme.Spacing.xs) {
                InspectorStatusDot(color: isCapturing ? InspectorTheme.brand : InspectorTheme.outline)
                Text(isCapturing ? "Capturing" : "Paused")
            }
            Text("PID: " + String(ProcessInfo.processInfo.processIdentifier))
                .font(InspectorFont.labelSmall.monospaced())
            Spacer()
            Text(shown == total ? "\(total) entries" : "\(shown) / \(total) entries")
                .monospacedDigit()
        }
        .font(InspectorFont.labelSmall)
        .foregroundColor(InspectorTheme.secondaryText)
        .padding(.horizontal, InspectorTheme.Spacing.lg)
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Android's `LogEntryItem`: an outlined card washed with the level color, level badge, tag and time over the
/// message in mono.
struct LogRowView: View {
    let entry: WormaCeptorLogEntry

    var body: some View {
        let color = LogLevels.color(entry.level)
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Text(LogLevels.letter(entry.level))
                    .font(InspectorFont.badge)
                    .foregroundColor(color)
                    .padding(.horizontal, InspectorTheme.Spacing.sm - InspectorTheme.Spacing.xxs)
                    .padding(.vertical, InspectorTheme.Spacing.xxs)
                    .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs).fill(color.opacity(InspectorTheme.Alpha.soft)))
                Text(entry.tag)
                    .font(InspectorFont.label.weight(.semibold))
                    .foregroundColor(InspectorTheme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(LogsFormat.time(entry.timestampMs))
                    .font(InspectorFont.code)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            Text(entry.message)
                .font(InspectorFont.code)
                .foregroundColor(InspectorTheme.textPrimary.opacity(InspectorTheme.Alpha.prominent))
                .lineLimit(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, InspectorTheme.Spacing.md)
        .padding(.vertical, InspectorTheme.Spacing.sm)
        .inspectorCard(
            fill: entry.level == .verbose
                ? InspectorTheme.surfaceHigh.opacity(InspectorTheme.Alpha.bold)
                : color.opacity(InspectorTheme.Alpha.subtle),
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(LogLevels.title(entry.level)), \(entry.tag), \(LogsFormat.time(entry.timestampMs)), \(entry.message)")
        .contextMenu {
            Button {
                UIPasteboard.general.string = entry.message
            } label: {
                Label("Copy message", systemImage: "doc.on.doc")
            }
            Button {
                UIPasteboard.general.string = LogLevels.line(entry)
            } label: {
                Label("Copy line", systemImage: "text.alignleft")
            }
        }
    }
}

#if DEBUG
#Preview("Log rows") {
    ScrollView {
        VStack(spacing: InspectorTheme.Spacing.xs) {
            ForEach(PreviewSamples.logEntries, id: \.id) { LogRowView(entry: $0) }
        }
        .padding(InspectorTheme.Spacing.sm)
    }
    .inspectorScreen()
}
#endif
