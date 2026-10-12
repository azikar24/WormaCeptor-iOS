import SwiftUI
import WormaCeptor

/// Live pages, newest first.
@MainActor
final class WebViewPagesModel: ObservableObject {
    @Published private(set) var pages: [WormaCeptorWebViewPage] = []

    private var subscription: WormaCeptorSubscription?

    init() {
        subscription = WormaCeptorWebViews.shared.observePages { [weak self] in self?.pages = $0 }
    }

    deinit {
        subscription?.cancel()
    }
}

/// Pages the app's web views showed and the requests their scripts made.
struct WebViewMonitorScreen: View {
    @StateObject private var model = WebViewPagesModel()

    var body: some View {
        WebViewPagesContent(pages: model.pages, onClear: { WormaCeptorWebViews.shared.clear() })
    }
}

/// Android's monitor list: request stats, a count, then one card per page (iOS groups requests by page).
struct WebViewPagesContent: View {
    let pages: [WormaCeptorWebViewPage]
    let onClear: () -> Void

    @State private var search = ""
    @State private var isSearching = false
    @State private var isConfirmingClear = false

    private var filtered: [WormaCeptorWebViewPage] {
        guard !search.isEmpty else { return pages }
        return pages.filter { page in
            page.url.localizedCaseInsensitiveContains(search)
                || page.requests.contains { $0.url.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorCollapsibleSearch(isActive: isSearching, placeholder: "Page or request URL", text: $search)
            if filtered.isEmpty {
                InspectorEmptyState(
                    systemImage: "globe",
                    title: pages.isEmpty ? "No web view pages" : "No matches",
                    message: pages.isEmpty
                        ? "Pages show up here once WormaCeptorWebViewMonitor.install() runs and the app opens a WKWebView."
                        : "No page or request URL contains \"\(search)\"."
                )
            } else {
                list
            }
        }
        .inspectorScreen()
        .navigationTitle("WebView monitor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                InspectorSearchButton(isActive: $isSearching, text: $search)
                Button(role: .destructive) {
                    isConfirmingClear = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .disabled(pages.isEmpty)
                .accessibilityLabel("Clear pages")
            }
        }
        .confirmationDialog("Clear all pages?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        } message: {
            Text("Pages and their requests are deleted. Web views keep recording.")
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
                WebViewStatsRow(requests: pages.flatMap(\.requests))
                Text(filtered.count == pages.count ? countText(pages.count) : "\(filtered.count) of \(countText(pages.count))")
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                ForEach(filtered, id: \.id) { page in
                    NavigationLink(destination: WebViewPageScreen(pageId: page.id, initial: page)) {
                        WebViewPageRow(page: page)
                    }
                    .buttonStyle(InspectorPressStyle())
                }
            }
            .padding(.horizontal, InspectorTheme.Spacing.lg)
            .padding(.vertical, InspectorTheme.Spacing.sm)
            .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: filtered.map(\.id))
        }
    }

    private func countText(_ count: Int) -> String {
        count == 1 ? "1 page" : "\(count) pages"
    }
}

/// Android's `StatsRow`: total, success, failed and pending counts, colored once non-zero.
private struct WebViewStatsRow: View {
    let requests: [WormaCeptorWebViewRequest]

    var body: some View {
        let failed = requests.filter { !$0.isPending && WebViewFormat.isFailure($0) }.count
        let pending = requests.filter(\.isPending).count
        HStack(spacing: InspectorTheme.Spacing.sm) {
            InspectorSummaryCard(count: requests.count, label: "Total")
            stat(requests.count - failed - pending, "Success", .success)
            stat(failed, "Failed", .error)
            stat(pending, "Pending", .warning)
        }
    }

    private func stat(_ count: Int, _ label: String, _ tone: WormaCeptorStatusTone) -> InspectorSummaryCard {
        InspectorSummaryCard(count: count, label: label, color: count > 0 ? InspectorTheme.color(for: tone) : InspectorTheme.textPrimary)
    }
}

private struct WebViewPageRow: View {
    let page: WormaCeptorWebViewPage

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Text(page.webViewId)
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .padding(.horizontal, InspectorTheme.Spacing.sm)
                    .padding(.vertical, InspectorTheme.Spacing.xxs)
                    .background(Capsule().fill(InspectorTheme.surfaceHigh))
                if page.isLoading {
                    InspectorBadge(text: "LOADING", color: InspectorTheme.color(for: .warning))
                }
                Spacer(minLength: InspectorTheme.Spacing.sm)
                Text(LogsFormat.time(page.startedMs))
                    .font(InspectorFont.labelSmall.monospaced())
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            Text(page.url)
                .font(InspectorFont.listHeadline)
                .foregroundColor(InspectorTheme.brand)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.leading)
            Text(page.requests.count == 1 ? "1 request" : "\(page.requests.count) requests")
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
        }
        .inspectorCard(fill: InspectorTheme.surface)
        .accessibilityElement(children: .combine)
    }
}

/// One page and its requests, live while the page keeps making them.
struct WebViewPageScreen: View {
    let pageId: Int64
    let initial: WormaCeptorWebViewPage
    @StateObject private var model = WebViewPagesModel()

    var body: some View {
        WebViewPageContent(page: model.pages.first { $0.id == pageId } ?? initial)
    }
}

struct WebViewPageContent: View {
    let page: WormaCeptorWebViewPage

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
                InspectorSectionCard("Page", systemImage: "globe") {
                    VStack(alignment: .leading, spacing: 0) {
                        InspectorDetailRow(label: "URL", value: page.url, monospaced: true)
                        InspectorDetailRow(label: "Web view", value: page.webViewId)
                        InspectorDetailRow(label: "Opened", value: LogsFormat.time(page.startedMs))
                        if let finished = page.finishedMs?.int64Value {
                            InspectorDetailRow(label: "Loaded", value: LogsFormat.time(finished))
                        }
                    }
                }
                .padding(.bottom, InspectorTheme.Spacing.sm)
                Text(page.requests.count == 1 ? "1 request" : "\(page.requests.count) requests")
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                if page.requests.isEmpty {
                    InspectorEmptyState(
                        systemImage: "network",
                        title: "No requests",
                        message: "fetch and XMLHttpRequest calls from this page show up here."
                    )
                }
                ForEach(page.requests, id: \.id) { request in
                    NavigationLink(destination: WebViewRequestScreen(request: request)) {
                        WebViewRequestRow(request: request)
                    }
                    .buttonStyle(InspectorPressStyle())
                }
            }
            .padding(InspectorTheme.Spacing.lg)
            .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: page.requests.map(\.id))
        }
        .inspectorScreen()
        .navigationTitle("Page")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum WebViewFormat {
    static func status(_ request: WormaCeptorWebViewRequest) -> String {
        if let code = request.statusCode { return "\(code.int32Value)" }
        return request.error == nil ? "..." : "ERR"
    }

    static func isFailure(_ request: WormaCeptorWebViewRequest) -> Bool {
        request.error != nil || (request.statusCode?.int32Value ?? 0) >= 400
    }

    /// Android's status color: amber pending, the status tone otherwise.
    static func color(_ request: WormaCeptorWebViewRequest) -> Color {
        request.isPending ? InspectorTheme.color(for: .warning) : InspectorTheme.color(for: request.tone)
    }
}

/// Android's `WebViewRequestItem`: a card tinted by status with the method, path in the accent color, a host
/// chip and kind, time and size; the status badge and duration on the right.
private struct WebViewRequestRow: View {
    let request: WormaCeptorWebViewRequest

    var body: some View {
        let statusColor = WebViewFormat.color(request)
        HStack(spacing: InspectorTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    InspectorMethodBadge(method: request.method)
                    Text(request.path.isEmpty ? request.url : request.path)
                        .font(InspectorFont.listHeadline)
                        .foregroundColor(InspectorTheme.brand)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    Text(request.host)
                        .font(InspectorFont.labelSmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .lineLimit(1)
                        .padding(.horizontal, InspectorTheme.Spacing.sm)
                        .padding(.vertical, InspectorTheme.Spacing.xxs)
                        .background(Capsule().fill(InspectorTheme.surfaceHigh))
                    Text(request.kind)
                        .font(InspectorFont.labelSmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                HStack(spacing: InspectorTheme.Spacing.md) {
                    Text(LogsFormat.time(request.timestampMs))
                    if let length = request.contentLength?.int64Value, length > 0 {
                        Text(InspectorFormat.bytes(length))
                    }
                }
                .font(InspectorFont.labelSmall.monospaced())
                .foregroundColor(InspectorTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: InspectorTheme.Spacing.xxs) {
                InspectorBadge(text: WebViewFormat.status(request), color: statusColor)
                if let duration = InspectorFormat.duration(request.durationMs) {
                    Text(duration)
                        .font(InspectorFont.labelSmall.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
        }
        .inspectorCard(
            fill: statusColor.opacity(InspectorTheme.Alpha.subtle),
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium)
        )
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("WebView pages") {
    NavigationView {
        WebViewPagesContent(pages: PreviewSamples.webViewPages, onClear: {})
    }
}

#Preview("WebView pages, dark") {
    NavigationView {
        WebViewPagesContent(pages: PreviewSamples.webViewPages, onClear: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("WebView page") {
    NavigationView {
        WebViewPageContent(page: PreviewSamples.webViewPages[0])
    }
}
#endif
