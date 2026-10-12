import SwiftUI

/// Android's `WormaCeptorMonitoringStatusBar`: a dot that pulses while sampling, Monitoring or Paused, and the sample
/// count.
struct MonitoringStatusBar: View {
    let isMonitoring: Bool
    let sampleCount: Int

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            MonitoringDot(isActive: isMonitoring)
            Text(isMonitoring ? "Monitoring" : "Paused")
                .font(InspectorFont.label)
                .foregroundColor(InspectorTheme.secondaryText)
            Spacer(minLength: 0)
            Text("\(sampleCount) samples")
                .font(InspectorFont.code)
                .foregroundColor(InspectorTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Android's `WormaCeptorMonitoringIndicator`: brand while active, fading to half and back every 500 ms.
struct MonitoringDot: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? InspectorTheme.brand : InspectorTheme.outline)
            .frame(width: InspectorTheme.Spacing.sm, height: InspectorTheme.Spacing.sm)
            .inspectorAnimation(InspectorMotion.standard(InspectorMotion.slow), value: isActive)
            .modifier(Pulse(isOn: isActive))
            .accessibilityHidden(true)
    }
}

/// Fades the content between full and half opacity every 500 ms while `isOn`, unless Reduce Motion is on.
struct Pulse: ViewModifier {
    let isOn: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? InspectorTheme.Alpha.bold : 1)
            .onAppear(perform: update)
            .onChange(of: isOn) { _ in update() }
    }

    private func update() {
        guard isOn, !reduceMotion else {
            withAnimation(nil) { dimmed = false }
            return
        }
        withAnimation(InspectorMotion.standard(InspectorMotion.verySlow).repeatForever(autoreverses: true)) {
            dimmed = true
        }
    }
}

/// Android's `WormaCeptorWarningBadge`: a pulsing warning sign next to the screen title.
struct WarningBadge: View {
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: InspectorTheme.IconSize.xs, weight: .bold))
            .foregroundColor(.white)
            .padding(InspectorTheme.Spacing.xs + 1)
            .background(Circle().fill(InspectorTheme.error))
            .modifier(Pulse(isOn: true))
            .accessibilityLabel("Usage is high")
    }
}

/// The red "HIGH" chip on Android's heap and CPU cards.
struct HighUsageBadge: View {
    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: InspectorTheme.IconSize.xs))
            Text("HIGH").font(InspectorFont.badge)
        }
        .foregroundColor(InspectorTheme.color(for: .error))
        .padding(.horizontal, InspectorTheme.Spacing.sm)
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: InspectorTheme.Radius.md)
                .fill(InspectorTheme.color(for: .error).opacity(InspectorTheme.Alpha.light))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("High usage")
    }
}

/// Android's `WormaCeptorChartLegendItem`: a 12 pt dot and a label.
struct ChartLegendItem: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.xs) {
            Circle().fill(color).frame(width: InspectorTheme.Spacing.md, height: InspectorTheme.Spacing.md)
            Text(label)
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
        }
    }
}

#Preview("Indicators") {
    VStack(spacing: InspectorTheme.Spacing.lg) {
        MonitoringStatusBar(isMonitoring: true, sampleCount: 42)
        MonitoringStatusBar(isMonitoring: false, sampleCount: 0)
        HStack {
            WarningBadge()
            HighUsageBadge()
            ChartLegendItem(label: "CPU Usage", color: InspectorTheme.brand)
        }
    }
    .padding()
}

#Preview("Indicators dark") {
    VStack(spacing: InspectorTheme.Spacing.lg) {
        MonitoringStatusBar(isMonitoring: true, sampleCount: 42)
        HStack {
            WarningBadge()
            HighUsageBadge()
        }
    }
    .padding()
    .inspectorScreen()
    .preferredColorScheme(.dark)
}
