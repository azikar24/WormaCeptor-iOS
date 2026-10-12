import SwiftUI

/// Android's body content types, detected from the Content-Type header.
enum BodyContentType {
    case json, xml, html, protobuf, formData, multipart, plainText, binary, pdf, image, unknown

    init(contentType: String?, isJson: Bool) {
        let type = contentType?.lowercased() ?? ""
        switch true {
        case isJson || type.contains("json"): self = .json
        case type.contains("html"): self = .html
        case type.contains("xml"): self = .xml
        case type.contains("protobuf"): self = .protobuf
        case type.contains("x-www-form-urlencoded"): self = .formData
        case type.contains("multipart"): self = .multipart
        case type.hasPrefix("image/"): self = .image
        case type.contains("pdf"): self = .pdf
        case type.contains("octet-stream"): self = .binary
        case type.isEmpty || type.hasPrefix("text/"): self = .plainText
        default: self = .unknown
        }
    }

    var title: String {
        switch self {
        case .json: return "JSON"
        case .xml: return "XML"
        case .html: return "HTML"
        case .protobuf: return "Protobuf"
        case .formData: return "Form Data"
        case .multipart: return "Multipart"
        case .plainText: return "Plain Text"
        case .binary: return "Binary"
        case .pdf: return "PDF"
        case .image: return "Image"
        case .unknown: return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .json: return "curlybraces"
        case .xml: return "chevron.left.forwardslash.chevron.right"
        case .html: return "globe"
        case .protobuf, .binary: return "square.stack.3d.up"
        case .formData: return "list.bullet"
        case .multipart: return "doc.on.doc"
        case .plainText: return "textformat"
        case .pdf: return "doc.richtext"
        case .image: return "photo"
        case .unknown: return "questionmark"
        }
    }

    /// Android's `FeatureColors.ContentType` hues in shades that reach 4.5:1 as text.
    var color: Color {
        switch self {
        case .json: return InspectorTheme.warning
        case .xml: return InspectorTheme.dynamic(light: 0x6D28D9, dark: 0xA78BFA)
        case .html: return InspectorTheme.dynamic(light: 0xBE185D, dark: 0xF472B6)
        case .protobuf: return InspectorTheme.dynamic(light: 0x047857, dark: 0x34D399)
        case .formData: return InspectorTheme.dynamic(light: 0x1D4ED8, dark: 0x60A5FA)
        case .multipart: return InspectorTheme.dynamic(light: 0x4338CA, dark: 0x818CF8)
        case .binary, .pdf: return InspectorTheme.error
        case .image: return InspectorTheme.brand
        case .plainText, .unknown: return InspectorTheme.secondaryText
        }
    }
}

/// Android's `ContentTypeChip`: icon and name on the type's color at 12%, hairline border.
struct ContentTypeChip: View {
    let type: BodyContentType

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.xs) {
            Image(systemName: type.systemImage)
                .font(.system(size: InspectorTheme.IconSize.xs - 2, weight: .semibold))
                .accessibilityHidden(true)
            Text(type.title)
                .font(InspectorFont.labelSmall.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundColor(type.color)
        .padding(.horizontal, InspectorTheme.Spacing.sm)
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs).fill(type.color.opacity(InspectorTheme.Alpha.light)))
        .overlay(
            RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                .strokeBorder(type.color.opacity(InspectorTheme.Alpha.moderate), lineWidth: InspectorTheme.Border.thin)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Content type \(type.title)")
    }
}

/// Android's `PrettyRawToggle`: two segments whose fill and text color fade over 250 ms.
struct PrettyRawToggle: View {
    @Binding var isPretty: Bool

    var body: some View {
        HStack(spacing: 0) {
            segment("Pretty", selected: isPretty)
            segment("Raw", selected: !isPretty)
        }
        .clipShape(RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs))
        .overlay(
            RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                .strokeBorder(InspectorTheme.brand.opacity(InspectorTheme.Alpha.moderate), lineWidth: InspectorTheme.Border.thin)
        )
        .accessibilityHidden(true)
        // The pill stays Android-small; the tap areas grow to 44 pt around it.
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .overlay {
            HStack(spacing: 0) {
                tapArea("Pretty", selected: isPretty) { isPretty = true }
                tapArea("Raw", selected: !isPretty) { isPretty = false }
            }
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: isPretty)
    }

    private func segment(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(selected ? InspectorFont.labelSmall.weight(.semibold) : InspectorFont.labelSmall.weight(.regular))
            .foregroundColor(selected ? InspectorTheme.brand : InspectorTheme.secondaryText)
            .padding(.horizontal, InspectorTheme.Spacing.sm)
            .padding(.vertical, InspectorTheme.Spacing.xs)
            .background(selected ? InspectorTheme.brand.opacity(InspectorTheme.Alpha.light) : Color.clear)
    }

    private func tapArea(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Android's `CollapsibleSection` header: a chevron that turns as the section opens, the title, optional trailing
/// controls. The caller shows the content below it with `InspectorMotion.expand`.
struct DetailSectionHeader<Trailing: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.xs) {
            Button(action: onToggle) {
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: InspectorTheme.IconSize.xs, weight: .semibold))
                        .foregroundColor(InspectorTheme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.medium), value: isExpanded)
                    Text(title)
                        .font(InspectorFont.titleSmall)
                        .foregroundColor(InspectorTheme.textPrimary)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: InspectorTheme.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityAddTraits(.isHeader)
            trailing()
        }
    }
}

/// The copy icon in a section header, labelled for VoiceOver and UI tests.
struct DetailCopyButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: InspectorTheme.IconSize.sm))
                .foregroundColor(InspectorTheme.secondaryText)
                .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("Body controls") {
    struct Demo: View {
        @State var pretty = true

        var body: some View {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
                DetailSectionHeader(title: "Body", isExpanded: true, onToggle: {}) {
                    ContentTypeChip(type: .json)
                    PrettyRawToggle(isPretty: $pretty)
                    DetailCopyButton(label: "Copy body") {}
                }
                HStack {
                    ForEach([BodyContentType.xml, .html, .formData, .image, .plainText], id: \.self) { ContentTypeChip(type: $0) }
                }
            }
            .padding()
            .inspectorScreen()
        }
    }
    return Demo()
}
#endif
