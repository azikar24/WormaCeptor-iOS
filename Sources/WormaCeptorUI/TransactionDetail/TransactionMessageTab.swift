import SwiftUI
import UIKit
import WormaCeptor

/// Android's `RequestTab` / `ResponseTab`: collapsible headers with a count, then the body with its content type,
/// pretty/raw toggle and copy button. JSON shows as a collapsible tree; search shows flat text with every hit marked
/// and the current one scrolled to.
struct TransactionMessageTab: View {
    let message: WormaCeptorMessage
    let emptyText: String
    /// Empty when search is closed.
    let searchQuery: String
    let onCopied: (String) -> Void

    @StateObject private var state: MessageBodyState

    init(message: WormaCeptorMessage, emptyText: String, searchQuery: String, onCopied: @escaping (String) -> Void) {
        self.message = message
        self.emptyText = emptyText
        self.searchQuery = searchQuery
        self.onCopied = onCopied
        _state = StateObject(wrappedValue: MessageBodyState(message: message))
    }

    private var headers: [(name: String, value: String)] {
        message.headers.reduce(into: []) { result, header in
            if let last = result.last, last.name == header.name {
                result[result.count - 1].value = last.value + ", " + header.value
            } else {
                result.append((header.name, header.value))
            }
        }
    }

    private var hasBody: Bool {
        !(message.body ?? "").isEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !headers.isEmpty { headersSection }
                    if !headers.isEmpty && hasBody {
                        Color.clear.frame(height: InspectorTheme.Spacing.xl)
                    }
                    if hasBody { bodySection }
                    if headers.isEmpty && !hasBody {
                        Text(emptyText)
                            .font(InspectorFont.body)
                            .foregroundColor(InspectorTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(InspectorTheme.Spacing.lg)
            }
            .onChange(of: state.currentMatch) { _ in scrollToMatch(proxy) }
            .onChange(of: searchQuery) { _ in
                state.currentMatch = 0
                scrollToMatch(proxy)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !searchQuery.isEmpty && hasBody {
                SearchMatchOverlay(
                    matchCount: state.matches(for: searchQuery).count,
                    currentIndex: state.currentMatch,
                    onStep: { state.step($0, query: searchQuery) }
                )
                .padding(.trailing, InspectorTheme.Spacing.lg)
                .padding(.bottom, InspectorTheme.Spacing.xxl)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: searchQuery.isEmpty)
        .onChange(of: message.body) { state.load(body: $0, isJson: message.isJson) }
    }

    @ViewBuilder private var headersSection: some View {
        DetailSectionHeader(title: "Headers", isExpanded: state.headersExpanded, onToggle: {
            withInspectorAnimation(InspectorMotion.standard(InspectorMotion.medium)) { state.headersExpanded.toggle() }
        }) {
            InspectorCountChip(count: headers.count)
            DetailCopyButton(label: "Copy headers") {
                UIPasteboard.general.string = headers.map { "\($0.name): \($0.value)" }.joined(separator: "\n")
                onCopied("Headers copied")
            }
        }
        if state.headersExpanded {
            ForEach(headers, id: \.name) { header in
                DetailRow(label: header.name, value: header.value)
                    .transition(InspectorMotion.expand)
            }
        }
    }

    @ViewBuilder private var bodySection: some View {
        DetailSectionHeader(title: "Body", isExpanded: state.bodyExpanded, onToggle: {
            withInspectorAnimation(InspectorMotion.standard(InspectorMotion.medium)) { state.bodyExpanded.toggle() }
        }) {
            ContentTypeChip(type: BodyContentType(contentType: message.contentType, isJson: message.isJson))
            PrettyRawToggle(isPretty: $state.isPretty)
            DetailCopyButton(label: "Copy body") {
                UIPasteboard.general.string = state.displayedText
                onCopied("Body copied")
            }
        }
        if state.bodyExpanded {
            if state.isPretty && state.json != nil && searchQuery.isEmpty {
                ForEach(state.jsonRows) { row in
                    JsonRowView(row: row, onToggle: state.toggle)
                        .codeLine()
                        .transition(InspectorMotion.expand)
                }
            } else {
                textLines
            }
            if message.isBodyTruncated {
                Text("Showing the first \(WormaCeptorInspectorData.shared.BodyDisplayLimit) characters.")
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .padding(.top, InspectorTheme.Spacing.sm)
            }
        }
    }

    private var textLines: some View {
        let lines = state.lines
        let current = state.matches(for: searchQuery)[safe: state.currentMatch]
        return ForEach(lines.indices, id: \.self) { index in
            Text(highlighted(lines[index], line: index, current: current))
                .font(InspectorFont.code)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .codeLine()
                .id(index)
                .transition(InspectorMotion.expand)
        }
    }

    private func highlighted(_ line: String, line index: Int, current: BodyMatch?) -> AttributedString {
        var text = AttributedString(line)
        text.foregroundColor = InspectorTheme.textPrimary
        for match in state.matches(onLine: index, query: searchQuery) {
            guard let range = Range(match.range, in: text) else { continue }
            text[range].backgroundColor = match == current ? SyntaxColors.searchHighlightCurrent : SyntaxColors.searchHighlight
        }
        return text
    }

    private func scrollToMatch(_ proxy: ScrollViewProxy) {
        guard let match = state.matches(for: searchQuery)[safe: state.currentMatch] else { return }
        withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) {
            proxy.scrollTo(match.line, anchor: .center)
        }
    }
}

private extension View {
    /// A line of the code block: Android's code background behind the JSON tree and body text.
    func codeLine() -> some View {
        padding(.horizontal, InspectorTheme.Spacing.sm)
            .padding(.vertical, InspectorTheme.Spacing.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SyntaxColors.codeBackground)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Android's `TransactionDetailSearchOverlay`: a floating pill with "current/total" and previous/next, or "No matches".
struct SearchMatchOverlay: View {
    let matchCount: Int
    let currentIndex: Int
    let onStep: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            if matchCount > 0 {
                Text("\(currentIndex + 1)/\(matchCount)")
                    .font(InspectorFont.bodyMedium.monospacedDigit())
                    .foregroundColor(InspectorTheme.textPrimary)
                    .padding(.trailing, InspectorTheme.Spacing.xs)
                    .accessibilityLabel("Match \(currentIndex + 1) of \(matchCount)")
                stepButton("chevron.up", label: "Previous match") { onStep(-1) }
                stepButton("chevron.down", label: "Next match") { onStep(1) }
            } else {
                Text("No matches")
                    .font(InspectorFont.bodyMedium)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(minHeight: InspectorTheme.minTouchTarget)
            }
        }
        .padding(.horizontal, InspectorTheme.Spacing.md)
        .background(Capsule().fill(InspectorTheme.surface))
        .overlay(Capsule().strokeBorder(InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.bold), lineWidth: InspectorTheme.Border.thin))
        .shadow(color: .black.opacity(InspectorTheme.Alpha.light), radius: 6, y: 2)
    }

    private func stepButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: InspectorTheme.IconSize.sm, weight: .semibold))
                .foregroundColor(InspectorTheme.textPrimary)
                .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("Response tab") {
    TransactionMessageTab(
        message: PreviewSamples.detailRich.response!,
        emptyText: "No response data",
        searchQuery: "",
        onCopied: { _ in }
    )
    .inspectorScreen()
}

#Preview("Response tab, search") {
    TransactionMessageTab(
        message: PreviewSamples.detailRich.response!,
        emptyText: "No response data",
        searchQuery: "id",
        onCopied: { _ in }
    )
    .inspectorScreen()
}
#endif
