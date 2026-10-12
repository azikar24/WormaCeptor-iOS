import SwiftUI

/// Android's `WormaCeptorTextField` (outlined): a label over an 8 pt outlined box that turns brand while focused and
/// error-red when invalid, with optional supporting text below and accessory buttons inside on the right.
struct InspectorTextField<Accessory: View>: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var supporting: String?
    var isError = false
    var isSecure = false
    var monospaced = false
    var multiline = false
    var keyboard: UIKeyboardType = .default
    @ViewBuilder var accessory: () -> Accessory

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            Text(label)
                .font(InspectorFont.label)
                .foregroundColor(isError ? InspectorTheme.error : focused ? InspectorTheme.brand : InspectorTheme.secondaryText)
            HStack(alignment: multiline ? .top : .center, spacing: InspectorTheme.Spacing.xs) {
                field
                    .font(monospaced ? InspectorFont.body.monospaced() : InspectorFont.body)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .focused($focused)
                    .keyboardType(keyboard)
                    .accessibilityLabel(label)
                accessory()
            }
            .padding(.leading, InspectorTheme.Spacing.md)
            .padding(.trailing, InspectorTheme.Spacing.xs)
            .frame(minHeight: multiline ? 96 : InspectorTheme.minTouchTarget + InspectorTheme.Spacing.xs, alignment: multiline ? .top : .center)
            .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.background))
            .overlay(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.md)
                    .strokeBorder(borderColor, lineWidth: focused ? InspectorTheme.Border.thick : InspectorTheme.Border.regular)
            )
            if let supporting {
                Text(supporting)
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(isError ? InspectorTheme.error : InspectorTheme.secondaryText)
            }
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: focused)
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: isError)
    }

    @ViewBuilder private var field: some View {
        if multiline {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .padding(.top, InspectorTheme.Spacing.md)
                        .padding(.leading, InspectorTheme.Spacing.xs)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.vertical, InspectorTheme.Spacing.xs)
                    .frame(minHeight: 88)
                    .clearEditorBackground()
            }
        } else if isSecure {
            SecureField(placeholder, text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } else {
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private var borderColor: Color {
        if isError { return InspectorTheme.error }
        return focused ? InspectorTheme.brand : InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.bold)
    }
}

extension InspectorTextField where Accessory == EmptyView {
    init(
        label: String,
        text: Binding<String>,
        placeholder: String = "",
        supporting: String? = nil,
        isError: Bool = false,
        monospaced: Bool = false,
        multiline: Bool = false,
        keyboard: UIKeyboardType = .default
    ) {
        self.init(
            label: label,
            text: text,
            placeholder: placeholder,
            supporting: supporting,
            isError: isError,
            monospaced: monospaced,
            multiline: multiline,
            keyboard: keyboard,
            accessory: { EmptyView() }
        )
    }
}

private extension View {
    /// TextEditor paints the system background; the outlined box draws its own.
    @ViewBuilder func clearEditorBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            onAppear { UITextView.appearance().backgroundColor = .clear }
        }
    }
}

#Preview("Text fields") {
    struct Demo: View {
        @State var latitude = "40.7128"
        @State var longitude = "200"
        @State var message = ""

        var body: some View {
            VStack(spacing: InspectorTheme.Spacing.md) {
                InspectorTextField(label: "Latitude", text: $latitude, supporting: "Range: -90 to 90")
                InspectorTextField(label: "Longitude", text: $longitude, supporting: "Range: -180 to 180", isError: true)
                InspectorTextField(label: "Message", text: $message, placeholder: "Enter notification message", multiline: true)
            }
            .padding()
        }
    }
    return Demo()
}

extension View {
    /// Scrolling the form hides the keyboard (iOS 16+), and the keyboard gets a Done button, so buttons under it stay
    /// reachable.
    func inspectorDismissesKeyboardOnScroll() -> some View {
        modifier(KeyboardDismissal())
    }
}

private struct KeyboardDismissal: ViewModifier {
    func body(content: Content) -> some View {
        dismissOnScroll(content)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .tint(InspectorTheme.brand)
                }
            }
    }

    @ViewBuilder private func dismissOnScroll(_ content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.immediately)
        } else {
            content
        }
    }
}
