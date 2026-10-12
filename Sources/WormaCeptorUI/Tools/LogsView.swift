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
        MiscToolColors.LogLevel.color(level)
    }

    /// `14:03:22.123 W/stderr: message`, the shape logcat prints.
    static func line(_ entry: WormaCeptorLogEntry) -> String {
        "\(LogsFormat.time(entry.timestampMs)) \(letter(entry.level))/\(entry.tag): \(entry.message)"
    }
}

enum LogsFormat {
    static func time(_ epochMillis: Int64) -> String {
        formatter.string(from: Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1000))
    }

    /// Android's `HH:mm:ss.SSS`, 24-hour whatever the locale.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

/// Android's console: search, level chips, a status bar, then one tinted card per line, newest at the bottom.
/// Follows new lines until the user scrolls up; the round button jumps back down and follows again.
struct LogsContent: View {
    let entries: [WormaCeptorLogEntry]
    let isCapturing: Bool
    let onToggleCapture: () -> Void
    let onClear: () -> Void

    @State private var search = ""
    @State private var levels = Set(LogLevels.all.map(\.ordinal))
    @State private var followsNewest = true
    @State private var isConfirmingClear = false

    private var filtered: [WormaCeptorLogEntry] {
        entries.filter { entry in
            levels.contains(entry.level.ordinal)
                && (search.isEmpty
                    || entry.message.localizedCaseInsensitiveContains(search)
                    || entry.tag.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        let visible = filtered
        VStack(spacing: 0) {
            InspectorSearchField(placeholder: "Search by tag or message…", text: $search)
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.vertical, InspectorTheme.Spacing.sm)
            LogLevelChips(entries: entries, selected: $levels)
                .padding(.bottom, InspectorTheme.Spacing.xs)
            LogsStatsBar(isCapturing: isCapturing, total: entries.count, shown: visible.count)
            if visible.isEmpty {
                emptyState
            } else {
                logList(visible)
            }
        }
        .inspectorScreen()
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: onToggleCapture) {
                    Image(systemName: isCapturing ? "pause.fill" : "play.fill")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel(isCapturing ? "Pause capture" : "Start capture")
                Button {
                    isConfirmingClear = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .disabled(entries.isEmpty)
                .accessibilityLabel("Clear logs")
                menu(visible: visible)
            }
        }
        .tint(InspectorTheme.brand)
        .confirmationDialog("Clear all logs?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        } message: {
            Text("Captured lines are deleted. Capture keeps running.")
        }
    }

    private func logList(_ visible: [WormaCeptorLogEntry]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: InspectorTheme.Spacing.xs) {
                    ForEach(visible, id: \.id) { entry in
                        LogRowView(entry: entry).id(entry.id)
                    }
                }
                .padding(.horizontal, InspectorTheme.Spacing.sm)
                .padding(.vertical, InspectorTheme.Spacing.xs)
            }
            .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { drag in
                // Pulling the content down means reading older lines: stop following like Android does.
                if drag.translation.height > 0, followsNewest {
                    withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { followsNewest = false }
                }
            })
            .onAppear { scrollToNewest(visible, proxy: proxy, animated: false) }
            .onChange(of: visible.last?.id) { _ in
                if followsNewest { scrollToNewest(visible, proxy: proxy, animated: true) }
            }
            .overlay(alignment: .bottomTrailing) {
                if !followsNewest {
                    scrollToBottomButton {
                        withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { followsNewest = true }
                        scrollToNewest(visible, proxy: proxy, animated: true)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }

    private func scrollToNewest(_ visible: [WormaCeptorLogEntry], proxy: ScrollViewProxy, animated: Bool) {
        guard let id = visible.last?.id else { return }
        if animated {
            withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { proxy.scrollTo(id, anchor: .bottom) }
        } else {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    /// Android's `WormaCeptorFAB` with the down arrow.
    private func scrollToBottomButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: InspectorTheme.IconSize.md, weight: .bold))
                .foregroundColor(InspectorTheme.background)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.xl).fill(InspectorTheme.brand))
        }
        .buttonStyle(InspectorPressStyle())
        .padding(InspectorTheme.Spacing.lg)
        .accessibilityLabel("Scroll to bottom")
    }

    private func menu(visible: [WormaCeptorLogEntry]) -> some View {
        Menu {
            Toggle("Follow new lines", isOn: $followsNewest)
            Button {
                UIPasteboard.general.string = visible.map(LogLevels.line).joined(separator: "\n")
            } label: {
                Label("Copy shown lines", systemImage: "doc.on.doc")
            }
            .disabled(visible.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .accessibilityLabel("Log options")
    }

    @ViewBuilder private var emptyState: some View {
        if !entries.isEmpty {
            InspectorEmptyState(systemImage: "magnifyingglass", title: "No matches", message: "No line matches the levels and search.")
        } else if isCapturing {
            InspectorEmptyState(
                systemImage: "arrow.down.to.line",
                title: "Waiting for logs…",
                message: "print, println, NSLog and Logger output shows up here as the app writes it."
            )
        } else {
            InspectorEmptyState(
                systemImage: "arrow.down.to.line",
                title: "No logs captured",
                message: "Start capture to record the app's print, NSLog and Logger output from now on.",
                actionTitle: "Start capture",
                action: onToggleCapture
            )
        }
    }
}

#if DEBUG
#Preview("Logs") {
    NavigationView {
        LogsContent(entries: PreviewSamples.logEntries, isCapturing: true, onToggleCapture: {}, onClear: {})
    }
}

#Preview("Logs dark") {
    NavigationView {
        LogsContent(entries: PreviewSamples.logEntries, isCapturing: true, onToggleCapture: {}, onClear: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Logs, capture off") {
    NavigationView {
        LogsContent(entries: [], isCapturing: false, onToggleCapture: {}, onClear: {})
    }
}
#endif
