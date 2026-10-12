import ObjectiveC
import UIKit
import WormaCeptor

/// Reports view controllers that stay alive after they leave the screen, for the Leaks tool and `list_leaks`.
///
/// ```swift
/// WormaCeptorLeaks.install() // at launch, debug builds only
/// ```
///
/// When a controller's `viewDidDisappear` runs (a subclass must call `super`), it is held weakly for `delay`
/// seconds, as Android does for a destroyed Activity. If it is still alive then and still off screen (no parent, not
/// presented, its view in no window), it is reported. Only the app's own classes are watched, not Apple's. A wait that
/// spanned a trip to the background starts over. A controller the app keeps on purpose to show again later (cached
/// in a property) is reported too; that report is expected.
public enum WormaCeptorLeaks {
    /// Starts watching; later calls only change `delay`. Call on the main thread. The default is Android's 5 s.
    public static func install(delay: TimeInterval = 5) {
        LeakWatcher.shared.delay = delay
        _ = installOnce
    }

    private static let installOnce: Void = {
        let type: AnyClass = UIViewController.self
        guard let original = class_getInstanceMethod(type, #selector(UIViewController.viewDidDisappear(_:))),
              let replacement = class_getInstanceMethod(
                  type, #selector(UIViewController.wormaceptor_viewDidDisappear(_:))
              ) else {
            print("WormaCeptor: leak detection is off, UIViewController has no viewDidDisappear(_:)")
            return
        }
        method_exchangeImplementations(original, replacement)
        LeakWatcher.shared.start()
        WormaCeptorLeakReports.shared.markWatching()
    }()
}

/// Schedules the delayed checks. Main thread only, like UIKit's appearance callbacks.
final class LeakWatcher {
    /// Waits that end this much later than planned (the app was suspended or the main thread hung) start over.
    static let lateTolerance: TimeInterval = 1
    static let maxAttempts = 3

    static let shared = LeakWatcher()

    private static var watchingKey: UInt8 = 0

    var delay: TimeInterval = 5
    /// Counts trips to the background, so a check can tell whether one happened during its wait.
    private(set) var backgroundTrips = 0

    private var observer: NSObjectProtocol?

    func start() {
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.backgroundTrips += 1 }
    }

    func didDisappear(_ controller: UIViewController) {
        guard Self.isAppClass(type(of: controller)), !isWatched(controller) else { return }
        setWatched(controller, true)
        schedule(controller, disappearedAt: Date(), attempt: 1)
    }

    private func schedule(_ controller: UIViewController, disappearedAt: Date, attempt: Int) {
        let trips = backgroundTrips
        let planned = Date().addingTimeInterval(delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak controller] in
            guard let self, let controller else { return }
            let interrupted = self.backgroundTrips != trips
                || Date().timeIntervalSince(planned) > Self.lateTolerance
            if interrupted, attempt < Self.maxAttempts {
                self.schedule(controller, disappearedAt: disappearedAt, attempt: attempt + 1)
                return
            }
            self.setWatched(controller, false)
            if !interrupted, Self.isOffScreen(controller) {
                WormaCeptorLeakReports.shared.record(
                    className: String(reflecting: type(of: controller)),
                    disappearedAtMs: Int64(disappearedAt.timeIntervalSince1970 * 1000)
                )
            }
        }
    }

    static func isOffScreen(_ controller: UIViewController) -> Bool {
        controller.parent == nil
            && controller.presentingViewController == nil
            && (!controller.isViewLoaded || controller.view.window == nil)
    }

    /// Apple's own controllers (keyboard, alerts, remote view services) are cached and reused by the system.
    static func isAppClass(_ type: AnyClass) -> Bool {
        !Bundle(for: type).bundlePath.contains("/System/Library/")
    }

    private func isWatched(_ controller: UIViewController) -> Bool {
        objc_getAssociatedObject(controller, &Self.watchingKey) as? Bool ?? false
    }

    private func setWatched(_ controller: UIViewController, _ watched: Bool) {
        objc_setAssociatedObject(controller, &Self.watchingKey, watched, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// After the exchange, `wormaceptor_viewDidDisappear` runs the original method.
extension UIViewController {
    @objc dynamic func wormaceptor_viewDidDisappear(_ animated: Bool) {
        wormaceptor_viewDidDisappear(animated)
        LeakWatcher.shared.didDisappear(self)
    }
}
