import SwiftUI

/// Android's `WormaCeptorEmptyState`: an icon in two brand-tinted circles that pulse, a title, a hint, and an
/// optional action.
struct InspectorEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: InspectorTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(InspectorTheme.brand.opacity(pulseAlpha * 0.2))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(InspectorTheme.brand.opacity(pulseAlpha * 0.3))
                    .frame(width: 80, height: 80)
                Image(systemName: systemImage)
                    .font(.system(size: InspectorTheme.IconSize.xl, weight: .medium))
                    .foregroundColor(InspectorTheme.brand)
            }
            .accessibilityHidden(true)
            VStack(spacing: InspectorTheme.Spacing.sm) {
                Text(title)
                    .font(InspectorFont.headline)
                    .foregroundColor(InspectorTheme.textPrimary)
                Text(message)
                    .font(InspectorFont.body)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(InspectorOutlinedButtonStyle())
            }
        }
        .padding(InspectorTheme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(InspectorMotion.standard(2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var pulseAlpha: Double {
        pulse ? 0.6 : 0.3
    }
}

/// Android's outlined button: brand text and border, 6 pt corners.
struct InspectorOutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InspectorFont.bodyMedium)
            .foregroundColor(InspectorTheme.brand)
            .padding(.horizontal, InspectorTheme.Spacing.lg)
            .frame(minHeight: InspectorTheme.minTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.sm)
                    .fill(InspectorTheme.brand.opacity(configuration.isPressed ? InspectorTheme.Alpha.light : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.sm)
                    .strokeBorder(InspectorTheme.outline, lineWidth: InspectorTheme.Border.regular)
            )
    }
}

/// Android's filled primary button.
struct InspectorFilledButtonStyle: ButtonStyle {
    var color: Color = InspectorTheme.brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InspectorFont.bodyMedium)
            .foregroundColor(InspectorTheme.background)
            .padding(.horizontal, InspectorTheme.Spacing.lg)
            .frame(minHeight: InspectorTheme.minTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.sm)
                    .fill(color.opacity(configuration.isPressed ? InspectorTheme.Alpha.prominent : 1))
            )
    }
}

/// Android's loading skeleton: placeholder rows with a shimmer sweeping across every 1.2 s.
struct InspectorSkeletonList: View {
    var rows = 6
    var rowHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: InspectorTheme.Spacing.sm) {
            ForEach(0..<rows, id: \.self) { _ in
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.md)
                    .fill(InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.light))
                    .frame(height: rowHeight)
                    .inspectorShimmer()
            }
        }
        .padding(InspectorTheme.Spacing.sm)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityLabel("Loading")
    }
}

extension View {
    func inspectorShimmer() -> some View {
        modifier(Shimmer())
    }
}

private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.moderate), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width)
                    .offset(x: phase * proxy.size.width)
                }
                .mask(content)
                .opacity(reduceMotion ? 0 : 1)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

#Preview("Empty") {
    InspectorEmptyState(
        systemImage: "wifi",
        title: "No requests yet",
        message: "Requests the app sends show up here as they happen.",
        actionTitle: "Refresh",
        action: {}
    )
    .inspectorScreen()
}

#Preview("Skeleton") {
    InspectorSkeletonList().inspectorScreen()
}
