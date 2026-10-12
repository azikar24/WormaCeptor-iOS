import SwiftUI

/// Android's `WormaCeptorBadge` (tonal): bold label on its color at 8%, 4 pt corners.
struct InspectorBadge: View {
    let text: String
    let color: Color
    var font: Font = InspectorFont.badge

    var body: some View {
        Text(text)
            .font(font.monospacedDigit())
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, InspectorTheme.Spacing.sm - InspectorTheme.Spacing.xxs)
            .padding(.vertical, InspectorTheme.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                    .fill(color.opacity(InspectorTheme.badgeFillOpacity))
            )
    }
}

/// Android's `WormaCeptorMethodBadge`: the HTTP method in mono, colored per method.
struct InspectorMethodBadge: View {
    let method: String

    var body: some View {
        let color = InspectorTheme.methodColor(method)
        Text(method.uppercased())
            .font(InspectorFont.codeSmall)
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, InspectorTheme.Spacing.xs)
            .padding(.vertical, InspectorTheme.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                    .fill(color.opacity(InspectorTheme.Alpha.light))
            )
            .accessibilityLabel(method)
    }
}

/// The grey count next to a section title (Android's category count chip).
struct InspectorCountChip: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(InspectorFont.labelSmall.monospacedDigit())
            .foregroundColor(InspectorTheme.secondaryText)
            .padding(.horizontal, InspectorTheme.Spacing.xs + InspectorTheme.Spacing.xxs)
            .padding(.vertical, InspectorTheme.Spacing.xxs)
            .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs).fill(InspectorTheme.surfaceHigh))
    }
}

/// A rounded square tinted with `color` holding an icon in that color: tool tiles, card headers, crash rows.
struct InspectorIconWell: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = InspectorTheme.IconSize.xxl
    var iconSize: CGFloat = InspectorTheme.IconSize.md

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundColor(color.opacity(InspectorTheme.Alpha.prominent))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.md)
                    .fill(color.opacity(InspectorTheme.Alpha.light))
            )
            .accessibilityHidden(true)
    }
}

#Preview("Badges") {
    VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
        HStack {
            ForEach(["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"], id: \.self) { InspectorMethodBadge(method: $0) }
        }
        HStack {
            InspectorBadge(text: "200", color: InspectorTheme.color(for: .success))
            InspectorBadge(text: "304", color: InspectorTheme.color(for: .redirect))
            InspectorBadge(text: "404", color: InspectorTheme.color(for: .warning))
            InspectorBadge(text: "500", color: InspectorTheme.color(for: .error))
            InspectorBadge(text: "MOCKED", color: InspectorTheme.mocked)
            InspectorCountChip(count: 8)
        }
        HStack {
            InspectorIconWell(systemImage: "memorychip", color: InspectorCategoryColor.performance)
            InspectorIconWell(systemImage: "folder.fill", color: InspectorCategoryColor.inspection)
        }
    }
    .padding()
}
