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

/// Android's location simulator: status card with a switch, custom coordinates, then searchable presets.
struct LocationContent: View {
    let fix: WormaCeptorLocationFix?
    let isInstalled: Bool
    let presets: [WormaCeptorLocationPreset]
    let error: String?
    let onSet: (WormaCeptorLocationFix) -> Void
    let onStop: () -> Void

    @State private var latitude = ""
    @State private var longitude = ""
    @State private var search = ""

    private var entered: WormaCeptorLocationFix? {
        guard let lat = Self.number(latitude), let lon = Self.number(longitude),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return WormaCeptorLocationFix(
            latitude: lat, longitude: lon, altitude: 0, accuracy: 1, speed: 0, course: 0, name: nil
        )
    }

    private var filteredPresets: [WormaCeptorLocationPreset] {
        search.isEmpty ? presets : presets.filter { ($0.fix.name ?? $0.id).localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                if !isInstalled {
                    LocationWarningBanner()
                }
                statusCard
                if isInstalled {
                    coordinatesCard
                    presetsSection
                }
                Text("Covers CLLocationManager's location, startUpdatingLocation and requestLocation in this app. CLLocationUpdate.liveUpdates, region monitoring, significant-change, visits and heading aren't mocked; set the simulator's location (Features > Location) for those.")
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorDismissesKeyboardOnScroll()
        .inspectorScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    Text("Location").font(.headline).foregroundColor(InspectorTheme.textPrimary)
                    if fix != nil {
                        InspectorBadge(text: "ACTIVE", color: MiscToolColors.locationActive)
                            .transition(.opacity)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.page), value: fix?.latitude)
    }

    private var statusCard: some View {
        InspectorToggleCard(
            title: fix != nil ? "Mock location active" : "Mock location disabled",
            status: statusLine,
            systemImage: "location.fill",
            isOn: fix != nil,
            onColor: MiscToolColors.locationActive,
            isEnabled: isInstalled && (fix != nil || entered != nil),
            onToggle: { on in
                if on, let entered {
                    onSet(entered)
                } else if !on {
                    onStop()
                }
            }
        ) {
            if let error {
                Text(error)
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.error)
                    .padding([.horizontal, .bottom], InspectorTheme.Spacing.lg)
            }
        }
    }

    private var statusLine: String {
        if let fix {
            return [Self.coordinates(fix), fix.name].compactMap { $0 }.joined(separator: "\n")
        }
        return isInstalled ? "Enter coordinates or select a preset to enable" : "Off. The app gets real locations."
    }

    private var coordinatesCard: some View {
        let matchesCurrent = fix.map { Self.number(latitude) == $0.latitude && Self.number(longitude) == $0.longitude } ?? false
        return VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            Text("Set custom location")
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            InspectorTextField(
                label: "Latitude",
                text: $latitude,
                placeholder: "e.g., 40.7128",
                supporting: "Range: -90 to 90",
                isError: Self.isOutOfRange(latitude, limit: 90),
                keyboard: .numbersAndPunctuation
            )
            InspectorTextField(
                label: "Longitude",
                text: $longitude,
                placeholder: "e.g., -74.0060",
                supporting: "Range: -180 to 180",
                isError: Self.isOutOfRange(longitude, limit: 180),
                keyboard: .numbersAndPunctuation
            )
            Button {
                if let entered { onSet(entered) }
            } label: {
                Label("Set mock location", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InspectorFilledButtonStyle())
            .disabled(entered == nil || matchesCurrent)
            .opacity(entered == nil || matchesCurrent ? InspectorTheme.Alpha.strong : 1)
        }
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            radius: InspectorTheme.Radius.lg,
            padding: InspectorTheme.Spacing.lg
        )
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            HStack {
                Text("Location presets")
                    .font(InspectorFont.titleMedium)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(presets.count) locations")
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            InspectorSearchField(placeholder: "Search presets…", text: $search)
            let visible = filteredPresets
            if visible.isEmpty {
                InspectorEmptyState(systemImage: "mappin", title: "No matches found", message: "Try a different search term")
                    .frame(height: 280)
            }
            ForEach(visible, id: \.id) { preset in
                LocationPresetCard(preset: preset, isSelected: Self.isSame(preset.fix, fix)) { onSet(preset.fix) }
            }
        }
    }

    static func coordinates(_ fix: WormaCeptorLocationFix) -> String {
        String(format: "%.4f, %.4f", fix.latitude, fix.longitude)
    }

    private static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces))
    }

    private static func isOutOfRange(_ text: String, limit: Double) -> Bool {
        guard let value = number(text) else { return false }
        return !(-limit...limit).contains(value)
    }

    private static func isSame(_ lhs: WormaCeptorLocationFix, _ rhs: WormaCeptorLocationFix?) -> Bool {
        guard let rhs else { return false }
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

/// Android's `MockLocationWarningBanner`, for a host that never installed the location hook.
private struct LocationWarningBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: InspectorTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: InspectorTheme.IconSize.lg))
                .foregroundColor(MiscToolColors.locationWarning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text("Location mocking not installed")
                    .font(InspectorFont.titleSmall)
                    .foregroundColor(InspectorTheme.textPrimary)
                Text("Call WormaCeptorLocation.install() at launch, or set the simulator's location with Features > Location.")
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .inspectorCard(
            fill: MiscToolColors.locationWarning.opacity(InspectorTheme.Alpha.subtle),
            border: MiscToolColors.locationWarning.opacity(InspectorTheme.Alpha.moderate),
            padding: InspectorTheme.Spacing.lg
        )
    }
}

/// Android's `PresetItem`: pin well, name and coordinates; the selected one takes the brand border and a check.
private struct LocationPresetCard: View {
    let preset: WormaCeptorLocationPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: InspectorTheme.Spacing.md) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: InspectorTheme.IconSize.md - 2))
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                    .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.sm).fill(InspectorTheme.surfaceHigh))
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    HStack(spacing: InspectorTheme.Spacing.xs) {
                        Text(preset.fix.name ?? preset.id)
                            .font(InspectorFont.bodyMedium)
                            .foregroundColor(InspectorTheme.textPrimary)
                            .lineLimit(1)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: InspectorTheme.IconSize.xs, weight: .bold))
                                .foregroundColor(InspectorTheme.brand)
                        }
                    }
                    Text(LocationContent.coordinates(preset.fix))
                        .font(InspectorFont.bodySmall.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .inspectorCard(
                fill: isSelected ? InspectorTheme.brandSubtle : InspectorTheme.surface,
                border: isSelected ? InspectorTheme.brand : InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
                padding: InspectorTheme.Spacing.lg
            )
        }
        .buttonStyle(InspectorPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint("Mocks this location")
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

#Preview("Location dark") {
    NavigationView {
        LocationContent(
            fix: nil,
            isInstalled: true,
            presets: WormaCeptorMockLocation.shared.presets,
            error: nil,
            onSet: { _ in },
            onStop: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Location not installed") {
    NavigationView {
        LocationContent(fix: nil, isInstalled: false, presets: [], error: nil, onSet: { _ in }, onStop: {})
    }
}
#endif
