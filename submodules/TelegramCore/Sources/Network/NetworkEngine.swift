import Foundation
import SwiftSignalKit
import MtProtoKit

/// The MTProto implementation that carries a `Network`'s sessions.
public enum NetworkEngineKind: String, Codable, Equatable {
    case mtProtoKit
    case rust
}

/// Per-request transport options.
public struct NetworkEngineRequestOptions: Equatable {
    /// When a request with `expectedResponseSize >= 512 KB` is cancelled while it is in flight,
    /// the session is reset so that the large response is not downloaded.
    public var expectedResponseSize: Int32
    /// When set, a pending request that sees no transport activity for 5 seconds triggers a
    /// secure transport reset and a new transport transaction.
    public var needsTimeoutTimer: Bool
    
    public init(expectedResponseSize: Int32 = 0, needsTimeoutTimer: Bool = false) {
        self.expectedResponseSize = expectedResponseSize
        self.needsTimeoutTimer = needsTimeoutTimer
    }
}

/// Snapshot of the per-request error state passed to `NetworkEngineRequest.shouldContinueAfterError`.
/// The underlying state is cumulative for the lifetime of a request: a value set by an earlier
/// error (for example `floodWaitSeconds`) is still present when a later error is reported.
public struct NetworkEngineErrorContext: Equatable {
    public var floodWaitSeconds: Int
    public var floodWaitErrorText: String?
    public var internalServerErrorCount: Int
    
    public init(floodWaitSeconds: Int, floodWaitErrorText: String?, internalServerErrorCount: Int) {
        self.floodWaitSeconds = floodWaitSeconds
        self.floodWaitErrorText = floodWaitErrorText
        self.internalServerErrorCount = internalServerErrorCount
    }
}

/// Metadata of the message that completed a request.
public struct NetworkEngineResponseInfo: Equatable {
    /// Server time of the response message, in seconds since 1970.
    public var timestamp: Double
    /// Network the response arrived on: 0 means wifi or other, any other value means cellular.
    public var networkType: Int32
    /// Seconds between sending the request and receiving the response, or 0 when unknown.
    public var duration: Double
    
    public init(timestamp: Double, networkType: Int32, duration: Double) {
        self.timestamp = timestamp
        self.networkType = networkType
        self.duration = duration
    }
}

/// A successful response. `result` is the value returned by `NetworkEngineRequest.parse`.
public struct NetworkEngineResponse {
    public let result: Any
    public let info: NetworkEngineResponseInfo
    
    public init(result: Any, info: NetworkEngineResponseInfo) {
        self.result = result
        self.info = info
    }
}

/// A failed request. `error` carries the `rpc_error` code and text exactly as received,
/// or an error synthesized by the engine (for example `500 TL_PARSING_ERROR`).
public struct NetworkEngineRequestFailure: Error {
    public let error: MTRpcError
    public let info: NetworkEngineResponseInfo
    
    public init(error: MTRpcError, info: NetworkEngineResponseInfo) {
        self.error = error
        self.info = info
    }
}

/// One RPC call. Built by TelegramCore and executed by a `NetworkEngineRequestService`.
public final class NetworkEngineRequest {
    /// The TL-serialized API function. Opaque to the engine.
    public let payload: Data
    /// Description used for logging. Also the carrier of the dependency tag read by `dependsOn`.
    public let metadata: WrappedRequestMetadata
    /// Short description used for logging.
    public let shortMetadata: WrappedRequestShortMetadata
    /// Parses the body of `rpc_result` (after gzip unwrapping). A nil result must complete the
    /// request with `500 TL_PARSING_ERROR` and clear the auth key's `apiInitializationHash`.
    public let parse: (Data) -> Any?
    public let options: NetworkEngineRequestOptions
    /// When set, the request is sent wrapped in `invokeAfterMsg` pointing at the latest earlier
    /// pending request whose metadata this closure accepts.
    public let dependsOn: ((WrappedRequestMetadata) -> Bool)?
    /// When set, a quick ack is requested for the request and this closure is called when it arrives.
    public let acknowledged: (() -> Void)?
    /// When set, called with the receive progress of the response packet and the packet length.
    public let progress: ((Float, Int) -> Void)?
    private let shouldContinueAfterErrorImpl: (NetworkEngineErrorContext) -> Bool
    private let completedImpl: (Result<NetworkEngineResponse, NetworkEngineRequestFailure>) -> Void
    /// Set by `NetworkTelemetry` before the request reaches an engine, and only read afterwards.
    var telemetry: NetworkTelemetry?
    var telemetryInfo: NetworkTelemetryRequestInfo?
    var telemetryProgress = NetworkTelemetryRequestProgress()
    
    init(
        payload: Data,
        metadata: WrappedRequestMetadata,
        shortMetadata: WrappedRequestShortMetadata,
        parse: @escaping (Data) -> Any?,
        options: NetworkEngineRequestOptions,
        shouldContinueAfterError: @escaping (NetworkEngineErrorContext) -> Bool,
        dependsOn: ((WrappedRequestMetadata) -> Bool)?,
        acknowledged: (() -> Void)?,
        progress: ((Float, Int) -> Void)?,
        completed: @escaping (Result<NetworkEngineResponse, NetworkEngineRequestFailure>) -> Void
    ) {
        self.payload = payload
        self.metadata = metadata
        self.shortMetadata = shortMetadata
        self.parse = parse
        self.options = options
        self.shouldContinueAfterErrorImpl = shouldContinueAfterError
        self.dependsOn = dependsOn
        self.acknowledged = acknowledged
        self.progress = progress
        self.completedImpl = completed
    }
    
    /// Asked on `FLOOD_WAIT_X`, `FLOOD_PREMIUM_WAIT_X` and `500`/`-500` errors. `true` retries the
    /// request after the wait (2 seconds for server errors), `false` completes it with the error.
    public func shouldContinueAfterError(_ context: NetworkEngineErrorContext) -> Bool {
        let result = self.shouldContinueAfterErrorImpl(context)
        if let telemetry = self.telemetry {
            telemetry.errorHandled(request: self, context: context, retried: result)
        }
        return result
    }
    
    /// Called by the engine exactly once, unless the request is cancelled first.
    public func completed(_ result: Result<NetworkEngineResponse, NetworkEngineRequestFailure>) {
        if let telemetry = self.telemetry, let info = self.telemetryInfo {
            telemetry.completed(request: self, info: info, result: result)
        }
        self.completedImpl(result)
    }
    
    deinit {
        if let telemetry = self.telemetry, let info = self.telemetryInfo, !self.telemetryProgress.finished {
            telemetry.released(request: self, info: info)
        }
    }
}

/// Receiver of non-RPC messages pushed by the server on a session.
public protocol NetworkEngineUpdateSink: AnyObject {
    /// The session was reset on either side (a new client session, or `new_session_created`).
    /// Updates may have been lost, so the receiver must resynchronize.
    func networkSessionDidReset()
    /// A parsed message that is not an MTProto service message or an `rpc_result`, in receive
    /// order. `message` is the value produced by `MTContext.serialization.parseMessage`.
    func networkSessionDidReceive(message: Any)
}

public struct NetworkEngineConnectionState: Equatable {
    public var isNetworkAvailable: Bool
    public var isConnected: Bool
    public var isUpdatingConnectionContext: Bool
    public var isPerformingServiceTasks: Bool
    public var proxyAddress: String?
    public var proxyHasConnectionIssues: Bool
    
    public init(isNetworkAvailable: Bool, isConnected: Bool, isUpdatingConnectionContext: Bool, isPerformingServiceTasks: Bool, proxyAddress: String?, proxyHasConnectionIssues: Bool) {
        self.isNetworkAvailable = isNetworkAvailable
        self.isConnected = isConnected
        self.isUpdatingConnectionContext = isUpdatingConnectionContext
        self.isPerformingServiceTasks = isPerformingServiceTasks
        self.proxyAddress = proxyAddress
        self.proxyHasConnectionIssues = proxyHasConnectionIssues
    }
}

/// Events of the main session. Worker sessions are created without a delegate.
public protocol NetworkEngineSessionDelegate: AnyObject {
    /// A `401` other than `SESSION_PASSWORD_NEEDED` and `AUTH_KEY_PERM_EMPTY` on the main session.
    /// This logs the account out irreversibly.
    func networkSessionAuthorizationRequired()
    /// Any `406` error.
    func networkSessionSoftAuthReset()
    func networkSessionConnectionStateChanged(_ state: NetworkEngineConnectionState)
}

/// Request scheduler of a session.
///
/// `Network` keeps a strong reference to its request service inside every cold request signal.
/// A request service must therefore not keep the session's connection alive by itself: once the
/// session is released, `add` must be a no-op whose request never completes.
public protocol NetworkEngineRequestService: AnyObject {
    /// Submits a request from any thread without blocking. Disposing the returned disposable
    /// cancels the request; it is safe from any thread, at any time, also after the session is gone.
    /// No callback of the request may run after its cancellation has been processed.
    /// Returns `EmptyDisposable` exactly when the request is refused and will never complete (its
    /// session is gone); `NetworkTelemetry` records such a request as dropped.
    func add(_ request: NetworkEngineRequest) -> Disposable
}

/// One MTProto session (one session id, one transport) to one datacenter.
public protocol NetworkEngineSession: AnyObject {
    var datacenterId: Int { get }
    var requestService: NetworkEngineRequestService { get }
    /// Sessions are created paused. Pausing drops the transport; resuming reconnects.
    func setPaused(_ paused: Bool)
    /// The user is actively using the account (app in the foreground, primary account). An engine
    /// may use it to choose keepalive timing. Sessions start offline; `Network` applies its current
    /// value right after creating a session.
    func setOnline(_ online: Bool)
    func addUpdateSink(_ sink: NetworkEngineUpdateSink)
    /// Tears a worker session down. The main session is never stopped explicitly.
    func stop()
    /// Moves every request that has not completed to `service`, as if it had been added there:
    /// the session never calls back for a moved request, and disposing the disposable `add`
    /// returned for it cancels it on `service`. `completion` runs once every request has moved.
    func movePendingRequests(to service: NetworkEngineRequestService, completion: @escaping () -> Void)
    /// Calls `observer` whenever the engine gives up on one of the session's connections. Engines
    /// that cannot tell why need not call it.
    func observeConnectionDrops(_ observer: @escaping (NetworkEngineConnectionDrop) -> Void)
}

public extension NetworkEngineSession {
    func observeConnectionDrops(_ observer: @escaping (NetworkEngineConnectionDrop) -> Void) {
    }
}

/// A connection the engine gave up on: which of its checks decided, whether the session had taken
/// a packet from it, and seconds since it started connecting.
public struct NetworkEngineConnectionDrop: Equatable {
    public var reason: String
    public var answered: Bool
    public var age: Double

    public init(reason: String, answered: Bool, age: Double) {
        self.reason = reason
        self.answered = answered
        self.age = age
    }
}

public enum NetworkEngineSessionRole: Equatable {
    /// The account's session to its master datacenter: receives updates and drives the connection status.
    case main
    /// A download or upload session. For a foreign datacenter that is not a CDN, the session
    /// imports the authorization from `masterDatacenterId` and re-imports it after a `401`.
    case worker(masterDatacenterId: Int, isMedia: Bool, isCdn: Bool)
}

/// Creates sessions bound to one `MTContext`, which stays the owner of configuration and
/// persisted state (auth keys, salts, tokens, addresses, time difference).
public protocol NetworkEngine: AnyObject {
    var kind: NetworkEngineKind { get }
    /// `delegate` is held weakly and must be set before the session can report anything.
    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession
}

/// Supplies an alternative engine. Passed through `NetworkInitializationArguments`, so a process
/// that does not pass one (extensions) stays on MtProtoKit.
public protocol NetworkEngineFactory {
    /// Returns nil when the engine cannot serve this context (for example an unsupported proxy
    /// configuration); the network then uses MtProtoKit. The TCP connection factory to use is
    /// `context.makeTcpConnectionInterface`, which changes when the proxy changes.
    func makeEngine(context: MTContext, isAppExtension: Bool) -> NetworkEngine?
    /// The engine carries WEB proxies itself; otherwise the network moves to MtProtoKit while one is on.
    var supportsWebProxy: Bool { get }
}

public extension NetworkEngineFactory {
    var supportsWebProxy: Bool {
        return false
    }
}
