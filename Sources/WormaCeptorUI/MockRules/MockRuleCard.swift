import SwiftUI
import UIKit
import WormaCeptor

/// Android's `MockRuleItem`: method + name, match type + URL pattern, the outcome badge, delete and the switch.
struct MockRuleCard: View {
    let rule: WormaCeptorMockRuleRow
    @Binding var isEnabled: Bool
    let onDelete: () -> Void

    /// Android colors 2xx/3xx in the accent and 4xx/5xx or a transport error in the error color.
    private var statusColor: Color {
        if rule.error != nil { return InspectorTheme.error }
        switch rule.statusCode {
        case 200..<400: return InspectorTheme.brand
        case 400..<600: return InspectorTheme.error
        default: return InspectorTheme.secondaryText
        }
    }

    private var outcome: String {
        guard let error = rule.error else { return "\(rule.statusCode)" }
        switch error {
        case "TIMEOUT": return "Timeout"
        case "NO_CONNECTION": return "No connection"
        case "CONNECTION_RESET": return "Connection reset"
        default: return error.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var matchLabel: String {
        rule.matchType.capitalized
    }

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            summary
                .opacity(rule.enabled ? 1 : InspectorTheme.Alpha.bold)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    [rule.method ?? "Any method", rule.name, "\(matchLabel) match", rule.urlPattern, outcome]
                        .joined(separator: ", ")
                )
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: InspectorTheme.Spacing.xxs) {
                InspectorBadge(text: outcome, color: statusColor)
                    .accessibilityHidden(true)
                HStack(spacing: 0) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: InspectorTheme.IconSize.sm))
                            .foregroundColor(InspectorTheme.error.opacity(InspectorTheme.Alpha.heavy))
                            .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete rule")
                    Toggle("Enabled", isOn: $isEnabled)
                        .labelsHidden()
                        .tint(InspectorTheme.brand)
                        .accessibilityLabel("Enable \(rule.name)")
                }
            }
        }
        .padding(InspectorTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: InspectorTheme.Radius.md)
                .fill(
                    rule.enabled
                        ? statusColor.opacity(InspectorTheme.Alpha.subtle)
                        : InspectorTheme.surfaceHigh.opacity(InspectorTheme.Alpha.intense)
                )
        )
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: rule.enabled)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                if let method = rule.method {
                    InspectorMethodBadge(method: method)
                }
                Text(rule.name)
                    .font(InspectorFont.bodyMedium)
                    .foregroundColor(InspectorTheme.brand)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack(spacing: InspectorTheme.Spacing.xs) {
                Text(matchLabel)
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .padding(.horizontal, InspectorTheme.Spacing.sm)
                    .padding(.vertical, InspectorTheme.Spacing.xxs)
                    .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs).fill(InspectorTheme.surfaceHigh))
                Text(rule.urlPattern)
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

/// Android's master toggle card without the switch: iOS has no global mocking switch, so it only counts the rules.
struct MockRulesSummaryCard: View {
    let ruleCount: Int

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.md) {
            Image(systemName: MockRulesSymbols.flask)
                .font(.system(size: InspectorTheme.IconSize.lg, weight: .semibold))
                .foregroundColor(InspectorTheme.brand)
                .frame(width: InspectorTheme.Spacing.xxxl, height: InspectorTheme.Spacing.xxxl)
                .background(
                    RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg)
                        .fill(InspectorTheme.brand.opacity(InspectorTheme.Alpha.light))
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text("Mocking enabled")
                    .font(InspectorFont.titleMedium)
                    .foregroundColor(InspectorTheme.textPrimary)
                // Secondary grey misses 4.5:1 on the teal tint; dimmed primary text keeps it.
                Text("\(ruleCount) rule\(ruleCount == 1 ? "" : "s") configured")
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.textPrimary.opacity(InspectorTheme.Alpha.heavy))
            }
            Spacer(minLength: 0)
        }
        .padding(InspectorTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg)
                .fill(InspectorTheme.brand.opacity(InspectorTheme.Alpha.moderate))
        )
        .accessibilityElement(children: .combine)
    }
}

enum MockRulesSymbols {
    /// Android's Science icon; SF Symbols has the flask from iOS 16.
    static let flask = UIImage(systemName: "flask.fill") != nil ? "flask.fill" : "testtube.2"
}

#if DEBUG
#Preview("Rule cards") {
    VStack(spacing: InspectorTheme.Spacing.sm) {
        MockRulesSummaryCard(ruleCount: PreviewSamples.rules.count)
        ForEach(PreviewSamples.rules, id: \.id) { rule in
            MockRuleCard(rule: rule, isEnabled: .constant(rule.enabled), onDelete: {})
        }
    }
    .padding()
    .inspectorScreen()
}
#endif
