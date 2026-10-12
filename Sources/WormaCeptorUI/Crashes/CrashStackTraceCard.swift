import SwiftUI
import WormaCeptor

/// Android's `StackTraceSection`: app frames first and highlighted, framework frames folded behind a toggle.
struct CrashStackTraceCard: View {
    let frames: [WormaCeptorStackFrame]
    let stackTrace: String

    @State private var showsFrameworkFrames: Bool

    init(frames: [WormaCeptorStackFrame], stackTrace: String) {
        self.frames = frames
        self.stackTrace = stackTrace
        // Nothing to show folded when no frame is the app's own.
        _showsFrameworkFrames = State(initialValue: !frames.contains(where: \.isAppCode))
    }

    /// Compose's `spring(DampingRatioNoBouncy, StiffnessMedium)`.
    private static let expandSpring = Animation.spring(response: 0.16, dampingFraction: 1)

    private var appFrames: [WormaCeptorStackFrame] {
        frames.filter(\.isAppCode)
    }

    private var frameworkFrames: [WormaCeptorStackFrame] {
        frames.filter { !$0.isAppCode }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CrashCardHeader(title: "Stack trace", copyText: stackTrace, copyLabel: "Stack trace")
                .padding(.bottom, InspectorTheme.Spacing.md)
            if !appFrames.isEmpty {
                Text("App code (\(appFrames.count))")
                    .font(InspectorFont.label)
                    .foregroundColor(InspectorTheme.brand)
                    .padding(.bottom, InspectorTheme.Spacing.sm)
                frameList(appFrames, highlighted: true)
            }
            if !frameworkFrames.isEmpty {
                frameworkToggle
                    .padding(.top, appFrames.isEmpty ? 0 : InspectorTheme.Spacing.md)
                if showsFrameworkFrames {
                    frameList(frameworkFrames, highlighted: false)
                        .transition(InspectorMotion.expand)
                }
            }
        }
        .clipped()
        .inspectorCard(padding: InspectorTheme.Spacing.lg)
    }

    private var frameworkToggle: some View {
        Button {
            withInspectorAnimation(Self.expandSpring) { showsFrameworkFrames.toggle() }
        } label: {
            HStack {
                Text("Framework & system (\(frameworkFrames.count))")
                    .font(InspectorFont.label)
                    .foregroundColor(InspectorTheme.secondaryText)
                Spacer(minLength: InspectorTheme.Spacing.sm)
                Image(systemName: "chevron.down")
                    .font(.system(size: InspectorTheme.IconSize.xs + 2, weight: .semibold))
                    .foregroundColor(InspectorTheme.secondaryText)
                    .rotationEffect(.degrees(showsFrameworkFrames ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: InspectorTheme.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(showsFrameworkFrames ? "Expanded" : "Collapsed")
    }

    private func frameList(_ list: [WormaCeptorStackFrame], highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            ForEach(Array(list.enumerated()), id: \.offset) { _, frame in
                CrashFrameRow(frame: frame, highlighted: highlighted)
            }
        }
    }
}

/// One stack line in mono; the `File.swift:12` reference in brand, as Android colors `File.kt:12`.
private struct CrashFrameRow: View {
    let frame: WormaCeptorStackFrame
    let highlighted: Bool

    private static let sourceReference = #"[^/()\s]+\.(kt|swift|m|mm|c|cpp):\d+"#

    private var styledText: AttributedString {
        var text = AttributedString(frame.text)
        text.foregroundColor = highlighted ? InspectorTheme.textPrimary : InspectorTheme.secondaryText
        if let match = frame.text.range(of: Self.sourceReference, options: .regularExpression),
           let range = text.range(of: frame.text[match]) {
            text[range].foregroundColor = InspectorTheme.brand
        }
        return text
    }

    var body: some View {
        Text(styledText)
            .font(highlighted ? InspectorFont.code.weight(.medium) : InspectorFont.code)
            .textSelection(.enabled)
            .padding(.horizontal, InspectorTheme.Spacing.sm)
            .padding(.vertical, InspectorTheme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                    .fill(highlighted ? InspectorTheme.brand.opacity(InspectorTheme.Alpha.light) : .clear)
            )
    }
}

/// A card title with a copy button, as on Android's message and stack trace cards.
struct CrashCardHeader: View {
    let title: String
    let copyText: String
    let copyLabel: String

    var body: some View {
        HStack {
            Text(title)
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: InspectorTheme.Spacing.sm)
            CopyButton(text: copyText, label: copyLabel)
                .foregroundColor(InspectorTheme.secondaryText)
        }
    }
}

#if DEBUG
#Preview("Stack trace") {
    ScrollView {
        CrashStackTraceCard(
            frames: PreviewSamples.crashDetail.frames,
            stackTrace: PreviewSamples.crashDetail.stackTrace
        )
        .padding()
    }
    .inspectorScreen()
}
#endif
