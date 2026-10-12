import Foundation
import ObjectiveC
@_exported import WormaCeptor

/// Captures URLSession traffic in WormaCeptor and serves its mock rules.
///
/// ```swift
/// WormaCeptorIos.shared.start(port: 8999, token: nil)
/// WormaCeptorURLSession.install()
/// ```
///
/// Covers `URLSession.shared` and every session built from a `URLSessionConfiguration.default` or `.ephemeral`
/// created after `install()`, which includes Alamofire's. Requests pass through untouched until WormaCeptor is
/// started.
public enum WormaCeptorURLSession {
    /// Registers the protocol for `URLSession.shared` and makes `.default` and `.ephemeral` configurations include
    /// it. Safe to call more than once. Sessions created before the call are not captured.
    public static func install() {
        _ = installOnce
    }

    private static let installOnce: Void = {
        URLProtocol.registerClass(WormaCeptorURLProtocol.self)
        exchangeClassGetter(
            #selector(getter: URLSessionConfiguration.default),
            #selector(getter: URLSessionConfiguration.wormaCeptorDefault)
        )
        exchangeClassGetter(
            #selector(getter: URLSessionConfiguration.ephemeral),
            #selector(getter: URLSessionConfiguration.wormaCeptorEphemeral)
        )
    }()

    private static func exchangeClassGetter(_ original: Selector, _ replacement: Selector) {
        guard
            let originalMethod = class_getClassMethod(URLSessionConfiguration.self, original),
            let replacementMethod = class_getClassMethod(URLSessionConfiguration.self, replacement)
        else {
            print("WormaCeptor: could not hook URLSessionConfiguration.\(original); custom sessions are not captured")
            return
        }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }

    /// `configuration` with the protocol first in `protocolClasses`.
    static func capturing(_ configuration: URLSessionConfiguration) -> URLSessionConfiguration {
        configuration.protocolClasses = [WormaCeptorURLProtocol.self] + withoutProtocol(configuration.protocolClasses)
        return configuration
    }

    static func withoutProtocol(_ classes: [AnyClass]?) -> [AnyClass] {
        (classes ?? []).filter { ObjectIdentifier($0) != ObjectIdentifier(WormaCeptorURLProtocol.self) }
    }
}

extension URLSessionConfiguration {
    // After the exchange these selectors run the original getters, so the calls below are not recursive.
    @objc dynamic class var wormaCeptorDefault: URLSessionConfiguration {
        WormaCeptorURLSession.capturing(self.wormaCeptorDefault)
    }

    @objc dynamic class var wormaCeptorEphemeral: URLSessionConfiguration {
        WormaCeptorURLSession.capturing(self.wormaCeptorEphemeral)
    }
}
