import Foundation
import OSLog
import WormaCeptor

/// Starts log capture with the app's own `Logger` and `os_log` entries included. Kotlin can't read the log store,
/// so this Swift feed adds them; `WormaCeptorLogs.shared.start()` alone captures stdout and stderr only.
///
/// ```swift
/// WormaCeptorLogCapture.start() // at launch, to capture from the beginning
/// ```
public enum WormaCeptorLogCapture {
    /// Starts capture, like the Logs screen's start button. Safe to call more than once.
    public static func start() {
        _ = installFeed
        WormaCeptorLogs.shared.start()
    }

    private static let installFeed: Void = {
        WormaCeptorLogs.shared.addSource(source: OSLogFeed())
    }()
}

/// Polls the process's log store each second for entries newer than the last poll.
final class OSLogFeed: NSObject, WormaCeptorLogSource {
    private static let interval: DispatchTimeInterval = .seconds(1)

    private let queue = DispatchQueue(label: "com.wormadev.wormaceptor.oslog")
    private var store: OSLogStore?
    private var timer: DispatchSourceTimer?
    private var since = Date()
    // Entries at exactly `since`, already forwarded: the next poll starts at that date and sees them again.
    private var seenAtSince = Set<Int>()

    func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            do {
                store = try OSLogStore(scope: .currentProcessIdentifier)
            } catch {
                print("WormaCeptor: os_log capture is off, the log store can't be opened: \(error)")
                return
            }
            since = Date()
            seenAtSince = []
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + Self.interval, repeating: Self.interval)
            timer.setEventHandler { [weak self] in self?.poll() }
            timer.resume()
            self.timer = timer
        }
    }

    func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            store = nil
        }
    }

    private func poll() {
        guard let store else { return }
        let entries: AnySequence<OSLogEntry>
        do {
            entries = try store.getEntries(at: store.position(date: since))
        } catch {
            print("WormaCeptor: os_log capture stopped, reading the log store failed: \(error)")
            stop()
            return
        }
        var newest = since
        var seenAtNewest = seenAtSince
        for case let entry as OSLogEntryLog in entries where entry.date >= since {
            let key = Self.key(entry)
            if entry.date == since, seenAtSince.contains(key) { continue }
            if entry.date > newest {
                newest = entry.date
                seenAtNewest = []
            }
            if entry.date == newest { seenAtNewest.insert(key) }
            WormaCeptorLogs.shared.appendOsLog(entry: WormaCeptorOsLogEntry(
                level: Int32(entry.level.rawValue),
                subsystem: entry.subsystem,
                category: entry.category,
                message: entry.composedMessage,
                timestampMs: Int64(entry.date.timeIntervalSince1970 * 1000),
                threadId: Int64(truncatingIfNeeded: entry.threadIdentifier)
            ))
        }
        since = newest
        seenAtSince = seenAtNewest
    }

    private static func key(_ entry: OSLogEntryLog) -> Int {
        var hasher = Hasher()
        hasher.combine(entry.date)
        hasher.combine(entry.threadIdentifier)
        hasher.combine(entry.composedMessage)
        return hasher.finalize()
    }
}
