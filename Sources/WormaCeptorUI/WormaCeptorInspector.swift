import ObjectiveC
import SwiftUI
import UIKit
@_exported import WormaCeptor

/// The in-app inspector: captured transactions, crashes, mock rules and tools. Embed it in SwiftUI:
///
/// ```swift
/// .sheet(isPresented: $showInspector) { WormaCeptorInspectorView(onDone: { showInspector = false }) }
/// ```
///
/// or present it from anywhere with `WormaCeptorInspector.present()`.
public struct WormaCeptorInspectorView: View {
    private let onDone: (() -> Void)?

    /// `onDone` adds a Done button that calls it; leave it nil when the inspector isn't presented modally.
    public init(onDone: (() -> Void)? = nil) {
        self.onDone = onDone
    }

    public var body: some View {
        TabView {
            NavigationView {
                TransactionListScreen().toolbar { doneButton }
            }
            .navigationViewStyle(.stack)
            .tabItem { Label("Transactions", systemImage: "arrow.left.arrow.right") }

            NavigationView {
                CrashListScreen().toolbar { doneButton }
            }
            .navigationViewStyle(.stack)
            .tabItem { Label("Crashes", systemImage: "ladybug") }

            NavigationView {
                ToolsScreen().toolbar { doneButton }
            }
            .navigationViewStyle(.stack)
            .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
        }
        // Android's three tabs and brand teal; mock rules live under Tools > Network, as on Android.
        .tint(InspectorTheme.brand)
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if let onDone {
                Button("Done", action: onDone)
            }
        }
    }
}

/// Opens the inspector from UIKit code, a debug menu, or a shake.
public enum WormaCeptorInspector {
    /// Presents the inspector over the key window's top view controller. Does nothing if it is already showing.
    @MainActor
    public static func present() {
        guard let top = topViewController(), !(top is InspectorHostingController) else { return }
        top.present(InspectorHostingController(), animated: true)
    }

    /// Opens the inspector when the device is shaken (Device > Shake in the simulator). Safe to call more than once.
    @MainActor
    public static func enableShakeToOpen() {
        _ = shakeHook
    }

    private static let shakeHook: Void = {
        let selector = #selector(UIResponder.motionEnded(_:with:))
        guard let method = class_getInstanceMethod(UIWindow.self, selector) else {
            print("WormaCeptor: could not hook UIWindow.motionEnded; shake to open is off")
            return
        }
        typealias MotionEnded = @convention(c) (UIWindow, Selector, UIEvent.EventSubtype, UIEvent?) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: MotionEnded.self)
        // Called with the real selector: UIResponder's version forwards the event to the next responder under the
        // selector it ran with, and nothing up the chain answers a renamed one.
        let hook: @convention(block) (UIWindow, UIEvent.EventSubtype, UIEvent?) -> Void = { window, motion, event in
            original(window, selector, motion, event)
            if motion == .motionShake {
                MainActor.assumeIsolated { present() }
            }
        }
        let implementation = imp_implementationWithBlock(hook)
        // UIWindow inherits motionEnded from UIResponder: add an override to UIWindow instead of replacing
        // UIResponder's own implementation, which every view and controller shares.
        if !class_addMethod(UIWindow.self, selector, implementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, implementation)
        }
    }()

    @MainActor
    private static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        var top = windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

private final class InspectorHostingController: UIHostingController<WormaCeptorInspectorView> {
    init() {
        super.init(rootView: WormaCeptorInspectorView())
        rootView = WormaCeptorInspectorView(onDone: { [weak self] in self?.dismiss(animated: true) })
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

#if DEBUG
#Preview("Inspector") {
    WormaCeptorInspectorView(onDone: {})
}
#endif
