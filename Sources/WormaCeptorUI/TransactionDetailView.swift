import SwiftUI
import UIKit
import WormaCeptor

/// One transaction; follows it live, so an in-flight request fills in when it completes. Swiping the tab row
/// sideways steps to the previous or next transaction with Android's 250 ms slide.
struct TransactionDetailScreen: View {
    @StateObject private var model: TransactionDetailModel

    init(id: String) {
        _model = StateObject(wrappedValue: TransactionDetailModel(id: id))
    }

    var body: some View {
        ZStack {
            if let detail = model.detail {
                TransactionDetailContent(
                    detail: detail,
                    navigation: TransactionDetailNavigation(
                        canGoNewer: model.canGoNewer,
                        canGoOlder: model.canGoOlder,
                        step: model.step
                    )
                )
                .id(detail.id)
                .transition(slide)
            } else if model.isLoaded {
                InspectorEmptyState(
                    systemImage: "questionmark.circle",
                    title: "Transaction gone",
                    message: "It was cleared after this screen opened."
                )
            } else {
                ProgressView()
            }
        }
        .inspectorScreen()
        .clipped()
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: SlideKey(id: model.detail?.id))
    }

    /// Android's AnimatedContent: the new transaction slides in from the side it was swiped from.
    private var slide: AnyTransition {
        let offset: CGFloat = 100 * CGFloat(model.direction)
        return .asymmetric(
            insertion: .offset(x: offset).combined(with: .opacity),
            removal: .offset(x: -offset).combined(with: .opacity)
        )
    }
}

/// Changes only when one loaded transaction replaces another, so the first load and live updates don't slide.
private struct SlideKey: Equatable {
    let id: String?

    static func == (lhs: SlideKey, rhs: SlideKey) -> Bool {
        lhs.id == nil || rhs.id == nil || lhs.id == rhs.id
    }
}

struct TransactionDetailNavigation {
    let canGoNewer: Bool
    let canGoOlder: Bool
    let step: (Int) -> Void
}

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case request = "Request"
    case response = "Response"

    var id: String { rawValue }
}

struct TransactionDetailContent: View {
    let detail: WormaCeptorTransactionDetail
    var navigation: TransactionDetailNavigation?

    @State private var tab = DetailTab.overview
    @State private var isSearching = false
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var shared: SharedText?
    @State private var toast: String?

    private var currentMessage: WormaCeptorMessage? {
        switch tab {
        case .overview: return nil
        case .request: return detail.request
        case .response: return detail.response
        }
    }

    private var canSearch: Bool {
        guard let message = currentMessage else { return false }
        return !(message.body ?? "").isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorTabRow(tabs: DetailTab.allCases, selection: $tab) { $0.rawValue }
                .simultaneousGesture(swipeBetweenTransactions)
            if isSearching && tab != .overview {
                InspectorSearchField(placeholder: "Search in body…", text: $query)
                    .padding(.horizontal, InspectorTheme.Spacing.lg)
                    .padding(.vertical, InspectorTheme.Spacing.sm)
                    .transition(InspectorMotion.expand)
            }
            InspectorPager(tabs: DetailTab.allCases, selection: $tab) { page($0) }
        }
        .inspectorScreen()
        .navigationTitle(detail.path)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .overlay(alignment: .bottom) { toastView }
        .sheet(item: $shared) { TextShareSheet(text: $0.text) }
        .onChange(of: query) { value in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                if query == value { debouncedQuery = value }
            }
        }
    }

    @ViewBuilder private func page(_ tab: DetailTab) -> some View {
        let searchQuery = isSearching ? debouncedQuery : ""
        switch tab {
        case .overview:
            TransactionOverviewTab(detail: detail) { copy(detail.url, confirmation: "URL copied") }
        case .request:
            TransactionMessageTab(
                message: detail.request, emptyText: "No request data", searchQuery: searchQuery, onCopied: showToast
            )
        case .response:
            if let response = detail.response {
                TransactionMessageTab(
                    message: response, emptyText: "No response data", searchQuery: searchQuery, onCopied: showToast
                )
            } else {
                let isPending = detail.error == nil
                Text(isPending ? "Waiting for response" : "No response received")
                    .font(InspectorFont.body)
                    .foregroundColor(isPending ? InspectorTheme.secondaryText : InspectorTheme.error)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            // Android's TextWithStartEllipsis: long paths keep their end.
            Text(detail.path.isEmpty ? detail.url : detail.path)
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.head)
                .accessibilityAddTraits(.isHeader)
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isSearching {
                Button {
                    withInspectorAnimation(InspectorMotion.standard(InspectorMotion.fast)) { isSearching = false }
                    query = ""
                    debouncedQuery = ""
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close search")
            } else if canSearch {
                Button {
                    withInspectorAnimation(InspectorMotion.standard(InspectorMotion.fast)) { isSearching = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search")
            }
            optionsMenu
        }
    }

    private var optionsMenu: some View {
        let body = (tab == .request ? detail.request.body : detail.response?.body ?? detail.request.body) ?? ""
        return Menu {
            Button {
                copy(detail.url, confirmation: "URL copied")
            } label: {
                Label("Copy URL", systemImage: "link")
            }
            Button {
                copy(body, confirmation: "Body copied")
            } label: {
                Label("Copy body", systemImage: "doc.on.doc")
            }
            .disabled(body.isEmpty)
            Divider()
            Button {
                shared = SharedText(text: TransactionText.summary(detail))
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Options")
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .font(InspectorFont.bodyMedium)
                .foregroundColor(InspectorTheme.background)
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.vertical, InspectorTheme.Spacing.md)
                .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.textPrimary))
                .padding(.bottom, InspectorTheme.Spacing.lg)
                .transition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    /// Android's SwipeableTopBar: swipe left for the next (older) transaction, right for the previous one.
    private var swipeBetweenTransactions: some Gesture {
        DragGesture(minimumDistance: InspectorTheme.Spacing.xl).onEnded { value in
            guard let navigation, abs(value.translation.width) > abs(value.translation.height) * 2,
                  abs(value.translation.width) > InspectorTheme.Spacing.xxxl else { return }
            let delta = value.translation.width < 0 ? 1 : -1
            guard delta > 0 ? navigation.canGoOlder : navigation.canGoNewer else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            navigation.step(delta)
        }
    }

    private func copy(_ text: String, confirmation: String) {
        UIPasteboard.general.string = text
        showToast(confirmation)
    }

    private func showToast(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
        withInspectorAnimation(InspectorMotion.standard(InspectorMotion.fast)) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard toast == message else { return }
            withInspectorAnimation(InspectorMotion.standard(InspectorMotion.fast)) { toast = nil }
        }
    }
}

private struct SharedText: Identifiable {
    let id = UUID()
    let text: String
}

private struct TextShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// The plain-text dump shared from the options menu (Android's "Copy as Text").
enum TransactionText {
    static func summary(_ detail: WormaCeptorTransactionDetail) -> String {
        var lines = ["\(detail.method) \(detail.url)"]
        if let code = detail.statusCode?.intValue {
            lines.append("Status: " + [String(code), detail.statusMessage].compactMap { $0 }.joined(separator: " "))
        }
        if let error = detail.error { lines.append("Error: \(error)") }
        if let duration = InspectorFormat.duration(detail.durationMs) { lines.append("Duration: \(duration)") }
        lines += section("Request", detail.request)
        if let response = detail.response { lines += section("Response", response) }
        return lines.joined(separator: "\n")
    }

    private static func section(_ title: String, _ message: WormaCeptorMessage) -> [String] {
        var lines = ["", "--- \(title) headers ---"] + message.headers.map { "\($0.name): \($0.value)" }
        if let body = message.body, !body.isEmpty {
            lines += ["", "--- \(title) body ---", body]
        }
        return lines
    }
}

#if DEBUG
#Preview("Detail") {
    NavigationView {
        TransactionDetailContent(detail: PreviewSamples.detailRich)
    }
}

#Preview("Detail, dark") {
    NavigationView {
        TransactionDetailContent(detail: PreviewSamples.detail)
    }
    .preferredColorScheme(.dark)
}

#Preview("Detail, failed") {
    NavigationView {
        TransactionDetailContent(detail: PreviewSamples.detailFailed)
    }
}
#endif
