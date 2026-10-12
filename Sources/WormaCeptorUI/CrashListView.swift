import SwiftUI
import UIKit
import WormaCeptor

final class CrashListModel: ObservableObject {
    @Published private(set) var rows: [WormaCeptorCrashRow] = []

    private var subscription: WormaCeptorSubscription?

    init() {
        subscription = WormaCeptorCrashes.shared.observeCrashes { [weak self] rows in
            self?.rows = rows
        }
    }

    deinit {
        subscription?.cancel()
    }

    func clear() {
        WormaCeptorCrashes.shared.clear()
    }
}

/// Crashes of earlier launches, newest first, with export and clear.
struct CrashListScreen: View {
    @StateObject private var model = CrashListModel()

    var body: some View {
        CrashListContent(rows: model.rows, onClear: model.clear)
    }
}

struct CrashListContent: View {
    let rows: [WormaCeptorCrashRow]
    let onClear: () -> Void

    @State private var isConfirmingClear = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: InspectorTheme.Spacing.sm) {
                ForEach(rows, id: \.id) { row in
                    NavigationLink(destination: CrashDetailScreen(id: row.id)) {
                        CrashRowCard(row: row)
                    }
                    .buttonStyle(InspectorPressStyle())
                    .transition(InspectorMotion.expand)
                }
            }
            .padding(InspectorTheme.Spacing.md)
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: rows.map(\.id))
        .overlay {
            if rows.isEmpty {
                InspectorEmptyState(
                    systemImage: "ladybug",
                    title: "No crashes captured",
                    message: "Your app is running smoothly. A crash shows up here on the next launch."
                )
            }
        }
        .inspectorScreen()
        .navigationTitle("Crashes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { menu }
        }
        .alert("Clear all crashes?", isPresented: $isConfirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onClear()
            }
        } message: {
            Text("This will permanently delete all captured crash reports. This action cannot be undone.")
        }
    }

    /// Android's overflow menu on the Crashes tab: export, clear all.
    private var menu: some View {
        Menu {
            if #available(iOS 16.0, *) {
                ShareLink(item: CrashExport.json(rows)) {
                    Label("Export crashes", systemImage: "square.and.arrow.up")
                }
            }
            Button(role: .destructive) {
                isConfirmingClear = true
            } label: {
                Label("Clear all crashes", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .accessibilityLabel("Crash actions")
        .disabled(rows.isEmpty)
    }
}

/// Android's crash export as JSON. The list rows carry no stack trace, so the export has the location instead.
enum CrashExport {
    static func json(_ rows: [WormaCeptorCrashRow]) -> String {
        let objects: [[String: Any]] = rows.map { row in
            [
                "timestamp": row.timestampMs,
                "exceptionType": row.exceptionType,
                "message": row.message ?? "",
                "location": row.location ?? "",
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys])
        else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }
}

#if DEBUG
#Preview("Crashes") {
    NavigationView {
        CrashListContent(rows: PreviewSamples.crashRows, onClear: {})
    }
}

#Preview("Crashes, dark") {
    NavigationView {
        CrashListContent(rows: PreviewSamples.crashRows, onClear: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Crashes, empty") {
    NavigationView {
        CrashListContent(rows: [], onClear: {})
    }
}
#endif
