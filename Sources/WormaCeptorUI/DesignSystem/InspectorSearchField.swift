import SwiftUI

/// Android's `WormaCeptorSearchBar`: outlined field, 8 pt corners, brand border while focused, clear button fades in.
struct InspectorSearchField: View {
    let placeholder: String
    @Binding var text: String

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(InspectorTheme.secondaryText)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .font(InspectorFont.body)
                .focused($focused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(InspectorTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, InspectorTheme.Spacing.md)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).strokeBorder(
                focused ? InspectorTheme.brand : InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.bold),
                lineWidth: focused ? InspectorTheme.Border.thick : InspectorTheme.Border.regular
            )
        )
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: focused)
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: text.isEmpty)
    }
}

#Preview("Search") {
    struct Demo: View {
        @State var text = ""

        var body: some View {
            InspectorSearchField(placeholder: "Search URL or method", text: $text).padding()
        }
    }
    return Demo()
}
