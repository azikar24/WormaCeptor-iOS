import SwiftUI

/// Android's `WormaCeptorContainer` as the crypto sections use it: an outlined card, 16 pt inside.
struct CryptoCard<Content: View>: View {
    var border: Color = InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium)
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md, content: content)
            .inspectorCard(fill: InspectorTheme.surface, border: border, padding: InspectorTheme.Spacing.lg)
    }
}

/// Android's `Typography.sectionHeader`.
struct CryptoSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(InspectorFont.titleSmall)
            .foregroundColor(InspectorTheme.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Android's key and IV fields: hidden until revealed, with show/hide and generate buttons inside.
struct CryptoSecretField: View {
    let title: String
    let name: String
    let systemImage: String?
    @Binding var text: String
    let onGenerate: () -> Void

    @State private var isRevealed = false

    var body: some View {
        InspectorTextField(label: title, text: $text, isSecure: !isRevealed, monospaced: true) {
            iconButton(isRevealed ? "eye.slash" : "eye", label: isRevealed ? "Hide \(name)" : "Show \(name)") {
                isRevealed.toggle()
            }
            iconButton("arrow.clockwise", label: "Generate \(name)", action: onGenerate)
        }
    }

    private func iconButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundColor(InspectorTheme.secondaryText)
                .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Android's `ResultCard`: success or failure header with a clear button, the output in a mono box, copy and
/// use-as-input buttons, and the algorithm/mode with the run time.
struct CryptoResultCard: View {
    let result: CryptoRun
    @ObservedObject var model: CryptoModel

    @State private var copied = false

    var body: some View {
        let isSuccess = result.output != nil
        let color = InspectorTheme.color(for: isSuccess ? .success : .error)
        CryptoCard(border: color.opacity(InspectorTheme.Alpha.moderate)) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Image(systemName: isSuccess ? "checkmark" : "exclamationmark.circle.fill")
                    .font(.system(size: InspectorTheme.IconSize.md, weight: .semibold))
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                Text("\(result.operation.rawValue) \(isSuccess ? "Success" : "Failed")")
                    .font(InspectorFont.titleSmall)
                    .foregroundColor(InspectorTheme.textPrimary)
                Spacer()
                Button(action: model.clearResult) {
                    Image(systemName: "trash")
                        .foregroundColor(InspectorTheme.secondaryText)
                        .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel("Clear result")
            }
            if let output = result.output {
                outputSection(output)
            } else {
                Text(result.error ?? "Unknown error")
                    .font(InspectorFont.body)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .textSelection(.enabled)
            }
            Text("\(result.algorithm.title)/\(result.mode.title) | \(result.durationMs)ms")
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
        }
    }
    @ViewBuilder private func outputSection(_ output: String) -> some View {
        Text("Output:")
            .font(InspectorFont.label)
            .foregroundColor(InspectorTheme.secondaryText)
        Text(output)
            .font(InspectorFont.body.monospaced())
            .foregroundColor(InspectorTheme.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(InspectorTheme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.sm).fill(InspectorTheme.background))
            .accessibilityLabel("Output")
            .accessibilityValue(output)
        HStack(spacing: InspectorTheme.Spacing.sm) {
            Button {
                UIPasteboard.general.string = output
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InspectorOutlinedButtonStyle())
            Button {
                model.useAsInput(output)
            } label: {
                Label("Use as input", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(InspectorOutlinedButtonStyle())
        }
    }
}

/// Past runs, newest first. Tap to load the input back; the trash button removes one.
struct CryptoHistoryScreen: View {
    @ObservedObject var model: CryptoModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        Group {
            if model.history.isEmpty {
                InspectorEmptyState(
                    systemImage: "clock.arrow.circlepath",
                    title: "No history yet",
                    message: "Your encryption and decryption operations will appear here"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: InspectorTheme.Spacing.sm) {
                        ForEach(model.history) { run in
                            CryptoRunRow(run: run, onLoad: {
                                model.load(run)
                                dismiss()
                            }, onRemove: {
                                withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { model.remove(run) }
                            })
                        }
                    }
                    .padding(InspectorTheme.Spacing.lg)
                }
            }
        }
        .inspectorScreen()
        .navigationTitle("Crypto history")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !model.history.isEmpty {
                    Button {
                        confirmClear = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(InspectorTheme.secondaryText)
                            .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                    }
                    .accessibilityLabel("Clear all")
                }
            }
        }
        .confirmationDialog("Clear history", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear all", role: .destructive, action: model.clearHistory)
        } message: {
            Text("Are you sure you want to clear all crypto history? This action cannot be undone.")
        }
    }
}

/// Android's history `WormaCeptorListItem`: lock icon, "Encrypt - AES-256/CBC", the input and the outcome.
private struct CryptoRunRow: View {
    static let previewLength = 50

    let run: CryptoRun
    let onLoad: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let failed = run.output == nil
        HStack(spacing: InspectorTheme.Spacing.md) {
            Button(action: onLoad) {
                HStack(spacing: InspectorTheme.Spacing.md) {
                    Image(systemName: run.operation == .encrypt ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: InspectorTheme.IconSize.sm))
                        .foregroundColor(failed ? InspectorTheme.error : InspectorTheme.secondaryText)
                        .frame(width: InspectorTheme.IconSize.lg)
                    VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                        Text("\(run.operation.rawValue) - \(run.algorithm.title)/\(run.mode.title)")
                            .font(InspectorFont.bodyMedium)
                            .foregroundColor(InspectorTheme.textPrimary)
                        Text(inputPreview)
                            .font(InspectorFont.code)
                            .foregroundColor(InspectorTheme.secondaryText)
                            .lineLimit(1)
                        Text("\(run.date.formatted(date: .omitted, time: .standard)) | \(failed ? "Failed" : "Success") | \(run.durationMs)ms")
                            .font(InspectorFont.labelSmall)
                            .foregroundColor(failed ? InspectorTheme.error : InspectorTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(InspectorPressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Loads the input back into the crypto tool")
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
            }
            .accessibilityLabel("Remove")
        }
        .padding(.leading, InspectorTheme.Spacing.md)
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: failed ? InspectorTheme.error.opacity(InspectorTheme.Alpha.moderate) : InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: 0
        )
    }

    private var inputPreview: String {
        run.input.count > Self.previewLength ? String(run.input.prefix(Self.previewLength)) + "..." : run.input
    }
}
