import SwiftUI
import UIKit
import WormaCeptor

/// Mock rules, laid out like Android's: a count card, then one card per rule to switch, delete or swipe away.
struct MockRulesScreen: View {
    @StateObject private var model = MockRulesModel()

    var body: some View {
        MockRulesContent(
            rules: model.rules,
            onToggle: model.setEnabled,
            onDelete: model.delete,
            onDeleteAll: model.deleteAll
        )
    }
}

struct MockRulesContent: View {
    let rules: [WormaCeptorMockRuleRow]
    let onToggle: (WormaCeptorMockRuleRow, Bool) -> Void
    let onDelete: (WormaCeptorMockRuleRow) -> Void
    let onDeleteAll: () -> Void

    @State private var isConfirmingDeleteAll = false
    @State private var pendingDelete: WormaCeptorMockRuleRow?

    var body: some View {
        VStack(spacing: 0) {
            // Outside the List: the UI test swipes the first cell, which must be a rule.
            MockRulesSummaryCard(ruleCount: rules.count)
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.vertical, InspectorTheme.Spacing.sm)
            if rules.isEmpty {
                MockRulesEmptyState()
                    .padding(.top, InspectorTheme.Spacing.xxl)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ruleList
            }
        }
        .inspectorScreen()
        .navigationTitle("Mock rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !rules.isEmpty {
                    Button(role: .destructive) {
                        isConfirmingDeleteAll = true
                    } label: {
                        Image(systemName: "trash")
                            .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                    }
                    .accessibilityLabel("Delete all rules")
                }
            }
        }
        .alert("Delete all rules", isPresented: $isConfirmingDeleteAll) {
            Button("Cancel", role: .cancel) {}
            Button("Delete all", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDeleteAll()
            }
        } message: {
            Text("This will permanently remove all \(rules.count) mock rules. This cannot be undone.")
        }
        .alert(
            "Delete rule",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { rule in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDelete(rule)
            }
        } message: { rule in
            Text("Delete \"\(rule.name)\"? This cannot be undone.")
        }
    }

    private var ruleList: some View {
        List {
            ForEach(rules, id: \.id) { rule in
                MockRuleCard(
                    rule: rule,
                    isEnabled: Binding(
                        get: { rule.enabled },
                        set: {
                            UISelectionFeedbackGenerator().selectionChanged()
                            onToggle(rule, $0)
                        }
                    ),
                    onDelete: { pendingDelete = rule }
                )
                .padding(.horizontal, InspectorTheme.Spacing.sm)
                .inspectorCardRow()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        onDelete(rule)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .modifier(HiddenListBackground())
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: rules.map(\.id))
    }
}

/// Android's `EmptyRulesState`: a grey flask, the title and a hint. iOS creates rules over MCP, not with a + button.
private struct MockRulesEmptyState: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: MockRulesSymbols.flask)
                .font(.system(size: InspectorTheme.IconSize.xxl, weight: .medium))
                .foregroundColor(InspectorTheme.secondaryText.opacity(InspectorTheme.Alpha.moderate))
                .frame(height: InspectorTheme.Spacing.xxxl)
                .accessibilityHidden(true)
                .padding(.bottom, InspectorTheme.Spacing.md)
            Text("No mock rules")
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.secondaryText)
                .padding(.bottom, InspectorTheme.Spacing.xs)
            Text("Create them with the create_mock_rule or mock_from_transaction MCP tools.")
                .font(InspectorFont.body)
                .foregroundColor(InspectorTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, InspectorTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

/// Lets the screen background show through a plain `List` (the system background differs in dark mode).
private struct HiddenListBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Mock rules") {
    NavigationView {
        MockRulesContent(rules: PreviewSamples.rules, onToggle: { _, _ in }, onDelete: { _ in }, onDeleteAll: {})
    }
}

#Preview("Mock rules, dark") {
    NavigationView {
        MockRulesContent(rules: PreviewSamples.rules, onToggle: { _, _ in }, onDelete: { _ in }, onDeleteAll: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Mock rules, empty") {
    NavigationView {
        MockRulesContent(rules: [], onToggle: { _, _ in }, onDelete: { _ in }, onDeleteAll: {})
    }
}
#endif
