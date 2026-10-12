import SwiftUI
import UIKit

/// Android's `WormaCeptorDetailRow`: label on the left (40%), medium value on the right, monospaced when long.
struct InspectorDetailRow: View {
    let label: String
    let value: String
    var monospaced: Bool?

    @ScaledMetric(relativeTo: .subheadline) private var labelWidth: CGFloat = 120

    private var usesMonospace: Bool {
        monospaced ?? (value.count > 20)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: InspectorTheme.Spacing.md) {
            Text(label)
                .font(InspectorFont.body)
                .foregroundColor(InspectorTheme.secondaryText)
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .font(usesMonospace ? InspectorFont.bodyMedium.monospaced() : InspectorFont.bodyMedium)
                .foregroundColor(InspectorTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button {
                UIPasteboard.general.string = value
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}

/// Android's `WormaCeptorDetailSection`: a grey title over a filled block of monospaced text.
struct InspectorDetailSection<Content: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        _ title: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(InspectorFont.titleSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                trailing()
            }
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(InspectorTheme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surfaceHigh))
        }
    }
}

/// A value inside `InspectorDetailSection`, monospaced and selectable.
struct InspectorDetailValue: View {
    let text: String
    var color: Color = InspectorTheme.textPrimary

    var body: some View {
        Text(text)
            .font(InspectorFont.code)
            .foregroundColor(color)
            .textSelection(.enabled)
    }
}

/// A small label over a value, for several values in one `InspectorDetailSection`.
struct InspectorDetailItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
            Text(label)
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
            InspectorDetailValue(text: value)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Android's `WormaCeptorDetailHeader`: a large tinted icon tile next to a title and a subtitle.
struct InspectorDetailHeader<Subtitle: View>: View {
    let systemImage: String
    let color: Color
    let title: String
    @ViewBuilder var subtitle: () -> Subtitle

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: InspectorTheme.IconSize.lg - 2, weight: .medium))
                .foregroundColor(color)
                .frame(width: InspectorTheme.Spacing.xxxl, height: InspectorTheme.Spacing.xxxl)
                .background(
                    RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg).fill(color.opacity(InspectorTheme.Alpha.light))
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text(title)
                    .font(InspectorFont.titleMedium)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                subtitle()
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Detail") {
    ScrollView {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
            InspectorDetailHeader(systemImage: "key", color: InspectorTheme.secondaryText, title: "Generic passwords") {
                Text("Encrypted").font(InspectorFont.labelSmall).foregroundColor(InspectorTheme.color(for: .success))
            }
            InspectorDetailSection("Key") { InspectorDetailValue(text: "com.example / token") }
            InspectorDetailSection("Details") {
                InspectorDetailItem(label: "Path", value: "/usr/lib/libc.dylib")
                InspectorDetailItem(label: "Size", value: "1.2 MB")
            }
            InspectorDetailRow(label: "Model", value: "iPhone18,1")
        }
        .padding()
    }
    .inspectorScreen()
}
