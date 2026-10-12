import SwiftUI

/// Loads a tool's snapshot on appear and on pull to refresh.
@MainActor
final class SnapshotModel<Value>: ObservableObject {
    @Published private(set) var value: Value
    @Published private(set) var error: String?
    @Published private(set) var isLoaded = false

    private let load: () async throws -> Value

    init(initial: Value, load: @escaping () async throws -> Value) {
        value = initial
        self.load = load
    }

    func refresh() async {
        do {
            value = try await load()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoaded = true
    }
}

/// Copies `text` and shows a checkmark for a moment.
struct CopyButton: View {
    let text: String
    let label: String

    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(copied ? "\(label) copied" : "Copy \(label.lowercased())")
    }
}
