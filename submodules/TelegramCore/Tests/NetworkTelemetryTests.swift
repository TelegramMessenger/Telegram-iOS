import XCTest
import SwiftSignalKit
import MtProtoKit
@testable import TelegramApi
@testable import TelegramCore

private final class TestClock {
    private let lock = NSLock()
    private var monotonic: Double = 1000.0
    private var wall: Double = 1_760_000_000.0

    var now: Double {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.monotonic
    }

    var wallNow: Double {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.wall
    }

    func advance(_ seconds: Double) {
        self.lock.lock()
        self.monotonic += seconds
        self.wall += seconds
        self.lock.unlock()
    }
}

private final class FakeRequestService: NetworkEngineRequestService {
    private let lock = NSLock()
    private var requests: [NetworkEngineRequest] = []
    private(set) var addedCount = 0
    private(set) var cancelledCount = 0
    /// Behaves like a service whose session is gone.
    var dropsRequests = false

    func add(_ request: NetworkEngineRequest) -> Disposable {
        if self.dropsRequests {
            return EmptyDisposable
        }
        self.lock.lock()
        self.requests.append(request)
        self.addedCount += 1
        self.lock.unlock()
        let id = ObjectIdentifier(request)
        return ActionDisposable { [weak self] in
            guard let self = self else {
                return
            }
            self.lock.lock()
            let removed = self.requests.firstIndex(where: { ObjectIdentifier($0) == id }).map { self.requests.remove(at: $0) }
            if removed != nil {
                self.cancelledCount += 1
            }
            self.lock.unlock()
        }
    }

    var pending: [NetworkEngineRequest] {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.requests
    }

    func removeAll() -> [NetworkEngineRequest] {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let result = self.requests
        self.requests.removeAll()
        return result
    }

    private func remove(_ request: NetworkEngineRequest) {
        self.lock.lock()
        self.requests.removeAll(where: { $0 === request })
        self.lock.unlock()
    }

    func succeed(_ request: NetworkEngineRequest, networkType: Int32 = 0) {
        self.remove(request)
        request.completed(.success(NetworkEngineResponse(result: true, info: NetworkEngineResponseInfo(timestamp: 0.0, networkType: networkType, duration: 0.0))))
    }

    func fail(_ request: NetworkEngineRequest, code: Int32, text: String, networkType: Int32 = 0) {
        self.remove(request)
        request.completed(.failure(NetworkEngineRequestFailure(error: MTRpcError(errorCode: code, errorDescription: text), info: NetworkEngineResponseInfo(timestamp: 0.0, networkType: networkType, duration: 0.0))))
    }

    func askToContinue(_ request: NetworkEngineRequest, floodWait: Int = 0, floodWaitText: String? = nil, serverErrors: Int = 0) -> Bool {
        return request.shouldContinueAfterError(NetworkEngineErrorContext(floodWaitSeconds: floodWait, floodWaitErrorText: floodWaitText, internalServerErrorCount: serverErrors))
    }
}

private final class FakeSession: NetworkEngineSession {
    let datacenterId: Int
    let role: NetworkEngineSessionRole
    let service = FakeRequestService()
    weak var delegate: NetworkEngineSessionDelegate?
    private(set) var sinks: [NetworkEngineUpdateSink] = []
    private(set) var paused: Bool?
    private(set) var online: Bool?
    private(set) var stopped = false

    init(datacenterId: Int, role: NetworkEngineSessionRole, delegate: NetworkEngineSessionDelegate?) {
        self.datacenterId = datacenterId
        self.role = role
        self.delegate = delegate
    }

    var requestService: NetworkEngineRequestService {
        return self.service
    }

    func setPaused(_ paused: Bool) {
        self.paused = paused
    }

    func setOnline(_ online: Bool) {
        self.online = online
    }

    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        self.sinks.append(sink)
    }

    func stop() {
        self.stopped = true
    }

    func movePendingRequests(to service: NetworkEngineRequestService, completion: @escaping () -> Void) {
        for request in self.service.removeAll() {
            let _ = service.add(request)
        }
        completion()
    }

    func report(_ state: NetworkTelemetryConnectionState) {
        self.delegate?.networkSessionConnectionStateChanged(engineConnectionState(state))
    }

    private var dropObservers: [(NetworkEngineConnectionDrop) -> Void] = []

    func observeConnectionDrops(_ observer: @escaping (NetworkEngineConnectionDrop) -> Void) {
        self.dropObservers.append(observer)
    }

    func drop(_ reason: String, answered: Bool = true, age: Double = 10.0) {
        for observer in self.dropObservers {
            observer(NetworkEngineConnectionDrop(reason: reason, answered: answered, age: age))
        }
    }
}

private final class FakeEngine: NetworkEngine {
    let kind: NetworkEngineKind
    private(set) var sessions: [FakeSession] = []

    init(kind: NetworkEngineKind) {
        self.kind = kind
    }

    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        let session = FakeSession(datacenterId: datacenterId, role: role, delegate: delegate)
        self.sessions.append(session)
        return session
    }
}

private final class FakeDelegate: NetworkEngineSessionDelegate {
    private(set) var states: [NetworkEngineConnectionState] = []
    private(set) var authorizationRequired = 0
    private(set) var softAuthResets = 0

    func networkSessionAuthorizationRequired() {
        self.authorizationRequired += 1
    }

    func networkSessionSoftAuthReset() {
        self.softAuthResets += 1
    }

    func networkSessionConnectionStateChanged(_ state: NetworkEngineConnectionState) {
        self.states.append(state)
    }
}

private final class FakeSink: NetworkEngineUpdateSink {
    private(set) var resets = 0
    private(set) var messages = 0

    func networkSessionDidReset() {
        self.resets += 1
    }

    func networkSessionDidReceive(message: Any) {
        self.messages += 1
    }
}

private func engineConnectionState(_ state: NetworkTelemetryConnectionState, proxyAddress: String? = nil) -> NetworkEngineConnectionState {
    switch state {
    case .waitingForNetwork:
        return NetworkEngineConnectionState(isNetworkAvailable: false, isConnected: false, isUpdatingConnectionContext: false, isPerformingServiceTasks: false, proxyAddress: proxyAddress, proxyHasConnectionIssues: false)
    case .connecting:
        return NetworkEngineConnectionState(isNetworkAvailable: true, isConnected: false, isUpdatingConnectionContext: false, isPerformingServiceTasks: false, proxyAddress: proxyAddress, proxyHasConnectionIssues: false)
    case .connectingWithProxyIssues:
        return NetworkEngineConnectionState(isNetworkAvailable: true, isConnected: false, isUpdatingConnectionContext: false, isPerformingServiceTasks: false, proxyAddress: proxyAddress, proxyHasConnectionIssues: true)
    case .updating:
        return NetworkEngineConnectionState(isNetworkAvailable: true, isConnected: true, isUpdatingConnectionContext: true, isPerformingServiceTasks: false, proxyAddress: proxyAddress, proxyHasConnectionIssues: false)
    case .online:
        return NetworkEngineConnectionState(isNetworkAvailable: true, isConnected: true, isUpdatingConnectionContext: false, isPerformingServiceTasks: false, proxyAddress: proxyAddress, proxyHasConnectionIssues: false)
    }
}

private func makeRequest<T>(_ function: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), fullDescriptionAsShortMetadata: Bool = false, expectedResponseSize: Int32 = 0, policy: @escaping (NetworkEngineErrorContext) -> Bool = { _ in false }, completed: @escaping (Result<NetworkEngineResponse, NetworkEngineRequestFailure>) -> Void = { _ in }) -> NetworkEngineRequest {
    let shortMetadata: CustomStringConvertible = fullDescriptionAsShortMetadata ? WrappedFunctionDescription(function.0) : WrappedShortFunctionDescription(function.0)
    return NetworkEngineRequest(
        payload: function.1.makeData(),
        metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(function.0), tag: nil),
        shortMetadata: WrappedRequestShortMetadata(shortMetadata: shortMetadata),
        parse: { _ in true },
        options: NetworkEngineRequestOptions(expectedResponseSize: expectedResponseSize, needsTimeoutTimer: false),
        shouldContinueAfterError: policy,
        dependsOn: nil,
        acknowledged: nil,
        progress: nil,
        completed: completed
    )
}

private func makeRequest(method: String, policy: @escaping (NetworkEngineErrorContext) -> Bool = { _ in false }, completed: @escaping (Result<NetworkEngineResponse, NetworkEngineRequestFailure>) -> Void = { _ in }) -> NetworkEngineRequest {
    let function = (FunctionDescription(name: method, parameters: []), Buffer(), DeserializeFunctionResponse<Api.Bool> { _ in nil })
    return makeRequest(function, policy: policy, completed: completed)
}

private func getConfigRequest(policy: @escaping (NetworkEngineErrorContext) -> Bool = { _ in false }, completed: @escaping (Result<NetworkEngineResponse, NetworkEngineRequestFailure>) -> Void = { _ in }) -> NetworkEngineRequest {
    return makeRequest(Api.functions.help.getConfig(), policy: policy, completed: completed)
}

private func uploadPartRequest(size: Int) -> NetworkEngineRequest {
    return makeRequest(Api.functions.upload.saveFilePart(fileId: 1, filePart: 0, bytes: Buffer(data: Data(count: size))))
}

private func getFileRequest() -> NetworkEngineRequest {
    let location = Api.InputFileLocation.inputDocumentFileLocation(.init(id: 123456789, accessHash: 987654321, fileReference: Buffer(data: Data([1, 2, 3])), thumbSize: ""))
    return makeRequest(Api.functions.upload.getFile(flags: 0, location: location, offset: 0, limit: 131072), expectedResponseSize: 131072)
}

private final class Harness {
    let clock: TestClock
    let telemetry: NetworkTelemetry
    let inner: FakeEngine
    let engine: RecordingNetworkEngine
    let delegate = FakeDelegate()
    let mainSession: NetworkEngineSession

    init(kind: NetworkEngineKind = .rust, directory: String? = nil, variant: String? = "b", watchEvery: Int = 1) {
        let clock = TestClock()
        self.clock = clock
        self.telemetry = NetworkTelemetry(directory: directory, layer: 214, app: "12.1 (5000)", system: "macos-15.4.0", variant: variant, watchEvery: watchEvery, clock: { clock.now }, wallClock: { clock.wallNow })
        self.inner = FakeEngine(kind: kind)
        self.engine = RecordingNetworkEngine(engine: self.inner, telemetry: self.telemetry)
        self.mainSession = self.engine.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: self.delegate)
    }

    var fakeMain: FakeSession {
        return self.inner.sessions[0]
    }

    func worker(datacenterId: Int, isMedia: Bool, isCdn: Bool) -> (session: NetworkEngineSession, fake: FakeSession) {
        let session = self.engine.makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: 2, isMedia: isMedia, isCdn: isCdn), usageCalculationInfo: nil, delegate: nil)
        return (session, self.inner.sessions[self.inner.sessions.count - 1])
    }

    @discardableResult
    func send(_ request: NetworkEngineRequest, on session: NetworkEngineSession? = nil) -> Disposable {
        return (session ?? self.mainSession).requestService.add(request)
    }

    func connection(_ state: NetworkTelemetryConnectionState) {
        self.fakeMain.report(state)
    }

    func fail(method: String, code: Int32 = 400, text: String = "BAD_REQUEST") {
        let request = makeRequest(method: method)
        self.send(request)
        self.fakeMain.service.fail(request, code: code, text: text)
    }

    func succeed(method: String, after duration: Double = 0.0) {
        let request = makeRequest(method: method)
        self.send(request)
        self.clock.advance(duration)
        self.fakeMain.service.succeed(request)
    }
}

private extension NetworkTelemetryReport {
    var current: NetworkTelemetrySummary {
        return self.summaries[self.summaries.count - 1]
    }
}

private func summary(_ report: NetworkTelemetryReport, engine: String, role: NetworkTelemetryRole, method: String) -> NetworkTelemetryMethodSummary? {
    return report.current.methods.first(where: { $0.engine == engine && $0.role == role && $0.method == method })
}

private func keys(_ json: JSON?) -> Set<String> {
    guard case let .dictionary(value)? = json else {
        return []
    }
    return Set(value.keys)
}

private func temporaryDirectory() -> String {
    return NSTemporaryDirectory() + "network-telemetry-tests-\(UUID().uuidString)"
}

final class NetworkTelemetryTests: XCTestCase {
    private var directories: [String] = []

    override func tearDown() {
        for directory in self.directories {
            try? FileManager.default.removeItem(atPath: directory)
        }
        self.directories.removeAll()
        super.tearDown()
    }

    private func makeDirectory() -> String {
        let directory = temporaryDirectory()
        self.directories.append(directory)
        return directory
    }

    // MARK: - Failure records

    func testFailureRecordCarriesReproductionContext() {
        let h = Harness()
        h.connection(.waitingForNetwork)
        h.clock.advance(1.0)
        h.connection(.connecting)
        h.clock.advance(2.0)
        h.connection(.online)
        for index in 0 ..< 5 {
            h.succeed(method: "messages.getHistory", after: 0.1 * Double(index + 1))
        }

        var policyAnswers = [true, false]
        var completions: [Result<NetworkEngineResponse, NetworkEngineRequestFailure>] = []
        let request = getConfigRequest(policy: { _ in policyAnswers.removeFirst() }, completed: { completions.append($0) })
        h.clock.advance(10.0)
        h.send(request)
        h.clock.advance(1.0)
        XCTAssertTrue(h.fakeMain.service.askToContinue(request, floodWait: 3, floodWaitText: "FLOOD_WAIT_3"))
        h.clock.advance(3.0)
        XCTAssertFalse(h.fakeMain.service.askToContinue(request, floodWait: 37, floodWaitText: "FLOOD_WAIT_37"))
        h.fakeMain.service.fail(request, code: 420, text: "FLOOD_WAIT_37")

        XCTAssertEqual(completions.count, 1)
        if case let .failure(failure)? = completions.first {
            XCTAssertEqual(failure.error.errorCode, 420)
            XCTAssertEqual(failure.error.errorDescription, "FLOOD_WAIT_37")
        } else {
            XCTFail("the original completion must receive the failure")
        }

        let records = h.telemetry.pendingFailures
        XCTAssertEqual(records.count, 1)
        guard let record = records.first else {
            return
        }
        XCTAssertEqual(record.schema, 1)
        XCTAssertEqual(record.sequence, 1)
        XCTAssertEqual(record.engine, "rust")
        XCTAssertEqual(record.variant, "b")
        XCTAssertEqual(record.role, .main)
        XCTAssertEqual(record.datacenter, 2)
        XCTAssertEqual(record.method, "help.getConfig")
        XCTAssertEqual(record.failure, .flood)
        XCTAssertEqual(record.code, 420)
        XCTAssertEqual(record.error, "FLOOD_WAIT_N")
        XCTAssertEqual(record.duration, 4.0, accuracy: 0.0001)
        XCTAssertEqual(record.retries, 1)
        XCTAssertEqual(record.floodWait, 3, "only the flood waits the request waited out")
        XCTAssertEqual(record.serverErrors, 0)
        XCTAssertEqual(record.requestBytes, networkTelemetrySizeBucket(Api.functions.help.getConfig().1.makeData().count))
        XCTAssertEqual(record.spannedSuspension, false)
        XCTAssertEqual(record.cellular, false)
        XCTAssertEqual(record.viaProxy, false)
        XCTAssertNil(record.userOnline)
        XCTAssertEqual(record.connection.map(\.state), [.waitingForNetwork, .connecting, .online])
        XCTAssertEqual(record.connection.map(\.ago), [18.5, 17.5, 15.5])
        XCTAssertEqual(record.sinceOnline, 0.0)
        XCTAssertEqual(record.latencySamples, 5)
        XCTAssertEqual(record.latencyP50 ?? 0.0, 0.3, accuracy: 0.0001)
        XCTAssertEqual(record.latencyP90 ?? 0.0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(record.uptime, 18)
        XCTAssertEqual(record.hour % 3600, 0)
        XCTAssertLessThanOrEqual(Double(record.hour), h.clock.wallNow)
        XCTAssertGreaterThan(Double(record.hour) + 3600.0, h.clock.wallNow)
        XCTAssertEqual(record.layer, 214)
        XCTAssertEqual(record.app, "12.1__5000_")
        XCTAssertEqual(record.system, "macos-15.4.0")
    }

    func testFailureAfterDisconnectReportsTimeSinceOnline() {
        let h = Harness()
        h.connection(.connecting)
        h.connection(.online)
        h.clock.advance(5.0)
        h.connection(.connecting)
        h.clock.advance(7.5)
        h.fail(method: "updates.getDifference", code: -503, text: "Timeout")

        let record = h.telemetry.pendingFailures.first
        XCTAssertEqual(record?.failure, .server)
        XCTAssertEqual(record?.sinceOnline, 7.5)
        XCTAssertEqual(record?.error, "Timeout")
    }

    func testRecordsHoldMethodNamesWithoutParameters() {
        let h = Harness()
        let secretUrl = "https://private.example.org/avatar?token=s3cr3tvalue&user=4815162342"
        let request = makeRequest(Api.functions.upload.getWebFile(location: .inputWebFileLocation(.init(url: secretUrl, accessHash: 1234567890123)), offset: 0, limit: 4096), fullDescriptionAsShortMetadata: true)
        h.send(request)
        h.fakeMain.service.fail(request, code: 400, text: "WEBFILE_NOT_AVAILABLE")

        let record = h.telemetry.pendingFailures.first
        XCTAssertEqual(record?.method, "upload.getWebFile")
        let encoded = String(data: try! JSONEncoder().encode(h.telemetry.pendingFailures), encoding: .utf8)!
        for fragment in ["private.example", "token", "s3cr3t", "4815162342", "1234567890123", "avatar"] {
            XCTAssertFalse(encoded.contains(fragment), "\(fragment) leaked into \(encoded)")
        }

        let other = NetworkEngineRequest(payload: Data(), metadata: WrappedRequestMetadata(metadata: "custom user@example.org", tag: nil), shortMetadata: WrappedRequestShortMetadata(shortMetadata: "custom user@example.org"), parse: { _ in nil }, options: NetworkEngineRequestOptions(), shouldContinueAfterError: { _ in false }, dependsOn: nil, acknowledged: nil, progress: nil, completed: { _ in })
        h.send(other)
        h.fakeMain.service.fail(other, code: 400, text: "X")
        XCTAssertEqual(h.telemetry.pendingFailures.last?.method, "unknown")
    }

    func testErrorTextsAreNormalized() {
        let cases: [(String, String)] = [
            ("FLOOD_WAIT_37", "FLOOD_WAIT_N"),
            ("FLOOD_PREMIUM_WAIT_120", "FLOOD_PREMIUM_WAIT_N"),
            ("FILE_MIGRATE_4", "FILE_MIGRATE_4"),
            ("SLOWMODE_WAIT_5", "SLOWMODE_WAIT_5"),
            ("USER_ID_4815162342_INVALID", "USER_ID_N_INVALID"),
            ("Timeout", "Timeout"),
            ("read timeout", "read timeout"),
            ("TL_PARSING_ERROR", "TL_PARSING_ERROR"),
            ("APNS_VERIFY_CHECK_ABCDEF0123456789", "APNS_VERIFY_CHECK_X"),
            ("PASSWORD_HASH_INVALID", "PASSWORD_HASH_INVALID"),
            ("SESSION_CLOSED", "SESSION_CLOSED"),
            ("E12", "X"),
            ("bad: user@example.org says \"hi\"", "OTHER"),
            ("proxy.example.org", "OTHER"),
            ("lowercase_error", "OTHER"),
            ("", ""),
            (String(repeating: "A", count: 100), "OTHER"),
            ("A_" + String(repeating: "B", count: 30), "A_X"),
            ("ПРИВЕТ_12", "OTHER")
        ]
        for (input, expected) in cases {
            XCTAssertEqual(networkTelemetryErrorText(input), expected, input)
        }
    }

    func testSizesAreBucketed() {
        XCTAssertEqual(networkTelemetrySizeBucket(0), 0)
        XCTAssertEqual(networkTelemetrySizeBucket(1), 16)
        XCTAssertEqual(networkTelemetrySizeBucket(16), 16)
        XCTAssertEqual(networkTelemetrySizeBucket(17), 32)
        XCTAssertEqual(networkTelemetrySizeBucket(1000), 1024)
        XCTAssertEqual(networkTelemetrySizeBucket(524288), 524288)
        XCTAssertEqual(networkTelemetrySizeBucket(524289), 1048576)
    }

    func testFailureClassification() {
        let cases: [(Int32, String, NetworkFailureClass)] = [
            (400, "PEER_ID_INVALID", .client),
            (403, "CHAT_WRITE_FORBIDDEN", .client),
            (401, "AUTH_KEY_UNREGISTERED", .auth),
            (406, "FRESH_RESET_AUTHORISATION_FORBIDDEN", .auth),
            (303, "FILE_MIGRATE_4", .migrate),
            (420, "FLOOD_WAIT_10", .flood),
            (400, "FLOOD_PREMIUM_WAIT_5", .flood),
            (500, "INTERNAL", .server),
            (-503, "Timeout", .server),
            (500, "TL_PARSING_ERROR", .parse),
            (400, "TL_VERIFICATION_ERROR", .parse)
        ]
        for (code, text, expected) in cases {
            XCTAssertEqual(networkFailureClass(code: code, text: text), expected, "\(code) \(text)")
        }
    }

    func testCancelledRequestIsAbandonedOnlyAfterThreshold() {
        let h = Harness()
        let quickDisposable = h.send(getConfigRequest())
        h.clock.advance(5.0)
        quickDisposable.dispose()
        XCTAssertEqual(h.fakeMain.service.cancelledCount, 1)
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty)

        let stuckDisposable = h.send(getConfigRequest())
        h.clock.advance(25.0)
        stuckDisposable.dispose()
        XCTAssertEqual(h.fakeMain.service.cancelledCount, 2)
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.abandoned])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.duration, 25.0)
        stuckDisposable.dispose()
        XCTAssertEqual(h.telemetry.pendingFailures.count, 1)

        let finished = getConfigRequest()
        let finishedDisposable = h.send(finished)
        h.clock.advance(1.0)
        h.fakeMain.service.succeed(finished)
        h.clock.advance(30.0)
        finishedDisposable.dispose()
        XCTAssertEqual(h.telemetry.pendingFailures.count, 1)

        let report = h.telemetry.makeReport(maxFailures: 10)
        let stats = summary(report, engine: "rust", role: .main, method: "help.getConfig")
        XCTAssertEqual(stats?.count, 1)
        XCTAssertEqual(stats?.failures, ["abandoned": 1])
    }

    func testHungRequestIsRecordedAsStalledOnce() {
        let h = Harness()
        h.connection(.online)
        let disposable = h.send(getConfigRequest())
        h.clock.advance(30.0)
        h.telemetry.checkStalledRequests()
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty)

        h.clock.advance(31.0)
        h.telemetry.checkStalledRequests()
        h.telemetry.checkStalledRequests()
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.stalled])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.duration, 61.0)
        XCTAssertEqual(h.telemetry.pendingFailures.first?.method, "help.getConfig")
        XCTAssertEqual(h.telemetry.pendingFailures.first?.inFlight, 1)
        XCTAssertEqual(h.telemetry.watchedRequestCount, 1)

        h.clock.advance(20.0)
        disposable.dispose()
        XCTAssertEqual(h.telemetry.pendingFailures.count, 1, "a stalled request is not reported again when it is abandoned")
        XCTAssertEqual(h.telemetry.watchedRequestCount, 0)
        XCTAssertEqual(summary(h.telemetry.makeReport(maxFailures: 0), engine: "rust", role: .main, method: "help.getConfig")?.failures, ["stalled": 1])
    }

    func testOnlyConnectedTimeCountsTowardStalls() {
        let h = Harness()
        h.connection(.waitingForNetwork)
        let waiting = getConfigRequest()
        h.send(waiting)
        h.clock.advance(120.0)
        h.telemetry.checkStalledRequests()
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty)

        h.connection(.connecting)
        h.clock.advance(5.0)
        h.connection(.online)
        h.telemetry.checkStalledRequests()
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty, "a request is not stalled the moment the connection comes back")
        h.clock.advance(61.0)
        h.telemetry.checkStalledRequests()
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.stalled])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.connection.map(\.state), [.waitingForNetwork, .connecting, .online])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.duration, 186.0)
        h.fakeMain.service.succeed(waiting)
        XCTAssertEqual(h.telemetry.watchedRequestCount, 0)
    }

    func testReconnectLoopStillStalls() {
        let h = Harness()
        h.connection(.online)
        let stuck = getConfigRequest()
        h.send(stuck)
        for _ in 0 ..< 4 {
            h.clock.advance(20.0)
            h.connection(.connecting)
            h.telemetry.checkStalledRequests()
            h.clock.advance(5.0)
            h.connection(.online)
        }
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.stalled], "60 s connected over three short connections is a stall")
        XCTAssertEqual(h.telemetry.pendingFailures.first?.duration, 70.0)
        h.fakeMain.service.succeed(stuck)
    }

    func testSuspendSavesTheState() {
        let directory = self.makeDirectory()
        let h = Harness(directory: directory)
        h.succeed(method: "help.getConfig", after: 0.1)
        h.mainSession.setPaused(true)
        h.telemetry.waitForStore()
        let reloaded = NetworkTelemetry(directory: directory, layer: 214, app: "12.1 (5000)", system: "macos-15.4.0", variant: "b")
        XCTAssertEqual(reloaded.makeReport(maxFailures: 0).current.requests, 1)
    }

    func testFloodWaitsAddUp() {
        let h = Harness()
        h.connection(.online)
        let request = getConfigRequest(policy: { _ in true })
        h.send(request)
        for _ in 0 ..< 3 {
            XCTAssertTrue(h.fakeMain.service.askToContinue(request, floodWait: 8, floodWaitText: "FLOOD_PREMIUM_WAIT_8"))
        }
        XCTAssertTrue(h.fakeMain.service.askToContinue(request, floodWait: 8, floodWaitText: "FLOOD_PREMIUM_WAIT_8", serverErrors: 1))
        h.clock.advance(25.0)
        h.fakeMain.service.succeed(request)
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty, "25 s with 24 s of flood waits is not slow")
        let failed = getConfigRequest(policy: { _ in true })
        h.send(failed)
        XCTAssertTrue(h.fakeMain.service.askToContinue(failed, floodWait: 5, floodWaitText: "FLOOD_WAIT_5"))
        XCTAssertTrue(h.fakeMain.service.askToContinue(failed, floodWait: 7, floodWaitText: "FLOOD_WAIT_7"))
        h.fakeMain.service.fail(failed, code: 420, text: "FLOOD_WAIT_9")
        XCTAssertEqual(h.telemetry.pendingFailures.first?.floodWait, 12)
        XCTAssertEqual(h.telemetry.pendingFailures.first?.retries, 2)
    }

    func testReleaseDuringASuspensionIsNotAbandoned() {
        let h = Harness()
        h.connection(.online)
        do {
            let request = getConfigRequest()
            let disposable = h.send(request)
            h.clock.advance(1.0)
            h.mainSession.setPaused(true)
            h.clock.advance(40.0)
            disposable.dispose()
        }
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty)
        h.mainSession.setPaused(false)
        do {
            let request = getConfigRequest()
            let disposable = h.send(request)
            h.clock.advance(25.0)
            disposable.dispose()
        }
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.abandoned])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.spannedSuspension, false)
    }

    func testReconnectAfterAResumeCountsTowardTimeToOnline() {
        let h = Harness()
        h.connection(.online)
        h.mainSession.setPaused(true)
        h.connection(.connecting)
        h.clock.advance(100.0)
        h.mainSession.setPaused(false)
        h.clock.advance(2.0)
        h.connection(.online)
        var timeToOnline = Array(repeating: Int32(0), count: NetworkTelemetry.latencyBucketBounds.count + 1)
        timeToOnline[8] = 1
        XCTAssertEqual(h.telemetry.makeReport(maxFailures: 0).current.connection.timeToOnline, timeToOnline)
    }

    func testWatchListFollowsEveryEnding() {
        let h = Harness()
        var disposables: [Disposable] = []
        var requests: [Int: NetworkEngineRequest] = [:]
        for index in 0 ..< 50 {
            let request = getConfigRequest()
            if index % 3 != 1 {
                requests[index] = request
            }
            disposables.append(h.send(request))
        }
        XCTAssertEqual(h.telemetry.watchedRequestCount, 50)
        for index in stride(from: 0, to: 50, by: 3) {
            h.fakeMain.service.succeed(requests[index]!)
        }
        for index in stride(from: 1, to: 50, by: 3) {
            disposables[index].dispose()
        }
        XCTAssertEqual(h.telemetry.watchedRequestCount, 16)
        for index in stride(from: 2, to: 50, by: 3) {
            h.fakeMain.service.fail(requests[index]!, code: 400, text: "E")
        }
        XCTAssertEqual(h.telemetry.watchedRequestCount, 0)
        for disposable in disposables {
            disposable.dispose()
        }
        XCTAssertEqual(h.telemetry.watchedRequestCount, 0)
        h.clock.advance(100.0)
        h.telemetry.checkStalledRequests()
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), Array(repeating: .client, count: 16))
    }

    func testSampledWatchingWatchesAboutOneInEight() {
        let h = Harness(watchEvery: 8)
        h.connection(.online)
        let requests = (0 ..< 4000).map { _ in getConfigRequest() }
        for request in requests {
            h.send(request)
        }
        let watched = h.telemetry.watchedRequestCount
        XCTAssertGreaterThan(watched, 4000 / 8 / 2)
        XCTAssertLessThan(watched, 4000 / 8 * 2)
        h.clock.advance(61.0)
        h.telemetry.checkStalledRequests()
        XCTAssertEqual(h.telemetry.pendingFailureCount, min(watched, NetworkTelemetry.maxFailureRecords))
        XCTAssertEqual(summary(h.telemetry.makeReport(maxFailures: 0), engine: "rust", role: .main, method: "help.getConfig")?.failures["stalled"], Int32(watched))
        for request in requests {
            h.fakeMain.service.succeed(request)
        }
        XCTAssertEqual(h.telemetry.watchedRequestCount, 0)
        XCTAssertEqual(h.telemetry.makeReport(maxFailures: 0).current.requests, 4000)
    }

    func testWatchListIsBounded() {
        let h = Harness()
        let requests = (0 ..< NetworkTelemetry.maxWatchedRequests + 10).map { _ in getConfigRequest() }
        for request in requests {
            h.send(request)
        }
        XCTAssertEqual(h.telemetry.watchedRequestCount, NetworkTelemetry.maxWatchedRequests)
        for request in requests.reversed() {
            h.fakeMain.service.succeed(request)
        }
        XCTAssertEqual(h.telemetry.watchedRequestCount, 0)
        XCTAssertEqual(h.telemetry.makeReport(maxFailures: 0).current.requests, Int32(requests.count))
    }

    func testRetriesAreSummarized() {
        let h = Harness()
        let retried = getConfigRequest(policy: { _ in true })
        h.send(retried)
        XCTAssertTrue(h.fakeMain.service.askToContinue(retried, floodWait: 2, floodWaitText: "FLOOD_WAIT_2"))
        XCTAssertTrue(h.fakeMain.service.askToContinue(retried, serverErrors: 1))
        h.fakeMain.service.succeed(retried)
        let failed = getConfigRequest(policy: { _ in true })
        h.send(failed)
        XCTAssertTrue(h.fakeMain.service.askToContinue(failed, serverErrors: 1))
        h.fakeMain.service.fail(failed, code: 500, text: "INTERNAL")
        let stats = summary(h.telemetry.makeReport(maxFailures: 0), engine: "rust", role: .main, method: "help.getConfig")
        XCTAssertEqual(stats?.count, 2)
        XCTAssertEqual(stats?.retries, 3)
        XCTAssertEqual(h.telemetry.pendingFailures.first?.retries, 1)
    }

    func testSlowSuccessIsRecorded() {
        let h = Harness()
        h.succeed(method: "messages.getHistory", after: 12.0)
        h.succeed(method: "messages.getHistory", after: 4.0)
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.slow])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.code, 0)
        XCTAssertEqual(h.telemetry.pendingFailures.first?.error, "")
        let stats = summary(h.telemetry.makeReport(maxFailures: 0), engine: "rust", role: .main, method: "messages.getHistory")
        XCTAssertEqual(stats?.count, 2)
        XCTAssertEqual(stats?.failures, ["slow": 1])
        XCTAssertEqual(stats?.latency[10], 1)
        XCTAssertEqual(stats?.latency[9], 1)
        XCTAssertEqual(stats?.latency.reduce(0, +), 2)
    }

    // MARK: - Aggregates

    func testSummarySeparatesEnginesAndRoles() {
        let h = Harness(kind: .mtProtoKit)
        h.succeed(method: "help.getConfig", after: 0.03)
        let media = h.worker(datacenterId: 4, isMedia: true, isCdn: false)
        let cdn = h.worker(datacenterId: 203, isMedia: true, isCdn: true)
        let upload = h.worker(datacenterId: 2, isMedia: false, isCdn: false)
        for (session, fake) in [media, cdn, upload] {
            let request = getFileRequest()
            h.send(request, on: session)
            h.clock.advance(0.15)
            fake.service.succeed(request)
        }

        let report = h.telemetry.makeReport(maxFailures: 0)
        XCTAssertEqual(report.current.requests, 4)
        XCTAssertEqual(summary(report, engine: "mtProtoKit", role: .main, method: "help.getConfig")?.count, 1)
        XCTAssertEqual(summary(report, engine: "mtProtoKit", role: .media, method: "upload.getFile")?.count, 1)
        XCTAssertEqual(summary(report, engine: "mtProtoKit", role: .cdn, method: "upload.getFile")?.count, 1)
        XCTAssertEqual(summary(report, engine: "mtProtoKit", role: .worker, method: "upload.getFile")?.count, 1)
        XCTAssertEqual(summary(report, engine: "mtProtoKit", role: .media, method: "upload.getFile")?.latency[4], 1)
        XCTAssertEqual(report.current.variant, "b")
        XCTAssertEqual(report.current.layer, 214)
    }

    func testRequestsCountUnderTheEngineTheyStartOn() {
        let clock = TestClock()
        let telemetry = NetworkTelemetry(directory: nil, layer: 214, app: "a", system: "s", variant: nil, watchEvery: 1, clock: { clock.now }, wallClock: { clock.wallNow })
        let mtProtoKit = FakeEngine(kind: .mtProtoKit)
        let rust = FakeEngine(kind: .rust)
        let switching = SwitchingNetworkEngine(engine: mtProtoKit)
        let engine = RecordingNetworkEngine(engine: switching, telemetry: telemetry)
        let session = engine.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: nil)
        let first = getConfigRequest()
        let _ = session.requestService.add(first)
        XCTAssertTrue(switching.switchEngine(to: .rust, drainTimeout: 3600.0, makeEngine: { rust }))
        let second = getConfigRequest()
        let _ = session.requestService.add(second)
        XCTAssertTrue(rust.sessions.first?.service.pending.first === second)
        mtProtoKit.sessions[0].service.succeed(first)
        rust.sessions[0].service.succeed(second)

        let report = telemetry.makeReport(maxFailures: 0)
        XCTAssertEqual(summary(report, engine: "mtProtoKit", role: .main, method: "help.getConfig")?.count, 1)
        XCTAssertEqual(summary(report, engine: "rust", role: .main, method: "help.getConfig")?.count, 1)
    }

    func testConnectionSummary() {
        let h = Harness()
        h.connection(.waitingForNetwork)
        h.clock.advance(2.0)
        h.connection(.connecting)
        h.clock.advance(3.0)
        h.connection(.updating)
        h.clock.advance(1.0)
        h.connection(.online)
        h.connection(.online)
        h.clock.advance(59.0)
        h.connection(.connectingWithProxyIssues)
        h.clock.advance(1.0)
        h.connection(.online)
        h.clock.advance(34.0)
        let sink = FakeSink()
        h.mainSession.addUpdateSink(sink)
        h.fakeMain.sinks.first?.networkSessionDidReset()

        let connection = h.telemetry.makeReport(maxFailures: 0).current.connection
        XCTAssertEqual(connection.seconds, ["waiting_network": 2.0, "connecting": 3.0, "updating": 1.0, "online": 93.0, "connecting_proxy_issues": 1.0])
        XCTAssertEqual(connection.transitions, 5)
        XCTAssertEqual(connection.disconnects, 1)
        var timeToOnline = Array(repeating: Int32(0), count: NetworkTelemetry.latencyBucketBounds.count + 1)
        timeToOnline[8] = 1
        timeToOnline[7] = 1
        XCTAssertEqual(connection.timeToOnline, timeToOnline)
        XCTAssertEqual(connection.sessionResets, 1)
        XCTAssertEqual(sink.resets, 1)
    }

    func testIdenticalTrafficGivesIdenticalDataOnBothEngines() {
        func run(_ kind: NetworkEngineKind) -> NetworkTelemetryReport {
            let h = Harness(kind: kind)
            h.connection(.connecting)
            h.clock.advance(0.7)
            h.connection(.online)
            for index in 0 ..< 20 {
                h.succeed(method: "messages.getHistory", after: 0.02 * Double(index % 7 + 1))
            }
            let media = h.worker(datacenterId: 4, isMedia: true, isCdn: false)
            for index in 0 ..< 6 {
                let request = getFileRequest()
                h.send(request, on: media.session)
                h.clock.advance(0.15)
                if index == 3 {
                    media.fake.service.fail(request, code: 400, text: "FILE_REFERENCE_EXPIRED")
                } else {
                    media.fake.service.succeed(request, networkType: 1)
                }
            }
            h.fail(method: "messages.sendMessage", code: 420, text: "FLOOD_WAIT_12")
            h.fail(method: "account.updateStatus", code: 500, text: "TL_PARSING_ERROR")
            let disposable = h.send(getConfigRequest())
            h.clock.advance(31.0)
            disposable.dispose()
            return h.telemetry.makeReport(maxFailures: 100)
        }
        let mtProtoKit = run(.mtProtoKit)
        let rust = run(.rust)

        func normalized(_ report: NetworkTelemetryReport) -> NetworkTelemetryReport {
            let summaries = report.summaries.map { summary -> NetworkTelemetrySummary in
                var summary = summary
                summary.methods = summary.methods.map { method in
                    var method = method
                    method.engine = "engine"
                    return method
                }
                return summary
            }
            let failures = report.failures.map { record -> NetworkFailureRecord in
                var record = record
                record.engine = "engine"
                return record
            }
            return NetworkTelemetryReport(summaries: summaries, failures: failures)
        }
        XCTAssertEqual(normalized(mtProtoKit), normalized(rust))
        XCTAssertEqual(Set(mtProtoKit.failures.map(\.engine)), ["mtProtoKit"])
        XCTAssertEqual(Set(rust.failures.map(\.engine)), ["rust"])
        XCTAssertEqual(rust.failures.map(\.failure), [.client, .flood, .parse, .abandoned])
        XCTAssertEqual(rust.current.requests, 28)
    }

    // MARK: - Bounds

    func testFailureBufferIsBounded() {
        let h = Harness()
        for index in 0 ..< 300 {
            h.fail(method: "messages.getHistory", text: "E\(index)")
        }
        let failures = h.telemetry.pendingFailures
        XCTAssertEqual(failures.count, NetworkTelemetry.maxFailureRecords)
        XCTAssertEqual(failures.first?.sequence, 45)
        XCTAssertEqual(failures.last?.sequence, 300)
        let report = h.telemetry.makeReport(maxFailures: 1000)
        XCTAssertEqual(report.failures.count, NetworkTelemetry.maxFailureRecords)
        XCTAssertEqual(report.current.droppedFailures, 44)
        XCTAssertEqual(summary(report, engine: "rust", role: .main, method: "messages.getHistory")?.failures, ["client": 300])
    }

    func testMethodTableIsBounded() {
        let h = Harness()
        for index in 0 ..< 600 {
            h.succeed(method: "test.method\(index)")
        }
        let report = h.telemetry.makeReport(maxFailures: 0)
        XCTAssertEqual(report.current.requests, 600)
        XCTAssertEqual(report.current.methods.count, NetworkTelemetry.maxReportedMethods + 1)
        XCTAssertEqual(report.current.methods.reduce(0, { $0 + $1.count }), 600)
        XCTAssertEqual(report.current.methods.last?.method, "other")
        XCTAssertEqual(report.current.methods.last?.engine, "any")
        XCTAssertEqual(report.current.methods.first?.method, "other")
        XCTAssertEqual(report.current.methods.first?.engine, "rust")
        XCTAssertEqual(report.current.methods.first?.count, Int32(600 - NetworkTelemetry.maxMethods))
    }

    func testConnectionHistoryIsBounded() {
        let h = Harness()
        for index in 0 ..< 100 {
            h.connection(index % 2 == 0 ? .connecting : .online)
            h.clock.advance(1.0)
        }
        h.fail(method: "help.getConfig")
        XCTAssertEqual(h.telemetry.pendingFailures.first?.connection.count, NetworkTelemetry.connectionHistory)
        XCTAssertEqual(h.telemetry.pendingFailures.first?.connection.last?.ago, 1.0)
    }

    // MARK: - Persistence

    func testFailuresAndPeriodSurviveRestart() {
        let directory = self.makeDirectory()
        let first = Harness(directory: directory)
        first.connection(.connecting)
        first.clock.advance(1.0)
        first.connection(.online)
        first.succeed(method: "help.getConfig", after: 0.05)
        first.fail(method: "messages.sendMessage", code: 400, text: "PEER_ID_INVALID")
        first.fail(method: "messages.sendMessage", code: 420, text: "FLOOD_WAIT_7")
        first.telemetry.writeSummary()
        first.telemetry.waitForStore()
        let before = first.telemetry.makeReport(maxFailures: 100)

        let second = NetworkTelemetry(directory: directory, layer: 214, app: "12.1 (5000)", system: "macos-15.4.0", variant: "b", clock: { first.clock.now }, wallClock: { first.clock.wallNow })
        let after = second.makeReport(maxFailures: 100)
        XCTAssertEqual(after.failures, before.failures)
        XCTAssertEqual(after.current.methods, before.current.methods)
        XCTAssertEqual(after.current.requests, 3)
        XCTAssertEqual(after.current.connection.seconds["connecting"], 1.0)
        XCTAssertEqual(second.periodStart, first.telemetry.periodStart)

        let engine = RecordingNetworkEngine(engine: FakeEngine(kind: .rust), telemetry: second)
        let session = engine.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: nil)
        let request = getConfigRequest()
        let _ = session.requestService.add(request)
        request.completed(.failure(NetworkEngineRequestFailure(error: MTRpcError(errorCode: 400, errorDescription: "X"), info: NetworkEngineResponseInfo(timestamp: 0.0, networkType: 0, duration: 0.0))))
        XCTAssertEqual(second.pendingFailures.last?.sequence, 3)
    }

    func testRecordersAreSharedPerDirectory() {
        let directory = self.makeDirectory()
        let first = NetworkTelemetry.shared(directory: directory, layer: 1, app: "a", system: "s", variant: nil)
        let second = NetworkTelemetry.shared(directory: directory, layer: 1, app: "a", system: "s", variant: nil)
        XCTAssertTrue(first === second)
        let otherDirectory = self.makeDirectory()
        weak var other: NetworkTelemetry?
        do {
            let telemetry = NetworkTelemetry.shared(directory: otherDirectory, layer: 1, app: "a", system: "s", variant: nil)
            XCTAssertFalse(first === telemetry)
            other = telemetry
        }
        XCTAssertNil(other, "the registry must not keep a recorder alive")
    }

    func testDamagedFilesAreIgnored() {
        let directory = self.makeDirectory()
        let h = Harness(directory: directory)
        h.fail(method: "help.getConfig", text: "A")
        h.telemetry.waitForStore()
        let handle = FileHandle(forWritingAtPath: directory + "/failures.jsonl")!
        handle.seekToEndOfFile()
        handle.write("{not json\n\u{0}\u{1}\n".data(using: .utf8)!)
        handle.closeFile()
        try! "garbage".write(toFile: directory + "/state.json", atomically: true, encoding: .utf8)

        let reloaded = NetworkTelemetry(directory: directory, layer: 214, app: "a", system: "s", variant: nil)
        XCTAssertEqual(reloaded.pendingFailures.map(\.error), ["A"])
        XCTAssertEqual(reloaded.makeReport(maxFailures: 0).current.requests, 0)
    }

    // MARK: - Reporting

    func testTakeReportAndCommit() {
        let directory = self.makeDirectory()
        let h = Harness(directory: directory)
        for index in 0 ..< 25 {
            h.fail(method: "messages.getHistory", text: "E\(index)")
        }
        h.clock.advance(100.0)
        let report = h.telemetry.takeReport(maxFailures: 10)
        XCTAssertEqual(report.failures.map(\.sequence), Array(1 ... 10))
        XCTAssertEqual(report.summaries.count, 1)
        XCTAssertEqual(report.summaries.first?.requests, 25)
        XCTAssertEqual(h.telemetry.periodStart, h.clock.wallNow)

        h.fail(method: "messages.getHistory", text: "LATE")
        h.succeed(method: "help.getConfig", after: 0.1)
        h.telemetry.commit(report: report)

        XCTAssertEqual(h.telemetry.pendingFailures.map(\.sequence), Array(11 ... 26))
        XCTAssertEqual(h.telemetry.pendingFailures.last?.error, "LATE")
        let next = h.telemetry.makeReport(maxFailures: 100)
        XCTAssertEqual(next.summaries.count, 1)
        XCTAssertEqual(next.current.requests, 2, "requests completing between taking and committing a report count in the new period")
        XCTAssertEqual(next.current.droppedFailures, 0)

        h.telemetry.writeSummary()
        h.telemetry.waitForStore()
        let reloaded = NetworkTelemetry(directory: directory, layer: 214, app: "12.1 (5000)", system: "macos-15.4.0", variant: "b")
        XCTAssertEqual(reloaded.pendingFailures, h.telemetry.pendingFailures)
        XCTAssertEqual(reloaded.makeReport(maxFailures: 0).current.requests, 2)
    }

    func testLabelChangesEndThePeriod() {
        let directory = self.makeDirectory()
        let h = Harness(directory: directory, variant: "a")
        h.succeed(method: "help.getConfig", after: 0.1)
        h.telemetry.setVariant("b")
        h.succeed(method: "help.getConfig", after: 0.1)
        h.succeed(method: "help.getConfig", after: 0.1)
        h.telemetry.setVariant("b")
        let report = h.telemetry.makeReport(maxFailures: 0)
        XCTAssertEqual(report.summaries.map(\.variant), ["a", "b"])
        XCTAssertEqual(report.summaries.map(\.requests), [1, 2])

        h.telemetry.writeSummary()
        h.telemetry.waitForStore()
        let updated = NetworkTelemetry(directory: directory, layer: 215, app: "12.2 (5100)", system: "macos-15.4.0", variant: "b")
        let afterUpdate = updated.makeReport(maxFailures: 0)
        XCTAssertEqual(afterUpdate.summaries.map(\.app), ["12.1__5000_", "12.1__5000_", "12.2__5100_"])
        XCTAssertEqual(afterUpdate.summaries.map(\.layer), [214, 214, 215])
        XCTAssertEqual(afterUpdate.summaries.map(\.requests), [1, 2, 0])

        let otherSystem = NetworkTelemetry(directory: self.makeDirectory(), layer: 214, app: "a", system: "macos-15.4.0", variant: nil)
        XCTAssertEqual(otherSystem.makeReport(maxFailures: 0).summaries.map(\.system), ["macos-15.4.0"])
    }

    func testSystemUpdateEndsThePeriod() {
        let directory = self.makeDirectory()
        let h = Harness(directory: directory)
        h.succeed(method: "help.getConfig", after: 0.1)
        h.telemetry.writeSummary()
        h.telemetry.waitForStore()
        let updated = NetworkTelemetry(directory: directory, layer: 214, app: "12.1 (5000)", system: "macos-15.5.0", variant: "b")
        let report = updated.makeReport(maxFailures: 0)
        XCTAssertEqual(report.summaries.map(\.system), ["macos-15.4.0", "macos-15.5.0"])
        XCTAssertEqual(report.summaries.map(\.requests), [1, 0])
    }

    func testStoredStateWithOtherBucketsIsDiscarded() {
        let directory = self.makeDirectory()
        let h = Harness(directory: directory)
        h.succeed(method: "help.getConfig", after: 0.1)
        h.telemetry.writeSummary()
        h.telemetry.waitForStore()
        let path = directory + "/state.json"
        let original = try! String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(original.contains("\"latency\":["))
        let fewer = original.replacingOccurrences(of: "\"latency\":\\[[0-9]+,", with: "\"latency\":[", options: .regularExpression)
        XCTAssertNotEqual(fewer, original)
        try! fewer.write(toFile: path, atomically: true, encoding: .utf8)
        let shorter = NetworkTelemetry(directory: directory, layer: 214, app: "12.1 (5000)", system: "macos-15.4.0", variant: "b")
        XCTAssertEqual(shorter.makeReport(maxFailures: 0).current.requests, 0)
        let more = original.replacingOccurrences(of: "\"latency\":[", with: "\"latency\":[0,")
        try! more.write(toFile: path, atomically: true, encoding: .utf8)

        let clock = TestClock()
        let reloaded = NetworkTelemetry(directory: directory, layer: 214, app: "12.1 (5000)", system: "macos-15.4.0", variant: "b", watchEvery: 1, clock: { clock.now }, wallClock: { clock.wallNow })
        XCTAssertEqual(reloaded.makeReport(maxFailures: 0).current.requests, 0)
        let engine = RecordingNetworkEngine(engine: FakeEngine(kind: .rust), telemetry: reloaded)
        let session = engine.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: nil)
        let request = getConfigRequest()
        let _ = session.requestService.add(request)
        request.completed(.success(NetworkEngineResponse(result: true, info: NetworkEngineResponseInfo(timestamp: 0.0, networkType: 0, duration: 0.0))))
        XCTAssertEqual(reloaded.makeReport(maxFailures: 0).current.requests, 1)
    }

    func testFailuresFileIsTrimmed() {
        let directory = self.makeDirectory()
        let h = Harness(directory: directory)
        for index in 0 ..< 600 {
            h.fail(method: "messages.getHistory", text: "E\(index)")
        }
        h.telemetry.waitForStore()
        let lines = try! String(contentsOfFile: directory + "/failures.jsonl", encoding: .utf8).split(separator: "\n")
        XCTAssertLessThan(lines.count, 2 * NetworkTelemetry.maxFailureRecords)
        let reloaded = NetworkTelemetry(directory: directory, layer: 214, app: "a", system: "s", variant: nil)
        XCTAssertEqual(reloaded.pendingFailures.map(\.sequence), (345 ... 600).map(Int64.init))
    }

    func testCommitAfterBufferRotationDoesNotResend() {
        let h = Harness()
        for index in 0 ..< NetworkTelemetry.maxFailureRecords {
            h.fail(method: "messages.getHistory", text: "E\(index)")
        }
        let report = h.telemetry.makeReport(maxFailures: NetworkTelemetry.maxFailureRecords)
        for index in 0 ..< 10 {
            h.fail(method: "messages.getHistory", text: "NEW\(index)")
        }
        h.telemetry.commit(report: report)
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.sequence), Array(Int64(NetworkTelemetry.maxFailureRecords + 1) ... Int64(NetworkTelemetry.maxFailureRecords + 10)))
    }

    func testConfigurationParsing() {
        func configuration(_ values: [String: JSON]?) -> NetworkTelemetryConfiguration {
            return NetworkTelemetryConfiguration.with(appConfiguration: AppConfiguration(data: values.map { .dictionary($0) }, hash: 0))
        }
        XCTAssertEqual(configuration(nil), .disabled)
        XCTAssertEqual(configuration([:]), .disabled)
        XCTAssertTrue(configuration(["network_telemetry_enabled": .bool(true)]).isEnabled)
        XCTAssertTrue(configuration(["network_telemetry_enabled": .number(1.0)]).isEnabled)
        XCTAssertFalse(configuration(["network_telemetry_enabled": .number(0.0)]).isEnabled)
        XCTAssertTrue(configuration(["network_telemetry_enabled": .string("true")]).isEnabled)
        XCTAssertFalse(configuration(["network_telemetry_enabled": .string("0")]).isEnabled)
        XCTAssertFalse(configuration(["network_telemetry_enabled": .null]).isEnabled)
        XCTAssertEqual(configuration(["network_telemetry_variant": .string("rust_b")]).variant, "rust_b")
        XCTAssertEqual(configuration(["network_telemetry_variant": .string("a b/c\u{1F600}" + String(repeating: "x", count: 40))]).variant?.count, 32)
        XCTAssertEqual(configuration(["network_telemetry_variant": .string("a b/c")]).variant, "a_b_c")
        XCTAssertNil(configuration(["network_telemetry_variant": .string("")]).variant)
        XCTAssertEqual(configuration(["network_telemetry_report_interval": .number(7200.0)]).reportInterval, 7200.0)
        XCTAssertEqual(configuration(["network_telemetry_report_interval": .number(5.0)]).reportInterval, 3600.0)
        XCTAssertEqual(configuration(["network_telemetry_report_interval": .number(1e9)]).reportInterval, 7.0 * 24.0 * 3600.0)
        XCTAssertEqual(configuration([:]).reportInterval, 24.0 * 3600.0)
    }

    func testRecordingDecision() {
        let enabled = NetworkTelemetryConfiguration(isEnabled: true, variant: nil, reportInterval: 86400.0)
        XCTAssertFalse(networkTelemetryShouldRecord(supplementary: true, isAppExtension: false, configuration: enabled))
        XCTAssertFalse(networkTelemetryShouldRecord(supplementary: false, isAppExtension: true, configuration: enabled))
        XCTAssertTrue(networkTelemetryShouldRecord(supplementary: false, isAppExtension: false, configuration: enabled))
        XCTAssertEqual(networkTelemetryShouldRecord(supplementary: false, isAppExtension: false, configuration: .disabled), networkTelemetryAlwaysRecords)

        networkTelemetryOverrides.recording = true
        XCTAssertTrue(networkTelemetryShouldRecord(supplementary: true, isAppExtension: true, configuration: .disabled))
        networkTelemetryOverrides.recording = false
        XCTAssertFalse(networkTelemetryShouldRecord(supplementary: false, isAppExtension: false, configuration: enabled))
        networkTelemetryOverrides.recording = nil
    }

    func testReportIsDue() {
        let enabled = NetworkTelemetryConfiguration(isEnabled: true, variant: nil, reportInterval: 86400.0)
        func due(_ now: Double, _ periodStart: Double, failures: Int = 0, ended: Int = 0, configuration: NetworkTelemetryConfiguration = enabled) -> Bool {
            return networkTelemetryReportIsDue(now: now, periodStart: periodStart, pendingFailures: failures, endedPeriods: ended, configuration: configuration)
        }
        XCTAssertFalse(due(1000.0, 0.0))
        XCTAssertTrue(due(86400.0, 0.0))
        XCTAssertFalse(due(86400.0, 0.0, configuration: .disabled))
        XCTAssertFalse(due(3599.0, 0.0, failures: 200))
        XCTAssertTrue(due(3600.0, 0.0, failures: 200))
        XCTAssertFalse(due(3600.0, 0.0, failures: 127))
        XCTAssertFalse(due(3599.0, 0.0, ended: 1))
        XCTAssertTrue(due(3600.0, 0.0, ended: 1))
        XCTAssertTrue(due(0.0, 50.0))
    }

    func testEventsAreChunkedAndKeepValues() {
        let h = Harness(variant: nil)
        h.succeed(method: "help.getConfig", after: 0.25)
        for index in 0 ..< 25 {
            h.clock.advance(0.125)
            h.fail(method: "messages.getHistory", text: "E\(index)")
        }
        let report = h.telemetry.makeReport(maxFailures: 100)
        let events = networkTelemetryEvents(report: report, reportId: -2, failuresPerEvent: 10)

        XCTAssertEqual(events.map(\.type), [NetworkTelemetryEvent.summaryType] + Array(repeating: NetworkTelemetryEvent.failuresType, count: 3))
        for event in events {
            guard case let .dictionary(data) = event.data else {
                XCTFail("event data must be an object")
                continue
            }
            XCTAssertEqual(data["report_id"], .string("fffffffffffffffe"))
            XCTAssertNotNil(apiJson(event.data), "event \(event.type) would not be sent")
        }
        guard case let .dictionary(summaryData) = events[0].data, case let .dictionary(firstChunk) = events[1].data, case let .dictionary(lastChunk) = events[3].data else {
            return XCTFail()
        }
        XCTAssertNil(summaryData["variant"])
        XCTAssertEqual(summaryData["part"], .number(0.0))
        XCTAssertEqual(summaryData["parts"], .number(1.0))
        XCTAssertEqual(summaryData["failure_count"], .number(25.0))
        XCTAssertEqual(summaryData["requests"], .number(26.0))
        XCTAssertEqual(firstChunk["offset"], .number(0.0))
        XCTAssertEqual(lastChunk["offset"], .number(20.0))
        guard case let .array(records)? = lastChunk["records"], case let .dictionary(record)? = records.first else {
            return XCTFail()
        }
        XCTAssertEqual(records.count, 5)
        XCTAssertEqual(record["sequence"], .number(21.0))
        XCTAssertEqual(record["error"], .string("X"))
        XCTAssertEqual(record["latency_p50"], .number(0.25))
        XCTAssertEqual(record["cellular"], .bool(false))
        XCTAssertEqual(record["via_proxy"], .bool(false))

        let empty = Harness().telemetry.makeReport(maxFailures: 10)
        XCTAssertTrue(networkTelemetryEvents(report: empty, reportId: 1, failuresPerEvent: 10).isEmpty)
    }

    /// The fields that leave the device. A new field must be added here on purpose, after checking
    /// that it identifies neither the user nor their contacts or content.
    func testReportedFieldsAreAllowlisted() {
        let h = Harness()
        h.mainSession.setOnline(true)
        h.connection(.connecting)
        h.connection(.online)
        let upload = uploadPartRequest(size: 30000)
        let download = getFileRequest()
        h.send(upload)
        h.send(download)
        h.clock.advance(1.0)
        h.fakeMain.service.succeed(upload)
        h.fakeMain.service.succeed(download)
        h.succeed(method: "help.getConfig", after: 0.1)
        h.send(getConfigRequest())
        h.telemetry.checkStalledRequests()
        h.fakeMain.drop("probe_timeout")
        h.fail(method: "messages.getHistory", code: 420, text: "FLOOD_WAIT_3")
        let worker = h.worker(datacenterId: 2, isMedia: true, isCdn: false)
        let part = getFileRequest()
        h.send(part, on: worker.session)
        worker.fake.service.fail(part, code: 400, text: "FILE_REFERENCE_EXPIRED")
        let report = h.telemetry.makeReport(maxFailures: 10)
        let events = networkTelemetryEvents(report: report, reportId: 7, failuresPerEvent: 10)

        XCTAssertEqual(keys(events[0].data), ["schema", "report_id", "part", "parts", "failure_count", "from_hour", "to_hour", "variant", "layer", "app", "system", "requests", "methods", "connection", "dropped_failures"])
        guard case let .dictionary(summaryData) = events[0].data, case let .array(methods)? = summaryData["methods"] else {
            return XCTFail()
        }
        XCTAssertEqual(keys(methods.first), ["engine", "role", "method", "count", "retries", "failures", "latency"])
        XCTAssertEqual(keys(summaryData["connection"]), ["seconds", "transitions", "disconnects", "time_to_online", "session_resets", "drops"])
        XCTAssertEqual(keys(events[1].data), ["schema", "report_id", "offset", "records"])
        guard case let .dictionary(chunk) = events[1].data, case let .array(records)? = chunk["records"] else {
            return XCTFail()
        }
        let mainKeys: Set<String> = ["schema", "sequence", "hour", "uptime", "engine", "variant", "role", "datacenter", "method", "failure", "code", "error", "duration", "spanned_suspension", "retries", "flood_wait", "server_errors", "request_bytes", "expected_bytes", "cellular", "via_proxy", "user_online", "connection", "drops", "since_online", "in_flight", "latency_p50", "latency_p90", "latency_samples", "uplink_rate", "downlink_rate", "layer", "app", "system"]
        XCTAssertEqual(keys(records.first), mainKeys)
        let media = records.first { record in
            guard case let .dictionary(fields) = record, case .string("media")? = fields["role"] else {
                return false
            }
            return true
        }
        XCTAssertNotNil(media)
        XCTAssertEqual(keys(media).subtracting(mainKeys), ["main_latency_p50", "main_latency_p90"], "a record of another session adds the main session's round trip and nothing else")
        guard case let .dictionary(record)? = records.first, case let .array(connection)? = record["connection"] else {
            return XCTFail()
        }
        XCTAssertEqual(keys(connection.first), ["ago", "state"])
        guard case let .array(drops)? = record["drops"] else {
            return XCTFail()
        }
        XCTAssertEqual(keys(drops.first), ["ago", "reason", "answered", "age"])
    }

    func testFailureRecordsCarryTheRateTheLinkLatelyMoved() {
        let h = Harness()
        h.connection(.online)
        let parts = [uploadPartRequest(size: 20000), uploadPartRequest(size: 20000)]
        let size = parts[0].payload.count
        parts.forEach { h.send($0) }
        h.clock.advance(2.0)
        parts.forEach { h.fakeMain.service.succeed($0) }
        h.clock.advance(50.0)
        let later = uploadPartRequest(size: 20000)
        h.send(later)
        h.clock.advance(1.0)
        h.fakeMain.service.succeed(later)
        let download = getFileRequest()
        h.send(download)
        h.clock.advance(4.0)
        h.fakeMain.service.succeed(download)
        h.fail(method: "messages.getHistory")
        let record = h.telemetry.pendingFailures.last
        XCTAssertEqual(record?.uplinkRate, networkTelemetrySizeBucket(size), "parallel parts add up and the idle 50 s between uploads do not count")
        XCTAssertNotEqual(networkTelemetrySizeBucket(size), networkTelemetrySizeBucket(size * 3 / 5), "summing the durations would have told apart")
        XCTAssertEqual(record?.downlinkRate, networkTelemetrySizeBucket(131072 / 4))

        h.clock.advance(NetworkTelemetry.transferWindow + 1.0)
        h.fail(method: "messages.getHistory")
        XCTAssertNil(h.telemetry.pendingFailures.last?.uplinkRate, "an old transfer says nothing about the link now")
        XCTAssertNil(h.telemetry.pendingFailures.last?.downlinkRate)

        let offline = Harness()
        offline.connection(.online)
        let spanning = uploadPartRequest(size: 20000)
        offline.send(spanning)
        offline.connection(.connecting)
        offline.clock.advance(5.0)
        offline.connection(.online)
        offline.clock.advance(1.0)
        offline.fakeMain.service.succeed(spanning)
        offline.fail(method: "messages.getHistory")
        XCTAssertNil(offline.telemetry.pendingFailures.last?.uplinkRate, "time without a connection is not a slow link")

        let changed = Harness()
        changed.connection(.online)
        let before = uploadPartRequest(size: 20000)
        changed.send(before)
        changed.clock.advance(1.0)
        changed.fakeMain.service.succeed(before)
        changed.connection(.waitingForNetwork)
        changed.connection(.online)
        changed.fail(method: "messages.getHistory")
        XCTAssertNil(changed.telemetry.pendingFailures.last?.uplinkRate, "transfers on the network that was lost do not describe the new one")

        let report = Harness()
        report.connection(.online)
        let log = makeRequest((FunctionDescription(name: "help.saveAppLog", parameters: []), Buffer(data: Data(count: 20000)), DeserializeFunctionResponse<Api.Bool> { _ in nil }))
        XCTAssertGreaterThanOrEqual(log.payload.count, 20000)
        report.send(log)
        report.clock.advance(1.0)
        report.fakeMain.service.succeed(log)
        report.fail(method: "messages.getHistory")
        XCTAssertNil(report.telemetry.pendingFailures.last?.uplinkRate, "a large call is not an upload part: its time includes the server's")

        let small = Harness()
        small.connection(.online)
        let tiny = uploadPartRequest(size: 1000)
        small.send(tiny)
        small.clock.advance(1.0)
        small.fakeMain.service.succeed(tiny)
        small.fail(method: "messages.getHistory")
        XCTAssertNil(small.telemetry.pendingFailures.last?.uplinkRate, "small requests measure the round trip, not the link")
    }

    func testReporterEnqueuesThenCommits() {
        let h = Harness()
        h.succeed(method: "help.getConfig", after: 0.1)
        h.fail(method: "messages.getHistory")
        let configuration = NetworkTelemetryConfiguration(isEnabled: true, variant: "c", reportInterval: 3600.0)
        var enqueued: [[NetworkTelemetryEvent]] = []
        let reporter = NetworkTelemetryReporter(telemetry: h.telemetry, wallClock: { h.clock.wallNow }, enqueue: { events in
            enqueued.append(events)
            return .complete()
        })

        let _ = reporter.reportIfDue(configuration: configuration).start()
        XCTAssertTrue(enqueued.isEmpty)
        XCTAssertEqual(h.telemetry.pendingFailureCount, 1)

        h.clock.advance(3600.0)
        let _ = reporter.reportIfDue(configuration: configuration).start()
        XCTAssertEqual(enqueued.count, 1)
        XCTAssertEqual(enqueued.first?.map(\.type), [NetworkTelemetryEvent.summaryType, NetworkTelemetryEvent.failuresType])
        if case let .dictionary(data)? = enqueued.first?.first?.data {
            XCTAssertEqual(data["variant"], .string("b"), "the counts were made under the old arm")
        } else {
            XCTFail()
        }
        XCTAssertEqual(h.telemetry.makeReport(maxFailures: 0).current.variant, "c")
        XCTAssertEqual(h.telemetry.pendingFailureCount, 0)
        XCTAssertEqual(h.telemetry.periodStart, h.clock.wallNow)

        let _ = reporter.reportIfDue(configuration: configuration).start()
        XCTAssertEqual(enqueued.count, 1)
    }

    func testReporterCommitsOnceTheWriteIsQueued() {
        let h = Harness()
        h.fail(method: "messages.getHistory")
        h.clock.advance(7200.0)
        var started = 0
        let reporter = NetworkTelemetryReporter(telemetry: h.telemetry, wallClock: { h.clock.wallNow }, enqueue: { _ in
            started += 1
            return .never()
        })
        let disposable = reporter.reportIfDue(configuration: NetworkTelemetryConfiguration(isEnabled: true, variant: "b", reportInterval: 3600.0)).start()
        XCTAssertEqual(started, 1)
        XCTAssertEqual(h.telemetry.pendingFailureCount, 0, "a queued Postbox write cannot be cancelled, so the report is committed when it is queued")
        disposable.dispose()
        XCTAssertEqual(h.telemetry.pendingFailureCount, 0)
        XCTAssertEqual(h.telemetry.endedPeriodCount, 0)

        h.fail(method: "messages.getHistory")
        let disabled = reporter.reportIfDue(configuration: .disabled).start()
        disabled.dispose()
        XCTAssertEqual(started, 1)
        XCTAssertEqual(h.telemetry.pendingFailureCount, 1)
    }

    func testSuspensionIsNotCountedAsWaiting() {
        let h = Harness()
        h.connection(.online)
        let longWait = getConfigRequest()
        h.send(longWait)
        h.clock.advance(5.0)
        h.mainSession.setPaused(true)
        h.clock.advance(300.0)
        h.mainSession.setPaused(false)
        h.clock.advance(5.0)
        h.telemetry.checkStalledRequests()
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty, "a suspension is not a stall")
        h.fakeMain.service.succeed(longWait)
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty, "10 s of waiting while active is neither a stall nor slow")
        let report = h.telemetry.makeReport(maxFailures: 0)
        XCTAssertEqual(summary(report, engine: "rust", role: .main, method: "help.getConfig")?.count, 1)
        XCTAssertEqual(summary(report, engine: "rust", role: .main, method: "help.getConfig")?.latency.reduce(0, +), 0)
        XCTAssertEqual(report.current.connection.seconds["online"], 10.0)

        let stuck = getConfigRequest()
        h.send(stuck)
        h.mainSession.setPaused(true)
        h.clock.advance(100.0)
        h.mainSession.setPaused(false)
        h.clock.advance(61.0)
        h.telemetry.checkStalledRequests()
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.stalled])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.spannedSuspension, true)
        XCTAssertEqual(h.telemetry.pendingFailures.first?.duration, 161.0)
        XCTAssertEqual(h.telemetry.makeReport(maxFailures: 0).current.connection.seconds["online"], 71.0)
        h.fakeMain.service.succeed(stuck)
    }

    func testSlowSuccessAfterSuspensionIsRecordedOnlyForActiveTime() {
        let h = Harness()
        let request = getConfigRequest()
        h.send(request)
        h.mainSession.setPaused(true)
        h.clock.advance(50.0)
        h.mainSession.setPaused(false)
        h.clock.advance(8.0)
        h.fakeMain.service.succeed(request)
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty)
        let slow = getConfigRequest()
        h.send(slow)
        h.mainSession.setPaused(true)
        h.clock.advance(50.0)
        h.mainSession.setPaused(false)
        h.clock.advance(12.0)
        h.fakeMain.service.succeed(slow)
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.slow])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.spannedSuspension, true)
    }

    func testFloodWaitIsNotAStall() {
        let h = Harness()
        h.connection(.online)
        let request = getConfigRequest(policy: { _ in true })
        h.send(request)
        XCTAssertTrue(h.fakeMain.service.askToContinue(request, floodWait: 120, floodWaitText: "FLOOD_WAIT_120"))
        h.clock.advance(150.0)
        h.telemetry.checkStalledRequests()
        XCTAssertTrue(h.telemetry.pendingFailures.isEmpty)
        h.clock.advance(40.0)
        h.telemetry.checkStalledRequests()
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.stalled])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.floodWait, 120)
        h.fakeMain.service.succeed(request)
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.stalled, .slow])
        XCTAssertEqual(summary(h.telemetry.makeReport(maxFailures: 0), engine: "rust", role: .main, method: "help.getConfig")?.latency.reduce(0, +), 0)
    }

    func testDroppedRequestIsRecordedOnce() {
        let h = Harness()
        h.fakeMain.service.dropsRequests = true
        do {
            let request = getConfigRequest()
            let disposable = h.send(request)
            XCTAssertTrue((disposable as AnyObject) === (EmptyDisposable as AnyObject))
            h.clock.advance(60.0)
            request.completed(.success(NetworkEngineResponse(result: true, info: NetworkEngineResponseInfo(timestamp: 0.0, networkType: 0, duration: 0.0))))
        }
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.dropped])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.method, "help.getConfig")
        let stats = summary(h.telemetry.makeReport(maxFailures: 0), engine: "rust", role: .main, method: "help.getConfig")
        XCTAssertEqual(stats?.failures, ["dropped": 1])
        XCTAssertEqual(stats?.count, 0, "a refused request is never counted as completed")
    }

    func testRecordsHoldNoRequestMetadata() {
        let h = Harness()
        weak var weakMetadata: WrappedRequestShortMetadata?
        do {
            let request = getConfigRequest()
            weakMetadata = request.shortMetadata
            let disposable = h.send(request)
            h.fakeMain.service.succeed(request)
            disposable.dispose()
        }
        XCTAssertNil(weakMetadata, "a waiting sample must not keep the request's metadata, which holds every argument")
        XCTAssertEqual(h.telemetry.makeReport(maxFailures: 0).current.requests, 1)
    }

    // MARK: - Decorator contract

    func testDelegateAndSinksAreForwarded() {
        let h = Harness()
        XCTAssertNotNil(h.fakeMain.delegate, "the session must keep the recording delegate alive; engines hold delegates weakly")
        h.connection(.connecting)
        h.connection(.online)
        h.fakeMain.delegate?.networkSessionAuthorizationRequired()
        h.fakeMain.delegate?.networkSessionSoftAuthReset()
        XCTAssertEqual(h.delegate.states, [engineConnectionState(.connecting), engineConnectionState(.online)])
        XCTAssertEqual(h.delegate.authorizationRequired, 1)
        XCTAssertEqual(h.delegate.softAuthResets, 1)

        let sink = FakeSink()
        h.mainSession.addUpdateSink(sink)
        h.fakeMain.sinks.first?.networkSessionDidReceive(message: 1)
        h.fakeMain.sinks.first?.networkSessionDidReset()
        XCTAssertEqual(sink.messages, 1)
        XCTAssertEqual(sink.resets, 1)

        let worker = h.worker(datacenterId: 4, isMedia: true, isCdn: false)
        let workerSink = FakeSink()
        worker.session.addUpdateSink(workerSink)
        XCTAssertTrue(worker.fake.sinks.first === workerSink)
        XCTAssertNil(worker.fake.delegate)
        XCTAssertEqual(h.telemetry.makeReport(maxFailures: 0).current.connection.sessionResets, 1)
    }

    func testDelegateIsNotRetainedByRecording() {
        let telemetry = NetworkTelemetry(directory: nil, layer: 1, app: "a", system: "s", variant: nil)
        let inner = FakeEngine(kind: .rust)
        let engine = RecordingNetworkEngine(engine: inner, telemetry: telemetry)
        weak var weakDelegate: FakeDelegate?
        var delegate: FakeDelegate? = FakeDelegate()
        weakDelegate = delegate
        let session = engine.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: delegate)
        delegate = nil
        XCTAssertNil(weakDelegate)
        inner.sessions[0].report(.online)
        XCTAssertEqual(session.datacenterId, 2)
    }

    func testSessionCallsAreForwarded() {
        let h = Harness()
        h.mainSession.setPaused(false)
        h.mainSession.setOnline(true)
        XCTAssertEqual(h.fakeMain.paused, false)
        XCTAssertEqual(h.fakeMain.online, true)
        XCTAssertEqual(h.mainSession.datacenterId, 2)
        let worker = h.worker(datacenterId: 4, isMedia: false, isCdn: false)
        worker.session.stop()
        XCTAssertTrue(worker.fake.stopped)
        XCTAssertFalse(h.fakeMain.stopped)
    }

    func testFailureRecordsSayWhetherTheUserWasOnline() {
        let h = Harness()
        h.connection(.online)
        h.mainSession.setOnline(true)
        h.fail(method: "help.getConfig", code: 500, text: "INTERNAL")
        let worker = h.worker(datacenterId: 4, isMedia: true, isCdn: false)
        worker.session.setOnline(false)
        h.fail(method: "help.getConfig", code: 500, text: "INTERNAL")
        h.mainSession.setOnline(false)
        h.fail(method: "help.getConfig", code: 500, text: "INTERNAL")
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.userOnline), [true, true, false], "only the main session follows the user")
    }

    func testFailuresOfTransferSessionsCarryTheMainSessionsRoundTrip() {
        let h = Harness()
        h.connection(.online)
        for duration in [0.1, 0.2, 0.3, 0.4, 0.5] {
            h.succeed(method: "help.getConfig", after: duration)
        }
        let upload = uploadPartRequest(size: 30000)
        h.send(upload)
        h.clock.advance(4.0)
        h.fakeMain.service.succeed(upload)
        let worker = h.worker(datacenterId: 2, isMedia: true, isCdn: false)
        let finished = getFileRequest()
        h.send(finished, on: worker.session)
        h.clock.advance(3.0)
        worker.fake.service.succeed(finished)
        let download = getFileRequest()
        h.send(download, on: worker.session)
        worker.fake.service.fail(download, code: 400, text: "FILE_REFERENCE_EXPIRED")
        h.fail(method: "help.getConfig", code: 500, text: "INTERNAL")

        let records = h.telemetry.pendingFailures
        XCTAssertEqual(records.map(\.role), [.media, .main])
        XCTAssertEqual(records.first?.mainLatencyP50 ?? 0.0, 0.3, accuracy: 0.0001)
        XCTAssertEqual(records.first?.mainLatencyP90 ?? 0.0, 0.5, accuracy: 0.0001, "an upload part on the main session is not a round trip")
        XCTAssertEqual(records.first?.latencyP50 ?? 0.0, 3.0, accuracy: 0.0001, "the media session's own latency is its download")
        XCTAssertNil(records.last?.mainLatencyP50, "a main record already has it as its own latency")
        guard let media = records.first, case let .dictionary(fields)? = networkTelemetryJSON(media) else {
            return XCTFail()
        }
        XCTAssertNotNil(fields["main_latency_p50"])
        XCTAssertNotNil(fields["main_latency_p90"])
    }

    func testConnectionDropsAreCountedByRoleAndCarriedByFailuresOfThatRole() {
        let h = Harness()
        h.connection(.online)
        let worker = h.worker(datacenterId: 2, isMedia: true, isCdn: false)
        h.fakeMain.drop("probe_timeout")
        h.clock.advance(5.0)
        worker.fake.drop("racer_won", answered: false, age: 2.5)
        worker.fake.drop("Not A Reason!")
        h.clock.advance(1.0)
        h.fail(method: "help.getConfig", code: 500, text: "INTERNAL")
        let download = getFileRequest()
        h.send(download, on: worker.session)
        worker.fake.service.fail(download, code: 400, text: "FILE_REFERENCE_EXPIRED")

        let records = h.telemetry.pendingFailures
        XCTAssertEqual(records.map(\.role), [.main, .media])
        XCTAssertEqual(records.first?.drops, [NetworkTelemetryDrop(ago: 6.0, reason: "probe_timeout", answered: true, age: 10.0)])
        XCTAssertEqual(records.last?.drops, [
            NetworkTelemetryDrop(ago: 1.0, reason: "racer_won", answered: false, age: 2.5),
            NetworkTelemetryDrop(ago: 1.0, reason: "other", answered: true, age: 10.0)
        ], "only the media sessions' drops, and no engine text leaves the device unchecked")
        XCTAssertEqual(h.telemetry.makeReport(maxFailures: 0).summaries.first?.connection.drops, ["main": ["probe_timeout": 1], "media": ["racer_won_unanswered": 1, "other": 1]])

        h.clock.advance(NetworkTelemetry.transferWindow + 1.0)
        h.fail(method: "help.getConfig", code: 500, text: "INTERNAL")
        XCTAssertNil(h.telemetry.pendingFailures.last?.drops, "an old drop says nothing about this failure")
    }

    func testRequestDroppedWithItsSessionIsAbandoned() {
        let h = Harness()
        let worker = h.worker(datacenterId: 4, isMedia: true, isCdn: false)
        let _ = worker.session.requestService.add(getFileRequest())
        h.clock.advance(45.0)
        XCTAssertEqual(worker.fake.service.removeAll().count, 1)
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.abandoned])
        XCTAssertEqual(h.telemetry.pendingFailures.first?.role, .media)
        XCTAssertEqual(h.telemetry.pendingFailures.first?.method, "upload.getFile")
        XCTAssertEqual(h.telemetry.pendingFailures.first?.expectedBytes, 131072)
    }

    func testCompletedRequestReleaseRecordsNothing() {
        let h = Harness()
        do {
            let request = getConfigRequest()
            let disposable = h.send(request)
            h.clock.advance(40.0)
            h.fakeMain.service.succeed(request)
            disposable.dispose()
        }
        XCTAssertEqual(h.telemetry.pendingFailures.map(\.failure), [.slow])
    }

    func testRequestsPassThroughUnchanged() {
        let h = Harness()
        var answers: [NetworkEngineErrorContext] = []
        var completions = 0
        let request = getConfigRequest(policy: { context in
            answers.append(context)
            return context.internalServerErrorCount < 2
        }, completed: { _ in
            completions += 1
        })
        let disposable = h.send(request)
        XCTAssertTrue(h.fakeMain.service.pending.first === request)
        XCTAssertTrue(h.fakeMain.service.askToContinue(request, serverErrors: 1))
        XCTAssertFalse(h.fakeMain.service.askToContinue(request, serverErrors: 2))
        XCTAssertEqual(answers.map(\.internalServerErrorCount), [1, 2])
        h.fakeMain.service.fail(request, code: 500, text: "INTERNAL")
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(h.telemetry.pendingFailures.first?.retries, 1)
        XCTAssertEqual(h.telemetry.pendingFailures.first?.serverErrors, 2)
        disposable.dispose()
        XCTAssertEqual(h.fakeMain.service.cancelledCount, 0)

        let cancelled = getConfigRequest()
        h.send(cancelled).dispose()
        XCTAssertEqual(h.fakeMain.service.cancelledCount, 1)
        XCTAssertTrue(h.fakeMain.service.pending.isEmpty)
    }

    func testMovedRequestIsCountedOnce() {
        let h = Harness()
        let target = h.worker(datacenterId: 2, isMedia: false, isCdn: false)
        let request = getConfigRequest()
        h.send(request)
        h.mainSession.movePendingRequests(to: target.session.requestService, completion: {})
        XCTAssertTrue(h.fakeMain.service.pending.isEmpty)
        XCTAssertTrue(target.fake.service.pending.first === request)
        target.fake.service.succeed(request)
        let report = h.telemetry.makeReport(maxFailures: 0)
        XCTAssertEqual(report.current.requests, 1)
        XCTAssertEqual(summary(report, engine: "rust", role: .main, method: "help.getConfig")?.count, 1)
    }

    func testConcurrentRequestsAreCountedExactly() {
        let h = Harness()
        let threads = 8
        let perThread = 2000
        DispatchQueue.concurrentPerform(iterations: threads) { thread in
            for index in 0 ..< perThread {
                let request = makeRequest(method: "m\(index % 3)")
                let disposable = h.mainSession.requestService.add(request)
                if (thread + index) % 5 == 0 {
                    h.fakeMain.service.fail(request, code: 400, text: "E")
                } else {
                    h.fakeMain.service.succeed(request)
                }
                disposable.dispose()
            }
        }
        let report = h.telemetry.makeReport(maxFailures: 0)
        XCTAssertEqual(report.current.requests, Int32(threads * perThread))
        XCTAssertEqual(h.telemetry.watchedRequestCount, 0)
        XCTAssertEqual(report.current.methods.reduce(0, { $0 + ($1.failures["client"] ?? 0) }), Int32(threads * perThread / 5))
        XCTAssertEqual(h.telemetry.pendingFailureCount, NetworkTelemetry.maxFailureRecords)
    }

    func testRecordingOverheadPerRequest() {
        let count = 100_000
        let bare = FakeRequestService()
        let h = Harness(watchEvery: NetworkTelemetry.watchEvery)
        let requests = (0 ..< count).map { _ in getConfigRequest() }
        let bareRequests = (0 ..< count).map { _ in getConfigRequest() }

        let bareStart = CFAbsoluteTimeGetCurrent()
        for request in bareRequests {
            let _ = bare.add(request)
            bare.succeed(request)
        }
        let bareTime = CFAbsoluteTimeGetCurrent() - bareStart

        let start = CFAbsoluteTimeGetCurrent()
        for request in requests {
            let _ = h.mainSession.requestService.add(request)
            h.fakeMain.service.succeed(request)
        }
        let time = CFAbsoluteTimeGetCurrent() - start
        let overhead = (time - bareTime) / Double(count) * 1_000_000.0
        print("NetworkTelemetry overhead: \(String(format: "%.2f", overhead)) us per request (bare \(String(format: "%.2f", bareTime / Double(count) * 1_000_000.0)) us)")
        XCTAssertEqual(h.telemetry.makeReport(maxFailures: 0).current.requests, Int32(count))
    }
}
