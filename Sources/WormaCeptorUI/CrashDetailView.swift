import SwiftUI
import WormaCeptor

final class CrashDetailModel: ObservableObject {
    @Published private(set) var detail: WormaCeptorCrashDetail?
    @Published private(set) var isLoaded = false

    private var subscription: WormaCeptorSubscription?

    init(id: Int64) {
        subscription = WormaCeptorCrashes.shared.observeCrash(id: id) { [weak self] detail in
            self?.detail = detail
            self?.isLoaded = true
        }
    }

    deinit {
        subscription?.cancel()
    }
}

/// One crash: what, where, when, the message and the stack.
struct CrashDetailScreen: View {
    @StateObject private var model: CrashDetailModel

    init(id: Int64) {
        _model = StateObject(wrappedValue: CrashDetailModel(id: id))
    }

    var body: some View {
        if let detail = model.detail {
            CrashDetailContent(detail: detail)
        } else if model.isLoaded {
            EmptyStateView(
                systemImage: "questionmark.circle",
                title: "Crash gone",
                message: "It was cleared after this screen opened."
            )
        } else {
            ProgressView()
        }
    }
}

struct CrashDetailContent: View {
    let detail: WormaCeptorCrashDetail

    @State private var showsAllFrames = false

    private var appFrameCount: Int {
        detail.frames.filter(\.isAppCode).count
    }

    /// With app frames, the others start folded, as on Android; without any, folding would hide everything.
    private var visibleFrames: [WormaCeptorStackFrame] {
        showsAllFrames || appFrameCount == 0 ? detail.frames : detail.frames.filter(\.isAppCode)
    }

    private var report: String {
        var lines = ["Crash: \(detail.exceptionType)", "Time: \(CrashFormat.full(detail.timestampMs))"]
        if let location = detail.location { lines.append("Location: \(location)") }
        if let message = detail.message { lines.append("Message: \(message)") }
        lines.append("")
        lines.append(detail.stackTrace)
        return lines.joined(separator: "\n")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                    Text(detail.exceptionType)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(InspectorTheme.color(for: .error))
                        .textSelection(.enabled)
                    if let location = detail.location {
                        Text("at \(location)")
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    Text(CrashFormat.full(detail.timestampMs))
                        .font(.caption)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                .padding(.vertical, InspectorTheme.Spacing.xs)
            }
            if let message = detail.message, !message.isEmpty {
                Section {
                    Text(message)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                } header: {
                    SectionHeader(title: "Message", copyText: message, copyLabel: "Message")
                }
            }
            Section {
                ForEach(Array(visibleFrames.enumerated()), id: \.offset) { _, frame in
                    Text(frame.text)
                        .font(.system(.caption2, design: .monospaced).weight(frame.isAppCode ? .semibold : .regular))
                        .foregroundColor(frame.isAppCode ? .primary : InspectorTheme.secondaryText)
                        .textSelection(.enabled)
                }
                if appFrameCount > 0, appFrameCount < detail.frames.count {
                    Button(showsAllFrames ? "Show app frames only" : "Show all \(detail.frames.count) frames") {
                        showsAllFrames.toggle()
                    }
                    .frame(minHeight: InspectorTheme.minTouchTarget)
                }
            } header: {
                SectionHeader(title: "Stack trace", copyText: detail.stackTrace, copyLabel: "Stack trace")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Crash")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if #available(iOS 16.0, *) {
                    ShareLink(item: report) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                    }
                    .accessibilityLabel("Share crash report")
                } else {
                    CopyButton(text: report, label: "Crash report")
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let copyText: String
    let copyLabel: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(InspectorTheme.secondaryText)
            Spacer()
            CopyButton(text: copyText, label: copyLabel)
        }
        .textCase(nil)
    }
}

#if DEBUG
#Preview("Crash detail") {
    NavigationView {
        CrashDetailContent(detail: PreviewSamples.crashDetail)
    }
}
#endif
