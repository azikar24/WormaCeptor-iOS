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
            .tabItem { Label("Crashes", systemImage: "exclamationmark.octagon") }

            NavigationView {
                MockRulesScreen().toolbar { doneButton }
            }
            .navigationViewStyle(.stack)
            .tabItem { Label("Mock rules", systemImage: "theatermasks") }

            NavigationView {
                ToolsScreen().toolbar { doneButton }
            }
            .navigationViewStyle(.stack)
            .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
        }
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
        let original = #selector(UIResponder.motionEnded(_:with:))
        let replacement = #selector(UIWindow.wormaCeptorMotionEnded(_:with:))
        guard
            let originalMethod = class_getInstanceMethod(UIWindow.self, original),
            let replacementMethod = class_getInstanceMethod(UIWindow.self, replacement)
        else {
            print("WormaCeptor: could not hook UIWindow.motionEnded; shake to open is off")
            return
        }
        // UIWindow inherits motionEnded from UIResponder: add an override to UIWindow instead of swapping
        // UIResponder's own implementation, which every view and controller shares.
        let added = class_addMethod(
            UIWindow.self,
            original,
            method_getImplementation(replacementMethod),
            method_getTypeEncoding(replacementMethod)
        )
        if added {
            class_replaceMethod(
                UIWindow.self,
                replacement,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, replacementMethod)
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

extension UIWindow {
    // After the hook this selector runs the inherited motionEnded, so the call below is not recursive.
    @objc fileprivate func wormaCeptorMotionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        wormaCeptorMotionEnded(motion, with: event)
        if motion == .motionShake {
            WormaCeptorInspector.present()
        }
    }
}

#if DEBUG
#Preview("Inspector") {
    WormaCeptorInspectorView(onDone: {})
}
#endif
