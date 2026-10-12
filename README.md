# WormaCeptor for iOS (test build)

Network inspector and debug tools for iOS apps: captures URLSession, Alamofire and Ktor traffic, crashes, logs, and more, with an in-app inspector and an MCP server for AI agents.

Early test build. Use it in debug builds only.

## Install

Xcode > File > Add Package Dependencies, then enter:

```
https://github.com/azikar24/WormaCeptor-iOS
```

Pick version `0.2.0` and add the products you need:

- `WormaCeptorURLSession`: capture, mocking, throttling, MCP server
- `WormaCeptorUI`: the in-app inspector (optional)

iOS 15+.

## Setup

Start it early, before the app creates any `URLSession` (for example in your `App` init or `application(_:didFinishLaunchingWithOptions:)`):

```swift
import WormaCeptorURLSession
import WormaCeptorUI

WormaCeptorIos.shared.start(port: 8999, token: nil)
WormaCeptorURLSession.install()
WormaCeptorInspector.enableShakeToOpen()   // shake to open; Device > Shake in the simulator
```

Or open the inspector from a button: `WormaCeptorInspector.present()`.

Opt-in tools, call once at launch if you want them:

```swift
WormaCeptorWebSocketCapture.install()   // URLSessionWebSocketTask
WormaCeptorWebViewMonitor.install()     // WKWebView pages and fetch/XHR
WormaCeptorLogCapture.start()           // print, NSLog, os_log
WormaCeptorLocation.install()           // location mocking
WormaCeptorLeaks.install()              // view controllers not freed
WormaCeptorHangs.shared.start()         // main-thread hangs
```

## Known limits

- Sessions created before `install()` and background `URLSession`s are not captured.
- The Keychain tool needs a signed build.

## Feedback

Open an issue on this repo.
