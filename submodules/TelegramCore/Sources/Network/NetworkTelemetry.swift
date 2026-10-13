import Foundation
import SwiftSignalKit
import MtProtoKit

/// Server-controlled switches for network telemetry, read from the app configuration.
///
/// `network_telemetry_enabled` turns recording (from the next launch) and reporting on,
/// `network_telemetry_variant` labels an A/B arm, and `network_telemetry_report_interval`
/// sets how often a report is sent, in seconds (clamped to 1 hour ... 7 days).
public struct NetworkTelemetryConfiguration: Equatable {
    public static let disabled = NetworkTelemetryConfiguration(isEnabled: false, variant: nil, reportInterval: 24 * 60 * 60)

    public var isEnabled: Bool
    public var variant: String?
    public var reportInterval: Double

    public init(isEnabled: Bool, variant: String?, reportInterval: Double) {
        self.isEnabled = isEnabled
        self.variant = variant
        self.reportInterval = reportInterval
    }

    public static func with(appConfiguration: AppConfiguration) -> NetworkTelemetryConfiguration {
        guard let data = appConfiguration.data else {
            return .disabled
        }
        var result = NetworkTelemetryConfiguration.disabled
        switch data["network_telemetry_enabled"] {
        case let value as Bool:
            result.isEnabled = value
        case let value as Double:
            result.isEnabled = value != 0.0
        case let value as String:
            result.isEnabled = !["", "0", "false", "no"].contains(value.lowercased())
        default:
            break
        }
        if let variant = data["network_telemetry_variant"] as? String, !variant.isEmpty {
            result.variant = networkTelemetryToken(variant, maxLength: 32)
        }
        if let interval = data["network_telemetry_report_interval"] as? Double {
            result.reportInterval = min(max(interval, 60.0 * 60.0), 7.0 * 24.0 * 60.0 * 60.0)
        }
        return result
    }
}

#if DEBUG
let networkTelemetryAlwaysRecords = true
#else
let networkTelemetryAlwaysRecords = false
#endif

/// Settings that benchmarks and tests replace to measure the recording itself.
struct NetworkTelemetryOverrides {
    var recording: Bool?
    var stalledAfter: Double?
    var watchEvery: Int?
}

var networkTelemetryOverrides = NetworkTelemetryOverrides()

/// Records the networks of the app's accounts while the server enables it, and always in Debug builds.
/// Extensions and supplementary networks never record.
func networkTelemetryShouldRecord(supplementary: Bool, isAppExtension: Bool, configuration: NetworkTelemetryConfiguration) -> Bool {
    if let recording = networkTelemetryOverrides.recording {
        return recording
    }
    if supplementary || isAppExtension {
        return false
    }
    return networkTelemetryAlwaysRecords || configuration.isEnabled
}

func networkTelemetrySystemVersion() -> String {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    #if os(macOS)
    let system = "macos"
    #else
    let system = "ios"
    #endif
    return "\(system)-\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
}

/// The kind of session a request ran on.
public enum NetworkTelemetryRole: String, Codable, Equatable, CaseIterable {
    case main
    case worker
    case media
    case cdn

    init(_ role: NetworkEngineSessionRole) {
        switch role {
        case .main:
            self = .main
        case let .worker(_, isMedia, isCdn):
            if isCdn {
                self = .cdn
            } else if isMedia {
                self = .media
            } else {
                self = .worker
            }
        }
    }

    var index: Int {
        switch self {
        case .main:
            return 0
        case .worker:
            return 1
        case .media:
            return 2
        case .cdn:
            return 3
        }
    }
}

/// What went wrong with a request.
public enum NetworkFailureClass: String, Codable, Equatable, CaseIterable {
    /// A 4xx error other than the ones below. Usually an expected answer, sometimes a client bug.
    case client
    /// 401 or 406.
    case auth
    /// 303: the request has to be repeated on another datacenter.
    case migrate
    /// 420 or a FLOOD_* error.
    case flood
    /// A 5xx or negative code from the server or the engine.
    case server
    /// The response could not be parsed or had an unexpected type (TL_* errors).
    case parse
    /// The request never completed and was released after waiting at least
    /// `NetworkTelemetry.abandonedAfter`: it was cancelled, or dropped with its session.
    case abandoned
    /// The engine refused the request when it was added, because its session was gone. The caller
    /// waits forever.
    case dropped
    /// The request had waited `NetworkTelemetry.stalledAfter` seconds of connected, active time, over
    /// any number of reconnects and not counting flood waits, and was still waiting. Recorded once,
    /// while the request goes on waiting. Only one request in `NetworkTelemetry.watchEvery` is watched.
    case stalled
    /// The request succeeded, but took longer than `NetworkTelemetry.slowAfter`, not counting flood
    /// waits and time the app spent suspended.
    case slow
}

/// The connection status of the main session, as the app shows it.
public enum NetworkTelemetryConnectionState: String, Codable, Equatable, CaseIterable {
    case waitingForNetwork = "waiting_network"
    case connecting
    case connectingWithProxyIssues = "connecting_proxy_issues"
    case updating
    case online

    init(_ state: NetworkEngineConnectionState) {
        if !state.isNetworkAvailable {
            self = .waitingForNetwork
        } else if !state.isConnected {
            self = state.proxyHasConnectionIssues ? .connectingWithProxyIssues : .connecting
        } else if state.isUpdatingConnectionContext || state.isPerformingServiceTasks {
            self = .updating
        } else {
            self = .online
        }
    }

    var isConnected: Bool {
        return self == .online || self == .updating
    }
}

public struct NetworkTelemetryConnectionEvent: Codable, Equatable {
    /// Seconds between this change and the failure it is attached to.
    public var ago: Double
    public var state: NetworkTelemetryConnectionState
}

/// A connection the engine gave up on, from engines that tell why.
public struct NetworkTelemetryDrop: Codable, Equatable {
    /// Seconds between the drop and the failure it is attached to.
    public var ago: Double
    /// Which of the engine's checks decided, such as `probe_timeout` or `racer_won`.
    public var reason: String
    /// Whether the session had taken a packet from the connection; the auth key handshake does not
    /// count.
    public var answered: Bool
    /// Seconds the connection lived, from starting to connect.
    public var age: Double
}

/// One failed, abandoned, dropped, stalled or slow request, with the context needed to reproduce it.
///
/// Anonymized by construction: the API method name but no parameters, the server's error constant
/// with numbers and tokens replaced, sizes rounded up to a power of two, coarse time (the hour),
/// the app and system versions, and no user, peer, content, address or proxy data.
public struct NetworkFailureRecord: Codable, Equatable {
    public var schema: Int32
    /// Increases with every record of the account; a gap means records were dropped.
    public var sequence: Int64
    /// Unix time floored to the hour.
    public var hour: Int32
    /// Seconds since the network was created, not counting device sleep.
    public var uptime: Int32
    public var engine: String
    public var variant: String?
    public var role: NetworkTelemetryRole
    public var datacenter: Int32
    public var method: String
    public var failure: NetworkFailureClass
    public var code: Int32
    public var error: String
    /// Seconds from submitting the request to its completion, release or stall check, not counting
    /// device sleep.
    public var duration: Double
    /// True when the app was suspended at some point while the request was waiting.
    public var spannedSuspension: Bool
    /// Flood waits and server errors the request waited out before this result.
    public var retries: Int32
    /// Seconds of all the flood waits.
    public var floodWait: Int32
    public var serverErrors: Int32
    /// The request's size rounded up to a power of two.
    public var requestBytes: Int32
    /// The response size the caller expects, rounded up to a power of two.
    public var expectedBytes: Int32
    public var cellular: Bool?
    public var viaProxy: Bool
    /// Whether the user was online, as while the app is in front: the main session then pings every
    /// round trip and gives up on a silent connection after a few, where an offline one waits
    /// minutes. Nil until the account set it.
    public var userOnline: Bool?
    /// The latest connection status changes before the failure, oldest first.
    public var connection: [NetworkTelemetryConnectionEvent]
    /// The latest connections of sessions of the same role the engine gave up on within
    /// `transferWindow` seconds, oldest first. Nil when there were none or the engine does not tell.
    public var drops: [NetworkTelemetryDrop]?
    /// Seconds since the connection was last online or updating (0 while it is), if it ever was.
    public var sinceOnline: Double?
    /// Requests in flight on all sessions, estimated from the requests watched for stalls at the
    /// latest check. Nil before the first check.
    public var inFlight: Int32?
    /// Latency of the latest successful requests on sessions of the same role.
    public var latencyP50: Double?
    public var latencyP90: Double?
    public var latencySamples: Int32
    /// On records of other sessions, the latency of the main session's latest small requests that
    /// stayed connected throughout: close to the link's round trip (plus server time), which a
    /// transfer's own latency does not show. The latest `latencyHistory` of them, however old.
    public var mainLatencyP50: Double?
    public var mainLatencyP90: Double?
    /// Bytes per second the latest uploads of `transferMinBytes` or more moved at together, over the
    /// time any of them was running, rounded up to a power of two. Nil without one in the last
    /// `transferWindow` seconds.
    public var uplinkRate: Int32?
    /// The same for downloads, by the size the caller asked for.
    public var downlinkRate: Int32?
    public var layer: Int32
    public var app: String
    public var system: String
}

public struct NetworkTelemetryMethodSummary: Codable, Equatable {
    public var engine: String
    public var role: NetworkTelemetryRole
    public var method: String
    /// Completed requests. Abandoned and dropped requests never complete and appear only in `failures`.
    public var count: Int32
    /// Times completed requests were repeated after a flood wait or a server error.
    public var retries: Int32
    /// Failures by `NetworkFailureClass` raw value.
    public var failures: [String: Int32]
    /// Successful requests per latency bucket; bucket `i` ends at `NetworkTelemetry.latencyBucketBounds[i]`,
    /// the last one is open-ended. Requests that waited through a suspension of the app or a flood
    /// wait are counted in `count` only.
    public var latency: [Int32]
}

public struct NetworkTelemetryConnectionSummary: Codable, Equatable {
    /// Seconds spent in each `NetworkTelemetryConnectionState` raw value while the app was active.
    public var seconds: [String: Double]
    public var transitions: Int32
    /// Changes from online or updating to waiting for network or connecting.
    public var disconnects: Int32
    /// Times from starting to connect, with the network available, to being online or updating,
    /// per latency bucket.
    public var timeToOnline: [Int32]
    /// `new_session_created` and other session resets that can lose updates.
    public var sessionResets: Int32
    /// Connections the engine gave up on, by session role and reason; `_unanswered` marks those the
    /// session never took a packet from. Nil from engines that do not tell.
    public var drops: [String: [String: Int32]]?
}

/// Aggregates of one period, the A/B comparison data. A period ends when it is reported, and when
/// the variant, the app version, the system version or the layer changes, so that every count
/// carries its own labels.
public struct NetworkTelemetrySummary: Codable, Equatable {
    public var schema: Int32
    public var fromHour: Int32
    public var toHour: Int32
    public var variant: String?
    public var layer: Int32
    public var app: String
    public var system: String
    public var requests: Int32
    public var methods: [NetworkTelemetryMethodSummary]
    public var connection: NetworkTelemetryConnectionSummary
    /// Failures that were counted but not kept as records because the buffer was full.
    public var droppedFailures: Int32
}

public struct NetworkTelemetryReport: Equatable {
    /// Ended periods, oldest first, then the current one.
    public let summaries: [NetworkTelemetrySummary]
    public let failures: [NetworkFailureRecord]
}

/// Keeps API strings to a safe alphabet and length.
func networkTelemetryToken(_ value: String, maxLength: Int) -> String {
    var result = String.UnicodeScalarView()
    for scalar in value.unicodeScalars {
        if result.count >= maxLength {
            break
        }
        switch scalar {
        case "A" ... "Z", "a" ... "z", "0" ... "9", "_", ".", "-":
            result.append(scalar)
        default:
            result.append("_")
        }
    }
    return String(result)
}

/// An engine's name for why it dropped a connection: a short lower-case identifier, or `other`.
func networkTelemetryDropReason(_ reason: String) -> String {
    let scalars = reason.unicodeScalars
    if scalars.isEmpty || scalars.count > 32 || !scalars.allSatisfy({ ("a" ... "z").contains($0) || ("0" ... "9").contains($0) || $0 == "_" }) {
        return "other"
    }
    return reason
}

/// Texts the engines produce themselves, kept as they are.
private let networkTelemetryEngineErrorTexts: Set<String> = ["Timeout", "ping timeout", "read timeout", "probe timeout"]

/// The server's error constant with anything variable replaced: per `_`-separated part, digit runs of
/// two or more become `N` (FLOOD_WAIT_37 → FLOOD_WAIT_N, FILE_MIGRATE_4 keeps its datacenter), and
/// parts mixing letters and digits, or longer than 24 letters, become `X` (a token such as the nonce
/// in APNS_VERIFY_CHECK_…). A text that is not an upper-case constant becomes OTHER, so no free text
/// leaves the device.
func networkTelemetryErrorText(_ text: String) -> String {
    if text.isEmpty || networkTelemetryEngineErrorTexts.contains(text) {
        return text
    }
    let scalars = text.unicodeScalars
    if scalars.count > 64 || !scalars.allSatisfy({ ("A" ... "Z").contains($0) || ("0" ... "9").contains($0) || $0 == "_" }) {
        return "OTHER"
    }
    return text.split(separator: "_", omittingEmptySubsequences: false).map { part -> String in
        let digits = part.unicodeScalars.filter { ("0" ... "9").contains($0) }.count
        if digits == part.unicodeScalars.count && digits > 0 {
            return digits == 1 ? String(part) : "N"
        } else if digits != 0 || part.unicodeScalars.count > 24 {
            return "X"
        } else {
            return String(part)
        }
    }.joined(separator: "_")
}

private func networkTelemetryUplinkBytes(_ request: NetworkEngineRequest, method: String) -> Int32 {
    return method.hasPrefix("upload.save") && request.payload.count >= NetworkTelemetry.transferMinBytes ? Int32(clamping: request.payload.count) : 0
}

private func networkTelemetryDownlinkBytes(_ request: NetworkEngineRequest) -> Int32 {
    let expected = request.options.expectedResponseSize
    return Int(expected) >= NetworkTelemetry.transferMinBytes ? expected : 0
}

/// `bytes` rounded up to a power of two, at least 16, so that a size says nothing about content.
func networkTelemetrySizeBucket(_ bytes: Int) -> Int32 {
    if bytes <= 0 {
        return 0
    }
    var bucket = 16
    while bucket < bytes && bucket < Int(Int32.max / 2) {
        bucket *= 2
    }
    return Int32(bucket)
}

func networkFailureClass(code: Int32, text: String) -> NetworkFailureClass {
    if text.hasPrefix("TL_") {
        return .parse
    }
    if code == 303 {
        return .migrate
    }
    if code == 420 || text.hasPrefix("FLOOD_") {
        return .flood
    }
    if code == 401 || code == 406 {
        return .auth
    }
    if code >= 500 || code < 0 {
        return .server
    }
    return .client
}

private final class NetworkTelemetryLock {
    private let pointer: UnsafeMutablePointer<os_unfair_lock>

    init() {
        self.pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self.pointer.initialize(to: os_unfair_lock())
    }

    deinit {
        self.pointer.deinitialize(count: 1)
        self.pointer.deallocate()
    }

    @inline(__always)
    func locked<T>(_ f: () -> T) -> T {
        os_unfair_lock_lock(self.pointer)
        defer {
            os_unfair_lock_unlock(self.pointer)
        }
        return f()
    }
}

private struct NetworkTelemetryMethodKey: Hashable {
    var engine: NetworkEngineKind
    var role: NetworkTelemetryRole
    var method: String
}

private struct NetworkTelemetryMethodStats {
    var count: Int32 = 0
    var retries: Int32 = 0
    var failures: [String: Int32] = [:]
    var latency: [Int32] = Array(repeating: 0, count: NetworkTelemetry.latencyBucketCount)

    mutating func addSuccess(latencyBucket: Int?, retries: Int32) {
        self.count += 1
        self.retries += retries
        if let latencyBucket = latencyBucket {
            self.latency[latencyBucket] += 1
        }
    }
}

/// The counters of the current period that are not per method.
private struct NetworkTelemetryPeriod: Codable {
    var fromTime: Double
    var variant: String?
    var app: String
    var system: String
    var layer: Int32
    var connectionSeconds: [String: Double] = [:]
    var transitions: Int32 = 0
    var disconnects: Int32 = 0
    var timeToOnline: [Int32] = Array(repeating: 0, count: NetworkTelemetry.latencyBucketCount)
    var sessionResets: Int32 = 0
    var drops: [String: [String: Int32]]?
    var droppedFailures: Int32 = 0

    init(fromTime: Double, variant: String?, app: String, system: String, layer: Int32) {
        self.fromTime = fromTime
        self.variant = variant
        self.app = app
        self.system = system
        self.layer = layer
    }
}

/// What `state.json` holds.
private struct NetworkTelemetryStoredState: Codable {
    var schema: Int32
    var period: NetworkTelemetryPeriod
    var methods: [NetworkTelemetryMethodSummary]
    var ended: [NetworkTelemetrySummary]
    var nextSequence: Int64
}

/// A successful request that is not yet counted.
private struct NetworkTelemetrySample {
    var engine: NetworkEngineKind
    var role: NetworkTelemetryRole
    var method: String
    var startedAt: Double
    var duration: Double
    /// The request's size when it is an upload part of at least `transferMinBytes`, else 0.
    var uplinkBytes: Int32
    /// The response size asked for when it is at least `transferMinBytes`, else 0.
    var downlinkBytes: Int32
    var cellular: Bool
    var retries: Int32
    /// False when the request waited through a suspension of the app, so its duration says nothing
    /// about the network.
    var countsLatency: Bool
    /// The connection stayed up the whole time, so the transfer measured the link, not time offline.
    var countsRate: Bool
}

private struct NetworkTelemetryTransferHistory {
    private var values: [(start: Double, end: Double, bytes: Int32)] = []
    private var next = 0

    mutating func add(start: Double, end: Double, bytes: Int32) {
        if self.values.count < NetworkTelemetry.transferHistory {
            self.values.append((start, end, bytes))
        } else {
            self.values[self.next] = (start, end, bytes)
            self.next = (self.next + 1) % NetworkTelemetry.transferHistory
        }
    }

    /// Bytes per second over the time any of the transfers that ended in the window was running, so
    /// that parallel parts add up and idle gaps between transfers do not count.
    func rate(now: Double) -> Int32? {
        let recent = self.values.filter { now - $0.end <= NetworkTelemetry.transferWindow }.sorted { $0.start < $1.start }
        var busy = 0.0
        var bytes = 0.0
        var spanStart = -Double.infinity
        var spanEnd = -Double.infinity
        for transfer in recent {
            bytes += Double(transfer.bytes)
            if transfer.start > spanEnd {
                busy += max(0.0, spanEnd - spanStart)
                spanStart = transfer.start
                spanEnd = transfer.end
            } else {
                spanEnd = max(spanEnd, transfer.end)
            }
        }
        busy += max(0.0, spanEnd - spanStart)
        if recent.isEmpty || busy <= 0.0 {
            return nil
        }
        return networkTelemetrySizeBucket(Int(min(bytes / busy, Double(Int32.max / 2))))
    }
}

private struct NetworkTelemetryLatencyHistory {
    private var values: [Double] = []
    private var next = 0

    mutating func add(_ value: Double) {
        if self.values.count < NetworkTelemetry.latencyHistory {
            self.values.append(value)
        } else {
            self.values[self.next] = value
            self.next = (self.next + 1) % NetworkTelemetry.latencyHistory
        }
    }

    var sorted: [Double] {
        return self.values.sorted()
    }
}

/// How a request's errors were handled so far.
struct NetworkTelemetryErrorState {
    var retries: Int32 = 0
    /// Seconds of every flood wait the request waited out. Engines report only the latest wait.
    var floodWaitTotal = 0
    var internalServerErrorCount = 0
}

/// When the app and its connection were active, for telling waiting on the network from waiting
/// while suspended or offline. Guarded by `pendingLock`.
private struct NetworkTelemetryActivity {
    /// When the app last became active after a suspension.
    var lastResumedAt: Double = -Double.infinity
    /// When the current suspension began, while the app is suspended.
    var suspendedAt: Double?
    /// When the connection last came up, while it is up and the app is active.
    var connectedSince: Double?
    /// Seconds the connection was up while the app was active, before `connectedSince`.
    var connectedTotal: Double = 0.0

    /// Seconds a request started at `startedAt` waited while the app was active, not counting flood waits.
    func waited(now: Double, startedAt: Double, floodWait: Int) -> Double {
        return min(now, self.suspendedAt ?? now) - max(startedAt, self.lastResumedAt) - Double(max(0, floodWait))
    }

    /// The connection has been up since `startedAt` without a break.
    func connectedThroughout(since startedAt: Double) -> Bool {
        return self.connectedSince.map { $0 <= startedAt } ?? false
    }

    /// Seconds the connection has been up while the app was active, in total. A request's stall clock
    /// is this minus its value when the request started, so time offline or suspended never counts
    /// and a reconnect loop does not reset it.
    func connectedClock(now: Double) -> Double {
        return self.connectedTotal + (self.connectedSince.map { max(0.0, now - $0) } ?? 0.0)
    }

    mutating func connectionUp(now: Double) {
        if self.connectedSince == nil {
            self.connectedSince = now
        }
    }

    mutating func connectionDown(now: Double) {
        if let connectedSince = self.connectedSince {
            self.connectedTotal += now - connectedSince
            self.connectedSince = nil
        }
    }

    func spannedSuspension(startedAt: Double) -> Bool {
        return startedAt < self.lastResumedAt || self.suspendedAt != nil
    }
}

/// What `NetworkTelemetry` notes about a request when it starts. Stored in the request before the
/// request reaches the engine, and only read afterwards.
struct NetworkTelemetryRequestInfo {
    var startedAt: Double
    var engine: NetworkEngineKind
    var role: NetworkTelemetryRole
    var datacenterId: Int
    /// The API method name, never its parameters. Resolved when the request starts, so that nothing
    /// kept for counting holds the request's metadata, which keeps every argument (upload parts too).
    var method: String
}

/// What changes while a request runs. Stored in the request and guarded by the telemetry's
/// `pendingLock`, except in the request's `deinit`, when nothing else can reach it.
struct NetworkTelemetryRequestProgress {
    var finished = false
    var errorState = NetworkTelemetryErrorState()
    var watch: NetworkTelemetryWatchEntry?
}

/// The parts of a request a failure record describes. Holds no payload and no metadata.
struct NetworkTelemetryRequestDescription {
    var info: NetworkTelemetryRequestInfo
    var requestBytes: Int
    var expectedBytes: Int32

    init(_ request: NetworkEngineRequest, info: NetworkTelemetryRequestInfo) {
        self.info = info
        self.requestBytes = request.payload.count
        self.expectedBytes = request.options.expectedResponseSize
    }
}

/// A request watched for stalls. Holds a description rather than the request, so that a watched
/// request is released, payload and parameters included, as soon as the engine is done with it.
final class NetworkTelemetryWatchEntry {
    let description: NetworkTelemetryRequestDescription
    /// The telemetry's connected clock when the request started.
    let connectedClockAtStart: Double
    /// Guarded by the telemetry's `pendingLock`.
    var finished = false
    var stallReported = false
    var errorState = NetworkTelemetryErrorState()

    init(description: NetworkTelemetryRequestDescription, connectedClockAtStart: Double) {
        self.description = description
        self.connectedClockAtStart = connectedClockAtStart
    }
}

func networkTelemetryMethodName(_ metadata: WrappedRequestShortMetadata) -> String {
    return metadata.functionName ?? "unknown"
}

private enum NetworkTelemetryFlush {
    case notNeeded
    case delayed
    case immediate
}

/// Seconds the device has been awake. Device sleep does not count, so a request in flight while a
/// laptop sleeps does not look slow.
private func networkTelemetryUptime() -> Double {
    return Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000_000.0
}

/// Records every request of a `Network` above the engine, so both engines are measured by the same
/// code: per-method counts and latency for A/B comparison, and a record of every failure with the
/// context needed to reproduce it.
///
/// Requests complete on the engines' serial queues, so a successful request only appends a sample to
/// a buffer under a short lock. The samples are counted in batches on a utility queue: 5 seconds after
/// the first one, or right away once 4096 are waiting. Failures, slow requests, reports and summaries
/// count the waiting samples first, so they always see every request that completed before them.
///
/// The main session's pauses mark suspensions of the app: a request that waited through one does not
/// count toward latency, stalls, slowness or abandonment, and connection time is counted only while
/// the app is active.
public final class NetworkTelemetry {
    static let schema: Int32 = 1
    /// Upper bounds, in seconds, of the latency buckets.
    public static let latencyBucketBounds: [Double] = [0.01, 0.025, 0.05, 0.1, 0.2, 0.4, 0.8, 1.5, 3.0, 6.0, 12.0, 30.0, 60.0]
    static let latencyBucketCount = NetworkTelemetry.latencyBucketBounds.count + 1
    static let maxFailureRecords = 256
    static let maxMethods = 512
    static let maxReportedMethods = 128
    static let maxEndedPeriods = 8
    static let connectionHistory = 24
    static let transferMinBytes = 16 * 1024
    static let transferHistory = 16
    static let transferWindow: Double = 120.0
    static let dropHistory = 32
    static let dropsPerRecord = 8
    static let dropReasonsPerRole = 32
    static let latencyHistory = 64
    static let flushDelay: Double = 5.0
    /// Under steady traffic the state is saved at most this often.
    static let saveInterval: Double = 60.0
    static let flushBatch = 4096
    /// A request released without completing after waiting at least this long is recorded as `abandoned`.
    public static let abandonedAfter: Double = 20.0
    /// A successful request that took at least this long is recorded as `slow`.
    public static let slowAfter: Double = 10.0
    /// A request still waiting after this long is recorded as `stalled`.
    public static let stalledAfter: Double = 60.0
    /// One request in this many is watched for stalls, chosen by a hash of its address and start time.
    /// Watching every request costs a shared list entry per request, which showed in million-request
    /// runs; a wedged session stalls many requests at once, so a sample still finds it.
    public static let watchEvery = 8
    /// Requests started while this many are watched are not watched for stalls.
    static let maxWatchedRequests = 8192
    /// Finished requests are dropped from the watch list after this many more have started.
    static let watchSweepBatch = 4096

    let clock: () -> Double
    private let wallClock: () -> Double
    private let stalledAfter: Double
    private let watchShift: Int
    private let store: NetworkTelemetryStore?
    private let flushQueue = Queue(name: "org.telegram.NetworkTelemetry", qos: .utility)
    private let startedAt: Double
    private let layer: Int32
    private let app: String
    private let system: String

    /// Guards the samples, the flush flags, the requests' progress and `activity`. Taken by the
    /// threads that complete requests, alone or inside `lock` or `watchLock`.
    private let pendingLock = NetworkTelemetryLock()
    private var pendingSamples: [NetworkTelemetrySample] = []
    private var delayedFlushScheduled = false
    private var immediateFlushScheduled = false
    private var activity = NetworkTelemetryActivity()

    /// Guards the watch list. Taken by the threads that start requests, so that they never wait for
    /// the threads that complete them.
    private let watchLock = NetworkTelemetryLock()
    /// Requests started since the last sweep or still in flight at it, oldest first.
    private var watched: [NetworkTelemetryWatchEntry] = []
    private var sweepThreshold = NetworkTelemetry.watchSweepBatch
    private var sweepScheduled = false
    private var stallCheckScheduled = false

    /// Guards everything else.
    private let lock = NetworkTelemetryLock()
    private var methods: [NetworkTelemetryMethodKey: NetworkTelemetryMethodStats] = [:]
    private var period: NetworkTelemetryPeriod
    private var ended: [NetworkTelemetrySummary] = []
    private var failures: [NetworkFailureRecord] = []
    private var nextSequence: Int64 = 1
    private var connectionEvents: [(time: Double, state: NetworkTelemetryConnectionState)] = []
    private var connectionState: NetworkTelemetryConnectionState?
    private var connectionStateSince: Double = 0.0
    private var lastConnected: Double?
    private var offlineSince: Double?
    private var suspended = false
    private var viaProxy = false
    private var userOnline: Bool?
    private var lastCellular: Bool?
    private var inFlightEstimate: Int32?
    private var recentLatency = Array(repeating: NetworkTelemetryLatencyHistory(), count: NetworkTelemetryRole.allCases.count)
    private var mainRoundTrip = NetworkTelemetryLatencyHistory()
    private var recentUploads = NetworkTelemetryTransferHistory()
    private var recentDownloads = NetworkTelemetryTransferHistory()
    private var recentDrops: [(time: Double, role: NetworkTelemetryRole, drop: NetworkTelemetryDrop)] = []
    private var variant: String?
    private var summaryDirty = false
    private var lastSaveAt: Double = -Double.infinity
    private var saveScheduled = false

    /// `directory` keeps unreported failures and the current period across launches; nil keeps
    /// everything in memory. `clock` counts seconds the device is awake, `wallClock` is Unix time.
    init(directory: String?, layer: Int32, app: String, system: String, variant: String?, stalledAfter: Double = NetworkTelemetry.stalledAfter, watchEvery: Int = NetworkTelemetry.watchEvery, clock: @escaping () -> Double = networkTelemetryUptime, wallClock: @escaping () -> Double = { Date().timeIntervalSince1970 }) {
        self.clock = clock
        self.wallClock = wallClock
        self.stalledAfter = stalledAfter
        precondition(watchEvery > 0 && watchEvery & (watchEvery - 1) == 0)
        self.watchShift = watchEvery.trailingZeroBitCount
        self.startedAt = clock()
        self.layer = layer
        self.app = networkTelemetryToken(app, maxLength: 48)
        self.system = networkTelemetryToken(system, maxLength: 48)
        self.variant = variant
        self.store = directory.flatMap(NetworkTelemetryStore.init(directory:))
        self.period = NetworkTelemetryPeriod(fromTime: wallClock(), variant: variant, app: self.app, system: self.system, layer: layer)
        guard let stored = self.store?.load() else {
            return
        }
        self.failures = Array(stored.failures.suffix(NetworkTelemetry.maxFailureRecords))
        self.nextSequence = max(stored.state?.nextSequence ?? 1, (stored.failures.last?.sequence ?? 0) + 1)
        guard let state = stored.state, state.schema == NetworkTelemetry.schema else {
            return
        }
        self.ended = Array(state.ended.suffix(NetworkTelemetry.maxEndedPeriods))
        let bucketsMatch = state.period.timeToOnline.count == NetworkTelemetry.latencyBucketCount && state.methods.allSatisfy { $0.latency.count == NetworkTelemetry.latencyBucketCount }
        if !bucketsMatch {
            return
        }
        self.period = state.period
        for method in state.methods {
            let key = NetworkTelemetryMethodKey(engine: NetworkEngineKind(rawValue: method.engine) ?? .mtProtoKit, role: method.role, method: method.method)
            self.methods[key] = NetworkTelemetryMethodStats(count: method.count, retries: method.retries, failures: method.failures, latency: method.latency)
        }
        if state.period.variant != variant || state.period.app != self.app || state.period.system != self.system || state.period.layer != layer {
            self.endPeriod(now: self.startedAt)
        }
    }

    private final class WeakTelemetry {
        weak var value: NetworkTelemetry?

        init(_ value: NetworkTelemetry) {
            self.value = value
        }
    }

    private static let registryLock = NetworkTelemetryLock()
    private static var registry: [String: WeakTelemetry] = [:]

    /// The recorder of `directory`, shared by every network of the process that records there, so
    /// that two networks of one account never write the same files independently.
    static func shared(directory: String, layer: Int32, app: String, system: String, variant: String?, stalledAfter: Double = NetworkTelemetry.stalledAfter, watchEvery: Int = NetworkTelemetry.watchEvery) -> NetworkTelemetry {
        return NetworkTelemetry.registryLock.locked {
            if let existing = NetworkTelemetry.registry[directory]?.value {
                return existing
            }
            NetworkTelemetry.registry = NetworkTelemetry.registry.filter { $0.value.value != nil }
            let telemetry = NetworkTelemetry(directory: directory, layer: layer, app: app, system: system, variant: variant, stalledAfter: stalledAfter, watchEvery: watchEvery)
            NetworkTelemetry.registry[directory] = WeakTelemetry(telemetry)
            return telemetry
        }
    }

    /// Ends the current period when the arm changes, so that its counts stay labelled with the arm
    /// they were measured in.
    public func setVariant(_ variant: String?) {
        let now = self.clock()
        self.lock.locked {
            if self.variant == variant {
                return
            }
            self.variant = variant
            self.endPeriod(now: now)
        }
        self.writeSummary()
    }

    private static func latencyBucket(_ duration: Double) -> Int {
        for (index, bound) in NetworkTelemetry.latencyBucketBounds.enumerated() {
            if duration <= bound {
                return index
            }
        }
        return NetworkTelemetry.latencyBucketBounds.count
    }

    // MARK: - Requests

    /// Starts recording a request. Called before the request reaches the engine.
    func begin(request: NetworkEngineRequest, engine: NetworkEngineKind, role: NetworkTelemetryRole, datacenterId: Int) {
        let info = NetworkTelemetryRequestInfo(startedAt: self.clock(), engine: engine, role: role, datacenterId: datacenterId, method: networkTelemetryMethodName(request.shortMetadata))
        request.telemetryInfo = info
        request.telemetry = self
        if self.watchShift != 0 {
            let address = UInt64(UInt(bitPattern: ObjectIdentifier(request).hashValue))
            let time = UInt64(bitPattern: Int64((info.startedAt * 1_000_000_000.0).rounded()))
            let hash = (address ^ time) &* 0x9e3779b97f4a7c15
            if hash >> UInt64(64 - self.watchShift) != 0 {
                return
            }
        }
        let connectedClock: Double = self.pendingLock.locked {
            return self.activity.connectedClock(now: info.startedAt)
        }
        let entry = NetworkTelemetryWatchEntry(description: NetworkTelemetryRequestDescription(request, info: info), connectedClockAtStart: connectedClock)
        let (sweep, check, added): (Bool, Bool, Bool) = self.watchLock.locked {
            if self.watched.count >= NetworkTelemetry.maxWatchedRequests {
                return (false, false, false)
            }
            self.watched.append(entry)
            var sweep = false
            if self.watched.count >= self.sweepThreshold && !self.sweepScheduled {
                self.sweepScheduled = true
                sweep = true
            }
            var check = false
            if !self.stallCheckScheduled {
                self.stallCheckScheduled = true
                check = true
            }
            return (sweep, check, true)
        }
        if added {
            request.telemetryProgress.watch = entry
        }
        if sweep {
            self.flushQueue.async { [weak self] in
                self?.sweepWatchedRequests(checkStalls: false)
            }
        }
        if check {
            self.scheduleStallCheck(after: self.stalledAfter)
        }
    }

    func errorHandled(request: NetworkEngineRequest, context: NetworkEngineErrorContext, retried: Bool) {
        self.pendingLock.locked {
            var errorState = request.telemetryProgress.errorState
            if retried && context.floodWaitSeconds > 0 && context.internalServerErrorCount <= errorState.internalServerErrorCount {
                errorState.floodWaitTotal += context.floodWaitSeconds
            }
            errorState.internalServerErrorCount = context.internalServerErrorCount
            if retried {
                errorState.retries += 1
            }
            request.telemetryProgress.errorState = errorState
            request.telemetryProgress.watch?.errorState = errorState
        }
    }

    /// Call with `pendingLock` held.
    private func finish(_ request: NetworkEngineRequest) -> NetworkTelemetryErrorState {
        request.telemetryProgress.finished = true
        request.telemetryProgress.watch?.finished = true
        return request.telemetryProgress.errorState
    }

    func completed(request: NetworkEngineRequest, info: NetworkTelemetryRequestInfo, result: Result<NetworkEngineResponse, NetworkEngineRequestFailure>) {
        let now = self.clock()
        let duration = max(0.0, now - info.startedAt)
        if case let .success(response) = result, duration < NetworkTelemetry.slowAfter {
            let cellular = response.info.networkType != 0
            let flush: NetworkTelemetryFlush? = self.pendingLock.locked {
                if request.telemetryProgress.finished {
                    return nil
                }
                let errorState = self.finish(request)
                self.pendingSamples.append(NetworkTelemetrySample(engine: info.engine, role: info.role, method: info.method, startedAt: info.startedAt, duration: duration, uplinkBytes: networkTelemetryUplinkBytes(request, method: info.method), downlinkBytes: networkTelemetryDownlinkBytes(request), cellular: cellular, retries: errorState.retries, countsLatency: !self.activity.spannedSuspension(startedAt: info.startedAt) && errorState.floodWaitTotal == 0, countsRate: self.activity.connectedThroughout(since: info.startedAt)))
                if self.pendingSamples.count >= NetworkTelemetry.flushBatch && !self.immediateFlushScheduled {
                    self.immediateFlushScheduled = true
                    return .immediate
                } else if !self.delayedFlushScheduled {
                    self.delayedFlushScheduled = true
                    return .delayed
                } else {
                    return .notNeeded
                }
            }
            if let flush = flush {
                self.schedule(flush)
            }
            return
        }
        let finished: (NetworkTelemetryErrorState, NetworkTelemetryActivity)? = self.pendingLock.locked {
            if request.telemetryProgress.finished {
                return nil
            }
            return (self.finish(request), self.activity)
        }
        guard let (errorState, activity) = finished else {
            return
        }
        let spannedSuspension = activity.spannedSuspension(startedAt: info.startedAt)
        let description = NetworkTelemetryRequestDescription(request, info: info)
        self.lock.locked {
            self.countPendingSamples()
            switch result {
            case let .success(response):
                let key = self.count(NetworkTelemetrySample(engine: info.engine, role: info.role, method: info.method, startedAt: info.startedAt, duration: duration, uplinkBytes: networkTelemetryUplinkBytes(request, method: info.method), downlinkBytes: networkTelemetryDownlinkBytes(request), cellular: response.info.networkType != 0, retries: errorState.retries, countsLatency: !spannedSuspension && errorState.floodWaitTotal == 0, countsRate: self.pendingLock.locked { self.activity.connectedThroughout(since: info.startedAt) }))
                if activity.waited(now: now, startedAt: info.startedAt, floodWait: errorState.floodWaitTotal) >= NetworkTelemetry.slowAfter {
                    self.methods[key, default: NetworkTelemetryMethodStats()].failures[NetworkFailureClass.slow.rawValue, default: 0] += 1
                    self.appendFailure(description, errorState: errorState, failure: .slow, code: 0, error: "", duration: duration, spannedSuspension: spannedSuspension, now: now)
                }
            case let .failure(failure):
                self.lastCellular = failure.info.networkType != 0
                let failureClass = networkFailureClass(code: failure.error.errorCode, text: failure.error.errorDescription ?? "")
                let key = self.methodKey(engine: info.engine, role: info.role, method: info.method)
                self.methods[key, default: NetworkTelemetryMethodStats()].count += 1
                self.methods[key, default: NetworkTelemetryMethodStats()].retries += errorState.retries
                self.methods[key, default: NetworkTelemetryMethodStats()].failures[failureClass.rawValue, default: 0] += 1
                self.appendFailure(description, errorState: errorState, failure: failureClass, code: failure.error.errorCode, error: networkTelemetryErrorText(failure.error.errorDescription ?? ""), duration: duration, spannedSuspension: spannedSuspension, now: now)
            }
            self.summaryDirty = true
        }
        self.scheduleDelayedFlush()
    }

    /// The engine refused the request when it was added: its session is gone and the caller will
    /// wait forever.
    func dropped(request: NetworkEngineRequest, info: NetworkTelemetryRequestInfo) {
        let now = self.clock()
        let state: NetworkTelemetryErrorState? = self.pendingLock.locked {
            if request.telemetryProgress.finished {
                return nil
            }
            return self.finish(request)
        }
        guard let errorState = state else {
            return
        }
        let description = NetworkTelemetryRequestDescription(request, info: info)
        self.lock.locked {
            self.countPendingSamples()
            let key = self.methodKey(engine: info.engine, role: info.role, method: info.method)
            self.methods[key, default: NetworkTelemetryMethodStats()].failures[NetworkFailureClass.dropped.rawValue, default: 0] += 1
            self.appendFailure(description, errorState: errorState, failure: .dropped, code: 0, error: "", duration: max(0.0, now - info.startedAt), spannedSuspension: false, now: now)
            self.summaryDirty = true
        }
        self.scheduleDelayedFlush()
    }

    /// A request is being released without ever completing: it was cancelled, or its session went
    /// away. Called from the request's `deinit`; reads the request and keeps no reference to it.
    func released(request: NetworkEngineRequest, info: NetworkTelemetryRequestInfo) {
        let now = self.clock()
        let abandoned: (NetworkTelemetryErrorState, Bool)? = self.pendingLock.locked {
            let errorState = self.finish(request)
            if request.telemetryProgress.watch?.stallReported == true {
                return nil
            }
            if self.activity.waited(now: now, startedAt: info.startedAt, floodWait: errorState.floodWaitTotal) < NetworkTelemetry.abandonedAfter {
                return nil
            }
            return (errorState, self.activity.spannedSuspension(startedAt: info.startedAt))
        }
        guard let (errorState, spannedSuspension) = abandoned else {
            return
        }
        let description = NetworkTelemetryRequestDescription(request, info: info)
        self.lock.locked {
            self.countPendingSamples()
            let key = self.methodKey(engine: info.engine, role: info.role, method: info.method)
            self.methods[key, default: NetworkTelemetryMethodStats()].failures[NetworkFailureClass.abandoned.rawValue, default: 0] += 1
            self.appendFailure(description, errorState: errorState, failure: .abandoned, code: 0, error: "", duration: max(0.0, now - info.startedAt), spannedSuspension: spannedSuspension, now: now)
            self.summaryDirty = true
        }
        self.scheduleDelayedFlush()
    }

    // MARK: - Stalls

    private func scheduleStallCheck(after delay: Double) {
        self.flushQueue.after(max(1.0, delay), { [weak self] in
            self?.checkStalledRequests()
        })
    }

    /// Records the requests that have been waiting for `stalledAfter` while the connection is up.
    func checkStalledRequests() {
        self.sweepWatchedRequests(checkStalls: true)
    }

    /// Drops finished requests from the watch list and, when `checkStalls` is set, records the stalled ones.
    private func sweepWatchedRequests(checkStalls: Bool) {
        let now = self.clock()
        var stalled: [(NetworkTelemetryRequestDescription, NetworkTelemetryErrorState, Bool)] = []
        var dropped: [NetworkTelemetryWatchEntry] = []
        var inFlight = 0
        let nextCheck: Double? = self.watchLock.locked {
            var kept: [NetworkTelemetryWatchEntry] = []
            var nextCheck: Double?
            self.pendingLock.locked {
                let activity = self.activity
                for entry in self.watched where !entry.finished {
                    kept.append(entry)
                    if !checkStalls || entry.stallReported {
                        continue
                    }
                    let startedAt = entry.description.info.startedAt
                    let waited = activity.connectedClock(now: now) - entry.connectedClockAtStart - Double(max(0, entry.errorState.floodWaitTotal))
                    if waited < self.stalledAfter {
                        if activity.connectedSince != nil {
                            let due = now + self.stalledAfter - waited
                            nextCheck = nextCheck.map { min($0, due) } ?? due
                        }
                    } else {
                        entry.stallReported = true
                        stalled.append((entry.description, entry.errorState, activity.spannedSuspension(startedAt: startedAt)))
                    }
                }
            }
            dropped = self.watched
            self.watched = kept
            inFlight = kept.count << self.watchShift
            self.sweepThreshold = min(NetworkTelemetry.maxWatchedRequests, kept.count + NetworkTelemetry.watchSweepBatch)
            if !checkStalls {
                self.sweepScheduled = false
                return nil
            }
            if kept.isEmpty {
                self.stallCheckScheduled = false
                return nil
            }
            return nextCheck ?? now + self.stalledAfter
        }
        dropped.removeAll()
        if let nextCheck = nextCheck {
            self.scheduleStallCheck(after: nextCheck - now)
        }
        self.lock.locked {
            self.inFlightEstimate = Int32(clamping: inFlight)
            if stalled.isEmpty {
                return
            }
            self.countPendingSamples()
            for (description, errorState, spannedSuspension) in stalled {
                let key = self.methodKey(engine: description.info.engine, role: description.info.role, method: description.info.method)
                self.methods[key, default: NetworkTelemetryMethodStats()].failures[NetworkFailureClass.stalled.rawValue, default: 0] += 1
                self.appendFailure(description, errorState: errorState, failure: .stalled, code: 0, error: "", duration: now - description.info.startedAt, spannedSuspension: spannedSuspension, now: now)
            }
            self.summaryDirty = true
        }
        if !stalled.isEmpty {
            self.scheduleDelayedFlush()
        }
    }

    /// Watched requests still in flight. For tests.
    var watchedRequestCount: Int {
        return self.watchLock.locked {
            self.pendingLock.locked {
                self.watched.filter({ !$0.finished }).count
            }
        }
    }

    // MARK: - Counting

    /// The key a request is counted under: methods beyond `maxMethods` share "other". Call with `lock` held.
    private func methodKey(engine: NetworkEngineKind, role: NetworkTelemetryRole, method: String) -> NetworkTelemetryMethodKey {
        var key = NetworkTelemetryMethodKey(engine: engine, role: role, method: method)
        if self.methods.count >= NetworkTelemetry.maxMethods && self.methods[key] == nil {
            key.method = "other"
        }
        return key
    }

    /// Call with `lock` held.
    @discardableResult
    private func count(_ sample: NetworkTelemetrySample) -> NetworkTelemetryMethodKey {
        let key = self.methodKey(engine: sample.engine, role: sample.role, method: sample.method)
        self.methods[key, default: NetworkTelemetryMethodStats()].addSuccess(latencyBucket: sample.countsLatency ? NetworkTelemetry.latencyBucket(sample.duration) : nil, retries: sample.retries)
        if sample.countsLatency {
            self.recentLatency[sample.role.index].add(sample.duration)
        }
        if sample.role == .main && sample.countsLatency && sample.countsRate && sample.uplinkBytes == 0 && sample.downlinkBytes == 0 {
            self.mainRoundTrip.add(sample.duration)
        }
        if sample.countsLatency && sample.countsRate {
            if sample.uplinkBytes > 0 {
                self.recentUploads.add(start: sample.startedAt, end: sample.startedAt + sample.duration, bytes: sample.uplinkBytes)
            }
            if sample.downlinkBytes > 0 {
                self.recentDownloads.add(start: sample.startedAt, end: sample.startedAt + sample.duration, bytes: sample.downlinkBytes)
            }
        }
        self.lastCellular = sample.cellular
        return key
    }

    /// Call with `lock` held.
    private func countPendingSamples() {
        var samples: [NetworkTelemetrySample] = []
        samples.reserveCapacity(256)
        self.pendingLock.locked {
            swap(&samples, &self.pendingSamples)
        }
        if samples.isEmpty {
            return
        }
        for sample in samples {
            self.count(sample)
        }
        self.summaryDirty = true
    }

    private func schedule(_ flush: NetworkTelemetryFlush) {
        switch flush {
        case .notNeeded:
            break
        case .immediate:
            self.flushQueue.async { [weak self] in
                self?.flush(delayed: false)
            }
        case .delayed:
            self.flushQueue.after(NetworkTelemetry.flushDelay, { [weak self] in
                self?.flush(delayed: true)
            })
        }
    }

    private func scheduleDelayedFlush() {
        let schedule: Bool = self.pendingLock.locked {
            if self.delayedFlushScheduled {
                return false
            }
            self.delayedFlushScheduled = true
            return true
        }
        if schedule {
            self.schedule(.delayed)
        }
    }

    /// Counts the waiting samples. A delayed flush also saves the current state.
    private func flush(delayed: Bool) {
        self.pendingLock.locked {
            if delayed {
                self.delayedFlushScheduled = false
            } else {
                self.immediateFlushScheduled = false
            }
        }
        if delayed {
            self.saveIfDue()
        } else {
            self.lock.locked {
                self.countPendingSamples()
            }
        }
    }

    /// Counts the waiting samples and saves the state, at most every `saveInterval`; a save that is
    /// not due yet is scheduled for when it is.
    private func saveIfDue() {
        let now = self.clock()
        let delay: Double? = self.lock.locked {
            self.countPendingSamples()
            if self.store == nil || !self.summaryDirty {
                return nil
            }
            if now - self.lastSaveAt >= NetworkTelemetry.saveInterval {
                self.save(now: now)
                return nil
            }
            if self.saveScheduled {
                return nil
            }
            self.saveScheduled = true
            return self.lastSaveAt + NetworkTelemetry.saveInterval - now
        }
        if let delay = delay {
            self.flushQueue.after(delay, { [weak self] in
                self?.writeSummary()
            })
        }
    }

    /// Call with `lock` held.
    private func save(now: Double) {
        guard let store = self.store else {
            return
        }
        self.summaryDirty = false
        self.saveScheduled = false
        self.lastSaveAt = now
        store.save(state: NetworkTelemetryStoredState(schema: NetworkTelemetry.schema, period: self.currentPeriod(now: now), methods: self.methodSummaries(), ended: self.ended, nextSequence: self.nextSequence))
    }

    /// Call with `lock` held.
    private func appendFailure(_ request: NetworkTelemetryRequestDescription, errorState: NetworkTelemetryErrorState, failure: NetworkFailureClass, code: Int32, error: String, duration: Double, spannedSuspension: Bool, now: Double) {
        let samples = self.recentLatency[request.info.role.index].sorted
        let mainSamples = request.info.role == .main ? [] : self.mainRoundTrip.sorted
        func percentile(_ p: Double, of samples: [Double]) -> Double? {
            if samples.isEmpty {
                return nil
            }
            let index = min(samples.count - 1, Int((Double(samples.count - 1) * p).rounded()))
            return (samples[index] * 1000.0).rounded() / 1000.0
        }
        let record = NetworkFailureRecord(
            schema: NetworkTelemetry.schema,
            sequence: self.nextSequence,
            hour: Int32(clamping: Int64(self.wallClock() / 3600.0) * 3600),
            uptime: Int32(clamping: Int64(now - self.startedAt)),
            engine: request.info.engine.rawValue,
            variant: self.variant,
            role: request.info.role,
            datacenter: Int32(clamping: request.info.datacenterId),
            method: request.info.method,
            failure: failure,
            code: code,
            error: error,
            duration: (duration * 1000.0).rounded() / 1000.0,
            spannedSuspension: spannedSuspension,
            retries: errorState.retries,
            floodWait: Int32(clamping: errorState.floodWaitTotal),
            serverErrors: Int32(clamping: errorState.internalServerErrorCount),
            requestBytes: networkTelemetrySizeBucket(request.requestBytes),
            expectedBytes: networkTelemetrySizeBucket(Int(request.expectedBytes)),
            cellular: self.lastCellular,
            viaProxy: self.viaProxy,
            userOnline: self.userOnline,
            connection: self.connectionEvents.suffix(NetworkTelemetry.connectionHistory).map { NetworkTelemetryConnectionEvent(ago: ((now - $0.time) * 1000.0).rounded() / 1000.0, state: $0.state) },
            drops: self.recentDrops(role: request.info.role, now: now),
            sinceOnline: self.connectionState?.isConnected == true ? 0.0 : self.lastConnected.map { ((now - $0) * 1000.0).rounded() / 1000.0 },
            inFlight: self.inFlightEstimate,
            latencyP50: percentile(0.5, of: samples),
            latencyP90: percentile(0.9, of: samples),
            latencySamples: Int32(samples.count),
            mainLatencyP50: percentile(0.5, of: mainSamples),
            mainLatencyP90: percentile(0.9, of: mainSamples),
            uplinkRate: self.recentUploads.rate(now: now),
            downlinkRate: self.recentDownloads.rate(now: now),
            layer: self.layer,
            app: self.app,
            system: self.system
        )
        self.nextSequence += 1
        if self.failures.count >= NetworkTelemetry.maxFailureRecords {
            self.failures.removeFirst()
            self.period.droppedFailures += 1
        }
        self.failures.append(record)
        self.store?.append(record)
    }

    // MARK: - Connection

    func connectionStateChanged(_ state: NetworkEngineConnectionState) {
        let now = self.clock()
        let newState = NetworkTelemetryConnectionState(state)
        let changed: Bool = self.lock.locked {
            self.viaProxy = state.proxyAddress != nil
            let previous = self.connectionState
            if let previous = previous {
                if previous == newState {
                    return false
                }
                if !self.suspended {
                    self.period.connectionSeconds[previous.rawValue, default: 0.0] += now - self.connectionStateSince
                }
                self.period.transitions += 1
            }
            let wasConnected = previous?.isConnected ?? false
            if newState.isConnected {
                if !wasConnected, let offlineSince = self.offlineSince {
                    self.period.timeToOnline[NetworkTelemetry.latencyBucket(now - offlineSince)] += 1
                }
                self.offlineSince = nil
            } else {
                if wasConnected {
                    self.period.disconnects += 1
                    self.lastConnected = now
                }
                if newState == .waitingForNetwork || self.suspended {
                    self.offlineSince = nil
                } else if self.offlineSince == nil {
                    self.offlineSince = now
                }
            }
            if newState.isConnected != wasConnected || previous == nil {
                let suspended = self.suspended
                self.pendingLock.locked {
                    if newState.isConnected && !suspended {
                        self.activity.connectionUp(now: now)
                    } else {
                        self.activity.connectionDown(now: now)
                    }
                }
            }
            if newState == .waitingForNetwork {
                self.countPendingSamples()
                self.recentUploads = NetworkTelemetryTransferHistory()
                self.recentDownloads = NetworkTelemetryTransferHistory()
            }
            self.connectionState = newState
            self.connectionStateSince = now
            self.connectionEvents.append((now, newState))
            if self.connectionEvents.count > NetworkTelemetry.connectionHistory {
                self.connectionEvents.removeFirst(self.connectionEvents.count - NetworkTelemetry.connectionHistory)
            }
            self.summaryDirty = true
            return true
        }
        if changed {
            self.scheduleDelayedFlush()
        }
    }

    func setUserOnline(_ online: Bool) {
        self.lock.locked {
            self.userOnline = online
        }
    }

    /// The main session was paused (the app is suspended or in the background) or resumed.
    func setSuspended(_ suspended: Bool) {
        let now = self.clock()
        self.lock.locked {
            if self.suspended == suspended {
                return
            }
            if let connectionState = self.connectionState, !self.suspended {
                self.period.connectionSeconds[connectionState.rawValue, default: 0.0] += now - self.connectionStateSince
            }
            self.suspended = suspended
            self.connectionStateSince = now
            if !suspended, let connectionState = self.connectionState, !connectionState.isConnected, connectionState != .waitingForNetwork {
                self.offlineSince = now
            } else {
                self.offlineSince = nil
            }
            self.summaryDirty = true
            let connected = self.connectionState?.isConnected == true
            self.pendingLock.locked {
                if suspended {
                    self.activity.suspendedAt = now
                    self.activity.connectionDown(now: now)
                } else {
                    self.activity.suspendedAt = nil
                    self.activity.lastResumedAt = now
                    if connected {
                        self.activity.connectionUp(now: now)
                    }
                }
            }
        }
        if suspended {
            self.writeSummary()
        }
    }

    func sessionReset() {
        self.lock.locked {
            self.period.sessionResets += 1
            self.summaryDirty = true
        }
        self.scheduleDelayedFlush()
    }

    /// The engine gave up on a connection of a session of `role`.
    func connectionDropped(role: NetworkTelemetryRole, _ drop: NetworkEngineConnectionDrop) {
        let now = self.clock()
        let reason = networkTelemetryDropReason(drop.reason)
        let key = drop.answered ? reason : reason + "_unanswered"
        self.lock.locked {
            var drops = self.period.drops ?? [:]
            var counts = drops[role.rawValue] ?? [:]
            if counts[key] != nil || counts.count < NetworkTelemetry.dropReasonsPerRole {
                counts[key, default: 0] += 1
                drops[role.rawValue] = counts
                self.period.drops = drops
            }
            self.recentDrops.append((time: now, role: role, drop: NetworkTelemetryDrop(ago: 0.0, reason: reason, answered: drop.answered, age: (drop.age * 1000.0).rounded() / 1000.0)))
            if self.recentDrops.count > NetworkTelemetry.dropHistory {
                self.recentDrops.removeFirst()
            }
            self.summaryDirty = true
        }
        self.scheduleDelayedFlush()
    }

    /// Call with `lock` held.
    private func recentDrops(role: NetworkTelemetryRole, now: Double) -> [NetworkTelemetryDrop]? {
        let drops = self.recentDrops.filter { $0.role == role && now - $0.time <= NetworkTelemetry.transferWindow }.suffix(NetworkTelemetry.dropsPerRecord).map { entry -> NetworkTelemetryDrop in
            var drop = entry.drop
            drop.ago = ((now - entry.time) * 1000.0).rounded() / 1000.0
            return drop
        }
        return drops.isEmpty ? nil : drops
    }

    // MARK: - Periods and reports

    /// Call with `lock` held.
    private func methodSummaries() -> [NetworkTelemetryMethodSummary] {
        return self.methods.map { key, stats in
            NetworkTelemetryMethodSummary(engine: key.engine.rawValue, role: key.role, method: key.method, count: stats.count, retries: stats.retries, failures: stats.failures, latency: stats.latency)
        }.sorted(by: { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return (lhs.engine, lhs.role.rawValue, lhs.method) < (rhs.engine, rhs.role.rawValue, rhs.method)
        })
    }

    /// The current period with the time spent in the current connection state. Call with `lock` held.
    private func currentPeriod(now: Double) -> NetworkTelemetryPeriod {
        var period = self.period
        if let connectionState = self.connectionState, !self.suspended {
            period.connectionSeconds[connectionState.rawValue, default: 0.0] += now - self.connectionStateSince
        }
        return period
    }

    /// Call with `lock` held, after counting the waiting samples.
    private func currentSummary(now: Double) -> NetworkTelemetrySummary {
        let period = self.currentPeriod(now: now)
        let all = self.methodSummaries()
        var methods = Array(all.prefix(NetworkTelemetry.maxReportedMethods))
        if all.count > NetworkTelemetry.maxReportedMethods {
            var other = NetworkTelemetryMethodSummary(engine: "any", role: .main, method: "other", count: 0, retries: 0, failures: [:], latency: Array(repeating: 0, count: NetworkTelemetry.latencyBucketCount))
            for method in all.dropFirst(NetworkTelemetry.maxReportedMethods) {
                other.count += method.count
                other.retries += method.retries
                for (failure, count) in method.failures {
                    other.failures[failure, default: 0] += count
                }
                for index in 0 ..< min(other.latency.count, method.latency.count) {
                    other.latency[index] += method.latency[index]
                }
            }
            methods.append(other)
        }
        return NetworkTelemetrySummary(
            schema: NetworkTelemetry.schema,
            fromHour: Int32(clamping: Int64(period.fromTime / 3600.0) * 3600),
            toHour: Int32(clamping: Int64(self.wallClock() / 3600.0) * 3600),
            variant: period.variant,
            layer: period.layer,
            app: period.app,
            system: period.system,
            requests: all.reduce(0, { $0 + $1.count }),
            methods: methods,
            connection: NetworkTelemetryConnectionSummary(seconds: period.connectionSeconds.mapValues { $0.rounded() }, transitions: period.transitions, disconnects: period.disconnects, timeToOnline: period.timeToOnline, sessionResets: period.sessionResets, drops: period.drops),
            droppedFailures: period.droppedFailures
        )
    }

    /// Whether the current period counted anything. Call with `lock` held.
    private var periodHasData: Bool {
        return !self.methods.isEmpty || self.period.transitions != 0 || self.period.sessionResets != 0 || self.period.drops != nil || self.period.droppedFailures != 0 || !self.period.connectionSeconds.isEmpty || self.connectionState != nil
    }

    /// Moves the current period, if it counted anything, to the ended ones and starts a new one with
    /// the current labels. Call with `lock` held.
    private func endPeriod(now: Double) {
        self.countPendingSamples()
        if self.periodHasData {
            self.ended.append(self.currentSummary(now: now))
            if self.ended.count > NetworkTelemetry.maxEndedPeriods {
                self.ended.removeFirst(self.ended.count - NetworkTelemetry.maxEndedPeriods)
            }
        }
        self.methods.removeAll()
        self.period = NetworkTelemetryPeriod(fromTime: self.wallClock(), variant: self.variant, app: self.app, system: self.system, layer: self.layer)
        self.connectionStateSince = now
        self.summaryDirty = true
    }

    /// Counts the waiting samples and saves the current state now if it changed. The save is queued
    /// while `lock` is held, so saves reach the disk in the order the state changed.
    func writeSummary() {
        let now = self.clock()
        self.lock.locked {
            self.countPendingSamples()
            self.saveScheduled = false
            if self.summaryDirty {
                self.save(now: now)
            }
        }
    }

    /// Unix time the current period started.
    public var periodStart: Double {
        return self.lock.locked {
            self.period.fromTime
        }
    }

    /// Periods that ended and wait to be reported.
    public var endedPeriodCount: Int {
        return self.lock.locked {
            self.ended.count
        }
    }

    /// The ended periods, the current one and up to `maxFailures` of the oldest unreported failures,
    /// without changing anything.
    public func makeReport(maxFailures: Int) -> NetworkTelemetryReport {
        let now = self.clock()
        return self.lock.locked {
            self.countPendingSamples()
            return NetworkTelemetryReport(summaries: self.ended + [self.currentSummary(now: now)], failures: Array(self.failures.prefix(max(0, maxFailures))))
        }
    }

    /// Ends the current period and hands out every ended period with up to `maxFailures` of the oldest
    /// unreported failures. Pass the report to `commit(report:)` once its sending is queued; requests
    /// completing meanwhile count in the new period.
    public func takeReport(maxFailures: Int) -> NetworkTelemetryReport {
        let now = self.clock()
        let report: NetworkTelemetryReport = self.lock.locked {
            self.endPeriod(now: now)
            let summaries = self.ended
            self.ended.removeAll()
            return NetworkTelemetryReport(summaries: summaries, failures: Array(self.failures.prefix(max(0, maxFailures))))
        }
        self.writeSummary()
        return report
    }

    /// Forgets the failures `report` carried, and any older ones.
    public func commit(report: NetworkTelemetryReport) {
        self.lock.locked {
            if let lastReported = report.failures.last?.sequence {
                self.failures.removeAll(where: { $0.sequence <= lastReported })
                self.store?.replace(failures: self.failures)
            }
        }
    }

    public var pendingFailureCount: Int {
        return self.lock.locked {
            self.failures.count
        }
    }

    /// Failures recorded and not yet reported, oldest first. Also kept on disk in `failures.jsonl`.
    public var pendingFailures: [NetworkFailureRecord] {
        return self.lock.locked {
            self.failures
        }
    }

    /// Waits for the background writes to finish. For tests.
    func waitForStore() {
        self.store?.sync()
    }
}

private struct NetworkTelemetryLoadedState {
    var state: NetworkTelemetryStoredState?
    var failures: [NetworkFailureRecord]
}

/// Files of one account's telemetry: `failures.jsonl` (unreported failure records, one JSON object
/// per line) and `state.json` (the current and the ended periods). Writes run on the store's queue in
/// the order they were queued; a write that fails is skipped and never empties a file.
private final class NetworkTelemetryStore {
    /// `failures.jsonl` is cut back to the latest `NetworkTelemetry.maxFailureRecords` lines once it
    /// holds this many.
    static let trimAtLines = NetworkTelemetry.maxFailureRecords * 2

    private let directory: String
    private let queue = Queue(name: "org.telegram.NetworkTelemetryStore", qos: .utility)
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    /// Lines in `failures.jsonl`, as far as the store knows. Used on the store's queue only.
    private var lines = 0

    private var failuresPath: String {
        return self.directory + "/failures.jsonl"
    }

    private var statePath: String {
        return self.directory + "/state.json"
    }

    init?(directory: String) {
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
        self.directory = directory
    }

    func load() -> NetworkTelemetryLoadedState {
        var failures: [NetworkFailureRecord] = []
        var lines = 0
        if let data = try? Data(contentsOf: URL(fileURLWithPath: self.failuresPath)) {
            let all = data.split(separator: UInt8(ascii: "\n"))
            lines = all.count
            for line in all.suffix(NetworkTelemetry.maxFailureRecords) {
                if let record = try? self.decoder.decode(NetworkFailureRecord.self, from: Data(line)) {
                    failures.append(record)
                }
            }
        }
        self.queue.async {
            self.lines = lines
        }
        var state: NetworkTelemetryStoredState?
        if let data = try? Data(contentsOf: URL(fileURLWithPath: self.statePath)) {
            state = try? self.decoder.decode(NetworkTelemetryStoredState.self, from: data)
        }
        return NetworkTelemetryLoadedState(state: state, failures: failures)
    }

    func append(_ record: NetworkFailureRecord) {
        self.queue.async {
            guard var data = try? self.encoder.encode(record) else {
                return
            }
            data.append(UInt8(ascii: "\n"))
            let descriptor = open(self.failuresPath, O_WRONLY | O_APPEND | O_CREAT, 0o600)
            if descriptor < 0 {
                return
            }
            let start = lseek(descriptor, 0, SEEK_END)
            let complete = data.withUnsafeBytes { buffer -> Bool in
                var offset = 0
                while offset < buffer.count {
                    let written = write(descriptor, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                    if written < 0 && errno == EINTR {
                        continue
                    }
                    if written <= 0 {
                        return false
                    }
                    offset += written
                }
                return true
            }
            if !complete && start >= 0 {
                _ = ftruncate(descriptor, start)
            }
            close(descriptor)
            if complete {
                self.lines += 1
                if self.lines >= NetworkTelemetryStore.trimAtLines {
                    self.trim()
                }
            }
        }
    }

    private func trim() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: self.failuresPath)) else {
            return
        }
        let lines = data.split(separator: UInt8(ascii: "\n")).suffix(NetworkTelemetry.maxFailureRecords)
        var result = Data()
        for line in lines {
            result.append(contentsOf: line)
            result.append(UInt8(ascii: "\n"))
        }
        if (try? result.write(to: URL(fileURLWithPath: self.failuresPath), options: .atomic)) != nil {
            self.lines = lines.count
        }
    }

    func replace(failures: [NetworkFailureRecord]) {
        self.queue.async {
            var data = Data()
            for record in failures {
                if let line = try? self.encoder.encode(record) {
                    data.append(line)
                    data.append(UInt8(ascii: "\n"))
                }
            }
            if (try? data.write(to: URL(fileURLWithPath: self.failuresPath), options: .atomic)) != nil {
                self.lines = failures.count
            }
        }
    }

    func save(state: NetworkTelemetryStoredState) {
        self.queue.async {
            if let data = try? self.encoder.encode(state) {
                try? data.write(to: URL(fileURLWithPath: self.statePath), options: .atomic)
            }
        }
    }

    func sync() {
        self.queue.sync {
        }
    }
}
