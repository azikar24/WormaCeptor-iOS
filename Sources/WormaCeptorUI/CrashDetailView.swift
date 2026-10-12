import SwiftUI
import WormaCeptor

final class CrashDetailModel: ObservableObject {
    @Published private(set) var detail: WormaCeptorCrashDetail?
    @Published private(set) var isLoaded = false

    private var subscription: WormaCeptorSubscription?

    init(id: Int64) {
        subscription = WormaCeptorCrashes.shared.observeCrash(id: id) { [weak self] detail in
            self?.detail = detail
            self?.isLoaded = true
        }
    }

    deinit {
        subscription?.cancel()
    }
}

/// One crash, laid out like Android's crash details: exception card, message card, stack trace card.
struct CrashDetailScreen: View {
    @StateObject private var model: CrashDetailModel

    init(id: Int64) {
        _model = StateObject(wrappedValue: CrashDetailModel(id: id))
    }

    var body: some View {
        if let detail = model.detail {
            CrashDetailContent(detail: detail)
        } else if model.isLoaded {
            InspectorEmptyState(
                systemImage: "questionmark.circle",
                title: "Crash not found",
                message: "It was cleared after this screen opened."
            )
            .inspectorScreen()
        } else {
            InspectorSkeletonList(rows: 3, rowHeight: 120).inspectorScreen()
        }
    }
}

struct CrashDetailContent: View {
    let detail: WormaCeptorCrashDetail

    /// Android's shared crash report text.
    private var report: String {
        var lines = [
            "WormaCeptor Crash Report",
            "=======================",
            "",
            "Exception: \(detail.exceptionType)",
            "Time: \(CrashFormat.full(detail.timestampMs))",
        ]
        if let message = detail.message, !message.isEmpty {
            lines += ["", "Message:", message]
        }
        lines += ["", "Stack Trace:", detail.stackTrace]
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CrashExceptionCard(detail: detail)
                    .padding(.bottom, InspectorTheme.Spacing.xl)
                if let message = detail.message, !message.isEmpty {
                    messageCard(message)
                        .padding(.bottom, InspectorTheme.Spacing.lg)
                }
                CrashStackTraceCard(frames: detail.frames, stackTrace: detail.stackTrace)
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
        .navigationTitle("Crash details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if #available(iOS 16.0, *) {
                    ShareLink(item: report, subject: Text("Crash Report: \(detail.exceptionType)")) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                    }
                    .accessibilityLabel("Share crash report")
                } else {
                    CopyButton(text: report, label: "Crash report")
                }
            }
        }
    }

    private func messageCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
            CrashCardHeader(title: "Exception message", copyText: message, copyLabel: "Message")
            Text(message)
                .font(InspectorFont.body)
                .foregroundColor(InspectorTheme.textPrimary)
                .textSelection(.enabled)
        }
        .inspectorCard(padding: InspectorTheme.Spacing.lg)
    }
}

/// Android's `ExceptionInfoCard`: a "CRASH" marker, the exception type large in red, when, and where.
private struct CrashExceptionCard: View {
    let detail: WormaCeptorCrashDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Circle()
                    .fill(InspectorTheme.error)
                    .frame(width: InspectorTheme.Spacing.sm, height: InspectorTheme.Spacing.sm)
                    .accessibilityHidden(true)
                Text("CRASH")
                    .font(InspectorFont.overline)
                    .foregroundColor(InspectorTheme.error)
            }
            .padding(.bottom, InspectorTheme.Spacing.md)
            Text(detail.exceptionType)
                .font(InspectorFont.titleLarge.weight(.bold))
                .foregroundColor(InspectorTheme.error)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, InspectorTheme.Spacing.sm)
            Text(CrashFormat.full(detail.timestampMs))
                .font(InspectorFont.body)
                .foregroundColor(InspectorTheme.secondaryText)
            if let location = detail.location {
                HStack(alignment: .firstTextBaseline, spacing: InspectorTheme.Spacing.xs) {
                    Text("at")
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                    Text(location)
                        .font(InspectorFont.code.weight(.medium))
                        .foregroundColor(InspectorTheme.brand)
                        .textSelection(.enabled)
                }
                .padding(.top, InspectorTheme.Spacing.xs)
                .accessibilityElement(children: .combine)
            }
        }
        .inspectorCard(
            fill: InspectorTheme.error.opacity(InspectorTheme.Alpha.subtle),
            border: InspectorTheme.error.opacity(InspectorTheme.Alpha.moderate),
            padding: InspectorTheme.Spacing.lg
        )
    }
}

#if DEBUG
#Preview("Crash detail") {
    NavigationView {
        CrashDetailContent(detail: PreviewSamples.crashDetail)
    }
}

#Preview("Crash detail, dark") {
    NavigationView {
        CrashDetailContent(detail: PreviewSamples.crashDetail)
    }
    .preferredColorScheme(.dark)
}
#endif
