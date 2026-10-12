#if DEBUG
import Foundation
import WormaCeptor

extension PreviewSamples {
    static let cpuHigh = WormaCeptorMetricState(
        metric: .cpu,
        isRunning: true,
        value: 87,
        valueText: "87%",
        tone: .error,
        history: (0..<40).map { KotlinDouble(double: 70 + 15 * sin(Double($0) / 3)) },
        details: [
            WormaCeptorInfoRow(label: "All cores", value: "87%"),
            WormaCeptorInfoRow(label: "One core", value: "522%"),
            WormaCeptorInfoRow(label: "Cores", value: "6"),
        ]
    )

    static let memoryRunning = WormaCeptorMetricState(
        metric: .memory,
        isRunning: true,
        value: 88_000_000,
        valueText: "83.9 MB",
        tone: .success,
        history: (0..<30).map { KotlinDouble(double: 80_000_000 + 8_000_000 * sin(Double($0) / 5)) },
        details: [
            WormaCeptorInfoRow(label: "Footprint", value: "83.9 MB"),
            WormaCeptorInfoRow(label: "Limit", value: "2 GB"),
            WormaCeptorInfoRow(label: "Available", value: "1.92 GB"),
            WormaCeptorInfoRow(label: "Of limit", value: "4%"),
            WormaCeptorInfoRow(label: "Malloc in use", value: "21.4 MB"),
            WormaCeptorInfoRow(label: "Malloc reserved", value: "36 MB"),
        ]
    )

    static let fpsRunning = WormaCeptorMetricState(
        metric: .fps,
        isRunning: true,
        value: 58,
        valueText: "58 fps",
        tone: .success,
        history: (0..<30).map { KotlinDouble(double: $0 % 9 == 0 ? 41 : 59) },
        details: [
            WormaCeptorInfoRow(label: "Average", value: "56 fps"),
            WormaCeptorInfoRow(label: "Min", value: "41 fps"),
            WormaCeptorInfoRow(label: "Max", value: "60 fps"),
            WormaCeptorInfoRow(label: "Dropped frames", value: "12"),
            WormaCeptorInfoRow(label: "Jank frames (over 32 ms)", value: "2"),
        ]
    )

    static let fpsStopped = WormaCeptorMetricState(
        metric: .fps,
        isRunning: false,
        value: 0,
        valueText: "0 fps",
        tone: .neutral,
        history: [],
        details: []
    )
}
#endif
