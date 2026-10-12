import SwiftUI
import WormaCeptor

/// Loads a snapshot of label/value sections on appear and on pull to refresh.
@MainActor
final class InfoSectionsModel: ObservableObject {
    @Published private(set) var sections: [WormaCeptorInfoSection] = []
    @Published private(set) var error: String?
    @Published private(set) var isLoaded = false
    @Published private(set) var loadedAt: Date?

    private let load: () async throws -> [WormaCeptorInfoSection]

    init(load: @escaping () async throws -> [WormaCeptorInfoSection]) {
        self.load = load
    }

    func refresh() async {
        do {
            sections = try await load()
            loadedAt = Date()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoaded = true
    }
}

/// Android's info cards: one outlined card per section with an icon, a copy action and label/value rows.
/// `extras` adds content under a section's rows (the device info usage bars).
struct InfoSectionsContent<Extras: View>: View {
    let sections: [WormaCeptorInfoSection]
    var footer: String?
    let systemImage: (String) -> String
    @ViewBuilder let extras: (WormaCeptorInfoSection) -> Extras

    var body: some View {
        ScrollView {
            VStack(spacing: InspectorTheme.Spacing.lg) {
                ForEach(sections, id: \.title) { section in
                    InspectorSectionCard(section.title, systemImage: systemImage(section.title)) {
                        CopyButton(text: InfoSectionsFormat.text(section), label: section.title)
                            .foregroundColor(InspectorTheme.secondaryText)
                    } content: {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(section.rows, id: \.label) { row in
                                InspectorDetailRow(label: row.label, value: row.value)
                            }
                            extras(section)
                        }
                    }
                }
                if let footer {
                    Text(footer)
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .padding(.top, InspectorTheme.Spacing.sm)
                }
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
    }
}

extension InfoSectionsContent where Extras == EmptyView {
    init(sections: [WormaCeptorInfoSection], footer: String? = nil, systemImage: @escaping (String) -> String = { _ in "info.circle" }) {
        self.init(sections: sections, footer: footer, systemImage: systemImage) { _ in EmptyView() }
    }
}

enum InfoSectionsFormat {
    /// "Title\nLabel: value" lines, what the copy actions put on the pasteboard.
    static func text(_ section: WormaCeptorInfoSection) -> String {
        ([section.title] + section.rows.map { "\($0.label): \($0.value)" }).joined(separator: "\n")
    }
}

/// A label/value line for stock `List` sections (other tools still use it).
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
