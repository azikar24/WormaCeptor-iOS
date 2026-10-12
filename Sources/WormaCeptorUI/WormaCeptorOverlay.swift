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

/// The panel: one line per metric, colored by health. Dark in both appearances so it reads over any screen.
final class OverlayPanel: UIView {
    var onTap: () -> Void = {}

    private let cpu = OverlayPanel.label()
    private let memory = OverlayPanel.label()
    private let fps = OverlayPanel.label()
    private var placed = false

    private static let margin: CGFloat = 8

    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.08, alpha: 0.9)
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.16).cgColor
        let stack = UIStackView(arrangedSubviews: [cpu, memory, fps])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
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

    func update(_ state: WormaCeptorPerformanceState) {
        render(cpu: text(state.cpu), memory: text(state.memory), fps: text(state.fps))
        cpu.textColor = Self.color(for: state.cpu.tone)
        memory.textColor = Self.color(for: state.memory.tone)
        fps.textColor = Self.color(for: state.fps.tone)
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
        cpu.text = "CPU \(cpuText)"
        memory.text = "MEM \(memoryText)"
        fps.text = "FPS \(fpsText)"
        accessibilityLabel = "Performance: CPU \(cpuText), memory \(memoryText), \(fpsText) frames per second"
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    private func text(_ metric: WormaCeptorMetricState) -> String {
        guard metric.isRunning else { return "off" }
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

    private static func label() -> UILabel {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        return label
    }

    /// InspectorTheme's dark-mode status colors: the panel is always dark, so they keep their contrast on it.
    private static func color(for tone: WormaCeptorStatusTone) -> UIColor {
        switch tone {
        case .success: return UIColor(red: 0x34 / 255, green: 0xD3 / 255, blue: 0x99 / 255, alpha: 1)
        case .warning: return UIColor(red: 0xFB / 255, green: 0xBF / 255, blue: 0x24 / 255, alpha: 1)
        case .error: return UIColor(red: 0xF8 / 255, green: 0x71 / 255, blue: 0x71 / 255, alpha: 1)
        default: return .white
        }
    }
}
