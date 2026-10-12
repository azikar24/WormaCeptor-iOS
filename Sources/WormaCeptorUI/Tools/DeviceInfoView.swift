import SwiftUI
import WormaCeptor

/// Device, OS, screen, memory, storage, app and network details, the same snapshot `get_device_info` returns.
struct DeviceInfoScreen: View {
    @StateObject private var model = InfoSectionsModel { try await WormaCeptorDeviceInfo.shared.sections() }

    var body: some View {
        InfoSectionsContent(sections: model.sections)
            .overlay {
                if let error = model.error {
                    EmptyStateView(systemImage: "exclamationmark.triangle", title: "Couldn't read device info", message: error)
                } else if !model.isLoaded {
                    ProgressView()
                }
            }
            .navigationTitle("Device info")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
    }
}

#if DEBUG
#Preview("Device info") {
    NavigationView {
        InfoSectionsContent(sections: PreviewSamples.deviceInfo)
            .navigationTitle("Device info")
    }
}
#endif
