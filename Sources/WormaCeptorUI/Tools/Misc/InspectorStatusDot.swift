import SwiftUI

/// Android's `WormaCeptorStatusDot`: a plain colored dot.
struct InspectorStatusDot: View {
    let color: Color
    var size: CGFloat = InspectorTheme.Spacing.sm

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Android's `WormaCeptorMonitoringIndicator`: a dot that pulses between full and half alpha every 500 ms while
/// active and holds still when idle or with Reduce Motion on.
struct InspectorMonitoringIndicator: View {
    let isActive: Bool
    var activeColor: Color = InspectorTheme.brand
    var inactiveColor: Color = InspectorTheme.outline

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(isActive ? activeColor : inactiveColor)
            .frame(width: InspectorTheme.Spacing.sm, height: InspectorTheme.Spacing.sm)
            .opacity(isActive && dimmed ? InspectorTheme.Alpha.bold : 1)
            .inspectorAnimation(InspectorMotion.standard(InspectorMotion.slow), value: isActive)
            .onAppear(perform: updatePulse)
            .onChange(of: isActive) { _ in updatePulse() }
            .accessibilityHidden(true)
    }

    private func updatePulse() {
        guard isActive, !reduceMotion else {
            dimmed = false
            return
        }
        withAnimation(InspectorMotion.standard(InspectorMotion.verySlow).repeatForever(autoreverses: true)) {
            dimmed = true
        }
    }
}

/// A navigation bar title with Android's monitoring dot after it (`WormaCeptorTopBar` `titleTrailing`).
struct InspectorMonitoringTitle: View {
    let title: String
    let isActive: Bool
    var activeColor: Color = MiscToolColors.monitoring
    var inactiveColor: Color = MiscToolColors.idle

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundColor(InspectorTheme.textPrimary)
            InspectorMonitoringIndicator(isActive: isActive, activeColor: activeColor, inactiveColor: inactiveColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "Monitoring" : "Stopped")
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Status dots") {
    VStack(spacing: InspectorTheme.Spacing.lg) {
        HStack {
            InspectorStatusDot(color: MiscToolColors.WebSocket.open)
            InspectorStatusDot(color: MiscToolColors.WebSocket.closed, size: InspectorTheme.Spacing.md)
        }
        InspectorMonitoringTitle(title: "Leaks", isActive: true)
        InspectorMonitoringTitle(title: "Main thread hangs", isActive: false)
    }
    .padding()
}
