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

struct WebViewPagesContent: View {
    let pages: [WormaCeptorWebViewPage]
    let onClear: () -> Void

    @State private var search = ""
    @State private var isConfirmingClear = false

    private var filtered: [WormaCeptorWebViewPage] {
        guard !search.isEmpty else { return pages }
        return pages.filter { page in
            page.url.localizedCaseInsensitiveContains(search)
                || page.requests.contains { $0.url.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        List(filtered, id: \.id) { page in
            NavigationLink(destination: WebViewPageScreen(pageId: page.id, initial: page)) {
                WebViewPageRow(page: page)
            }
        }
        .listStyle(.plain)
        .searchable(text: $search, prompt: "Page or request URL")
        .overlay {
            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "globe",
                    title: pages.isEmpty ? "No web view pages" : "No matches",
                    message: pages.isEmpty
                        ? "Pages show up here once WormaCeptorWebViewMonitor.install() runs and the app opens a WKWebView."
                        : "No page or request URL contains \"\(search)\"."
                )
            }
        }
        .navigationTitle("WebView monitor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(role: .destructive) {
                isConfirmingClear = true
            } label: {
                Image(systemName: "trash")
                    .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
            .disabled(pages.isEmpty)
            .accessibilityLabel("Clear pages")
        }
        .confirmationDialog("Clear all pages?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        } message: {
            Text("Pages and their requests are deleted. Web views keep recording.")
        }
    }
}

private struct WebViewPageRow: View {
    let page: WormaCeptorWebViewPage

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Text(page.webViewId)
                    .font(.caption.weight(.semibold))
                if page.isLoading {
                    InspectorBadge(text: "Loading", color: InspectorTheme.color(for: .redirect))
                }
                Text("\(page.requests.count) requests")
                    .font(.caption)
                    .foregroundColor(InspectorTheme.secondaryText)
                Spacer(minLength: InspectorTheme.Spacing.sm)
                Text(LogsFormat.time(page.startedMs))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            Text(page.url)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(.vertical, InspectorTheme.Spacing.xxs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
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
        List {
            Section {
                InfoRowView(row: WormaCeptorInfoRow(label: "URL", value: page.url))
                InfoRowView(row: WormaCeptorInfoRow(label: "Web view", value: page.webViewId))
                InfoRowView(row: WormaCeptorInfoRow(label: "Opened", value: LogsFormat.time(page.startedMs)))
                if let finished = page.finishedMs?.int64Value {
                    InfoRowView(row: WormaCeptorInfoRow(label: "Loaded", value: LogsFormat.time(finished)))
                }
            }
            Section("Requests") {
                ForEach(page.requests, id: \.id) { request in
                    NavigationLink(destination: WebViewRequestScreen(request: request)) {
                        WebViewRequestRow(request: request)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if page.requests.isEmpty {
                EmptyStateView(
                    systemImage: "network",
                    title: "No requests",
                    message: "fetch and XMLHttpRequest calls from this page show up here."
                )
            }
        }
        .navigationTitle("Page")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum WebViewFormat {
    static func status(_ request: WormaCeptorWebViewRequest) -> String {
        if let code = request.statusCode { return "\(code.int32Value)" }
        return request.error == nil ? "..." : "ERR"
    }
}

private struct WebViewRequestRow: View {
    let request: WormaCeptorWebViewRequest

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                InspectorBadge(text: WebViewFormat.status(request), color: InspectorTheme.color(for: request.tone))
                Text(request.method)
                    .font(.caption.weight(.semibold))
                Text(request.kind)
                    .font(.caption)
                    .foregroundColor(InspectorTheme.secondaryText)
                Spacer(minLength: InspectorTheme.Spacing.sm)
                if let duration = InspectorFormat.duration(request.durationMs) {
                    Text(duration)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
            Text(request.path.isEmpty ? request.url : request.path)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
            Text(request.host)
                .font(.caption)
                .foregroundColor(InspectorTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, InspectorTheme.Spacing.xxs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

/// One request: outcome, timing and both header sets.
struct WebViewRequestScreen: View {
    let request: WormaCeptorWebViewRequest

    private var overview: [WormaCeptorInfoRow] {
        [
            WormaCeptorInfoRow(label: "URL", value: request.url),
            WormaCeptorInfoRow(label: "Method", value: request.method),
            WormaCeptorInfoRow(label: "Kind", value: request.kind),
            WormaCeptorInfoRow(label: "Frame", value: request.isMainFrame ? "Main frame" : "Iframe"),
            WormaCeptorInfoRow(label: "Status", value: WebViewFormat.status(request)),
            request.error.map { WormaCeptorInfoRow(label: "Error", value: $0) },
            request.mimeType.map { WormaCeptorInfoRow(label: "Content type", value: $0) },
            request.contentLength.map { WormaCeptorInfoRow(label: "Size", value: InspectorFormat.bytes($0.int64Value)) },
            InspectorFormat.duration(request.durationMs).map { WormaCeptorInfoRow(label: "Duration", value: $0) },
            WormaCeptorInfoRow(label: "Started", value: LogsFormat.time(request.timestampMs)),
        ].compactMap { $0 }
    }

    var body: some View {
        List {
            Section {
                ForEach(overview, id: \.label) { InfoRowView(row: $0) }
            }
            headers("Request headers", request.requestHeaders)
            headers("Response headers", request.responseHeaders)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(request.path.isEmpty ? "Request" : request.path)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func headers(_ title: String, _ rows: [WormaCeptorInfoRow]) -> some View {
        Section(title) {
            if rows.isEmpty {
                Text("None").foregroundColor(InspectorTheme.secondaryText)
            } else {
                ForEach(rows, id: \.label) { InfoRowView(row: $0) }
            }
        }
    }
}

#if DEBUG
#Preview("WebView pages") {
    NavigationView {
        WebViewPagesContent(pages: PreviewSamples.webViewPages, onClear: {})
    }
}

#Preview("WebView page") {
    NavigationView {
        WebViewPageContent(page: PreviewSamples.webViewPages[0])
    }
}

#Preview("WebView request") {
    NavigationView {
        WebViewRequestScreen(request: PreviewSamples.webViewPages[0].requests[0])
    }
}
#endif
