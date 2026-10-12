import SwiftUI

/// One encrypt or decrypt run, for the result card and the history.
struct CryptoRun: Identifiable, Equatable {
    enum Operation: String {
        case encrypt = "Encrypt"
        case decrypt = "Decrypt"
    }

    let id = UUID()
    let operation: Operation
    let input: String
    /// Nil when the run failed.
    let output: String?
    let error: String?
    let algorithm: CryptoAlgorithm
    let mode: CipherMode
    let date: Date
    let durationMs: Int
}

/// The crypto tool's state. Shared, so the history outlives the screen like Android's engine does.
final class CryptoModel: ObservableObject {
    static let shared = CryptoModel()
    static let maxHistory = 50

    @Published var config: CryptoConfig
    @Published var input: String
    @Published private(set) var result: CryptoRun?
    @Published private(set) var history: [CryptoRun]

    init(config: CryptoConfig = .standard, input: String = "", result: CryptoRun? = nil, history: [CryptoRun] = []) {
        self.config = config
        self.input = input
        self.result = result
        self.history = history
    }

    func apply(_ preset: CryptoPreset) {
        config = preset.config
    }

    func generateKey() {
        config.key = CryptoToolkit.generateKey(config)
    }

    func generateIv() {
        config.iv = CryptoToolkit.generateIv(config)
    }

    var canRun: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func run(_ operation: CryptoRun.Operation) {
        guard canRun else { return }
        let started = Date()
        var output: String?
        var error: String?
        do {
            output = operation == .encrypt
                ? try CryptoToolkit.encrypt(input, config: config)
                : try CryptoToolkit.decrypt(input, config: config)
        } catch let failure {
            error = failure.localizedDescription
        }
        let run = CryptoRun(
            operation: operation, input: input, output: output, error: error,
            algorithm: config.algorithm, mode: config.mode, date: started,
            durationMs: Int(Date().timeIntervalSince(started) * 1000)
        )
        result = run
        history = Array(([run] + history).prefix(Self.maxHistory))
    }

    func useAsInput(_ text: String) {
        input = text
    }

    func clearResult() {
        result = nil
    }

    func load(_ run: CryptoRun) {
        input = run.input
    }

    func remove(_ run: CryptoRun) {
        history.removeAll { $0.id == run.id }
    }

    func clearHistory() {
        history = []
    }
}

/// AES, DES and 3DES encrypt and decrypt, Android's crypto tool. UI only: no MCP route, as on Android.
struct CryptoScreen: View {
    @ObservedObject var model: CryptoModel = .shared

    var body: some View {
        CryptoContent(model: model)
            .navigationTitle("Crypto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: CryptoHistoryScreen(model: model)) {
                        Image(systemName: "clock.arrow.circlepath")
                            .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                    }
                    .accessibilityLabel("History")
                }
            }
    }
}

struct CryptoContent: View {
    @ObservedObject var model: CryptoModel
    @State private var copied = false

    var body: some View {
        List {
            Section("Presets") {
                ForEach(CryptoPreset.allCases) { preset in
                    presetRow(preset)
                }
            }
            Section {
                Picker("Algorithm", selection: $model.config.algorithm) {
                    ForEach(CryptoAlgorithm.allCases) { Text($0.title).tag($0) }
                }
                Picker("Mode", selection: $model.config.mode) {
                    ForEach(CipherMode.allCases) { Text($0.title).tag($0) }
                }
                Picker("Padding", selection: $model.config.padding) {
                    ForEach(CryptoPadding.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!model.config.mode.usesPadding)
                Picker("Key format", selection: $model.config.keyFormat) {
                    ForEach(KeyFormat.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Advanced")
            } footer: {
                if !model.config.mode.usesPadding {
                    Text("\(model.config.mode.title) needs no padding.")
                }
            }
            .frame(minHeight: InspectorTheme.minTouchTarget)

            Section("Key (\(model.config.algorithm.keyBytes) bytes)") {
                SecretField(title: "Key", text: $model.config.key)
                Button("Generate key", action: model.generateKey)
                    .frame(minHeight: InspectorTheme.minTouchTarget)
            }
            if model.config.mode.requiresIv {
                Section("IV (Initialization Vector)") {
                    SecretField(title: "IV", text: $model.config.iv)
                    Button("Generate IV", action: model.generateIv)
                        .frame(minHeight: InspectorTheme.minTouchTarget)
                }
            }

            Section("Input") {
                TextEditor(text: $model.input)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 96)
                    .accessibilityLabel("Text to encrypt or decrypt")
                HStack(spacing: InspectorTheme.Spacing.md) {
                    runButton(.encrypt)
                    runButton(.decrypt)
                }
                .padding(.vertical, InspectorTheme.Spacing.xs)
            }

            if let result = model.result {
                resultSection(result)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func presetRow(_ preset: CryptoPreset) -> some View {
        let config = preset.config
        let selected = model.config.algorithm == config.algorithm && model.config.mode == config.mode
            && (!config.mode.usesPadding || model.config.padding == config.padding)
        return Button { model.apply(preset) } label: {
            HStack {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    Text(preset.title).foregroundColor(.primary)
                    Text(preset.summary)
                        .font(.footnote)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark").foregroundColor(.accentColor).accessibilityHidden(true)
                }
            }
            .frame(minHeight: InspectorTheme.minTouchTarget)
            .contentShape(Rectangle())
        }
        .accessibilityHint("Applies the preset and clears the key and IV")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func runButton(_ operation: CryptoRun.Operation) -> some View {
        Button {
            model.run(operation)
        } label: {
            Text(operation.rawValue)
                .frame(maxWidth: .infinity, minHeight: InspectorTheme.minTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canRun)
    }

    @ViewBuilder
    private func resultSection(_ result: CryptoRun) -> some View {
        Section {
            if let output = result.output {
                Text(output)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .accessibilityLabel("Output")
                    .accessibilityValue(output)
                Button {
                    UIPasteboard.general.string = output
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .frame(minHeight: InspectorTheme.minTouchTarget)
                Button {
                    model.useAsInput(output)
                } label: {
                    Label("Use as input", systemImage: "arrow.up.doc")
                }
                .frame(minHeight: InspectorTheme.minTouchTarget)
            } else {
                Text(result.error ?? "Unknown error")
                    .foregroundColor(InspectorTheme.color(for: .error))
                    .textSelection(.enabled)
            }
            Button("Clear result", role: .destructive, action: model.clearResult)
                .frame(minHeight: InspectorTheme.minTouchTarget)
        } header: {
            HStack {
                Text("\(result.operation.rawValue) \(result.algorithm.title)/\(result.mode.title)")
                Spacer()
                InspectorBadge(
                    text: result.output != nil ? "SUCCESS" : "FAILED",
                    color: InspectorTheme.color(for: result.output != nil ? .success : .error)
                )
            }
        }
    }
}

/// A key or IV, hidden until revealed, with no autocorrection or capitalization.
private struct SecretField: View {
    let title: String
    @Binding var text: String
    @State private var isRevealed = false

    var body: some View {
        HStack {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .font(.body.monospaced())
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isRevealed ? "Hide \(title)" : "Show \(title)")
        }
    }
}

/// Past runs, newest first. Tap to load the input back, swipe to remove.
struct CryptoHistoryScreen: View {
    @ObservedObject var model: CryptoModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        List {
            if model.history.isEmpty {
                VStack(spacing: InspectorTheme.Spacing.xs) {
                    Text("No history yet").font(.headline)
                    Text("Your encryption and decryption operations will appear here")
                        .font(.footnote)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, InspectorTheme.Spacing.lg)
            }
            ForEach(model.history) { run in
                Button {
                    model.load(run)
                    dismiss()
                } label: {
                    CryptoRunRow(run: run)
                }
                .swipeActions {
                    Button("Remove", role: .destructive) { model.remove(run) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Crypto history")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear all", role: .destructive) { confirmClear = true }
                    .disabled(model.history.isEmpty)
            }
        }
        .confirmationDialog("Clear history", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear all", role: .destructive, action: model.clearHistory)
        } message: {
            Text("Are you sure you want to clear all crypto history? This action cannot be undone.")
        }
    }
}

private struct CryptoRunRow: View {
    let run: CryptoRun

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack {
                InspectorBadge(
                    text: run.operation.rawValue.uppercased(),
                    color: InspectorTheme.color(for: run.output != nil ? .success : .error)
                )
                Text("\(run.algorithm.title)/\(run.mode.title)")
                    .font(.footnote.monospaced())
                    .foregroundColor(.primary)
                Spacer()
                Text(run.date.formatted(date: .omitted, time: .standard))
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            Text(run.input)
                .font(.callout.monospaced())
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(run.output ?? run.error ?? "")
                .font(.footnote.monospaced())
                .foregroundColor(run.output != nil ? InspectorTheme.secondaryText : InspectorTheme.color(for: .error))
                .lineLimit(2)
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Loads the input back into the crypto tool")
    }
}

#if DEBUG
#Preview("Crypto") {
    NavigationView {
        CryptoContent(model: PreviewSamples.crypto())
            .navigationTitle("Crypto")
    }
}

#Preview("Crypto history") {
    NavigationView {
        CryptoHistoryScreen(model: PreviewSamples.crypto())
    }
}
#endif
