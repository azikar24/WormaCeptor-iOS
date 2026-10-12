import SwiftUI
import WormaCeptor

/// One search hit: the line it is on and where in that line.
struct BodyMatch: Equatable {
    let line: Int
    let range: Range<String.Index>
}

/// What the Request or Response tab shows of one message: the body split into lines (pretty and raw), the parsed JSON
/// tree with its collapsed nodes, section expansion, and search hits. Parsing and splitting run once per body.
final class MessageBodyState: ObservableObject {
    @Published var isPretty = true {
        didSet { if isPretty != oldValue { currentMatch = 0 } }
    }
    @Published var headersExpanded = true
    @Published var bodyExpanded = true
    @Published var currentMatch = 0
    @Published private(set) var jsonRows: [JsonRow] = []

    private(set) var json: JsonValue?
    private var body = ""
    private var prettyLines: [String] = []
    private var rawLines: [String]?
    private var collapsed: Set<String> = []
    private var searchCache: (query: String, isPretty: Bool, matches: [BodyMatch], byLine: [Int: [BodyMatch]])?

    init(message: WormaCeptorMessage?) {
        load(body: message?.body, isJson: message?.isJson ?? false)
    }

    func load(body newBody: String?, isJson: Bool) {
        let text = newBody ?? ""
        guard text != body || (prettyLines.isEmpty && !text.isEmpty) else { return }
        body = text
        json = isJson ? JsonParser.parse(text) : nil
        prettyLines = text.isEmpty ? [] : text.components(separatedBy: "\n")
        rawLines = nil
        searchCache = nil
        jsonRows = json.map { JsonRow.rows(for: $0, collapsed: collapsed) } ?? []
    }

    /// The lines on screen in text mode: the stored body when pretty, single-line JSON when raw.
    var lines: [String] {
        if isPretty || json == nil { return prettyLines }
        if let rawLines { return rawLines }
        let lines = json.map { [$0.compact] } ?? prettyLines
        rawLines = lines
        return lines
    }

    var displayedText: String {
        lines.joined(separator: "\n")
    }

    func toggle(_ path: String) {
        guard let json else { return }
        if collapsed.contains(path) {
            collapsed.remove(path)
        } else {
            collapsed.insert(path)
        }
        withInspectorAnimation(InspectorMotion.standard(InspectorMotion.fast)) {
            jsonRows = JsonRow.rows(for: json, collapsed: collapsed)
        }
    }

    /// Case-insensitive hits of `query` in the shown lines, like Android's `findMatchRanges`.
    func matches(for query: String) -> [BodyMatch] {
        search(query).matches
    }

    func matches(onLine line: Int, query: String) -> [BodyMatch] {
        search(query).byLine[line] ?? []
    }

    func step(_ delta: Int, query: String) {
        let count = matches(for: query).count
        guard count > 0 else { return }
        currentMatch = (currentMatch + delta + count) % count
    }

    private func search(_ query: String) -> (matches: [BodyMatch], byLine: [Int: [BodyMatch]]) {
        if let cache = searchCache, cache.query == query, cache.isPretty == isPretty {
            return (cache.matches, cache.byLine)
        }
        var matches: [BodyMatch] = []
        if !query.isEmpty {
            for (index, line) in lines.enumerated() {
                var start = line.startIndex
                while let found = line.range(of: query, options: .caseInsensitive, range: start..<line.endIndex) {
                    matches.append(BodyMatch(line: index, range: found))
                    start = line.index(after: found.lowerBound)
                }
            }
        }
        let byLine = Dictionary(grouping: matches, by: \.line)
        searchCache = (query, isPretty, matches, byLine)
        return (matches, byLine)
    }
}
