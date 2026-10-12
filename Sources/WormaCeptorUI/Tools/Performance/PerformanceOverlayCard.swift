import SwiftUI

/// Android's `PerformanceOverlayToggle`, under the Performance header on the Tools tab: tap to show or hide the
/// floating overlay. Its own subscription, so the rest of the tab doesn't redraw every second.
struct PerformanceOverlayCard: View {
    @StateObject private var model = PerformanceModel()

    var body: some View {
        PerformanceOverlayCardContent(isShowing: model.state?.isOverlayShowing == true) { show in
            if show { WormaCeptorOverlay.show() } else { WormaCeptorOverlay.hide() }
        }
    }
}

struct PerformanceOverlayCardContent: View {
    let isShowing: Bool
    let onToggle: (Bool) -> Void

    private let accent = InspectorCategoryColor.performance

    var body: some View {
        Button {
            onToggle(!isShowing)
        } label: {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Image(systemName: "speedometer")
                    .font(.system(size: InspectorTheme.IconSize.md - 2, weight: .semibold))
                    .foregroundColor(accent.opacity(isShowing ? 1 : InspectorTheme.Alpha.heavy))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: InspectorTheme.Radius.md)
                            .fill(accent.opacity(isShowing ? InspectorTheme.Alpha.medium : InspectorTheme.Alpha.soft))
                    )
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    Text("Performance Overlay")
                        .font(InspectorFont.bodyMedium)
                        .foregroundColor(InspectorTheme.textPrimary)
                    Text(isShowing ? "Showing CPU, Memory, FPS" : "Tap to enable floating widget")
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                Spacer(minLength: 0)
                Text(isShowing ? "ON" : "OFF")
                    .font(InspectorFont.badge)
                    .foregroundColor(isShowing ? InspectorTheme.warning : InspectorTheme.secondaryText)
                    .padding(.horizontal, InspectorTheme.Spacing.sm)
                    .padding(.vertical, InspectorTheme.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: InspectorTheme.Radius.sm)
                            .fill(isShowing ? accent.opacity(InspectorTheme.Alpha.medium) : InspectorTheme.surfaceHigh)
                    )
            }
            .padding(InspectorTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg)
                    .fill(isShowing ? accent.opacity(InspectorTheme.Alpha.soft) : InspectorTheme.surfaceHigh.opacity(InspectorTheme.Alpha.bold))
            )
            .overlay(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg)
                    .strokeBorder(
                        isShowing ? accent.opacity(InspectorTheme.Alpha.strong) : InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
                        lineWidth: InspectorTheme.Border.regular
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg))
        }
        .buttonStyle(InspectorPressStyle())
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: isShowing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Performance Overlay")
        .accessibilityValue(isShowing ? "On" : "Off")
        .accessibilityHint("CPU, memory and FPS above the app. Tap the overlay to open WormaCeptor.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Overlay card") {
    VStack(spacing: InspectorTheme.Spacing.md) {
        PerformanceOverlayCardContent(isShowing: false) { _ in }
        PerformanceOverlayCardContent(isShowing: true) { _ in }
    }
    .padding()
}

#Preview("Overlay card dark") {
    VStack(spacing: InspectorTheme.Spacing.md) {
        PerformanceOverlayCardContent(isShowing: false) { _ in }
        PerformanceOverlayCardContent(isShowing: true) { _ in }
    }
    .padding()
    .inspectorScreen()
    .preferredColorScheme(.dark)
}
