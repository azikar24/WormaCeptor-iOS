import SwiftUI

/// Android's `ComposeSyntaxColors`. Dark property, string and comment are lifted a step to reach 4.5:1 on the code
/// background.
enum SyntaxColors {
    static let property = InspectorTheme.dynamic(light: 0x871094, dark: 0xA98BC0)
    static let string = InspectorTheme.dynamic(light: 0x067D17, dark: 0x87A878)
    static let number = InspectorTheme.dynamic(light: 0x1750EB, dark: 0x6897BB)
    static let keyword = InspectorTheme.dynamic(light: 0x0033B3, dark: 0xCC7832)
    static let punctuation = InspectorTheme.dynamic(light: 0x000000, dark: 0xA9B7C6)
    static let comment = InspectorTheme.dynamic(light: 0x6B6B6B, dark: 0x959595)
    static let codeBackground = InspectorTheme.dynamic(light: 0xFAFAFA, dark: 0x252526)
    static let searchHighlight = InspectorTheme.dynamic(light: 0xFFF59D, dark: 0x613214)
    static let searchHighlightCurrent = InspectorTheme.dynamic(light: 0x4DD0E1, dark: 0x264F78)
}

/// One visible line of the JSON tree. Collapsing a node drops its children from the list, so the body stays a flat,
/// lazily rendered list however large it is.
struct JsonRow: Identifiable, Equatable {
    enum Kind: Equatable {
        /// `{` or `[` of a non-empty container; `count` is its size, shown when it is collapsed.
        case open(key: String?, isObject: Bool, count: Int, isExpanded: Bool)
        /// An empty container or a scalar, with its trailing comma.
        case value(key: String?, value: JsonValue, isLast: Bool)
        case close(isObject: Bool, isLast: Bool)
    }

    let id: String
    let path: String
    let depth: Int
    let kind: Kind

    static func rows(for root: JsonValue, collapsed: Set<String>) -> [JsonRow] {
        var rows: [JsonRow] = []
        append(root, key: nil, path: "$", depth: 0, isLast: true, collapsed: collapsed, into: &rows)
        return rows
    }

    private static func append(
        _ value: JsonValue,
        key: String?,
        path: String,
        depth: Int,
        isLast: Bool,
        collapsed: Set<String>,
        into rows: inout [JsonRow]
    ) {
        let children: [(String?, JsonValue)]
        let isObject: Bool
        switch value {
        case .object(let members):
            children = members.map { ($0.key, $0.value) }
            isObject = true
        case .array(let items):
            children = items.map { (nil, $0) }
            isObject = false
        default:
            rows.append(JsonRow(id: path, path: path, depth: depth, kind: .value(key: key, value: value, isLast: isLast)))
            return
        }
        guard !children.isEmpty else {
            rows.append(JsonRow(id: path, path: path, depth: depth, kind: .value(key: key, value: value, isLast: isLast)))
            return
        }
        let isExpanded = !collapsed.contains(path)
        rows.append(JsonRow(
            id: path + "{",
            path: path,
            depth: depth,
            kind: .open(key: key, isObject: isObject, count: children.count, isExpanded: isExpanded)
        ))
        guard isExpanded else { return }
        for (index, child) in children.enumerated() {
            append(
                child.1,
                key: child.0,
                path: "\(path).\(index)",
                depth: depth + 1,
                isLast: index == children.count - 1,
                collapsed: collapsed,
                into: &rows
            )
        }
        rows.append(JsonRow(id: path + "}", path: path, depth: depth, kind: .close(isObject: isObject, isLast: isLast)))
    }
}

/// Android's `JsonTreeView` line: 16 pt per level, a chevron on containers that turns 0 to 90 degrees in 150 ms.
struct JsonRowView: View {
    let row: JsonRow
    let onToggle: (String) -> Void

    private static let indent: CGFloat = 16
    private static let chevronWidth: CGFloat = 14

    var body: some View {
        switch row.kind {
        case let .open(key, isObject, count, isExpanded):
            Button {
                onToggle(row.path)
            } label: {
                HStack(spacing: 0) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: InspectorTheme.IconSize.xs - 2, weight: .semibold))
                        .foregroundColor(SyntaxColors.punctuation)
                        .frame(width: Self.chevronWidth)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: isExpanded)
                    Text(openText(key: key, isObject: isObject, count: count, isExpanded: isExpanded))
                        .font(InspectorFont.code)
                    Spacer(minLength: 0)
                }
                .padding(.leading, CGFloat(row.depth) * Self.indent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(key: key, isObject: isObject, count: count))
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        case let .value(key, value, isLast):
            Text(valueText(key: key, value: value, isLast: isLast))
                .font(InspectorFont.code)
                .padding(.leading, CGFloat(row.depth) * Self.indent + Self.chevronWidth)
        case let .close(isObject, isLast):
            Text((isObject ? "}" : "]") + (isLast ? "" : ","))
                .font(InspectorFont.code)
                .foregroundColor(SyntaxColors.punctuation)
                .padding(.leading, CGFloat(row.depth) * Self.indent + Self.chevronWidth)
        }
    }

    private func openText(key: String?, isObject: Bool, count: Int, isExpanded: Bool) -> AttributedString {
        var text = keyText(key)
        text += styled(isObject ? "{" : "[", SyntaxColors.punctuation)
        if !isExpanded {
            let noun = isObject ? (count == 1 ? "key" : "keys") : (count == 1 ? "item" : "items")
            text += styled(" \(count) \(noun) ", SyntaxColors.comment)
            text += styled(isObject ? "}" : "]", SyntaxColors.punctuation)
        }
        return text
    }

    private func valueText(key: String?, value: JsonValue, isLast: Bool) -> AttributedString {
        var text = keyText(key)
        switch value {
        case .string(let string): text += styled(JsonValue.quoted(string), SyntaxColors.string)
        case .number(let number): text += styled(number, SyntaxColors.number)
        case .bool(let bool): text += styled(bool ? "true" : "false", SyntaxColors.keyword)
        case .null: text += styled("null", SyntaxColors.keyword)
        case .object: text += styled("{}", SyntaxColors.punctuation)
        case .array: text += styled("[]", SyntaxColors.punctuation)
        }
        if !isLast { text += styled(",", SyntaxColors.punctuation) }
        return text
    }

    private func keyText(_ key: String?) -> AttributedString {
        guard let key else { return AttributedString() }
        return styled(JsonValue.quoted(key), SyntaxColors.property) + styled(": ", SyntaxColors.punctuation)
    }

    private func styled(_ string: String, _ color: Color) -> AttributedString {
        var text = AttributedString(string)
        text.foregroundColor = color
        return text
    }

    private func accessibilityLabel(key: String?, isObject: Bool, count: Int) -> String {
        let kind = isObject ? "Object, \(count) \(count == 1 ? "key" : "keys")" : "Array, \(count) \(count == 1 ? "item" : "items")"
        return [key, kind].compactMap { $0 }.joined(separator: ", ")
    }
}

#if DEBUG
#Preview("JSON tree") {
    struct Demo: View {
        @State var collapsed: Set<String> = ["$.2"]
        let root = JsonParser.parse(PreviewSamples.jsonBody) ?? .null

        var body: some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    ForEach(JsonRow.rows(for: root, collapsed: collapsed)) { row in
                        JsonRowView(row: row) { path in
                            if collapsed.contains(path) { collapsed.remove(path) } else { collapsed.insert(path) }
                        }
                    }
                }
                .padding(InspectorTheme.Spacing.sm)
                .background(SyntaxColors.codeBackground)
                .padding()
            }
            .inspectorScreen()
        }
    }
    return Demo()
}
#endif
