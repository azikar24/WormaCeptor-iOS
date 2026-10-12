import SwiftUI

/// Android's enable cards (`EnableToggleCard`, `MockLocationStatusCard`): a 48 pt icon well tinted with the status
/// color, a title and status line, and a switch. The whole card toggles; the border takes the color while on.
struct InspectorToggleCard<Detail: View>: View {
    let title: String
    let status: String
    let systemImage: String
    let isOn: Bool
    var onColor: Color = InspectorTheme.brand
    var isEnabled = true
    let onToggle: (Bool) -> Void
    @ViewBuilder var detail: () -> Detail

    init(
        title: String,
        status: String,
        systemImage: String,
        isOn: Bool,
        onColor: Color = InspectorTheme.brand,
        isEnabled: Bool = true,
        onToggle: @escaping (Bool) -> Void,
        @ViewBuilder detail: @escaping () -> Detail = { EmptyView() }
    ) {
        self.title = title
        self.status = status
        self.systemImage = systemImage
        self.isOn = isOn
        self.onColor = onColor
        self.isEnabled = isEnabled
        self.onToggle = onToggle
        self.detail = detail
    }

    var body: some View {
        let statusColor = isOn ? onColor : InspectorTheme.secondaryText
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: Binding(get: { isOn }, set: onToggle)) {
                HStack(spacing: InspectorTheme.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.system(size: InspectorTheme.IconSize.lg, weight: .semibold))
                        .foregroundColor(statusColor)
                        .frame(width: InspectorTheme.Spacing.xxxl, height: InspectorTheme.Spacing.xxxl)
                        .background(
                            RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg)
                                .fill(statusColor.opacity(InspectorTheme.Alpha.light))
                        )
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                        Text(title)
                            .font(InspectorFont.titleMedium)
                            .foregroundColor(InspectorTheme.textPrimary)
                        Text(status)
                            .font(InspectorFont.bodySmall)
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                }
            }
            .tint(onColor)
            .disabled(!isEnabled)
            .padding(InspectorTheme.Spacing.lg)
            detail()
        }
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: isOn
                ? onColor.opacity(InspectorTheme.Alpha.moderate)
                : InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            radius: InspectorTheme.Radius.lg,
            padding: 0
        )
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.page), value: isOn)
    }
}

#Preview("Toggle card") {
    VStack(spacing: InspectorTheme.Spacing.lg) {
        InspectorToggleCard(
            title: "Rate limiting",
            status: "Active, throttling the network",
            systemImage: "speedometer",
            isOn: true,
            onToggle: { _ in }
        )
        InspectorToggleCard(title: "Rate limiting", status: "Off", systemImage: "speedometer", isOn: false, onToggle: { _ in })
        HStack(spacing: InspectorTheme.Spacing.sm) {
            InspectorSummaryCard(value: "2", label: "Critical", color: MiscToolColors.Leak.critical)
            InspectorSummaryCard(value: "0", label: "High", color: InspectorTheme.textPrimary)
        }
    }
    .padding()
}
