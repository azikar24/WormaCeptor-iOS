import SwiftUI
import WormaCeptor

/// One web view request as Android's detail screen: method, path and status in the top bar, then status, URL,
/// request, header and response cards, and the error if there is one.
struct WebViewRequestScreen: View {
    let request: WormaCeptorWebViewRequest

    var body: some View {
        ScrollView {
            VStack(spacing: InspectorTheme.Spacing.lg) {
                statusCard
                InspectorSectionCard("URL", systemImage: "link") {
                    CopyButton(text: request.url, label: "URL").foregroundColor(InspectorTheme.secondaryText)
                } content: {
                    Text(request.url)
                        .font(InspectorFont.code)
                        .foregroundColor(InspectorTheme.textPrimary)
                        .textSelection(.enabled)
                }
                InspectorSectionCard("Request", systemImage: "doc.text") {
                    rows([
                        ("Method", request.method),
                        ("Kind", request.kind),
                        ("Main frame", request.isMainFrame ? "Yes" : "No"),
                        ("Started", LogsFormat.time(request.timestampMs)),
                    ])
                }
                headers("Request headers", request.requestHeaders)
                if request.statusCode != nil || request.mimeType != nil || request.contentLength != nil {
                    InspectorSectionCard("Response", systemImage: "checkmark.circle") {
                        rows([
                            ("Status code", request.statusCode.map { "\($0.int32Value)" }),
                            ("Content type", request.mimeType),
                            ("Size", request.contentLength.map { InspectorFormat.bytes($0.int64Value) }),
                            ("Duration", InspectorFormat.duration(request.durationMs)),
                        ])
                    }
                }
                headers("Response headers", request.responseHeaders)
                if let error = request.error {
                    errorCard(error)
                }
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { title }
        }
    }

    private var title: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            InspectorMethodBadge(method: request.method)
            VStack(alignment: .leading, spacing: 0) {
                Text(request.path.isEmpty ? "Request" : request.path)
                    .font(InspectorFont.titleSmall)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(request.host)
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .lineLimit(1)
            }
            InspectorBadge(text: WebViewFormat.status(request), color: WebViewFormat.color(request))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var statusCard: some View {
        let failed = WebViewFormat.isFailure(request)
        let title = request.isPending ? "Pending" : (failed ? "Failed" : "Success")
        let icon = request.isPending ? "hourglass" : (failed ? "xmark.octagon" : "checkmark.circle")
        let status = request.statusCode.map { "HTTP \($0.int32Value)" } ?? request.error ?? "Waiting for response"
        return InspectorSectionCard(title, systemImage: icon) {
            rows([("Status", status), ("Duration", InspectorFormat.duration(request.durationMs))])
        }
    }

    private func rows(_ pairs: [(String, String?)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(pairs.compactMap { label, value in value.map { (label, $0) } }, id: \.0) { label, value in
                InspectorDetailRow(label: label, value: value)
            }
        }
    }

    @ViewBuilder private func headers(_ title: String, _ headers: [WormaCeptorInfoRow]) -> some View {
        if !headers.isEmpty {
            InspectorSectionCard("\(title) (\(headers.count))", systemImage: "chevron.left.forwardslash.chevron.right") {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
                    ForEach(headers, id: \.label) { header in
                        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                            Text(header.label)
                                .font(InspectorFont.code.weight(.semibold))
                                .foregroundColor(InspectorTheme.secondaryText)
                            Text(header.value)
                                .font(InspectorFont.code)
                                .foregroundColor(InspectorTheme.textPrimary)
                                .textSelection(.enabled)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func errorCard(_ error: String) -> some View {
        HStack(alignment: .top, spacing: InspectorTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(InspectorTheme.error)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text("Error").font(InspectorFont.titleSmall).foregroundColor(InspectorTheme.error)
                Text(error).font(InspectorFont.code).foregroundColor(InspectorTheme.textPrimary).textSelection(.enabled)
            }
        }
        .inspectorCard(
            fill: InspectorTheme.error.opacity(InspectorTheme.Alpha.subtle),
            border: InspectorTheme.error.opacity(InspectorTheme.Alpha.strong),
            padding: InspectorTheme.Spacing.lg
        )
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("WebView request") {
    NavigationView {
        WebViewRequestScreen(request: PreviewSamples.webViewPages[0].requests[0])
    }
}

#Preview("WebView request failed, dark") {
    NavigationView {
        WebViewRequestScreen(request: PreviewSamples.webViewPages[0].requests[1])
    }
    .preferredColorScheme(.dark)
}
#endif
