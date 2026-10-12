import UIKit
import WormaCeptor

/// A small floating panel with live CPU, memory and FPS, above everything in the app. Drag it anywhere; tap it to open
/// the inspector. Touches outside the panel reach the app, and it never takes keyboard focus.
///
/// Showing it starts the monitors that aren't running; hiding it stops only those, like Android's overlay.
public enum WormaCeptorOverlay {
    @MainActor private static var controller: OverlayController?

    /// Whether the overlay is on screen (or waiting for a scene to become active).
    @MainActor
    public static var isShowing: Bool { controller != nil }

    /// Shows the overlay. Does nothing if it is showing.
    @MainActor
    public static func show() {
        guard controller == nil else { return }
        controller = OverlayController()
    }

    /// Hides the overlay and stops the monitors it started.
    @MainActor
    public static func hide() {
        controller?.tearDown()
        controller = nil
    }
}

/// Keeps the overlay window on an active scene and feeds the panel.
@MainActor
private final class OverlayController {
    private let panel = OverlayPanel()
    private var window: OverlayWindow?
    private var subscription: WormaCeptorSubscription?
    private var observers: [NSObjectProtocol] = []

    init() {
        panel.onTap = { WormaCeptorInspector.present() }
        WormaCeptorPerformance.shared.overlayShown()
        // Kotlin delivers on the main queue; the hop tells the compiler so.
        subscription = WormaCeptorPerformance.shared.observe { [weak self] state in
            Task { @MainActor in self?.panel.update(state) }
        }
        let center = NotificationCenter.default
        // Follow the scene the user is in (iPad multitasking), and come back after ours disconnects.
        observers = [
            center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] note in
                let scene = note.object as? UIWindowScene
                Task { @MainActor in self?.attach(to: scene) }
            },
            center.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] note in
                let scene = note.object as? UIScene
                Task { @MainActor in self?.sceneDisconnected(scene) }
            },
        ]
        attach(to: Self.activeScene())
    }

    func tearDown() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        subscription?.cancel()
        subscription = nil
        window?.isHidden = true
        window = nil
        WormaCeptorPerformance.shared.overlayHidden()
    }

    private func attach(to scene: UIWindowScene?) {
        guard let scene else { return }
        if let window {
            if window.windowScene !== scene { window.windowScene = scene }
            return
        }
        let window = OverlayWindow(windowScene: scene, panel: panel)
        // Visible without makeKeyAndVisible: the app's window stays key.
        window.isHidden = false
        self.window = window
    }

    private func sceneDisconnected(_ scene: UIScene?) {
        guard let window, window.windowScene === scene else { return }
        window.isHidden = true
        self.window = nil
        attach(to: Self.activeScene())
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
    }
}

/// A window above alerts that only claims touches on its panel.
final class OverlayWindow: UIWindow {
    let panel: OverlayPanel

    init(windowScene: UIWindowScene, panel: OverlayPanel) {
        self.panel = panel
        super.init(windowScene: windowScene)
        setUp()
    }

    /// Not attached to a scene, so never on screen: for tests, which have no scene.
    init(frame: CGRect, panel: OverlayPanel) {
        self.panel = panel
        super.init(frame: frame)
        setUp()
    }

    private func setUp() {
        windowLevel = .alert + 1
        backgroundColor = .clear
        let root = OverlayRootController()
        rootViewController = root
        root.view.addSubview(panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Never key, so text fields in the app keep the keyboard.
    override var canBecomeKey: Bool { false }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard !panel.isHidden, panel.superview != nil else { return false }
        return panel.bounds.contains(panel.convert(point, from: self))
    }
}

/// Lays the panel out and leaves the status bar and rotation to the app's own window.
private final class OverlayRootController: UIViewController {
    private var appController: UIViewController? {
        view.window?.windowScene?.windows.first { $0.isKeyWindow }?.rootViewController
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (view.subviews.first as? OverlayPanel)?.keepInside(view.bounds.inset(by: view.safeAreaInsets))
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { appController?.preferredStatusBarStyle ?? .default }
    override var prefersStatusBarHidden: Bool { appController?.prefersStatusBarHidden ?? false }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        appController?.supportedInterfaceOrientations ?? .all
    }
}

/// Android's overlay pill: a dot in the metric's health color, a grey label and a white value per metric, on #1C1C1E in
/// both appearances so it reads over any screen. The view itself is at least 44 pt tall to keep the touch target; the
/// pill is centered in it.
final class OverlayPanel: UIView {
    var onTap: () -> Void = {}

    private let pill = UIView()
    private let cpu = OverlayMetricView(label: "CPU")
    private let memory = OverlayMetricView(label: "MEM")
    private let fps = OverlayMetricView(label: "FPS")
    private var placed = false

    private static let margin: CGFloat = 8

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        pill.backgroundColor = OverlayColors.background
        pill.isUserInteractionEnabled = false
        pill.layer.shadowColor = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.2
        pill.layer.shadowRadius = 4
        pill.layer.shadowOffset = CGSize(width: 0, height: 2)
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)
        let stack = UIStackView(arrangedSubviews: [cpu, memory, fps])
        stack.axis = .horizontal
        stack.spacing = InspectorTheme.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: trailingAnchor),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: InspectorTheme.minTouchTarget),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: InspectorTheme.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -InspectorTheme.Spacing.md),
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: InspectorTheme.Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -InspectorTheme.Spacing.sm),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Opens WormaCeptor"
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
        render(cpu: "--", memory: "--", fps: "--")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pill.layer.cornerRadius = pill.bounds.height / 2
    }

    func update(_ state: WormaCeptorPerformanceState) {
        render(cpu: text(state.cpu), memory: text(state.memory), fps: text(state.fps))
        cpu.dotColor = Self.color(for: state.cpu)
        memory.dotColor = Self.color(for: state.memory)
        fps.dotColor = Self.color(for: state.fps)
    }

    /// First layout: top trailing corner. Later ones (rotation, resize) pull it back on screen.
    func keepInside(_ area: CGRect) {
        let size = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let width = max(size.width, InspectorTheme.minTouchTarget)
        let height = max(size.height, InspectorTheme.minTouchTarget)
        let origin = placed ? frame.origin : CGPoint(x: area.maxX - width - Self.margin, y: area.minY + Self.margin)
        placed = true
        frame = CGRect(
            x: min(max(origin.x, area.minX + Self.margin), area.maxX - width - Self.margin),
            y: min(max(origin.y, area.minY + Self.margin), area.maxY - height - Self.margin),
            width: width,
            height: height
        )
    }

    private func render(cpu cpuText: String, memory memoryText: String, fps fpsText: String) {
        cpu.value = cpuText
        memory.value = memoryText
        fps.value = fpsText
        accessibilityLabel = "Performance: CPU \(cpuText), memory \(memoryText), \(fpsText) frames per second"
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    private func text(_ metric: WormaCeptorMetricState) -> String {
        guard metric.isRunning else { return "--" }
        // FPS reads per second: nothing until the first second has passed.
        if metric.metric == .fps && metric.history.isEmpty { return "--" }
        return metric.metric == .fps ? String(Int(metric.value.rounded())) : metric.valueText
    }

    @objc private func tapped() {
        onTap()
    }

    @objc private func dragged(_ gesture: UIPanGestureRecognizer) {
        guard let container = superview else { return }
        let translation = gesture.translation(in: container)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        gesture.setTranslation(.zero, in: container)
        if gesture.state == .ended || gesture.state == .cancelled {
            keepInside(container.bounds.inset(by: container.safeAreaInsets))
        }
    }

    /// Android's `MetricStatus` colors; grey while the monitor is off. A running monitor without a verdict (memory
    /// with no limit to compare against, as on the simulator) reads as good, like Android's 0% heap.
    private static func color(for metric: WormaCeptorMetricState) -> UIColor {
        guard metric.isRunning else { return OverlayColors.inactive }
        switch metric.tone {
        case .warning: return OverlayColors.warning
        case .error: return OverlayColors.critical
        default: return OverlayColors.good
        }
    }
}

/// Android's `Palette.Overlay*` colors.
private enum OverlayColors {
    static let background = rgb(0x1C1C1E)
    static let good = rgb(0x32D74B)
    static let warning = rgb(0xFF9F0A)
    static let critical = rgb(0xFF453A)
    static let inactive = rgb(0x8E8E93)

    private static func rgb(_ value: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// One metric in the pill: 6 pt dot, 10 pt label, 13 pt monospaced value.
private final class OverlayMetricView: UIView {
    private let dot = UIView()
    private let valueLabel = UILabel()

    var value: String {
        get { valueLabel.text ?? "" }
        set { valueLabel.text = newValue }
    }

    var dotColor: UIColor {
        get { dot.backgroundColor ?? .clear }
        set { dot.backgroundColor = newValue }
    }

    private static let dotSize: CGFloat = 6

    init(label: String) {
        super.init(frame: .zero)
        dot.backgroundColor = OverlayColors.inactive
        dot.layer.cornerRadius = Self.dotSize / 2
        let name = UILabel()
        name.attributedText = NSAttributedString(string: label, attributes: [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: OverlayColors.inactive,
            .kern: 0.5,
        ])
        valueLabel.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        valueLabel.textColor = .white
        let stack = UIStackView(arrangedSubviews: [dot, name, valueLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = InspectorTheme.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: Self.dotSize),
            dot.heightAnchor.constraint(equalToConstant: Self.dotSize),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
