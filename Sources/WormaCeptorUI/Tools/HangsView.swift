import SwiftUI
import WormaCeptor

/// Found hangs and whether the watchdog runs, live.
@MainActor
final class HangsModel: ObservableObject {
    @Published private(set) var hangs: [WormaCeptorHang] = []
    @Published private(set) var isRunning = false

    private var subscriptions: [WormaCeptorSubscription] = []

    init() {
        subscriptions = [
            WormaCeptorHangs.shared.observe { [weak self] hangs in self?.hangs = hangs },
            WormaCeptorHangs.shared.observeRunning { [weak self] running in self?.isRunning = running.boolValue },
        ]
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
    }

    func setRunning(_ running: Bool) {
        if running {
            WormaCeptorHangs.shared.start()
        } else {
            WormaCeptorHangs.shared.stop()
        }
    }

    func clear() {
        WormaCeptorHangs.shared.clear()
    }
}

/// Times the main thread stopped answering, the list `list_violations` returns.
struct HangsScreen: View {
    @StateObject private var model = HangsModel()

    var body: some View {
        HangsContent(
            hangs: model.hangs,
            isRunning: model.isRunning,
            onSetRunning: model.setRunning,
            onClear: model.clear
        )
    }
}

struct HangsContent: View {
    let hangs: [WormaCeptorHang]
    let isRunning: Bool
    let onSetRunning: (Bool) -> Void
    let onClear: () -> Void

    @State private var isConfirmingClear = false

    var body: some View {
        List {
            Section {
                Toggle("Detect hangs", isOn: Binding(get: { isRunning }, set: onSetRunning))
                    .frame(minHeight: InspectorTheme.minTouchTarget)
            } footer: {
                Text("Reports the main thread blocked for \(WormaCeptorHangs.shared.DefaultThresholdMs) ms or more, with its stack, the iOS stand-in for Android's StrictMode. The first \(WormaCeptorHangs.shared.StartupGraceMs / 1000) s after turning it on are skipped.")
            }
            Section {
                ForEach(hangs, id: \.id) { hang in
                    NavigationLink(destination: HangDetailView(hang: hang)) {
                        HangRowView(hang: hang)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if hangs.isEmpty {
                Text(isRunning ? "No hangs found" : "Detection is off")
                    .foregroundColor(InspectorTheme.secondaryText)
            }
        }
        .navigationTitle("Main thread hangs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isConfirmingClear = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .disabled(hangs.isEmpty)
                .accessibilityLabel("Clear hangs")
            }
        }
        .confirmationDialog("Clear all hangs?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        }
    }
}

enum HangFormat {
    static func tone(_ hang: WormaCeptorHang) -> WormaCeptorStatusTone {
        hang.durationMs >= 1000 ? .error : .warning
    }

    /// The first frame outside Apple's libraries: usually the app code that blocked.
    static func culprit(_ hang: WormaCeptorHang) -> String? {
        let system = ["libsystem_", "libdispatch", "libobjc", "Foundation", "CoreFoundation", "UIKitCore", "?  "]
        return hang.stack.first { frame in !system.contains { frame.hasPrefix($0) } }
    }
}

private struct HangRowView: View {
    let hang: WormaCeptorHang

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack {
                InspectorBadge(
                    text: InspectorFormat.duration(KotlinLong(value: hang.durationMs)) ?? "",
                    color: InspectorTheme.color(for: HangFormat.tone(hang))
                )
                Spacer()
                Text(InspectorFormat.time(hang.timestampMs))
                    .font(.caption)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            Text(HangFormat.culprit(hang) ?? "No stack")
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2)
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

/// One hang's full main-thread stack.
struct HangDetailView: View {
    let hang: WormaCeptorHang

    var body: some View {
        List {
            Section("Hang") {
                InfoRowView(row: WormaCeptorInfoRow(
                    label: "Blocked for",
                    value: InspectorFormat.duration(KotlinLong(value: hang.durationMs)) ?? ""
                ))
                InfoRowView(row: WormaCeptorInfoRow(label: "Started", value: InspectorFormat.time(hang.timestampMs)))
            }
            Section {
                if hang.stack.isEmpty {
                    Text("The main thread couldn't be sampled.")
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                ForEach(Array(hang.stack.enumerated()), id: \.offset) { index, frame in
                    Text("\(index)  \(frame)")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            } header: {
                HStack {
                    Text("Main thread stack")
                    Spacer()
                    CopyButton(text: hang.stack.joined(separator: "\n"), label: "Stack")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Hang")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Hangs") {
    NavigationView {
        HangsContent(hangs: PreviewSamples.hangs, isRunning: true, onSetRunning: { _ in }, onClear: {})
    }
}

#Preview("Hang detail") {
    NavigationView {
        HangDetailView(hang: PreviewSamples.hangs[0])
    }
}
#endif
