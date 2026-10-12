import SwiftUI
import WormaCeptor

/// Android's `OverviewTab`: Timing (with the request/response timeline), Security and Data Transfer cards.
struct TransactionOverviewTab: View {
    let detail: WormaCeptorTransactionDetail
    let onCopyUrl: () -> Void

    private var isPending: Bool {
        detail.response == nil && detail.error == nil
    }

    /// Android shows the transaction status (ACTIVE, COMPLETED, FAILED).
    private var status: (text: String, tone: WormaCeptorStatusTone) {
        if detail.error != nil { return ("Failed", .error) }
        if isPending { return ("Active", .neutral) }
        return ("Completed", detail.tone)
    }

    private var responseCode: String {
        guard let code = detail.statusCode?.intValue else { return "-" }
        return [String(code), detail.statusMessage].compactMap { $0 }.joined(separator: " ")
    }

    /// Kotlin reports the TLS version only when the client exposes it, so an https URL also counts as secure.
    private var isSecure: Bool {
        detail.tlsVersion != nil || detail.url.lowercased().hasPrefix("https://")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: InspectorTheme.Spacing.lg) {
                timingCard
                InspectorSectionCard("Security", systemImage: "checkmark.shield") {
                    DetailRow(label: "Protocol", value: detail.protocol ?? "Unknown")
                    SecurityBadge(isSecure: isSecure, tlsVersion: detail.tlsVersion)
                }
                InspectorSectionCard("Data Transfer", systemImage: "externaldrive") {
                    let requestSize = detail.request.bodySize
                    let responseSize = detail.response?.bodySize ?? 0
                    VStack(alignment: .leading, spacing: 0) {
                        DetailRow(label: "Request Size", value: OverviewFormat.bytes(requestSize))
                        DetailRow(label: "Response Size", value: OverviewFormat.bytes(responseSize))
                        DetailRow(label: "Total Transfer", value: OverviewFormat.bytes(requestSize + responseSize))
                    }
                }
            }
            .padding(InspectorTheme.Spacing.lg)
        }
    }

    private var timingCard: some View {
        InspectorSectionCard("Timing", systemImage: "clock") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    DetailRow(label: "URL", value: detail.url)
                    DetailCopyButton(label: "Copy URL", action: onCopyUrl)
                        .padding(.top, -InspectorTheme.Spacing.md)
                }
                DetailRow(label: "Method") { InspectorMethodBadge(method: detail.method) }
                DetailRow(label: "Status") {
                    HStack(spacing: InspectorTheme.Spacing.xs) {
                        InspectorBadge(text: status.text, color: InspectorTheme.color(for: status.tone))
                        if detail.isMocked {
                            InspectorBadge(text: "MOCKED", color: InspectorTheme.mocked)
                        }
                    }
                }
                DetailRow(label: "Response Code", value: responseCode)
                DetailRow(label: "Duration", value: InspectorFormat.duration(detail.durationMs) ?? "-")
                DetailRow(label: "Timestamp", value: OverviewFormat.timestamp(detail.timestampMs))
                if let error = detail.error {
                    DetailRow(label: "Error", value: error)
                }
            }
            TransactionTimeline(
                duration: InspectorFormat.duration(detail.durationMs) ?? "0 ms",
                hasResponse: detail.response != nil,
                isPending: isPending
            )
            .padding(.top, InspectorTheme.Spacing.xs)
        }
    }
}

/// Android's `DetailRow`: "Label: value" on one line that wraps, value selectable.
struct DetailRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: () -> Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(label): ")
                .font(InspectorFont.body)
                .foregroundColor(InspectorTheme.secondaryText)
            value()
            Spacer(minLength: 0)
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

extension DetailRow where Value == DetailValueText {
    init(label: String, value: String) {
        self.label = label
        self.value = { DetailValueText(text: value) }
    }
}

struct DetailValueText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(InspectorFont.body)
            .foregroundColor(InspectorTheme.textPrimary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Android's three-phase bar: request, network, response (grey while pending, red when it failed).
private struct TransactionTimeline: View {
    let duration: String
    let hasResponse: Bool
    let isPending: Bool

    private var responseColor: Color {
        if hasResponse { return InspectorTheme.brand.opacity(InspectorTheme.Alpha.heavy) }
        if isPending { return InspectorTheme.secondaryText.opacity(InspectorTheme.Alpha.medium) }
        return InspectorTheme.error.opacity(InspectorTheme.Alpha.strong)
    }

    private var endLabel: String {
        hasResponse ? "Response" : (isPending ? "Pending" : "Failed")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            Text("Request/Response Timeline")
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    InspectorTheme.brand.opacity(InspectorTheme.Alpha.heavy).frame(width: proxy.size.width * 0.3)
                    InspectorTheme.brand.opacity(InspectorTheme.Alpha.intense).frame(width: proxy.size.width * 0.4)
                    responseColor
                }
                .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs))
            }
            .frame(height: InspectorTheme.Spacing.sm)
            HStack {
                Text("Request")
                Spacer()
                Text(duration).fontWeight(.semibold)
                Spacer()
                Text(endLabel)
            }
            .font(InspectorFont.labelSmall)
            .foregroundColor(InspectorTheme.secondaryText)
        }
        .padding(InspectorTheme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surfaceHigh))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timeline: request, \(duration), \(endLabel.lowercased())")
    }
}

/// Android's `SslBadge`: lock and TLS version in brand, or an open lock and "Insecure Connection" in red.
private struct SecurityBadge: View {
    let isSecure: Bool
    let tlsVersion: String?

    var body: some View {
        let color = isSecure ? InspectorTheme.brand : InspectorTheme.error
        HStack(spacing: InspectorTheme.Spacing.xs) {
            Image(systemName: isSecure ? "lock.fill" : "lock.open")
                .font(.system(size: InspectorTheme.IconSize.sm - 2, weight: .semibold))
                .accessibilityHidden(true)
            Text(isSecure ? (tlsVersion ?? "Secure Connection") : "Insecure Connection")
                .font(InspectorFont.label.weight(.semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, InspectorTheme.Spacing.md)
        .padding(.vertical, InspectorTheme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs).fill(color.opacity(InspectorTheme.Alpha.subtle)))
        .overlay(
            RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                .strokeBorder(color.opacity(InspectorTheme.Alpha.moderate), lineWidth: InspectorTheme.Border.regular)
        )
        .padding(.top, InspectorTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSecure ? "Secure, \(tlsVersion ?? "TLS")" : "Insecure connection")
    }
}

enum OverviewFormat {
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func timestamp(_ epochMillis: Int64) -> String {
        timestampFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1000))
    }

    /// Android's formatBytes: "0 B" rather than "Zero KB".
    static func bytes(_ count: Int64) -> String {
        count == 0 ? "0 B" : ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}

#if DEBUG
#Preview("Overview") {
    TransactionOverviewTab(detail: PreviewSamples.detailRich, onCopyUrl: {}).inspectorScreen()
}

#Preview("Overview, failed, dark") {
    TransactionOverviewTab(detail: PreviewSamples.detailFailed, onCopyUrl: {})
        .inspectorScreen()
        .preferredColorScheme(.dark)
}
#endif
