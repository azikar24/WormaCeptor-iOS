import Foundation
import WormaCeptor

/// The numbers behind Android's `MetricsCard`, from the rows the list shows.
struct TransactionMetrics {
    struct Bucket: Equatable {
        let count: Int
        let total: Int
    }

    let total: Int
    /// Percent of finished requests that completed. The core marks 4xx and 5xx failed, so that is 2xx and 3xx here.
    let successRate: Double
    let averageMs: Double
    let fast: Bucket
    let medium: Bucket
    let slow: Bucket
    /// Count per status range, only ranges with requests, in 2xx..5xx order.
    let statusRanges: [(range: StatusRangeFilter, count: Int)]
    /// Count per method, most used first.
    let methods: [(method: String, count: Int)]

    init(rows: [WormaCeptorTransactionRow]) {
        total = rows.count
        let finished = rows.filter { !$0.isInFlight }
        let succeeded = finished.filter { $0.tone == .success || $0.tone == .redirect }.count
        successRate = finished.isEmpty ? 0 : Double(succeeded) / Double(finished.count) * 100
        let durations = finished.compactMap { $0.durationMs?.int64Value }
        averageMs = durations.isEmpty ? 0 : Double(durations.reduce(0, +)) / Double(durations.count)
        fast = Bucket(count: durations.filter { $0 < 100 }.count, total: durations.count)
        medium = Bucket(count: durations.filter { (100...500).contains($0) }.count, total: durations.count)
        slow = Bucket(count: durations.filter { $0 > 500 }.count, total: durations.count)
        statusRanges = StatusRangeFilter.allCases
            .map { range in (range, rows.filter { range.contains($0) }.count) }
            .filter { $0.1 > 0 }
        methods = Dictionary(grouping: rows, by: \.method)
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
    }

    /// Android's `formatDurationAvg`: whole milliseconds under a second, else seconds with two decimals.
    var averageText: String {
        averageMs >= 1000 ? String(format: "%.2fs", averageMs / 1000) : "\(Int(averageMs))ms"
    }

    var successText: String { String(format: "%.1f%%", successRate) }
}
