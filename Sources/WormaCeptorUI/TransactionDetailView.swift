import SwiftUI
import UIKit
import WormaCeptor

/// One transaction; follows it live, so an in-flight request fills in when it completes.
struct TransactionDetailScreen: View {
    @StateObject private var model: TransactionDetailModel

    init(id: String) {
        _model = StateObject(wrappedValue: TransactionDetailModel(id: id))
    }

    var body: some View {
        if let detail = model.detail {
            TransactionDetailContent(detail: detail)
        } else if model.isLoaded {
            EmptyStateView(
                systemImage: "questionmark.circle",
                title: "Transaction gone",
                message: "It was cleared after this screen opened."
            )
        } else {
            ProgressView()
        }
    }
}

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case request = "Request"
    case response = "Response"

    var id: String { rawValue }
}

struct TransactionDetailContent: View {
    let detail: WormaCeptorTransactionDetail
    @State private var tab = DetailTab.overview

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(DetailTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, InspectorTheme.Spacing.lg)
            .padding(.vertical, InspectorTheme.Spacing.sm)

            List {
                switch tab {
                case .overview:
                    OverviewSection(detail: detail)
                case .request:
                    MessageSections(message: detail.request)
                case .response:
                    if let response = detail.response {
                        MessageSections(message: response)
                    } else {
                        Text(detail.error == nil ? "Waiting for the response" : "No response")
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("\(detail.method) \(detail.path)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OverviewSection: View {
    let detail: WormaCeptorTransactionDetail

    private var status: String {
        guard let code = detail.statusCode?.intValue else {
            return detail.error == nil ? "In flight" : "Failed"
        }
        return [String(code), detail.statusMessage].compactMap { $0 }.joined(separator: " ")
    }

    var body: some View {
        Section {
            ValueRow(label: "URL", value: detail.url, monospaced: true)
            HStack {
                ValueRow(label: "Status", value: status)
                Spacer()
                if detail.isMocked {
                    InspectorBadge(text: "MOCK", color: InspectorTheme.mocked)
                }
                Circle()
                    .fill(InspectorTheme.color(for: detail.tone))
                    .frame(width: InspectorTheme.Spacing.md, height: InspectorTheme.Spacing.md)
                    .accessibilityHidden(true)
            }
            ValueRow(label: "Method", value: detail.method)
            if let duration = InspectorFormat.duration(detail.durationMs) {
                ValueRow(label: "Duration", value: duration)
            }
            ValueRow(label: "Started", value: InspectorFormat.time(detail.timestampMs))
            if let error = detail.error {
                ValueRow(label: "Error", value: error)
            }
        }
        Section {
            ValueRow(label: "Request body", value: InspectorFormat.bytes(detail.request.bodySize))
            if let response = detail.response {
                ValueRow(label: "Response body", value: InspectorFormat.bytes(response.bodySize))
            }
            if let networkProtocol = detail.protocol {
                ValueRow(label: "Protocol", value: networkProtocol)
            }
            if let tls = detail.tlsVersion {
                ValueRow(label: "TLS", value: tls)
            }
        }
    }
}

private struct MessageSections: View {
    let message: WormaCeptorMessage

    var body: some View {
        Section {
            if message.headers.isEmpty {
                Text("No headers").foregroundColor(InspectorTheme.secondaryText)
            }
            ForEach(Array(message.headers.enumerated()), id: \.offset) { _, header in
                ValueRow(label: header.name, value: header.value, monospaced: true)
            }
        } header: {
            Text("Headers (\(message.headers.count))")
                .foregroundColor(InspectorTheme.secondaryText)
        }
        Section {
            if let body = message.body, !body.isEmpty {
                Text(body)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No body").foregroundColor(InspectorTheme.secondaryText)
            }
        } header: {
            BodyHeader(message: message)
        } footer: {
            if message.isBodyTruncated {
                Text("Showing the first \(WormaCeptorInspectorData.shared.BodyDisplayLimit) characters.")
            }
        }
    }
}

private struct BodyHeader: View {
    let message: WormaCeptorMessage
    @State private var copied = false

    private var summary: String {
        [InspectorFormat.bytes(message.bodySize), message.isJson ? "JSON" : nil].compactMap { $0 }.joined(separator: ", ")
    }

    var body: some View {
        HStack {
            Text("Body")
                .foregroundColor(InspectorTheme.secondaryText)
            Text(summary)
                .font(.footnote)
                .foregroundColor(InspectorTheme.secondaryText)
            Spacer()
            if let body = message.body, !body.isEmpty {
                Button {
                    UIPasteboard.general.string = body
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel(copied ? "Body copied" : "Copy body")
            }
        }
        .textCase(nil)
    }
}

/// A caption over a selectable value.
private struct ValueRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
            Text(label)
                .font(.caption)
                .foregroundColor(InspectorTheme.secondaryText)
            Text(value)
                .font(monospaced ? .system(.footnote, design: .monospaced) : .body)
                .textSelection(.enabled)
        }
        .padding(.vertical, InspectorTheme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Detail") {
    NavigationView {
        TransactionDetailContent(detail: PreviewSamples.detail)
    }
}
#endif
