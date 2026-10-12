import SwiftUI
import WormaCeptor

/// The active mock, live.
@MainActor
final class LocationModel: ObservableObject {
    @Published private(set) var fix: WormaCeptorLocationFix?
    @Published private(set) var error: String?

    let isInstalled = WormaCeptorMockLocation.shared.isInstalled
    let presets = WormaCeptorMockLocation.shared.presets
    private var subscription: WormaCeptorSubscription?

    init() {
        subscription = WormaCeptorMockLocation.shared.observe { [weak self] fix in self?.fix = fix }
    }

    deinit {
        subscription?.cancel()
    }

    func set(_ fix: WormaCeptorLocationFix) {
        error = WormaCeptorMockLocation.shared.set(fix: fix)
    }

    func stop() {
        WormaCeptorMockLocation.shared.clear()
        error = nil
    }
}

/// Mocks the location the app's `CLLocationManager`s report, the same thing `simulate_location` does.
struct LocationScreen: View {
    @StateObject private var model = LocationModel()

    var body: some View {
        LocationContent(
            fix: model.fix,
            isInstalled: model.isInstalled,
            presets: model.presets,
            error: model.error,
            onSet: model.set,
            onStop: model.stop
        )
    }
}

struct LocationContent: View {
    let fix: WormaCeptorLocationFix?
    let isInstalled: Bool
    let presets: [WormaCeptorLocationPreset]
    let error: String?
    let onSet: (WormaCeptorLocationFix) -> Void
    let onStop: () -> Void

    @State private var latitude = ""
    @State private var longitude = ""

    private var entered: WormaCeptorLocationFix? {
        guard let lat = Double(latitude.trimmingCharacters(in: .whitespaces)),
              let lon = Double(longitude.trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return WormaCeptorLocationFix(
            latitude: lat, longitude: lon, altitude: 0, accuracy: 1, speed: 0, course: 0, name: nil
        )
    }

    var body: some View {
        Form {
            statusSection
            if isInstalled {
                coordinatesSection
                Section("Presets") {
                    ForEach(presets, id: \.id) { preset in
                        Button {
                            onSet(preset.fix)
                        } label: {
                            HStack {
                                Text(preset.fix.name ?? preset.id)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(Self.coordinates(preset.fix))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(InspectorTheme.secondaryText)
                            }
                            .frame(minHeight: InspectorTheme.minTouchTarget)
                        }
                        .accessibilityHint("Mocks this location")
                    }
                }
            }
        }
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var statusSection: some View {
        Section {
            if !isInstalled {
                Text("Not installed. Call WormaCeptorLocation.install() at launch, or set the simulator's location with Features > Location.")
                    .font(.callout)
                    .foregroundColor(InspectorTheme.secondaryText)
            } else if let fix {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    Text(fix.name ?? "Custom")
                    Text(Self.coordinates(fix))
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                        .textSelection(.enabled)
                }
                .frame(minHeight: InspectorTheme.minTouchTarget)
                .accessibilityElement(children: .combine)
                Button(role: .destructive, action: onStop) {
                    Label("Stop mocking", systemImage: "location.slash")
                        .frame(minHeight: InspectorTheme.minTouchTarget)
                }
            } else {
                Text("Off. The app gets real locations.")
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundColor(InspectorTheme.color(for: .error))
            }
        } header: {
            Text("Mock location")
        } footer: {
            Text("Covers CLLocationManager's location, startUpdatingLocation and requestLocation in this app. CLLocationUpdate.liveUpdates, region monitoring, significant-change, visits and heading aren't mocked; set the simulator's location (Features > Location) for those.")
        }
    }

    private var coordinatesSection: some View {
        Section {
            TextField("Latitude (-90 to 90)", text: $latitude)
                .keyboardType(.numbersAndPunctuation)
            TextField("Longitude (-180 to 180)", text: $longitude)
                .keyboardType(.numbersAndPunctuation)
            Button {
                if let entered { onSet(entered) }
            } label: {
                Label("Set location", systemImage: "location")
                    .frame(minHeight: InspectorTheme.minTouchTarget)
            }
            .disabled(entered == nil)
        } header: {
            Text("Coordinates")
        }
    }

    static func coordinates(_ fix: WormaCeptorLocationFix) -> String {
        String(format: "%.4f, %.4f", fix.latitude, fix.longitude)
    }
}

#if DEBUG
#Preview("Location") {
    NavigationView {
        LocationContent(
            fix: WormaCeptorMockLocation.shared.presets[4].fix,
            isInstalled: true,
            presets: WormaCeptorMockLocation.shared.presets,
            error: nil,
            onSet: { _ in },
            onStop: {}
        )
    }
}

#Preview("Location not installed") {
    NavigationView {
        LocationContent(fix: nil, isInstalled: false, presets: [], error: nil, onSet: { _ in }, onStop: {})
    }
}
#endif
