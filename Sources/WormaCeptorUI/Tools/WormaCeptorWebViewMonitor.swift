import ObjectiveC
import UIKit
import WebKit
import WormaCeptor

/// Records the pages every `WKWebView` shows and the `fetch` and `XMLHttpRequest` calls their scripts make, in
/// `WormaCeptorWebViews`. Off until `install()`, as on Android, where the host wraps its `WebViewClient`.
///
/// ```swift
/// WormaCeptorWebViewMonitor.install()
/// ```
///
/// Web views created after the call get a script in every frame and a message handler named `wormaceptorWebView`;
/// the host's navigation delegate and its own handlers stay untouched. Images, styles and other subresources the
/// page loads without a script call are not seen.
public enum WormaCeptorWebViewMonitor {
    /// Hooks `WKWebView`'s initializers. Safe to call more than once.
    public static func install() {
        _ = installOnce
    }

    static let handlerName = "wormaceptorWebView"

    private static let installOnce: Void = {
        hookInitWithFrame()
        hookInitWithCoder()
    }()

    // Self is passed and returned as raw pointers so ARC leaves the init family's ownership (consumed self,
    // retained result) to the original implementation.
    private typealias FrameInit = @convention(c)
        (UnsafeMutableRawPointer, Selector, CGRect, WKWebViewConfiguration) -> UnsafeMutableRawPointer?
    private typealias FrameInitBlock = @convention(block)
        (UnsafeMutableRawPointer, CGRect, WKWebViewConfiguration) -> UnsafeMutableRawPointer?
    private typealias CoderInit = @convention(c) (UnsafeMutableRawPointer, Selector, NSCoder) -> UnsafeMutableRawPointer?
    private typealias CoderInitBlock = @convention(block) (UnsafeMutableRawPointer, NSCoder) -> UnsafeMutableRawPointer?

    private static func hookInitWithFrame() {
        let selector = #selector(WKWebView.init(frame:configuration:))
        guard let method = class_getInstanceMethod(WKWebView.self, selector) else {
            print("WormaCeptor: WKWebView.init(frame:configuration:) not found; web views are not monitored")
            return
        }
        let original = unsafeBitCast(method_getImplementation(method), to: FrameInit.self)
        let block: FrameInitBlock = { object, frame, configuration in
            // The web view copies its configuration but shares the content controller, so preparing it first covers
            // the very first load.
            prepare(configuration.userContentController)
            let result = original(object, selector, frame, configuration)
            if let result { track(Unmanaged<WKWebView>.fromOpaque(result).takeUnretainedValue()) }
            return result
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func hookInitWithCoder() {
        let selector = #selector(WKWebView.init(coder:))
        guard let method = class_getInstanceMethod(WKWebView.self, selector) else {
            print("WormaCeptor: WKWebView.init(coder:) not found; storyboard web views are not monitored")
            return
        }
        let original = unsafeBitCast(method_getImplementation(method), to: CoderInit.self)
        let block: CoderInitBlock = { object, coder in
            let result = original(object, selector, coder)
            if let result {
                let webView = Unmanaged<WKWebView>.fromOpaque(result).takeUnretainedValue()
                prepare(webView.configuration.userContentController)
                track(webView)
            }
            return result
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static var preparedKey: UInt8 = 0
    private static var webViewIdKey: UInt8 = 0
    private static var observationsKey: UInt8 = 0
    private static var nextWebView = 1

    /// Adds the script and the handler once per content controller; web views can share one.
    private static func prepare(_ controller: WKUserContentController) {
        guard objc_getAssociatedObject(controller, &preparedKey) == nil else { return }
        objc_setAssociatedObject(controller, &preparedKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        controller.add(MessageHandler.shared, name: handlerName)
    }

    /// Names the web view and follows its URL and loading state through KVO, leaving its delegates alone.
    private static func track(_ webView: WKWebView) {
        guard objc_getAssociatedObject(webView, &webViewIdKey) == nil else { return }
        objc_setAssociatedObject(webView, &webViewIdKey, "WebView \(nextWebView)", .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        nextWebView += 1
        let observations = [
            webView.observe(\.url) { webView, _ in report(webView) },
            webView.observe(\.isLoading) { webView, _ in report(webView) },
        ]
        // Owned by the web view, so they go away with it; the handlers get the web view as an argument.
        objc_setAssociatedObject(webView, &observationsKey, observations, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private static func report(_ webView: WKWebView) {
        guard let url = webView.url?.absoluteString else { return }
        WormaCeptorWebViews.shared.navigation(webViewId: id(of: webView), url: url, isLoading: webView.isLoading)
    }

    fileprivate static func id(of webView: WKWebView) -> String {
        objc_getAssociatedObject(webView, &webViewIdKey) as? String ?? "WebView"
    }

    /// One handler for every web view. It holds no web view, so the content controller retaining it retains none.
    private final class MessageHandler: NSObject, WKScriptMessageHandler {
        static let shared = MessageHandler()

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let webView = message.webView, let body = message.body as? [AnyHashable: Any] else { return }
            WormaCeptorWebViews.shared.receive(
                webViewId: WormaCeptorWebViewMonitor.id(of: webView),
                pageUrl: webView.url?.absoluteString ?? "",
                isMainFrame: message.frameInfo.isMainFrame,
                body: body
            )
        }
    }

    /// Wraps `fetch` and `XMLHttpRequest` in each frame and posts start, end and error messages. Recording never
    /// changes what the page sees: a failure to describe a call falls back to the plain call.
    static let script = #"""
    (function () {
      if (window.__wormaceptorWebView) return;
      window.__wormaceptorWebView = true;
      var handlers = window.webkit && window.webkit.messageHandlers;
      var handler = handlers && handlers.wormaceptorWebView;
      if (!handler) return;
      var counter = 0;
      function nextId() {
        counter += 1;
        return Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8) + '-' + counter;
      }
      function attempt(describe, fallback) {
        try { return describe(); } catch (error) { return fallback; }
      }
      function absolute(url) {
        return attempt(function () { return new URL(String(url), location.href).href; }, String(url));
      }
      function headersOf(headers) {
        return attempt(function () {
          var out = {};
          if (headers) new Headers(headers).forEach(function (value, name) { out[name] = value; });
          return out;
        }, {});
      }
      function parseHeaders(raw) {
        var out = {};
        String(raw || '').split(/\r?\n/).forEach(function (line) {
          var colon = line.indexOf(':');
          if (colon > 0) out[line.slice(0, colon).trim().toLowerCase()] = line.slice(colon + 1).trim();
        });
        return out;
      }

      var originalFetch = window.fetch;
      if (originalFetch) {
        window.fetch = function (input, init) {
          var id = nextId();
          var isRequest = typeof Request !== 'undefined' && input instanceof Request;
          handler.postMessage({
            type: 'start', kind: 'fetch', id: id,
            url: absolute(isRequest ? input.url : input),
            method: String((init && init.method) || (isRequest ? input.method : 'GET')),
            headers: headersOf((init && init.headers) || (isRequest ? input.headers : undefined))
          });
          return originalFetch.apply(this, arguments).then(function (response) {
            handler.postMessage({ type: 'end', id: id, status: response.status, headers: headersOf(response.headers) });
            return response;
          }, function (error) {
            handler.postMessage({ type: 'error', id: id, message: String((error && error.message) || error) });
            throw error;
          });
        };
      }

      var XHR = window.XMLHttpRequest;
      if (XHR) {
        var open = XHR.prototype.open;
        var setRequestHeader = XHR.prototype.setRequestHeader;
        var send = XHR.prototype.send;
        XHR.prototype.open = function (method, url) {
          this.__wormaceptor = { method: String(method || 'GET'), url: absolute(url), headers: {} };
          return open.apply(this, arguments);
        };
        XHR.prototype.setRequestHeader = function (name, value) {
          if (this.__wormaceptor) this.__wormaceptor.headers[String(name).toLowerCase()] = String(value);
          return setRequestHeader.apply(this, arguments);
        };
        XHR.prototype.send = function () {
          var info = this.__wormaceptor;
          if (info) {
            var xhr = this;
            var id = nextId();
            var failure = 'Network error';
            handler.postMessage({ type: 'start', kind: 'xhr', id: id, url: info.url, method: info.method, headers: info.headers });
            xhr.addEventListener('abort', function () { failure = 'Aborted'; });
            xhr.addEventListener('timeout', function () { failure = 'Timed out'; });
            xhr.addEventListener('loadend', function () {
              if (xhr.status === 0) {
                handler.postMessage({ type: 'error', id: id, message: failure });
              } else {
                handler.postMessage({
                  type: 'end', id: id, status: xhr.status, headers: parseHeaders(xhr.getAllResponseHeaders())
                });
              }
            });
          }
          return send.apply(this, arguments);
        };
      }
    })();
    """#
}
