#if DEBUG
import Foundation
import WormaCeptor

/// Sample data for the `#Preview`s, built from the Kotlin types the screens get at runtime.
enum PreviewSamples {
    static let now = Int64(Date().timeIntervalSince1970 * 1000)

    static let deviceInfo: [WormaCeptorInfoSection] = [
        WormaCeptorInfoSection(title: "App", rows: [
            WormaCeptorInfoRow(label: "Package name", value: "com.wormadev.wormaceptor.sample"),
            WormaCeptorInfoRow(label: "Version name", value: "1.0"),
        ]),
        WormaCeptorInfoSection(title: "Device", rows: [
            WormaCeptorInfoRow(label: "Model", value: "iPhone18,1"),
            WormaCeptorInfoRow(label: "Is emulator", value: "true"),
        ]),
    ]

    static let fileEntries: [WormaCeptorFileEntry] = [
        WormaCeptorFileEntry(
            name: "cache", path: "/Documents/cache", isDirectory: true, sizeBytes: 0, lastModifiedMs: now, isWritable: true
        ),
        WormaCeptorFileEntry(
            name: "config.json", path: "/Documents/config.json", isDirectory: false, sizeBytes: 2_340,
            lastModifiedMs: now, isWritable: true
        ),
        WormaCeptorFileEntry(
            name: "a-very-long-export-file-name-that-gets-truncated-in-the-middle.csv",
            path: "/Documents/export.csv", isDirectory: false, sizeBytes: 1_250_000, lastModifiedMs: now,
            isWritable: true
        ),
    ]

    static let fileContent = WormaCeptorFileContent(
        text: "{\n  \"name\": \"demo\",\n  \"auth_token\": \"abc123\"\n}",
        mimeType: "application/json",
        isText: true
    )

    static let defaultsDomains: [WormaCeptorDefaultsDomain] = [
        WormaCeptorDefaultsDomain(name: "com.wormadev.wormaceptor.sample", entries: [
            WormaCeptorDefaultsEntry(key: "apiBaseUrl", value: "https://api.example.com", type: .string),
            WormaCeptorDefaultsEntry(key: "launchCount", value: "12", type: .integer),
            WormaCeptorDefaultsEntry(key: "onboarded", value: "true", type: .boolean),
            WormaCeptorDefaultsEntry(key: "recentSearches", value: "[\"shoes\",\"hats\"]", type: .array),
            WormaCeptorDefaultsEntry(key: "zoom", value: "1.5", type: .decimal),
        ]),
        WormaCeptorDefaultsDomain(name: "group.com.wormadev.wormaceptor.sample", entries: [
            WormaCeptorDefaultsEntry(key: "widgetTheme", value: "dark", type: .string),
        ]),
    ]

    static let keychain: [WormaCeptorKeychainItem] = [
        WormaCeptorKeychainItem(
            storageType: "GENERIC_PASSWORD", kind: "Generic passwords", key: "com.wormadev.sample / access_token",
            value: "eyJhbGciOiJIUzI1NiJ9.e30.sig", valueSize: KotlinLong(longLong: 28), createdMs: KotlinLong(longLong: now),
            modifiedMs: KotlinLong(longLong: now),
            details: [
                WormaCeptorInfoRow(label: "Service", value: "com.wormadev.sample"),
                WormaCeptorInfoRow(label: "Account", value: "access_token"),
                WormaCeptorInfoRow(label: "Accessible", value: "After first unlock"),
            ]
        ),
        WormaCeptorKeychainItem(
            storageType: "GENERIC_PASSWORD", kind: "Generic passwords", key: "com.wormadev.sample / db_key",
            value: nil, valueSize: KotlinLong(longLong: 32), createdMs: nil, modifiedMs: nil,
            details: [WormaCeptorInfoRow(label: "Account", value: "db_key")]
        ),
        WormaCeptorKeychainItem(
            storageType: "KEY", kind: "Keys", key: "com.wormadev.sample.signing",
            value: nil, valueSize: nil, createdMs: nil, modifiedMs: nil,
            details: [WormaCeptorInfoRow(label: "Key type", value: "EC (P-256/384/521)")]
        ),
    ]

    static let databases: [WormaCeptorDatabase] = [
        WormaCeptorDatabase(
            name: "app.sqlite", path: "/Library/Application Support/app.sqlite", sizeBytes: 98_304, tableCount: 4
        ),
        WormaCeptorDatabase(
            name: "Cache.db", path: "/Library/Caches/com.example/Cache.db", sizeBytes: 40_960, tableCount: 5
        ),
    ]

    static let tables: [WormaCeptorTable] = [
        WormaCeptorTable(name: "ZORDER", rowCount: 128, columnCount: 6),
        WormaCeptorTable(name: "ZUSER", rowCount: 1, columnCount: 9),
        WormaCeptorTable(name: "Z_METADATA", rowCount: 1, columnCount: 3),
    ]

    static let columns: [WormaCeptorColumn] = [
        WormaCeptorColumn(name: "Z_PK", type: "INTEGER", isPrimaryKey: true, isNullable: true),
        WormaCeptorColumn(name: "ZTITLE", type: "VARCHAR", isPrimaryKey: false, isNullable: true),
        WormaCeptorColumn(name: "ZTOTAL", type: "FLOAT", isPrimaryKey: false, isNullable: false),
    ]

    static let queryResult = WormaCeptorQueryResult.companion.of(
        columns: ["Z_PK", "ZTITLE", "ZTOTAL", "ZRECEIPT"],
        rows: [
            ["1", "Coffee beans", "12.5", "<BLOB 2048 bytes>"],
            ["2", NSNull(), "3.0", NSNull()],
            ["3", "A long order title that does not fit in one column", "149.99", NSNull()],
        ]
    )

    static let libraries: [WormaCeptorLoadedLibrary] = [
        WormaCeptorLoadedLibrary(
            name: "Sample", path: "/private/var/containers/Bundle/Application/1/Sample.app/Sample", type: "EXECUTABLE",
            sizeBytes: KotlinLong(longLong: 4_200_000), loadAddress: "0x100f40000", version: nil, isSystemLibrary: false
        ),
        WormaCeptorLoadedLibrary(
            name: "SampleKit", path: "/private/var/containers/Bundle/Application/1/Sample.app/Frameworks/SampleKit.framework/SampleKit",
            type: "FRAMEWORK", sizeBytes: KotlinLong(longLong: 1_800_000), loadAddress: "0x101a20000", version: "5.1.0",
            isSystemLibrary: false
        ),
        WormaCeptorLoadedLibrary(
            name: "Foundation", path: "/System/Library/Frameworks/Foundation.framework/Foundation", type: "FRAMEWORK",
            sizeBytes: nil, loadAddress: "0x1a2b30000", version: nil, isSystemLibrary: true
        ),
        WormaCeptorLoadedLibrary(
            name: "libswiftCore.dylib", path: "/usr/lib/swift/libswiftCore.dylib", type: "DYLIB",
            sizeBytes: nil, loadAddress: "0x1a0c10000", version: nil, isSystemLibrary: true
        ),
    ]

    static let pushTokens: [WormaCeptorPushTokenEntry] = [
        WormaCeptorPushTokenEntry(token: "7f3a9c0e5b1d4e8f2a6c9b0d3e7f1a4c5b8d2e6f9a0c3b7d1e4f8a2c5b9d0e3f", receivedMs: now),
        WormaCeptorPushTokenEntry(token: "1c4f7a0d3e6b9c2f5a8d1e4b7c0f3a6d9e2b5c8f1a4d7e0b3c6f9a2d5e8b1c4f", receivedMs: now - 86_400_000),
    ]

    static let logEntries: [WormaCeptorLogEntry] = [
        WormaCeptorLogEntry(id: 1, timestampMs: now - 4_000, level: .info, tag: "stdout", threadId: 0, message: "App launched"),
        WormaCeptorLogEntry(
            id: 2, timestampMs: now - 3_000, level: .debug, tag: "network", threadId: 1_730_481,
            message: "GET https://httpbin.org/get?client=urlsession"
        ),
        WormaCeptorLogEntry(
            id: 3, timestampMs: now - 2_000, level: .info, tag: "NSLog", threadId: 1_730_481, message: "Session restored for ada"
        ),
        WormaCeptorLogEntry(
            id: 4, timestampMs: now - 1_000, level: .warn, tag: "stderr", threadId: 0,
            message: "Unable to simultaneously satisfy constraints. Probably at least one of the constraints in the following list is one you don't want."
        ),
        WormaCeptorLogEntry(id: 5, timestampMs: now, level: .error, tag: "auth", threadId: 1_730_502, message: "Token refresh failed: 401"),
    ]

    static let permission = NotificationPermission(status: "Allowed", alerts: "On", badges: "On", sounds: "Off")

    static let rows: [WormaCeptorTransactionRow] = [
        row("GET", "/get?client=urlsession", 200, .success, 412),
        row("POST", "/anything/orders", 201, .success, 980, mocked: true),
        row("GET", "/status/404", 404, .warning, 120),
        row("GET", "/status/503", 503, .error, 2_340),
        row("DELETE", "/very/long/path/that/keeps/going/to/show/how/a/row/truncates/in/the/middle?x=1", nil, .neutral, nil),
    ]

    static let detail = WormaCeptorTransactionDetail(
        id: "1",
        method: "GET",
        url: "https://httpbin.org/get?client=urlsession",
        host: "httpbin.org",
        path: "/get",
        statusCode: KotlinInt(int: 200),
        statusMessage: "OK",
        tone: .success,
        durationMs: KotlinLong(longLong: 412),
        timestampMs: now,
        isMocked: false,
        error: nil,
        protocol: "h2",
        tlsVersion: "TLSv1.3",
        request: WormaCeptorMessage(
            headers: [WormaCeptorHeader(name: "Accept", value: "*/*")],
            body: nil,
            bodySize: 0,
            contentType: nil,
            isJson: false,
            isBodyTruncated: false
        ),
        response: WormaCeptorMessage(
            headers: [
                WormaCeptorHeader(name: "Content-Length", value: "312"),
                WormaCeptorHeader(name: "Content-Type", value: "application/json"),
            ],
            body: "{\n    \"args\": {\n        \"client\": \"urlsession\"\n    },\n    \"url\": \"https://httpbin.org/get\"\n}",
            bodySize: 312,
            contentType: "application/json",
            isJson: true,
            isBodyTruncated: false
        )
    )

    static let crashRows: [WormaCeptorCrashRow] = [
        WormaCeptorCrashRow(
            id: 3, timestampMs: now - 90_000, exceptionType: "SIGTRAP",
            message: "Trace/breakpoint trap (Swift runtime error, force unwrap or fatalError)",
            location: "WormaCeptorSample.ContentView.crash() -> ()"
        ),
        WormaCeptorCrashRow(
            id: 2, timestampMs: now - 3_600_000, exceptionType: "NSInvalidArgumentException",
            message: "*** -[__NSPlaceholderDictionary initWithObjects:forKeys:count:]: attempt to insert nil object",
            location: nil
        ),
        WormaCeptorCrashRow(
            id: 1, timestampMs: now - 86_400_000, exceptionType: "kotlin.IllegalStateException",
            message: "Cart is empty", location: "CartRepository.kt:42"
        ),
    ]

    static let crashDetail = WormaCeptorCrashDetail(
        id: 1,
        timestampMs: now - 86_400_000,
        exceptionType: "kotlin.IllegalStateException",
        message: "Cart is empty",
        location: "CartRepository.kt:42",
        stackTrace: crashFrames.map(\.text).joined(separator: "\n"),
        frames: crashFrames
    )

    private static let crashFrames: [WormaCeptorStackFrame] = [
        WormaCeptorStackFrame(
            text: "at 0   WormaCeptorSample   0x0000000100a1c2d4 kfun:kotlin.Throwable#<init>(kotlin.String?){} + 92",
            isAppCode: false
        ),
        WormaCeptorStackFrame(
            text: "at 1   WormaCeptorSample   0x0000000100b3e010 kfun:com.example.CartRepository#checkout(){} + 52 "
                + "(/src/CartRepository.kt:42:9)",
            isAppCode: true
        ),
        WormaCeptorStackFrame(
            text: "at 2   UIKitCore   0x0000000185f0a4c8 -[UIApplication sendAction:to:from:forEvent:] + 96",
            isAppCode: false
        ),
    ]

    static let rules: [WormaCeptorMockRuleRow] = [
        WormaCeptorMockRuleRow(
            id: "1", name: "Orders down", isNameGenerated: false, enabled: true, method: "GET",
            urlPattern: "https://api.example.com/orders*", matchType: "PREFIX", statusCode: 503, error: nil, tone: .error
        ),
        WormaCeptorMockRuleRow(
            id: "2", name: "ANY https://api.example.com/login", isNameGenerated: true, enabled: false, method: nil,
            urlPattern: "https://api.example.com/login", matchType: "EXACT", statusCode: 200, error: "TIMEOUT", tone: .error
        ),
    ]

    private static func row(
        _ method: String,
        _ path: String,
        _ code: Int32?,
        _ tone: WormaCeptorStatusTone,
        _ durationMs: Int64?,
        mocked: Bool = false
    ) -> WormaCeptorTransactionRow {
        WormaCeptorTransactionRow(
            id: path,
            method: method,
            host: "httpbin.org",
            path: path,
            url: "https://httpbin.org\(path)",
            statusCode: code.map { KotlinInt(int: $0) },
            tone: tone,
            durationMs: durationMs.map { KotlinLong(longLong: $0) },
            timestampMs: now,
            isMocked: mocked,
            isInFlight: code == nil
        )
    }

    static let cpu = WormaCeptorMetricState(
        metric: .cpu,
        isRunning: true,
        value: 34,
        valueText: "34%",
        tone: .success,
        history: (0..<40).map { KotlinDouble(double: 20 + 15 * sin(Double($0) / 4)) },
        details: [
            WormaCeptorInfoRow(label: "All cores", value: "34%"),
            WormaCeptorInfoRow(label: "One core", value: "204%"),
            WormaCeptorInfoRow(label: "Cores", value: "6"),
        ]
    )

    static let rateLimit = WormaCeptorRateLimitState(
        enabled: true,
        downloadSpeedKbps: 400,
        uploadSpeedKbps: 100,
        latencyMs: 400,
        packetLossPercent: 2,
        presetId: "SLOW_3G",
        downloadText: "400 Kbps",
        uploadText: "100 Kbps",
        requestsThrottled: 12,
        packetsDropped: 1,
        totalDelayMs: 6_240,
        bytesThrottledText: "184 KB"
    )

    static let rateLimitPresets: [WormaCeptorRateLimitPreset] = [
        WormaCeptorRateLimitPreset(
            id: "WIFI", title: "Wi-Fi", downloadKbps: 50_000, uploadKbps: 20_000, latencyMs: 10,
            packetLossPercent: 0, downloadText: "50.0 Mbps", uploadText: "20.0 Mbps"
        ),
        WormaCeptorRateLimitPreset(
            id: "SLOW_3G", title: "Slow 3G", downloadKbps: 400, uploadKbps: 100, latencyMs: 400,
            packetLossPercent: 2, downloadText: "400 Kbps", uploadText: "100 Kbps"
        ),
        WormaCeptorRateLimitPreset(
            id: "OFFLINE", title: "Offline", downloadKbps: 0, uploadKbps: 0, latencyMs: 0,
            packetLossPercent: 100, downloadText: "0 Kbps", uploadText: "0 Kbps"
        ),
    ]

    static func crypto() -> CryptoModel {
        let config = CryptoConfig(
            algorithm: .aes256, mode: .gcm, padding: .none,
            key: "q83vEjRWeJCrze8SNFZ4kKvN7xI0VniQq83vEjRWeJA=", iv: "AAECAwQFBgcICQoL", keyFormat: .base64
        )
        let encrypted = CryptoRun(
            operation: .encrypt, input: "{\"token\":\"abc\"}", output: "3pUJ0f2a0Z9wq3v9c2xjYmRlZmdoaWprbG1ub3A=",
            error: nil, algorithm: .aes256, mode: .gcm, date: Date(), durationMs: 1
        )
        let failed = CryptoRun(
            operation: .decrypt, input: "bm90IHJlYWxseQ==", output: nil,
            error: CryptoFailure.badTag.message, algorithm: .aes256, mode: .gcm, date: Date(), durationMs: 0
        )
        return CryptoModel(config: config, input: "{\"token\":\"abc\"}", result: encrypted, history: [encrypted, failed])
    }

    static let memoryStopped = WormaCeptorMetricState(
        metric: .memory,
        isRunning: false,
        value: 0,
        valueText: "Zero KB",
        tone: .neutral,
        history: [],
        details: []
    )

    static let leaks: [WormaCeptorLeak] = [
        WormaCeptorLeak(
            timestampMs: now,
            className: "Sample.ProfileViewController",
            details: "ProfileViewController was still alive 5.0 s after it left the screen (no parent, not presented, not in a window). Something holds a strong reference to it: a closure capturing self, a delegate that isn't weak, a timer, or a notification observer.",
            retainedForMs: 5_000,
            severity: "CRITICAL"
        ),
        WormaCeptorLeak(
            timestampMs: now - 60_000,
            className: "Sample.CheckoutViewController",
            details: "CheckoutViewController was still alive 5.1 s after it left the screen.",
            retainedForMs: 5_100,
            severity: "HIGH"
        ),
    ]

    static let hangs: [WormaCeptorHang] = [
        WormaCeptorHang(
            id: 2,
            timestampMs: now,
            durationMs: 1_240,
            stack: [
                "libsystem_kernel.dylib  __semwait_signal + 8",
                "Foundation  +[NSThread sleepForTimeInterval:] + 148",
                "WormaCeptorSample  ContentView.blockMainThread() + 52",
                "SwiftUI  0x1d2f0a8c4",
            ]
        ),
        WormaCeptorHang(id: 1, timestampMs: now - 30_000, durationMs: 310, stack: []),
    ]

    static let pushTemplates: [WormaCeptorPushTemplate] = WormaCeptorPushSimulator.shared.templates + [
        WormaCeptorPushTemplate(
            id: "saved",
            name: "Order shipped",
            notification: WormaCeptorPushNotification(
                title: "Your order shipped",
                body: "Arrives Thursday",
                threadId: "orders",
                priority: .high,
                data: ["deeplink": "sample://orders/42"]
            ),
            isBuiltIn: false
        ),
    ]

    static let webSocketConnections: [WormaCeptorWebSocketConnection] = [
        WormaCeptorWebSocketConnection(
            id: 2, url: "wss://echo.example.com/chat?room=42", state: .open, openedAtMs: KotlinLong(longLong: now - 8_000),
            closedAtMs: nil, closeCode: nil, closeReason: nil, durationMs: KotlinLong(longLong: 8_000), frameCount: 3
        ),
        WormaCeptorWebSocketConnection(
            id: 1, url: "wss://stream.example.com/prices", state: .closed, openedAtMs: KotlinLong(longLong: now - 60_000),
            closedAtMs: KotlinLong(longLong: now - 30_000), closeCode: KotlinInt(int: 1001), closeReason: "going away",
            durationMs: KotlinLong(longLong: 30_000), frameCount: 0
        ),
    ]

    static let webSocketFrames: [WormaCeptorWebSocketFrame] = [
        WormaCeptorWebSocketFrame(
            id: 1, connectionId: 2, type: .text, direction: .sent, payload: "{\"type\":\"join\",\"room\":42}",
            timestampMs: now - 7_000, size: 26
        ),
        WormaCeptorWebSocketFrame(
            id: 2, connectionId: 2, type: .binary, direction: .received, payload: "cafe0042", timestampMs: now - 6_000,
            size: 4
        ),
        WormaCeptorWebSocketFrame(
            id: 3, connectionId: 2, type: .ping, direction: .sent, payload: "", timestampMs: now - 5_000, size: 0
        ),
    ]

    static let webViewPages: [WormaCeptorWebViewPage] = [
        WormaCeptorWebViewPage(
            id: 1, webViewId: "WebView 1", url: "https://shop.example.com/cart", startedMs: now - 4_000,
            finishedMs: KotlinLong(longLong: now - 3_200), isLoading: false,
            requests: [
                WormaCeptorWebViewRequest(
                    id: "WebView 1/a", kind: "fetch", method: "POST", url: "https://shop.example.com/api/cart",
                    host: "shop.example.com", path: "/api/cart", isMainFrame: true, statusCode: KotlinInt(int: 200),
                    tone: .success, mimeType: "application/json", contentLength: KotlinLong(longLong: 512),
                    durationMs: KotlinLong(longLong: 142), error: nil,
                    requestHeaders: [WormaCeptorInfoRow(label: "content-type", value: "application/json")],
                    responseHeaders: [WormaCeptorInfoRow(label: "content-type", value: "application/json")],
                    timestampMs: now - 3_500, isPending: false
                ),
                WormaCeptorWebViewRequest(
                    id: "WebView 1/b", kind: "XHR", method: "GET", url: "https://ads.example.net/slot",
                    host: "ads.example.net", path: "/slot", isMainFrame: false, statusCode: nil, tone: .error,
                    mimeType: nil, contentLength: nil, durationMs: KotlinLong(longLong: 30), error: "Network error",
                    requestHeaders: [], responseHeaders: [], timestampMs: now - 3_400, isPending: false
                ),
            ]
        ),
    ]
}
#endif
