import SwiftUI

/// Android's top-bar search action: a magnifier that turns into a close button. Closing clears the query.
struct InspectorSearchButton: View {
    @Binding var isActive: Bool
    @Binding var text: String

    var body: some View {
        Button {
            withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) {
                isActive.toggle()
                if !isActive { text = "" }
            }
        } label: {
            Image(systemName: isActive ? "xmark" : "magnifyingglass")
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .accessibilityLabel(isActive ? "Close search" : "Search")
    }
}

/// The search field under the top bar that expands in and fades, as on Android.
struct InspectorCollapsibleSearch: View {
    let isActive: Bool
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(spacing: 0) {
            if isActive {
                InspectorSearchField(placeholder: placeholder, text: $text)
                    .padding(.horizontal, InspectorTheme.Spacing.lg)
                    .padding(.vertical, InspectorTheme.Spacing.sm)
                    .transition(InspectorMotion.expand)
            }
        }
        .clipped()
    }
}

/// A two-line principal title, Android's top bar title with a subtitle.
struct InspectorNavigationTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(InspectorFont.titleSmall)
                .foregroundColor(InspectorTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(subtitle)
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Android's top-bar refresh action, a spinner while it runs.
struct InspectorRefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isRefreshing {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .disabled(isRefreshing)
        .accessibilityLabel("Refresh")
    }
}
