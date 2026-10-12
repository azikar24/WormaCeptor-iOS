import Foundation
import Security
import WormaCeptor

/// Records each http(s) request in WormaCeptor, then serves a matching mock rule or forwards the request through
/// its own `URLSession`. All capture logic (matching, redaction, body caps, storage) is in Kotlin; this class only
/// moves bytes and callbacks.
///
/// Client callbacks run on the thread that called `startLoading`, in its run loop modes, as Apple's
/// CustomHTTPProtocol sample does. Network throttling never blocks that thread: waits are scheduled, and a paced
/// response reaches the client in order through `PacedDelivery`.
final class WormaCeptorURLProtocol: URLProtocol {
    /// Marks forwarded requests so this protocol doesn't take its own traffic.
    private static let handledKey = WormaCeptorUrlSessionCapture.shared.HandledKey
    private static let bodyChunkSize = 16_384

    private static let forwardingSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = WormaCeptorURLSession.withoutProtocol(configuration.protocolClasses)
        let queue = OperationQueue()
        queue.name = "com.wormadev.wormaceptor.forwarding"
        queue.maxConcurrentOperationCount = 1
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: queue)
    }()

    private var transaction: WormaCeptorUrlTransaction?
    private var clientThread: Thread?
    private var runLoopModes = [RunLoop.Mode.default.rawValue]
    /// Read and written on the client thread only.
    private var isStopped = false
    /// A mock's delay or the throttle's wait before sending.
    private var pendingStart: DispatchWorkItem?
    private var forwardedTask: URLSessionDataTask?
    private let delivery = PacedDelivery()

    // Delegate queue state.
    private var protocolName: String?
    private var tlsVersion: String?
    private var wasRedirected = false
    private var throttle: WormaCeptorUrlThrottle?
    private var pacer: WormaCeptorUrlPacer?

    private let challengeLock = NSLock()
    private var challengeHandler: ((URLSession.AuthChallengeDisposition, URLCredential?) -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        WormaCeptorUrlSessionCapture.shared.shouldCapture(request: request)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        clientThread = Thread.current
        if let mode = RunLoop.current.currentMode, mode != .default {
            runLoopModes.append(mode.rawValue)
        }
        let body = Self.body(of: request)
        var outgoing = request
        // The loading system hands bodies over as a stream, which can be read once.
        if request.httpBodyStream != nil {
            outgoing.httpBody = body
        }
        transaction = WormaCeptorUrlSessionCapture.shared.begin(request: outgoing, body: body)
        if let mock = transaction?.mock() {
            serve(mock)
        } else if let throttle = transaction?.throttle() {
            forward(outgoing, after: throttle)
        } else {
            forward(outgoing)
        }
    }

    override func stopLoading() {
        isStopped = true
        pendingStart?.cancel()
        delivery.cancel()
        forwardedTask?.cancel()
        resolveChallenge(.cancelAuthenticationChallenge, nil)
        // Ignored when the load already finished.
        transaction?.didFail(error: URLError(.cancelled))
    }

    private func forward(_ request: URLRequest) {
        guard let marked = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: marked)
        let task = Self.forwardingSession.dataTask(with: marked as URLRequest)
        task.delegate = ForwardingDelegate(owner: self)
        forwardedTask = task
        task.resume()
    }

    /// Waits out the throttle's latency and upload time, then sends, or fails when packet loss dropped the request.
    private func forward(_ request: URLRequest, after throttle: WormaCeptorUrlThrottle) {
        self.throttle = throttle
        let work = DispatchWorkItem { [weak self] in
            self?.onClientThread { protocolInstance in
                if let error = throttle.error {
                    protocolInstance.transaction?.didFail(error: error)
                    protocolInstance.client?.urlProtocol(protocolInstance, didFailWithError: error)
                } else {
                    protocolInstance.forward(request)
                }
            }
        }
        pendingStart = work
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(throttle.delayMs)), execute: work)
    }

    private func serve(_ mock: WormaCeptorUrlMock) {
        let work = DispatchWorkItem { [weak self] in
            self?.onClientThread { $0.deliver(mock) }
        }
        pendingStart = work
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(mock.delayMs)), execute: work)
    }

    private func deliver(_ mock: WormaCeptorUrlMock) {
        if let error = mock.error {
            transaction?.didFail(error: error)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let response = mock.response else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        transaction?.didReceive(response: response)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        transaction?.didLoad(data: mock.body)
        client?.urlProtocol(self, didLoad: mock.body)
        transaction?.didFinish(protocolName: nil, tlsVersion: nil)
        client?.urlProtocolDidFinishLoading(self)
    }

    /// Runs `work` on the client thread unless loading was stopped by then.
    private func onClientThread(_ work: @escaping (WormaCeptorURLProtocol) -> Void) {
        guard let thread = clientThread else { return }
        let box = ClientWork { [self] in
            if !isStopped { work(self) }
        }
        perform(#selector(runClientWork(_:)), on: thread, with: box, waitUntilDone: false, modes: runLoopModes)
    }

    @objc private func runClientWork(_ box: ClientWork) {
        box.run()
    }

    /// Like `onClientThread`, but once the response is paced, behind the paced data and `delayMs` from now at the
    /// earliest. Forwarding queue only.
    private func toClient(afterMs delayMs: Int64 = 0, _ work: @escaping (WormaCeptorURLProtocol) -> Void) {
        guard pacer != nil else {
            onClientThread(work)
            return
        }
        delivery.enqueue(afterMs: delayMs) { [weak self] in
            self?.onClientThread(work)
        }
    }

    fileprivate func resolveChallenge(_ disposition: URLSession.AuthChallengeDisposition, _ credential: URLCredential?) {
        challengeLock.lock()
        let handler = challengeHandler
        challengeHandler = nil
        challengeLock.unlock()
        handler?(disposition, credential)
    }

    private static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: bodyChunkSize)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private static func name(of version: tls_protocol_version_t) -> String {
        switch version {
        case .TLSv10: return "TLSv1"
        case .TLSv11: return "TLSv1.1"
        case .TLSv12: return "TLSv1.2"
        case .TLSv13: return "TLSv1.3"
        case .DTLSv10: return "DTLSv1"
        case .DTLSv12: return "DTLSv1.2"
        @unknown default: return "unknown"
        }
    }
}

/// The forwarding task's callbacks, delivered through `ForwardingDelegate`.
extension WormaCeptorURLProtocol {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        transaction?.didReceive(response: response)
        pacer = throttle?.startDownload()
        toClient { $0.client?.urlProtocol($0, didReceive: response, cacheStoragePolicy: .notAllowed) }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        transaction?.didLoad(data: data)
        guard let pacer else {
            onClientThread { $0.client?.urlProtocol($0, didLoad: data) }
            return
        }
        let size = Int(pacer.chunkBytes)
        for start in stride(from: data.startIndex, to: data.endIndex, by: size) {
            let chunk = data.subdata(in: start..<min(start + size, data.endIndex))
            toClient(afterMs: pacer.delayMsFor(count: Int64(chunk.count))) {
                $0.client?.urlProtocol($0, didLoad: chunk)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let last = metrics.transactionMetrics.last
        protocolName = last?.networkProtocolName
        tlsVersion = last?.negotiatedTLSProtocolVersion.map(Self.name(of:))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if wasRedirected { return }
        if let error {
            transaction?.didFail(error: error)
            toClient { $0.client?.urlProtocol($0, didFailWithError: error) }
        } else {
            transaction?.didFinish(protocolName: protocolName, tlsVersion: tlsVersion)
            toClient { $0.client?.urlProtocolDidFinishLoading($0) }
        }
    }

    /// Hands the redirect to the app's session, which decides whether to follow it with a new request through this
    /// protocol. The 3xx response is recorded as its own transaction.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        transaction?.didReceive(response: response)
        transaction?.didFinish(protocolName: protocolName, tlsVersion: tlsVersion)
        guard let redirect = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            completionHandler(request)
            return
        }
        URLProtocol.removeProperty(forKey: Self.handledKey, in: redirect)
        wasRedirected = true
        task.cancel()
        completionHandler(nil)
        onClientThread {
            $0.client?.urlProtocol($0, wasRedirectedTo: redirect as URLRequest, redirectResponse: response)
            $0.client?.urlProtocol($0, didFailWithError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        }
    }

    /// Passes the challenge to the app's session (its delegate, or default handling), as if no protocol were there.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        challengeLock.lock()
        challengeHandler = completionHandler
        challengeLock.unlock()
        let sender = ForwardingDelegate(owner: self)
        let forwarded = URLAuthenticationChallenge(authenticationChallenge: challenge, sender: sender)
        onClientThread { $0.client?.urlProtocol($0, didReceive: forwarded) }
    }
}

/// The forwarding task's delegate and the challenge sender handed to the app. Both protocols are `Sendable`, which a
/// `URLProtocol` subclass can't be, so this object takes the calls and passes them to its protocol. URLSession calls the
/// delegate serially on the forwarding queue; the protocol guards the challenge handler with a lock.
private final class ForwardingDelegate: NSObject, URLSessionDataDelegate, URLAuthenticationChallengeSender,
    @unchecked Sendable {
    // Strong, as the task held the protocol before: the task releases its delegate when it completes.
    private let owner: WormaCeptorURLProtocol

    init(owner: WormaCeptorURLProtocol) {
        self.owner = owner
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        owner.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        owner.urlSession(session, dataTask: dataTask, didReceive: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        owner.urlSession(session, task: task, didFinishCollecting: metrics)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        owner.urlSession(session, task: task, didCompleteWithError: error)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        owner.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: request,
            completionHandler: completionHandler
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        owner.urlSession(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        owner.resolveChallenge(.useCredential, credential)
    }

    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        owner.resolveChallenge(.useCredential, nil)
    }

    func cancel(_ challenge: URLAuthenticationChallenge) {
        owner.resolveChallenge(.cancelAuthenticationChallenge, nil)
    }

    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {
        owner.resolveChallenge(.performDefaultHandling, nil)
    }

    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {
        owner.resolveChallenge(.rejectProtectionSpace, nil)
    }
}

/// Runs throttled deliveries one at a time, in the order they were queued, each no earlier than its due time, so a
/// paced body arrives in order and the completion after the last chunk. Nothing runs after `cancel()`.
private final class PacedDelivery: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.wormadev.wormaceptor.throttle")
    /// Touched on `queue` only.
    private var pending: [(due: DispatchTime, run: () -> Void)] = []
    private var isWaiting = false
    private var isCancelled = false

    func enqueue(afterMs delayMs: Int64, _ run: @escaping () -> Void) {
        let due = DispatchTime.now() + .milliseconds(Int(delayMs))
        queue.async { [self] in
            guard !isCancelled else { return }
            pending.append((due, run))
            runNext()
        }
    }

    func cancel() {
        queue.async { [self] in
            isCancelled = true
            pending.removeAll()
        }
    }

    private func runNext() {
        guard !isWaiting, !isCancelled, !pending.isEmpty else { return }
        let next = pending.removeFirst()
        isWaiting = true
        queue.asyncAfter(deadline: next.due) { [weak self] in
            guard let self else { return }
            isWaiting = false
            if !isCancelled { next.run() }
            runNext()
        }
    }
}

/// A closure `perform(_:on:with:waitUntilDone:modes:)` can carry.
private final class ClientWork: NSObject {
    let run: () -> Void

    init(_ run: @escaping () -> Void) {
        self.run = run
    }
}
