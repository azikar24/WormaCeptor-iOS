import SwiftUI
import WormaCeptor

/// Loads a snapshot of label/value sections on appear and on pull to refresh.
@MainActor
final class InfoSectionsModel: ObservableObject {
    @Published private(set) var sections: [WormaCeptorInfoSection] = []
    @Published private(set) var error: String?
    @Published private(set) var isLoaded = false

    private let load: () async throws -> [WormaCeptorInfoSection]

    init(load: @escaping () async throws -> [WormaCeptorInfoSection]) {
        self.load = load
    }

    func refresh() async {
        do {
            sections = try await load()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoaded = true
    }
}

/// Read-only label/value sections. Long-press a value to copy it.
struct InfoSectionsContent: View {
    let sections: [WormaCeptorInfoSection]

    var body: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.rows, id: \.label) { row in
                        InfoRowView(row: row)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct InfoRowView: View {
    let row: WormaCeptorInfoRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: InspectorTheme.Spacing.md) {
            Text(row.label)
                .foregroundColor(InspectorTheme.secondaryText)
            Spacer(minLength: InspectorTheme.Spacing.sm)
            Text(row.value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button {
                UIPasteboard.general.string = row.value
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}
