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
                    if !model.history.isEmpty {
                        NavigationLink(destination: CryptoHistoryScreen(model: model)) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(InspectorTheme.secondaryText)
                                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                        }
                        .accessibilityLabel("History")
                    }
                }
            }
    }
}

/// Android's crypto tool: presets, collapsible advanced options, key and IV, input, then the result card.
struct CryptoContent: View {
    @ObservedObject var model: CryptoModel
    @State private var isAdvancedExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                presetsCard
                advancedCard
                keyCard
                inputCard
                if let result = model.result {
                    CryptoResultCard(result: result, model: model)
                        .transition(InspectorMotion.expand)
                }
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorDismissesKeyboardOnScroll()
        .inspectorScreen()
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: model.result)
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: model.config.mode)
    }

    private var presetsCard: some View {
        CryptoCard {
            CryptoSectionTitle("Presets")
            InspectorChipRow(inset: 0) {
                ForEach(CryptoPreset.allCases) { preset in
                    InspectorChip(label: preset.title, isSelected: isSelected(preset)) { model.apply(preset) }
                        .accessibilityHint("\(preset.summary). Applies the preset and clears the key and IV")
                }
            }
        }
    }

    private func isSelected(_ preset: CryptoPreset) -> Bool {
        let config = preset.config
        return model.config.algorithm == config.algorithm && model.config.mode == config.mode
            && (!config.mode.usesPadding || model.config.padding == config.padding)
    }

    private var advancedCard: some View {
        InspectorExpandableSection(isExpanded: $isAdvancedExpanded) {
            Text("Advanced")
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.textPrimary)
        } content: {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
                chips("Algorithm", CryptoAlgorithm.allCases, title: \.title, selection: $model.config.algorithm)
                chips("Mode", CipherMode.allCases, title: \.title, selection: $model.config.mode)
                chips("Padding", CryptoPadding.allCases, title: \.title, selection: $model.config.padding)
                    .disabled(!model.config.mode.usesPadding)
                    .opacity(model.config.mode.usesPadding ? 1 : InspectorTheme.Alpha.strong)
                if !model.config.mode.usesPadding {
                    Text("\(model.config.mode.title) needs no padding.")
                        .font(InspectorFont.labelSmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
            .padding(.top, InspectorTheme.Spacing.sm)
        }
        .padding(.horizontal, InspectorTheme.Spacing.lg)
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: 0
        )
    }

    private var keyCard: some View {
        CryptoCard {
            chips("Key format", KeyFormat.allCases, title: \.title, selection: $model.config.keyFormat)
            CryptoSecretField(
                title: "Key (\(model.config.algorithm.keyBytes) bytes)",
                name: "key",
                systemImage: "key.fill",
                text: $model.config.key,
                onGenerate: model.generateKey
            )
            if model.config.mode.requiresIv {
                CryptoSecretField(
                    title: "IV (Initialization Vector)",
                    name: "IV",
                    systemImage: nil,
                    text: $model.config.iv,
                    onGenerate: model.generateIv
                )
                .transition(InspectorMotion.expand)
            }
        }
    }

    private var inputCard: some View {
        CryptoCard {
            CryptoSectionTitle("Input")
            InspectorTextField(
                label: "Enter text to encrypt/decrypt",
                text: $model.input,
                monospaced: true,
                multiline: true
            )
            HStack(spacing: InspectorTheme.Spacing.md) {
                runButton(.encrypt)
                runButton(.decrypt)
            }
        }
    }

    private func runButton(_ operation: CryptoRun.Operation) -> some View {
        Button {
            withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { model.run(operation) }
        } label: {
            Text(operation.rawValue).frame(maxWidth: .infinity)
        }
        .buttonStyle(InspectorFilledButtonStyle())
        .disabled(!model.canRun)
        .opacity(model.canRun ? 1 : InspectorTheme.Alpha.strong)
    }

    private func chips<Option: Identifiable & Hashable>(
        _ title: String,
        _ options: [Option],
        title optionTitle: KeyPath<Option, String>,
        selection: Binding<Option>
    ) -> some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            CryptoSectionTitle(title)
            InspectorChipRow(inset: 0) {
                ForEach(options) { option in
                    InspectorChip(label: option[keyPath: optionTitle], isSelected: selection.wrappedValue == option) {
                        selection.wrappedValue = option
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Crypto") {
    NavigationView {
        CryptoContent(model: PreviewSamples.crypto())
            .navigationTitle("Crypto")
    }
}

#Preview("Crypto dark") {
    NavigationView {
        CryptoContent(model: PreviewSamples.crypto())
            .navigationTitle("Crypto")
    }
    .preferredColorScheme(.dark)
}

#Preview("Crypto history") {
    NavigationView {
        CryptoHistoryScreen(model: PreviewSamples.crypto())
    }
}
#endif
