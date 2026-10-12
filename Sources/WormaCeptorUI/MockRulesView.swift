import SwiftUI
import WormaCeptor

/// Mock rules: turn them on or off, swipe to delete.
struct MockRulesScreen: View {
    @StateObject private var model = MockRulesModel()

    var body: some View {
        MockRulesContent(rules: model.rules, onToggle: model.setEnabled, onDelete: model.delete)
    }
}

struct MockRulesContent: View {
    let rules: [WormaCeptorMockRuleRow]
    let onToggle: (WormaCeptorMockRuleRow, Bool) -> Void
    let onDelete: (WormaCeptorMockRuleRow) -> Void

    var body: some View {
        List(rules, id: \.id) { rule in
            MockRuleRowView(rule: rule, isEnabled: Binding(get: { rule.enabled }, set: { onToggle(rule, $0) }))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        onDelete(rule)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .listStyle(.plain)
        .overlay {
            if rules.isEmpty {
                EmptyStateView(
                    systemImage: "theatermasks",
                    title: "No mock rules",
                    message: "Create them with the create_mock_rule or mock_from_transaction MCP tools."
                )
            }
        }
        .navigationTitle("Mock rules")
    }
}

struct MockRuleRowView: View {
    let rule: WormaCeptorMockRuleRow
    @Binding var isEnabled: Bool

    private var outcome: String {
        if let error = rule.error { return "Fails with \(error)" }
        return "Responds \(rule.statusCode)"
    }

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                // A generated name is just the method and pattern shown below.
                if !rule.isNameGenerated {
                    Text(rule.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    Text(rule.method ?? "ANY")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                    Text(rule.urlPattern)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(InspectorTheme.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    InspectorBadge(text: outcome, color: InspectorTheme.color(for: rule.tone))
                    Text(rule.matchType.lowercased())
                        .font(.caption)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: InspectorTheme.Spacing.sm)
            Toggle("Enabled", isOn: $isEnabled)
                .labelsHidden()
                .accessibilityLabel("Enable \(rule.name)")
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
    }
}

#if DEBUG
#Preview("Mock rules") {
    NavigationView {
        MockRulesContent(rules: PreviewSamples.rules, onToggle: { _, _ in }, onDelete: { _ in })
    }
}

#Preview("Mock rules, empty") {
    NavigationView {
        MockRulesContent(rules: [], onToggle: { _, _ in }, onDelete: { _ in })
    }
}
#endif
