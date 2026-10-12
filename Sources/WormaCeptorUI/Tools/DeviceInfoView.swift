import SwiftUI
import WormaCeptor

/// Device, OS, screen, memory, storage, app and network details, the same snapshot `get_device_info` returns.
struct DeviceInfoScreen: View {
    @StateObject private var model = InfoSectionsModel { try await WormaCeptorDeviceInfo.shared.sections() }

    var body: some View {
        ZStack {
            if let error = model.error, model.sections.isEmpty {
                InspectorEmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn't read device info",
                    message: error,
                    actionTitle: "Retry",
                    action: { Task { await model.refresh() } }
                )
            } else if !model.isLoaded {
                InspectorSkeletonList(rows: 4, rowHeight: 160).transition(.opacity)
            } else {
                DeviceInfoContent(sections: model.sections, collectedAt: model.loadedAt).transition(.opacity)
            }
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: model.isLoaded)
        .inspectorScreen()
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
    }
}

/// Android's device info: Device, OS, Screen, Memory, Storage, App, Network cards, usage bars, collection time.
struct DeviceInfoContent: View {
    let sections: [WormaCeptorInfoSection]
    var collectedAt: Date?

    private static let order = ["Device", "OS", "Screen", "Memory", "Storage", "App", "Network"]

    private var ordered: [WormaCeptorInfoSection] {
        sections.sorted { (Self.order.firstIndex(of: $0.title) ?? .max) < (Self.order.firstIndex(of: $1.title) ?? .max) }
    }

    var body: some View {
        InfoSectionsContent(
            sections: ordered,
            footer: collectedAt.map { "Collected \($0.formatted(date: .abbreviated, time: .standard))" },
            systemImage: Self.systemImage
        ) { section in
            switch section.title {
            case "Memory":
                if let percent = memoryUsage(section) { UsageLine(percent: percent) }
            case "Storage":
                if let percent = StorageUsage.percent() { UsageLine(percent: percent) }
            default:
                EmptyView()
            }
        }
        .navigationTitle("Device info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                CopyButton(text: ordered.map(InfoSectionsFormat.text).joined(separator: "\n\n"), label: "All")
            }
        }
    }

    /// Android's section icons.
    static func systemImage(_ title: String) -> String {
        switch title {
        case "Device": return "iphone"
        case "OS": return "gearshape.2"
        case "Screen": return "rectangle.portrait"
        case "Memory": return "memorychip"
        case "Storage": return "internaldrive"
        case "App": return "square.grid.2x2"
        case "Network": return "network"
        default: return "info.circle"
        }
    }

    private func memoryUsage(_ section: WormaCeptorInfoSection) -> Double? {
        section.rows.first { $0.label == "Usage percentage" }.flatMap { Double($0.value) }
    }
}

/// The share of the app's volume in use. The snapshot only carries formatted sizes, so this reads the volume.
private enum StorageUsage {
    static func percent() -> Double? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity, total > 0,
              let available = values.volumeAvailableCapacity else { return nil }
        return Double(total - available) / Double(total) * 100
    }
}

/// Android's usage line: "Usage" and the percentage in green, amber (50%+) or red (90%+) over a rounded bar.
private struct UsageLine: View {
    let percent: Double

    private var color: Color {
        if percent >= 90 { return InspectorTheme.color(for: .error) }
        if percent >= 50 { return InspectorTheme.color(for: .warning) }
        return InspectorTheme.color(for: .success)
    }

    var body: some View {
        VStack(spacing: InspectorTheme.Spacing.xs) {
            HStack {
                Text("Usage").font(InspectorFont.bodySmall).foregroundColor(InspectorTheme.secondaryText)
                Spacer()
                Text(String(format: "%.1f%%", percent))
                    .font(InspectorFont.bodySmall.weight(.semibold).monospacedDigit())
                    .foregroundColor(color)
            }
            UsageBar(fraction: percent / 100, color: color)
        }
        .padding(.top, InspectorTheme.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usage")
        .accessibilityValue(String(format: "%.0f percent", percent))
    }
}

#if DEBUG
#Preview("Device info") {
    NavigationView {
        DeviceInfoContent(sections: PreviewSamples.deviceInfo, collectedAt: Date())
    }
}

#Preview("Device info, dark") {
    NavigationView {
        DeviceInfoContent(sections: PreviewSamples.deviceInfo, collectedAt: Date())
    }
    .preferredColorScheme(.dark)
}
#endif
