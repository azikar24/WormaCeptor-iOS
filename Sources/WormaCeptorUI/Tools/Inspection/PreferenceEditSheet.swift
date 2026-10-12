import SwiftUI
import WormaCeptor

/// Android's `PreferenceEditSheet`: a title, the key and type read-only, a value input fitted to the type, then
/// Cancel and a filled Save.
struct PreferenceEditSheet: View {
    let entry: WormaCeptorDefaultsEntry
    let onSave: (PreferenceEdit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var flag: Bool
    @FocusState private var valueFocused: Bool

    init(entry: WormaCeptorDefaultsEntry, onSave: @escaping (PreferenceEdit) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _text = State(initialValue: entry.value)
        _flag = State(initialValue: entry.value == "true")
    }

    /// Nil while the text isn't a valid number for a number entry.
    private var edit: PreferenceEdit? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        switch entry.type {
        case .boolean: return .boolean(flag)
        case .integer: return Int64(trimmed).map(PreferenceEdit.integer)
        case .decimal: return Double(trimmed).map(PreferenceEdit.double)
        default: return .string(text)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                Text("Edit preference")
                    .font(InspectorFont.titleLarge)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                field("Key") {
                    Text(entry.key)
                        .font(InspectorFont.body.monospaced())
                        .foregroundColor(InspectorTheme.secondaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(InspectorTheme.Spacing.md)
                        .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surfaceHigh))
                }
                field("Type") {
                    InspectorBadge(text: entry.type.label, color: PreferenceTypeColor.color(for: entry.type), font: InspectorFont.label)
                }
                valueField
                actions
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
        .inspectorSheetDetents()
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            Text(label)
                .font(InspectorFont.label)
                .foregroundColor(InspectorTheme.secondaryText)
            content()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var valueField: some View {
        switch entry.type {
        case .boolean:
            Toggle(isOn: $flag) {
                Text("Value").font(InspectorFont.body).foregroundColor(InspectorTheme.textPrimary)
            }
            .tint(InspectorTheme.brand)
            .frame(minHeight: InspectorTheme.minTouchTarget)
        case .integer, .decimal:
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                outlined(TextField("Value", text: $text).keyboardType(.numbersAndPunctuation), minHeight: InspectorTheme.minTouchTarget)
                if edit == nil {
                    Text(entry.type == .integer ? "Enter a whole number." : "Enter a number.")
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.error)
                }
            }
        default:
            outlined(TextEditor(text: $text).inspectorHiddenEditorBackground().accessibilityLabel("Value"), minHeight: InspectorTheme.minTouchTarget * 3)
        }
    }

    private func outlined<Field: View>(_ input: Field, minHeight: CGFloat) -> some View {
        input
            .font(InspectorFont.body.monospaced())
            .focused($valueFocused)
            .padding(.horizontal, InspectorTheme.Spacing.md)
            .padding(.vertical, InspectorTheme.Spacing.xs)
            .frame(minHeight: minHeight)
            .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).strokeBorder(
                    edit == nil
                        ? InspectorTheme.error
                        : (valueFocused ? InspectorTheme.brand : InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.bold)),
                    lineWidth: valueFocused ? InspectorTheme.Border.thick : InspectorTheme.Border.regular
                )
            )
            .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: valueFocused)
    }

    private var actions: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            Spacer()
            Button("Cancel") { dismiss() }
                .font(InspectorFont.bodyMedium)
                .foregroundColor(InspectorTheme.brand)
                .padding(.horizontal, InspectorTheme.Spacing.md)
                .frame(minHeight: InspectorTheme.minTouchTarget)
            Button("Save") {
                if let edit {
                    onSave(edit)
                    dismiss()
                }
            }
            .buttonStyle(InspectorFilledButtonStyle())
            .disabled(edit == nil)
            .opacity(edit == nil ? InspectorTheme.Alpha.strong : 1)
        }
    }
}

#if DEBUG
#Preview("Edit a string") {
    PreferenceEditSheet(entry: PreviewSamples.defaultsDomains[0].entries[0]) { _ in }
}

#Preview("Edit a number, dark") {
    PreferenceEditSheet(entry: PreviewSamples.defaultsDomains[0].entries[1]) { _ in }
        .preferredColorScheme(.dark)
}
#endif
