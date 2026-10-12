import SwiftUI

/// A line the chart draws across its width, like Android's threshold lines.
struct ChartThreshold {
    let value: Double
    let color: Color
}

/// Android's "… Over Time" card: title, a 200 pt chart (or "No data yet"), and a legend.
struct MetricChartCard<Legend: View>: View {
    let title: String
    let values: [Double]
    let range: ClosedRange<Double>
    var thresholds: [ChartThreshold] = []
    let summary: String
    @ViewBuilder var legend: () -> Legend

    static var chartHeight: CGFloat { 200 }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            Text(title)
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Group {
                if values.isEmpty {
                    Text("No data yet")
                        .font(InspectorFont.body)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MetricLineChart(values: values, range: range, thresholds: thresholds)
                        .accessibilityElement()
                        .accessibilityLabel(title)
                        .accessibilityValue(summary)
                }
            }
            .frame(height: Self.chartHeight)
            .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surfaceHigh))
            HStack(spacing: InspectorTheme.Spacing.lg) { legend() }
        }
        .inspectorCard(radius: InspectorTheme.Radius.lg, padding: InspectorTheme.Spacing.lg)
    }
}

/// Android's Canvas chart: four grid bands, threshold lines, the readings as a 2 pt line over a 12% area, spread
/// across the width.
struct MetricLineChart: View {
    let values: [Double]
    let range: ClosedRange<Double>
    var thresholds: [ChartThreshold] = []
    var color: Color = InspectorTheme.brand

    private static let inset = InspectorTheme.Spacing.lg
    private static let gridLines = 4

    var body: some View {
        GeometryReader { proxy in
            let plot = CGRect(origin: .zero, size: proxy.size).insetBy(dx: Self.inset, dy: Self.inset)
            ZStack {
                grid(in: plot).stroke(InspectorTheme.outline.opacity(InspectorTheme.Alpha.moderate), lineWidth: 1)
                ForEach(thresholds.indices, id: \.self) { index in
                    let y = self.y(thresholds[index].value, in: plot)
                    Path { $0.move(to: CGPoint(x: plot.minX, y: y)); $0.addLine(to: CGPoint(x: plot.maxX, y: y)) }
                        .stroke(thresholds[index].color.opacity(InspectorTheme.Alpha.bold), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                }
                if values.count > 1 {
                    area(in: plot).fill(color.opacity(InspectorTheme.Alpha.light))
                    line(in: plot).stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func grid(in plot: CGRect) -> Path {
        Path { path in
            for index in 0...Self.gridLines {
                let y = plot.minY + plot.height / CGFloat(Self.gridLines) * CGFloat(index)
                path.move(to: CGPoint(x: plot.minX, y: y))
                path.addLine(to: CGPoint(x: plot.maxX, y: y))
            }
        }
    }

    private func points(in plot: CGRect) -> [CGPoint] {
        let step = plot.width / CGFloat(max(values.count - 1, 1))
        return values.enumerated().map { index, value in
            CGPoint(x: plot.minX + step * CGFloat(index), y: y(value, in: plot))
        }
    }

    private func y(_ value: Double, in plot: CGRect) -> CGFloat {
        let span = max(range.upperBound - range.lowerBound, .ulpOfOne)
        let fraction = (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / span
        return plot.maxY - plot.height * CGFloat(fraction)
    }

    private func line(in plot: CGRect) -> Path {
        Path { path in path.addLines(points(in: plot)) }
    }

    private func area(in plot: CGRect) -> Path {
        Path { path in
            let points = points(in: plot)
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: plot.maxY))
            // addLines would start a new subpath; the area has to continue from the baseline.
            points.forEach { path.addLine(to: $0) }
            path.addLine(to: CGPoint(x: last.x, y: plot.maxY))
            path.closeSubpath()
        }
    }
}

#if DEBUG
#Preview("Chart") {
    VStack(spacing: InspectorTheme.Spacing.lg) {
        MetricChartCard(
            title: "CPU Usage Over Time",
            values: PreviewSamples.cpu.history.map(\.doubleValue),
            range: 0...100,
            thresholds: [ChartThreshold(value: 50, color: InspectorTheme.warning)],
            summary: "40 samples"
        ) {
            ChartLegendItem(label: "CPU Usage", color: InspectorTheme.brand)
        }
        MetricChartCard(title: "Memory Over Time", values: [], range: 0...1, summary: "") {
            ChartLegendItem(label: "Footprint", color: InspectorTheme.brand)
        }
    }
    .padding()
}

#Preview("Chart dark") {
    MetricChartCard(
        title: "CPU Usage Over Time",
        values: PreviewSamples.cpu.history.map(\.doubleValue),
        range: 0...100,
        summary: "40 samples"
    ) {
        ChartLegendItem(label: "CPU Usage", color: InspectorTheme.brand)
    }
    .padding()
    .inspectorScreen()
    .preferredColorScheme(.dark)
}
#endif
