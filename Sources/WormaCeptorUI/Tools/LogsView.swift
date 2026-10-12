import SwiftUI
import WormaCeptor

/// Live captured lines and whether capture runs.
@MainActor
final class LogsModel: ObservableObject {
    @Published private(set) var entries: [WormaCeptorLogEntry] = []
    @Published private(set) var isCapturing = false

    private var subscriptions: [WormaCeptorSubscription] = []

    init() {
        subscriptions = [
            WormaCeptorLogs.shared.observe { [weak self] entries in self?.entries = entries },
            WormaCeptorLogs.shared.observeCapturing { [weak self] capturing in self?.isCapturing = capturing.boolValue },
        ]
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
    }

    func toggleCapture() {
        if isCapturing {
            WormaCeptorLogs.shared.stop()
        } else {
            WormaCeptorLogCapture.start()
        }
    }

    func clear() {
        WormaCeptorLogs.shared.clear()
    }
}

/// The app's stdout, stderr and os_log lines, the same buffer `tail_logs` reads.
struct LogsScreen: View {
    @StateObject private var model = LogsModel()

    var body: some View {
        LogsContent(
            entries: model.entries,
            isCapturing: model.isCapturing,
            onToggleCapture: model.toggleCapture,
            onClear: model.clear
        )
    }
}

enum LogLevels {
    static let all = WormaCeptorLogLevel.entries

    static func letter(_ level: WormaCeptorLogLevel) -> String {
        String(level.name.prefix(1))
    }

    static func title(_ level: WormaCeptorLogLevel) -> String {
        level.name.capitalized
    }

    static func color(_ level: WormaCeptorLogLevel) -> Color {
        switch level {
        case .verbose: return InspectorTheme.color(for: .neutral)
        case .debug: return InspectorTheme.color(for: .redirect)
        case .info: return InspectorTheme.color(for: .success)
        case .warn: return InspectorTheme.color(for: .warning)
        default: return InspectorTheme.color(for: .error)
        }
    }

    /// `14:03:22.123 W/stderr: message`, the shape logcat prints.
    static func line(_ entry: WormaCeptorLogEntry) -> String {
        "\(LogsFormat.time(entry.timestampMs)) \(letter(entry.level))/\(entry.tag): \(entry.message)"
    }
}

enum LogsFormat {
    static func time(_ epochMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
        return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().second().secondFraction(.fractional(3)))
    }
}

/// Newest at the bottom like logcat. Filter by minimum level, search tag and message, follow new lines or hold.
struct LogsContent: View {
    let entries: [WormaCeptorLogEntry]
    let isCapturing: Bool
    let onToggleCapture: () -> Void
    let onClear: () -> Void

    @State private var search = ""
    @State private var minimumLevel: WormaCeptorLogLevel = .verbose
    @State private var followsNewest = true
    @State private var isConfirmingClear = false

    private var filtered: [WormaCeptorLogEntry] {
        entries.filter { entry in
            entry.level.ordinal >= minimumLevel.ordinal
                && (search.isEmpty
                    || entry.message.localizedCaseInsensitiveContains(search)
                    || entry.tag.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        let visible = filtered
        ScrollViewReader { proxy in
            List(visible, id: \.id) { entry in
                LogRowView(entry: entry)
                    .id(entry.id)
            }
            .listStyle(.plain)
            .onChange(of: visible.last?.id) { id in
                if followsNewest, let id { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
        .searchable(text: $search, prompt: "Tag or message")
        .overlay { emptyState(visible: visible) }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: onToggleCapture) {
                    Image(systemName: isCapturing ? "stop.circle" : "play.circle")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel(isCapturing ? "Stop capture" : "Start capture")
                menu(visible: visible)
            }
        }
        .confirmationDialog("Clear all logs?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        } message: {
            Text("Captured lines are deleted. Capture keeps running.")
        }
    }

    private func menu(visible: [WormaCeptorLogEntry]) -> some View {
        Menu {
            Picker("Minimum level", selection: $minimumLevel) {
                ForEach(LogLevels.all, id: \.ordinal) { level in
                    Text(LogLevels.title(level)).tag(level)
                }
            }
            Toggle("Follow new lines", isOn: $followsNewest)
            Button {
                UIPasteboard.general.string = visible.map(LogLevels.line).joined(separator: "\n")
            } label: {
                Label("Copy shown lines", systemImage: "doc.on.doc")
            }
            .disabled(visible.isEmpty)
            Button(role: .destructive) {
                isConfirmingClear = true
            } label: {
                Label("Clear logs", systemImage: "trash")
            }
            .disabled(entries.isEmpty)
        } label: {
            Image(systemName: minimumLevel == .verbose ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .accessibilityLabel("Log options")
    }

    @ViewBuilder private func emptyState(visible: [WormaCeptorLogEntry]) -> some View {
        if !entries.isEmpty, visible.isEmpty {
            EmptyStateView(systemImage: "magnifyingglass", title: "No matches", message: "No line matches the level and search.")
        } else if entries.isEmpty, isCapturing {
            EmptyStateView(
                systemImage: "text.alignleft",
                title: "No lines yet",
                message: "print, println, NSLog and Logger output shows up here as the app writes it."
            )
        } else if entries.isEmpty {
            VStack(spacing: InspectorTheme.Spacing.md) {
                EmptyStateView(
                    systemImage: "text.alignleft",
                    title: "Capture is off",
                    message: "Start it to record the app's print, NSLog and Logger output from now on."
                )
                Button("Start capture", action: onToggleCapture)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: InspectorTheme.minTouchTarget)
            }
        }
    }
}

struct LogRowView: View {
    let entry: WormaCeptorLogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: InspectorTheme.Spacing.sm) {
            InspectorBadge(text: LogLevels.letter(entry.level), color: LogLevels.color(entry.level))
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    Text(entry.tag)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: InspectorTheme.Spacing.sm)
                    Text(LogsFormat.time(entry.timestampMs))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(6)
            }
        }
        .padding(.vertical, InspectorTheme.Spacing.xxs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
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
#Preview("Logs") {
    NavigationView {
        LogsContent(entries: PreviewSamples.logEntries, isCapturing: true, onToggleCapture: {}, onClear: {})
    }
}

#Preview("Logs, capture off") {
    NavigationView {
        LogsContent(entries: [], isCapturing: false, onToggleCapture: {}, onClear: {})
    }
}
#endif
