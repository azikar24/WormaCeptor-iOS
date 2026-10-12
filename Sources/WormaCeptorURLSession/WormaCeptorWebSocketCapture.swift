import Foundation
import ObjectiveC
import WormaCeptor

/// Records `URLSessionWebSocketTask` connections and frames in `WormaCeptorWebSockets`, for every session, including
/// Ktor's Darwin engine. Off until `install()`, as on Android, where the host wraps its listener.
///
/// ```swift
/// WormaCeptorWebSocketCapture.install()
/// ```
///
/// It replaces methods on Foundation's private WebSocket task class. When a later iOS renames the class or a method,
/// capture of that part stops and a line is logged; the app's sockets keep working.
public enum WormaCeptorWebSocketCapture {
    /// Hooks the task class. Safe to call more than once. Tasks resumed before the call are tracked from their next
    /// frame on.
    public static func install() {
        _ = installOnce
    }

    private static let taskClassName = "__NSURLSessionWebSocketTask"

    private static let installOnce: Void = {
        guard let taskClass = NSClassFromString(taskClassName) else {
            print("WormaCeptor: \(taskClassName) not found; WebSocket frames are not captured")
            return
        }
        hookResume(taskClass)
        hookSend(taskClass)
        hookReceive(taskClass)
        hookPing(taskClass)
        hookCancel(taskClass)
    }()

    private static let records = WormaCeptorWebSockets.shared

    private typealias ResumeFunction = @convention(c) (NSObject, Selector) -> Void
    private typealias Completion = @convention(block) (NSError?) -> Void
    private typealias SendFunction = @convention(c) (NSObject, Selector, NSObject, Completion?) -> Void
    private typealias ReceiveCompletion = @convention(block) (NSObject?, NSError?) -> Void
    private typealias ReceiveFunction = @convention(c) (NSObject, Selector, ReceiveCompletion?) -> Void
    private typealias PingFunction = @convention(c) (NSObject, Selector, Completion?) -> Void
    private typealias CancelFunction = @convention(c) (NSObject, Selector, Int, NSData?) -> Void

    private static func hookResume(_ taskClass: AnyClass) {
        replace(taskClass, "resume") { original, selector in
            let call = unsafeBitCast(original, to: ResumeFunction.self)
            let block: @convention(block) (NSObject) -> Void = { task in
                _ = connectionId(of: task)
                call(task, selector)
            }
            return block
        }
    }

    private static func hookSend(_ taskClass: AnyClass) {
        replace(taskClass, "sendMessage:completionHandler:") { original, selector in
            let call = unsafeBitCast(original, to: SendFunction.self)
            let block: @convention(block) (NSObject, NSObject, Completion?) -> Void = { task, message, completion in
                record(message, direction: .sent, on: task)
                call(task, selector, message, completion)
            }
            return block
        }
    }

    private static func hookReceive(_ taskClass: AnyClass) {
        replace(taskClass, "receiveMessageWithCompletionHandler:") { original, selector in
            let call = unsafeBitCast(original, to: ReceiveFunction.self)
            let block: @convention(block) (NSObject, ReceiveCompletion?) -> Void = { task, completion in
                let wrapped: ReceiveCompletion = { message, error in
                    if let message {
                        record(message, direction: .received, on: task)
                    } else if let error {
                        recordEnd(of: task, error: error)
                    }
                    completion?(message, error)
                }
                call(task, selector, wrapped)
            }
            return block
        }
    }

    private static func hookPing(_ taskClass: AnyClass) {
        replace(taskClass, "sendPingWithPongReceiveHandler:") { original, selector in
            let call = unsafeBitCast(original, to: PingFunction.self)
            let block: @convention(block) (NSObject, Completion?) -> Void = { task, completion in
                let id = connectionId(of: task)
                records.ping(connectionId: id)
                let wrapped: Completion = { error in
                    if error == nil { records.pong(connectionId: id) }
                    completion?(error)
                }
                call(task, selector, wrapped)
            }
            return block
        }
    }

    private static func hookCancel(_ taskClass: AnyClass) {
        replace(taskClass, "cancelWithCloseCode:reason:") { original, selector in
            let call = unsafeBitCast(original, to: CancelFunction.self)
            let block: @convention(block) (NSObject, Int, NSData?) -> Void = { task, code, reason in
                records.connectionClosed(
                    connectionId: connectionId(of: task),
                    code: Int32(truncatingIfNeeded: code),
                    reason: reason.flatMap { String(data: $0 as Data, encoding: .utf8) }
                )
                call(task, selector, code, reason)
            }
            return block
        }
    }

    /// Points `name` on `taskClass` at the block `makeBlock` returns for the current implementation. An inherited
    /// method gets an override on `taskClass` only, so other task classes keep the original.
    private static func replace(_ taskClass: AnyClass, _ name: String, makeBlock: (IMP, Selector) -> Any) {
        let selector = NSSelectorFromString(name)
        guard taskClass.instancesRespond(to: selector), let method = class_getInstanceMethod(taskClass, selector) else {
            print("WormaCeptor: \(taskClassName) has no \(name); that part of WebSocket capture is off")
            return
        }
        let replacement = imp_implementationWithBlock(makeBlock(method_getImplementation(method), selector))
        if !class_addMethod(taskClass, selector, replacement, method_getTypeEncoding(method)) {
            method_setImplementation(method, replacement)
        }
    }

    private static var connectionKey: UInt8 = 0
    private static let connectionLock = NSLock()

    /// The task's connection id, registering the connection the first time.
    private static func connectionId(of task: NSObject) -> Int64 {
        connectionLock.lock()
        defer { connectionLock.unlock() }
        if let id = objc_getAssociatedObject(task, &connectionKey) as? NSNumber {
            return id.int64Value
        }
        let request = (task as? URLSessionTask).flatMap { $0.originalRequest ?? $0.currentRequest }
        let id = records.connectionStarted(url: request?.url.map(webSocketUrl)?.absoluteString ?? "")
        objc_setAssociatedObject(task, &connectionKey, NSNumber(value: id), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return id
    }

    /// The task's request carries the http(s) form of the URL; shows it as the ws(s) URL the app asked for.
    private static func webSocketUrl(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        switch components.scheme?.lowercased() {
        case "http": components.scheme = "ws"
        case "https": components.scheme = "wss"
        default: break
        }
        return components.url ?? url
    }

    /// Records an `NSURLSessionWebSocketMessage`, read by key since Swift only sees the bridged enum.
    private static func record(_ message: NSObject, direction: WormaCeptorWebSocketDirection, on task: NSObject) {
        let id = connectionId(of: task)
        if let text = message.value(forKey: "string") as? String {
            records.textFrame(connectionId: id, direction: direction, text: text)
        } else if let data = message.value(forKey: "data") as? Data {
            records.binaryFrame(connectionId: id, direction: direction, data: data)
        }
    }

    /// A failed receive ends the socket: closed with the peer's code when it sent one, else failed.
    private static func recordEnd(of task: NSObject, error: NSError) {
        let id = connectionId(of: task)
        guard let socket = task as? URLSessionWebSocketTask, socket.closeCode != .invalid else {
            records.connectionFailed(connectionId: id, reason: error.localizedDescription)
            return
        }
        records.connectionClosed(
            connectionId: id,
            code: Int32(socket.closeCode.rawValue),
            reason: socket.closeReason.flatMap { String(data: $0, encoding: .utf8) }
        )
    }
}
