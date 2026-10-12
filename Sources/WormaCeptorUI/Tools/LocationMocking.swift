import CoreLocation
import ObjectiveC
import WormaCeptor

/// Lets the Location tool and `simulate_location` mock what the app's `CLLocationManager`s report.
///
/// ```swift
/// WormaCeptorLocation.install() // at launch, debug builds only
/// ```
///
/// While a mock is set, `location` returns it, `startUpdatingLocation()` and `requestLocation()` deliver it to the
/// delegate (and every new mock after that), and real updates are paused; clearing the mock starts them again.
/// Authorization and `locationServicesEnabled()` are left as they are. Not covered: `CLLocationUpdate.liveUpdates`,
/// region and beacon monitoring, significant-change and visit updates, and heading. For those, set the simulator's
/// own location (Features > Location), which every API sees.
public enum WormaCeptorLocation {
    /// Swizzles `CLLocationManager` once; later calls do nothing.
    public static func install() {
        _ = installOnce
    }

    private static let installOnce: Void = {
        LocationMock.swizzle(#selector(CLLocationManager.startUpdatingLocation),
                             #selector(CLLocationManager.wormaceptor_startUpdatingLocation))
        LocationMock.swizzle(#selector(CLLocationManager.stopUpdatingLocation),
                             #selector(CLLocationManager.wormaceptor_stopUpdatingLocation))
        LocationMock.swizzle(#selector(CLLocationManager.requestLocation),
                             #selector(CLLocationManager.wormaceptor_requestLocation))
        LocationMock.swizzle(#selector(getter: CLLocationManager.location),
                             #selector(getter: CLLocationManager.wormaceptor_location))
        WormaCeptorMockLocation.shared.install(hook: LocationMock.shared)
    }()
}

/// The mock and the managers that asked for continuous updates. Managers are held weakly. Deliveries run on the run
/// loop of the thread that started updates, usually main, where Core Location calls the delegate too.
final class LocationMock: NSObject, WormaCeptorLocationHook {
    static let shared = LocationMock()

    private static var runLoopKey: UInt8 = 0

    private let lock = NSLock()
    private var fix: WormaCeptorLocationFix?
    private let updating = NSHashTable<CLLocationManager>.weakObjects()

    var updatingCount: Int {
        locked { updating.allObjects.count }
    }

    func mockLocation() -> CLLocation? {
        locked { fix }.map(Self.location)
    }

    func onMockChanged(fix newFix: WormaCeptorLocationFix?) {
        let (previous, managers) = locked { () -> (WormaCeptorLocationFix?, [CLLocationManager]) in
            let previous = fix
            fix = newFix
            return (previous, updating.allObjects)
        }
        for manager in managers {
            switch (previous, newFix) {
            case (nil, let next?):
                perform(on: manager) { manager in
                    manager.wormaceptor_stopUpdatingLocation()
                    Self.deliver(next, to: manager)
                }
            case (_?, let next?):
                perform(on: manager) { Self.deliver(next, to: $0) }
            case (_?, nil):
                perform(on: manager) { $0.wormaceptor_startUpdatingLocation() }
            case (nil, nil):
                break
            }
        }
    }

    /// True when the mock handled the call and the real one must not run.
    func startUpdating(_ manager: CLLocationManager) -> Bool {
        remember(for: manager)
        let fix = locked { () -> WormaCeptorLocationFix? in
            updating.add(manager)
            return self.fix
        }
        guard let fix else { return false }
        perform(on: manager) { Self.deliver(fix, to: $0) }
        return true
    }

    func stopUpdating(_ manager: CLLocationManager) {
        locked { updating.remove(manager) }
    }

    /// True when the mock answered the request.
    func requestOnce(_ manager: CLLocationManager) -> Bool {
        remember(for: manager)
        guard let fix = locked({ fix }) else { return false }
        perform(on: manager) { Self.deliver(fix, to: $0) }
        return true
    }

    static func swizzle(_ original: Selector, _ replacement: Selector) {
        let type: AnyClass = CLLocationManager.self
        guard let originalMethod = class_getInstanceMethod(type, original),
              let replacementMethod = class_getInstanceMethod(type, replacement) else {
            print("WormaCeptor: location mocking is off, CLLocationManager has no \(original)")
            return
        }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// The caller's run loop if it is running one (a thread with its own run loop), else main: a GCD thread's run
    /// loop never runs, so work queued there would never happen.
    private func remember(for manager: CLLocationManager) {
        let runLoop = Thread.isMainThread || RunLoop.current.currentMode == nil ? RunLoop.main : RunLoop.current
        objc_setAssociatedObject(manager, &Self.runLoopKey, runLoop, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func perform(on manager: CLLocationManager, _ work: @escaping (CLLocationManager) -> Void) {
        let runLoop = objc_getAssociatedObject(manager, &Self.runLoopKey) as? RunLoop ?? .main
        runLoop.perform(inModes: [.common]) { [weak manager] in
            guard let manager else { return }
            work(manager)
        }
        CFRunLoopWakeUp(runLoop.getCFRunLoop())
    }

    private static func deliver(_ fix: WormaCeptorLocationFix, to manager: CLLocationManager) {
        manager.delegate?.locationManager?(manager, didUpdateLocations: [location(fix)])
    }

    /// Stamped now: apps commonly drop fixes older than a few seconds.
    private static func location(_ fix: WormaCeptorLocationFix) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: fix.latitude, longitude: fix.longitude),
            altitude: fix.altitude,
            horizontalAccuracy: CLLocationAccuracy(fix.accuracy),
            verticalAccuracy: CLLocationAccuracy(fix.accuracy),
            course: CLLocationDirection(fix.course),
            speed: CLLocationSpeed(fix.speed),
            timestamp: Date()
        )
    }
}

// After the exchange, each `wormaceptor_` selector runs the original method.
extension CLLocationManager {
    @objc dynamic func wormaceptor_startUpdatingLocation() {
        if LocationMock.shared.startUpdating(self) { return }
        wormaceptor_startUpdatingLocation()
    }

    @objc dynamic func wormaceptor_stopUpdatingLocation() {
        LocationMock.shared.stopUpdating(self)
        wormaceptor_stopUpdatingLocation()
    }

    @objc dynamic func wormaceptor_requestLocation() {
        if LocationMock.shared.requestOnce(self) { return }
        wormaceptor_requestLocation()
    }

    @objc dynamic var wormaceptor_location: CLLocation? {
        LocationMock.shared.mockLocation() ?? self.wormaceptor_location
    }
}
