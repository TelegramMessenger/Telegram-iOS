import Foundation
import SwiftSignalKit
import MtProtoKit
import TelegramCore
import MTProtoEngineFFI
import MTProtoRustEngineMapping

struct RustRequestControl {
    var isCancelled = false
    var moved: Disposable?
}

final class RustPendingRequest {
    let request: NetworkEngineRequest
    let localId: UInt64
    let flags: UInt32
    let expectedResponseSize: UInt32
    let control = Atomic<RustRequestControl>(value: RustRequestControl())
    var engineId: UInt64 = 0
    var isInEngine = false
    var isFinished = false
    var errorState = RustEngineErrorState()
    var resubmitTimer: SwiftSignalKit.Timer?
    var verificationDisposable: MTDisposable?
    var verificationTimer: SwiftSignalKit.Timer?

    init(request: NetworkEngineRequest, localId: UInt64, flags: UInt32, expectedResponseSize: UInt32) {
        self.request = request
        self.localId = localId
        self.flags = flags
        self.expectedResponseSize = expectedResponseSize
    }

    var isCancelled: Bool {
        return self.control.with { $0.isCancelled }
    }

    func releaseResources() {
        self.resubmitTimer?.invalidate()
        self.resubmitTimer = nil
        self.verificationDisposable?.dispose()
        self.verificationDisposable = nil
        self.verificationTimer?.invalidate()
        self.verificationTimer = nil
    }
}

final class RustRequestService: NetworkEngineRequestService {
    weak var session: RustNetworkSession?

    init() {
    }

    func add(_ request: NetworkEngineRequest) -> Disposable {
        guard let session = self.session else {
            return EmptyDisposable
        }
        return session.add(request)
    }
}

final class RustNetworkSession: NetworkEngineSession {
    let datacenterId: Int
    let requestService: NetworkEngineRequestService

    private let runtime: RustEngineRuntime
    private let engine: OpaquePointer?
    private let context: MTContext
    private let isMain: Bool
    private let isCdn: Bool
    private let isMedia: Bool
    private let masterDatacenterId: Int
    private let requiresForeignAuthToken: Bool
    private let requiredAuthToken: NSNumber?
    private let withoutUpdates: Bool
    private let queue: Queue
    private let mailbox: RustEngineMailbox
    private let listener: RustContextListener
    private weak var delegate: NetworkEngineSessionDelegate?
    private let usageManager: MTNetworkUsageManager?
    private var selector: MTDatacenterAuthInfoSelector
    private var obfuscationDatacenterId: Int16
    private let isStopped = Atomic<Bool>(value: false)
    private var handle: MTSessionHandle = 0
    private var logPrefix: String

    private var pendingById: [UInt64: RustPendingRequest] = [:]
    private var activeRequests: [RustPendingRequest] = []
    private var activeByLocalId: [UInt64: RustPendingRequest] = [:]
    private var heldRequests: [RustPendingRequest] = []
    private var verifyingRequests: [UInt64: RustPendingRequest] = [:]
    private var sinks: [NetworkEngineUpdateSink] = []
    private var dropObservers: [(NetworkEngineConnectionDrop) -> Void] = []

    private var externallyPaused = true
    private var appliedPaused = true
    private var appliedOnline = false
    private var holdForReplacementKey = false
    private var holdForUnsupportedProxy = false

    private var installedKeyId: Int64?
    private var installedKeyAt: CFAbsoluteTime = 0.0
    private var awaitingKey = false
    private var rejectedKeyId: Int64?
    private var authTokenReady: Bool

    private let runsPfs: Bool
    private let httpPort: UInt16
    private var temporaryKeyId: Int64?
    private var madeTemporaryKey: (keyId: Int64, key: Data, salt: Int64)?

    private var schemes: [MTTransportScheme]
    private var addressFingerprint: [String]
    private var requestedSchemes = false
    private var apiEnvironment: MTApiEnvironment

    private var lastEventKind: RustEngineEventKind?
    private var lastConnectionFlags: RustEngineConnectionFlags?
    private var lastEngineProxyAddress: String?
    private var lastNetworkIsCellular = false
    private var lastReportedState: NetworkEngineConnectionState?
    private var connectionWatchdog: SwiftSignalKit.Timer?
    private var connectionWatchdogDelay: Double = RustNetworkSession.connectionWatchdogInitialDelay
    private var connectionProblemsReported = false

    private static let connectionWatchdogInitialDelay: Double = 20.0
    private static let connectionWatchdogMaxDelay: Double = 320.0
    private static let permanentKeyImmunity: Double = 60.0
    private static let temporaryKeyMinimumLifetime: Int32 = 300

    init(runtime: RustEngineRuntime, context: MTContext, datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?, serverPublicKeys: [String], httpPort: UInt16) {
        self.runtime = runtime
        self.httpPort = httpPort
        self.engine = runtime.engine
        self.context = context
        self.datacenterId = datacenterId
        self.delegate = delegate

        let roleName: String
        switch role {
        case .main:
            self.isMain = true
            self.isCdn = false
            self.isMedia = false
            self.masterDatacenterId = datacenterId
            roleName = "main"
        case let .worker(masterDatacenterId, isMedia, isCdn):
            self.isMain = false
            self.isCdn = isCdn
            self.isMedia = isMedia
            self.masterDatacenterId = masterDatacenterId
            roleName = isCdn ? "cdn" : (isMedia ? "media" : "worker")
        }
        self.requiresForeignAuthToken = rustEngineRequiresForeignAuthToken(isMain: self.isMain, isCdn: self.isCdn, datacenterId: datacenterId, masterDatacenterId: self.masterDatacenterId)
        self.runsPfs = rustEngineRunsPfs(isCdn: self.isCdn, useTempAuthKeys: context.useTempAuthKeys, publicKeyCount: serverPublicKeys.count)
        self.requiredAuthToken = self.requiresForeignAuthToken ? (datacenterId as NSNumber) : nil

        self.queue = Queue(name: "org.telegram.MTProtoRust.session")
        self.mailbox = RustEngineMailbox(queue: self.queue)
        self.listener = RustContextListener(queue: self.queue)
        self.usageManager = usageCalculationInfo.flatMap { MTNetworkUsageManager(info: $0) }
        let requestService = RustRequestService()
        self.requestService = requestService
        self.apiEnvironment = context.apiEnvironment
        self.withoutUpdates = !self.isMain || self.apiEnvironment.disableUpdates

        if let requiredAuthToken = self.requiredAuthToken {
            self.authTokenReady = requiredAuthToken.isEqual(context.authTokenForDatacenter(withId: datacenterId))
        } else {
            self.authTokenReady = true
        }

        let schemes = RustNetworkSession.loadSchemes(context: context, datacenterId: datacenterId, isMedia: self.isMedia, apiEnvironment: self.apiEnvironment)
        self.schemes = schemes
        self.addressFingerprint = RustNetworkSession.fingerprint(schemes)
        let preferForMedia = schemes.first?.address.preferForMedia ?? false
        self.selector = RustNetworkSession.authInfoSelector(context: context, isCdn: self.isCdn, preferForMedia: preferForMedia)
        self.obfuscationDatacenterId = rustEngineObfuscationDatacenterId(datacenterId: datacenterId, isTestingEnvironment: context.isTestingEnvironment, preferForMedia: preferForMedia)
        self.holdForUnsupportedProxy = (self.apiEnvironment.socksProxySettings?.webProxy ?? false) && !runtime.carriesWebProxy
        self.logPrefix = "[MTProtoRust#0 dc\(datacenterId) \(roleName)]"

        let authInfo = context.authInfoForDatacenter(withId: datacenterId, selector: self.keySelector)

        let arena = RustEngineArena()
        var setup = MTSessionSetup()
        setup.datacenter_id = Int32(datacenterId)
        setup.obfuscation_dc_id = self.obfuscationDatacenterId
        setup.role = rustEngineSessionRole(isMain: self.isMain, isCdn: self.isCdn, datacenterId: datacenterId, masterDatacenterId: self.masterDatacenterId).rawValue
        setup.framing = UInt8(MTFramingAbridged)
        let addresses = RustNetworkSession.makeAddresses(schemes, arena: arena)
        setup.addresses = arena.array(addresses)
        setup.address_count = addresses.count
        setup.proxy = RustNetworkSession.makeProxy(self.apiEnvironment.socksProxySettings, arena: arena)
        if let authInfo = authInfo, let material = RustNetworkSession.makeKeyMaterial(authInfo, includeInitHash: !self.runsPfs, arena: arena) {
            setup.auth_key = material.key
            setup.salts = material.salts
            setup.salt_count = material.saltCount
            setup.has_init_hash = material.hasInitHash
            setup.init_hash = material.initHash
            self.installedKeyId = authInfo.authKeyId
        }
        setup.generate_key = 0
        setup.environment = arena.value(RustNetworkSession.makeEnvironment(self.apiEnvironment, layer: RustNetworkSession.currentLayer(context), arena: arena))
        setup.time_difference = context.globalTimeDifference()
        setup.online = 0
        setup.paused = 1
        setup.keep_connected = self.isMain ? 1 : 0
        setup.idle_disconnect_after = self.isMain ? 0.0 : 60.0
        setup.request_timeout = 5.0
        if self.runsPfs {
            let publicKeys = serverPublicKeys.map { arena.string($0) }
            setup.public_keys_pem = arena.array(publicKeys)
            setup.public_key_count = publicKeys.count
            setup.pfs_lifetime = context.tempKeyExpiration
            setup.pfs_make_permanent_key = 0
            if let stored = self.storedTemporaryKey(), let temporaryKey = RustNetworkSession.makeTemporaryKey(stored, timeDifference: context.globalTimeDifference(), arena: arena) {
                setup.pfs_temporary_key = arena.value(temporaryKey)
            }
        }

        let mailbox = self.mailbox
        let handle: MTSessionHandle = withExtendedLifetime(arena) {
            return withUnsafePointer(to: &setup) { pointer in
                return runtime.createSession(setup: pointer, mailbox: mailbox)
            }
        }
        self.handle = handle
        self.logPrefix = "[MTProtoRust#\(handle) dc\(datacenterId) \(roleName)]"

        self.mailbox.attach(self)
        self.listener.session = self
        requestService.session = self

        context.add(self.listener)

        if handle == 0 {
            rustEngineImportantLog("\(self.logPrefix) mt_session_create failed, requests on this session will never complete")
        } else {
            rustEngineLog("\(self.logPrefix) created, key \(authInfo != nil ? "present" : "missing") selector \(self.selector.rawValue)\(self.runsPfs ? ", PFS in the engine" : ""), \(addresses.count) addresses, token \(self.requiresForeignAuthToken ? (self.authTokenReady ? "ready" : "missing") : "not required")")
            if let engine = self.engine, !self.isCdn {
                mt_session_set_transport(engine, handle, UInt8(MTTransportAuto), self.httpPort)
                if #available(macOS 10.14, iOS 12.0, *) {
                    RustNetworkSession.setWebEndpoint(engine: engine, handle: handle, isTestingEnvironment: context.isTestingEnvironment)
                }
            }
        }

        if self.requiresForeignAuthToken && !self.authTokenReady, let engine = self.engine, handle != 0 {
            mt_session_set_auth_token_ready(engine, handle, 0)
        }
    }

    deinit {
        if !self.isStopped.swap(true) {
            self.teardown()
        }
        self.releaseQueueResources()
    }

    func stop() {
        if self.isStopped.swap(true) {
            return
        }
        rustEngineLog("\(self.logPrefix) stop")
        self.teardown()
        self.queue.async { [weak self] in
            self?.releaseQueueResources()
        }
    }

    private func teardown() {
        self.runtime.destroySession(handle: self.handle)
        self.context.remove(self.listener)
    }

    private func releaseQueueResources() {
        for request in self.activeRequests {
            request.releaseResources()
        }
        for (_, request) in self.verifyingRequests {
            request.releaseResources()
        }
        self.connectionWatchdog?.invalidate()
        self.connectionWatchdog = nil
    }

    func setPaused(_ paused: Bool) {
        self.queue.async { [weak self] in
            guard let self = self, !self.isStopped.with({ $0 }) else {
                return
            }
            if self.externallyPaused == paused {
                return
            }
            self.externallyPaused = paused
            rustEngineImportantLog("\(self.logPrefix) \(paused ? "pause" : "resume")")
            if !paused {
                self.refreshSchemes()
                self.resetConnectionWatchdogBackoff()
            }
            self.applyPaused()
            if !paused {
                if self.awaitingKey {
                    self.requestAwaitedKey()
                }
                self.ensureAuthToken()
            }
            self.updateConnectionWatchdog()
            self.reportConnectionState()
        }
    }

    func setOnline(_ online: Bool) {
        self.queue.async { [weak self] in
            guard let self = self, !self.isStopped.with({ $0 }) else {
                return
            }
            if self.appliedOnline == online {
                return
            }
            self.appliedOnline = online
            rustEngineLog("\(self.logPrefix) \(online ? "online" : "offline")")
            guard let engine = self.engine, self.handle != 0 else {
                return
            }
            mt_session_set_online(engine, self.handle, online ? 1 : 0)
        }
    }

    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        self.queue.async { [weak self] in
            self?.sinks.append(sink)
        }
    }

    func observeConnectionDrops(_ observer: @escaping (NetworkEngineConnectionDrop) -> Void) {
        self.queue.async { [weak self] in
            self?.dropObservers.append(observer)
        }
    }

    func add(_ request: NetworkEngineRequest) -> Disposable {
        let flags = rustEngineRequestFlags(wantsQuickAck: request.acknowledged != nil, wantsProgress: request.progress != nil, needsTimeoutTimer: request.options.needsTimeoutTimer, withoutUpdates: self.withoutUpdates)
        let localId = self.runtime.nextRequestId()
        let pending = RustPendingRequest(request: request, localId: localId, flags: flags, expectedResponseSize: rustEngineExpectedResponseSize(request.options.expectedResponseSize))
        self.queue.async { [weak self] in
            self?.submit(pending)
        }
        let control = pending.control
        let queue = self.queue
        return ActionDisposable { [weak self] in
            var moved: Disposable?
            let _ = control.modify { current in
                var updated = current
                updated.isCancelled = true
                moved = current.moved
                return updated
            }
            if let moved = moved {
                moved.dispose()
            } else {
                queue.async {
                    self?.cancel(localId: localId)
                }
            }
        }
    }

    func movePendingRequests(to service: NetworkEngineRequestService, completion: @escaping () -> Void) {
        self.queue.async { [weak self] in
            guard let self = self else {
                completion()
                return
            }
            let pendings = self.activeRequests.filter { !$0.isFinished && !$0.isCancelled }
            for pending in pendings {
                let engineId = pending.engineId
                let wasInEngine = pending.isInEngine
                self.finish(pending)
                if wasInEngine, engineId != 0, let engine = self.engine, self.handle != 0 {
                    mt_session_cancel(engine, self.handle, engineId)
                }
                let disposable = service.add(pending.request)
                var isCancelled = false
                let _ = pending.control.modify { current in
                    var updated = current
                    updated.moved = disposable
                    isCancelled = current.isCancelled
                    return updated
                }
                if isCancelled {
                    disposable.dispose()
                }
            }
            if !pendings.isEmpty {
                rustEngineImportantLog("\(self.logPrefix) moved \(pendings.count) unanswered requests to another engine")
            }
            completion()
        }
    }

    private func cancel(localId: UInt64) {
        guard let pending = self.activeByLocalId[localId] else {
            return
        }
        self.cancel(pending)
    }

    private func submit(_ pending: RustPendingRequest) {
        if pending.isCancelled || self.isStopped.with({ $0 }) {
            return
        }
        self.activeRequests.append(pending)
        self.activeByLocalId[pending.localId] = pending
        self.sendToEngine(pending)
        self.updateConnectionWatchdog()
    }

    private func sendToEngine(_ pending: RustPendingRequest) {
        guard let engine = self.engine, self.handle != 0 else {
            return
        }
        if self.requiresForeignAuthToken && self.installedKeyId == nil {
            if !self.heldRequests.contains(where: { $0 === pending }) {
                self.heldRequests.append(pending)
            }
            return
        }
        var invokeAfter: UInt64 = 0
        if let dependsOn = pending.request.dependsOn {
            let earlier = self.activeRequests.firstIndex(where: { $0 === pending }).map { self.activeRequests[..<$0] } ?? self.activeRequests[...]
            let candidates = earlier.filter { $0.isInEngine }
            if let index = rustEngineDependencyIndex(candidates: candidates, accepts: { dependsOn($0.request.metadata) }) {
                invokeAfter = candidates[index].engineId
            }
        }
        let requestId = self.runtime.nextRequestId()
        if requestId == 0 {
            return
        }
        if pending.engineId != 0 {
            self.pendingById.removeValue(forKey: pending.engineId)
        }
        pending.engineId = requestId
        pending.isInEngine = true
        self.pendingById[requestId] = pending
        let payload = pending.request.payload
        payload.withUnsafeBytes { bytes in
            var request = MTProtoEngineFFI.MTRequest()
            request.id = requestId
            request.body = MTBytes(data: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), length: bytes.count)
            request.flags = pending.flags
            request.expected_response_size = pending.expectedResponseSize
            request.invoke_after = invokeAfter
            mt_session_send(engine, self.handle, &request)
        }
        rustEngineLog("\(self.logPrefix) send #\(requestId) \(pending.request.shortMetadata.description)\(invokeAfter != 0 ? " after #\(invokeAfter)" : "")")
    }

    private func cancel(_ pending: RustPendingRequest) {
        if pending.isFinished {
            return
        }
        let engineId = pending.engineId
        let wasInEngine = pending.isInEngine
        self.finish(pending)
        if wasInEngine, engineId != 0, let engine = self.engine, self.handle != 0 {
            mt_session_cancel(engine, self.handle, engineId)
            rustEngineLog("\(self.logPrefix) cancel #\(engineId)")
        }
    }

    private func finish(_ pending: RustPendingRequest) {
        pending.isFinished = true
        pending.isInEngine = false
        pending.releaseResources()
        if pending.engineId != 0, self.pendingById[pending.engineId] === pending {
            self.pendingById.removeValue(forKey: pending.engineId)
        }
        if pending.engineId != 0, self.verifyingRequests[pending.engineId] === pending {
            self.verifyingRequests.removeValue(forKey: pending.engineId)
        }
        if self.activeByLocalId.removeValue(forKey: pending.localId) != nil, let index = self.activeRequests.firstIndex(where: { $0 === pending }) {
            self.activeRequests.remove(at: index)
        }
        if let index = self.heldRequests.firstIndex(where: { $0 === pending }) {
            self.heldRequests.remove(at: index)
        }
        self.updateConnectionWatchdog()
    }

    private func flushHeldRequests() {
        if self.heldRequests.isEmpty {
            return
        }
        let held = self.heldRequests
        self.heldRequests.removeAll()
        for pending in held where !pending.isFinished && !pending.isCancelled {
            self.sendToEngine(pending)
        }
    }

    func handleEngineEvent(_ event: RustEngineEvent) {
        if self.isStopped.with({ $0 }) {
            return
        }
        guard let kind = event.kind else {
            rustEngineLog("\(self.logPrefix) unknown event kind \(event.rawKind)")
            return
        }
        let previousKind = self.lastEventKind
        self.lastEventKind = kind

        switch kind {
        case .completed:
            self.handleCompleted(event)
        case .failed:
            self.handleFailed(event, previousKind: previousKind)
        case .retryDecisionRequired:
            self.handleRetryDecision(event)
        case .acknowledged:
            if let pending = self.pendingById[event.requestId], !pending.isCancelled {
                pending.request.acknowledged?()
            }
        case .progress:
            if let pending = self.pendingById[event.requestId], !pending.isCancelled {
                pending.request.progress?(Float(event.value1), Int(event.value2))
            }
        case .floodWaitReported:
            break
        case .verificationRequired:
            self.handleVerificationRequired(event)
        case .authorizationRequired:
            let action = rustEngineAuthorizationRequiredAction(isMain: self.isMain)
            rustEngineImportantLog("\(self.logPrefix) authorization required: 401 \(event.text), \(action)")
            switch action {
            case .logOut:
                self.delegate?.networkSessionAuthorizationRequired()
            case .ignore:
                break
            }
        case .softAuthReset:
            rustEngineImportantLog("\(self.logPrefix) soft auth reset: \(event.text)")
            if self.isMain {
                self.delegate?.networkSessionSoftAuthReset()
            }
        case .authTokenRequired:
            rustEngineImportantLog("\(self.logPrefix) auth token required")
            if self.requiresForeignAuthToken {
                self.authTokenReady = false
            }
            self.workerAuthorizationRequired()
        case .temporaryKeyRejected:
            rustEngineImportantLog("\(self.logPrefix) received AUTH_KEY_PERM_EMPTY")
            if self.runsPfs {
                return
            }
            self.handleMissingKey(rejectedKeyId: self.installedKeyId, engineStillHoldsKey: true)
        case .authKeyInvalid:
            rustEngineImportantLog("\(self.logPrefix) auth key invalid (\(event.code))")
            if self.runsPfs {
                return
            }
            let rejectedKeyId = self.installedKeyId
            self.installedKeyId = nil
            self.handleMissingKey(rejectedKeyId: rejectedKeyId, engineStillHoldsKey: false)
            self.updateConnectionWatchdog()
        case .authKeyRequired:
            self.handleAuthKeyRequired()
        case .initHashStored:
            self.updateContextInitializationHash(event.text)
        case .initHashCleared:
            self.updateContextInitializationHash(nil)
        case .updatesReset:
            rustEngineLog("\(self.logPrefix) updates reset")
            for sink in self.sinks {
                sink.networkSessionDidReset()
            }
        case .update:
            self.handleUpdate(event, previousWasUpdatesReset: previousKind == .updatesReset)
        case .timeDifferenceUpdated:
            if rustEngineSharesTimeDifference(isCdn: self.isCdn) {
                self.context.setGlobalTimeDifference(event.value1)
            }
        case .saltsUpdated:
            self.mergeSalts(event.salts)
        case .pong:
            break
        case .connectionState:
            self.lastConnectionFlags = RustEngineConnectionFlags(rawValue: event.flags)
            self.lastEngineProxyAddress = event.text.isEmpty ? nil : event.text
            self.updateConnectionWatchdog()
            self.reportConnectionState()
        case .networkUsage:
            self.lastNetworkIsCellular = (event.flags & UInt32(MTNetworkUsageCellular)) != 0
            if let usageManager = self.usageManager {
                let interface = self.lastNetworkIsCellular ? MTNetworkUsageManagerInterfaceWWAN : MTNetworkUsageManagerInterfaceOther
                if event.integer1 > 0 {
                    usageManager.addIncomingBytes(UInt(clamping: event.integer1), interface: interface)
                }
                if event.integer2 > 0 {
                    usageManager.addOutgoingBytes(UInt(clamping: event.integer2), interface: interface)
                }
            }
        case .addressResult:
            let index = Int(clamping: event.integer1)
            if index >= 0 && index < self.schemes.count {
                let scheme = self.schemes[index]
                if event.code != 0 {
                    self.context.reportTransportSchemeSuccess(forDatacenterId: self.datacenterId, transportScheme: scheme)
                } else {
                    self.context.reportTransportSchemeFailure(forDatacenterId: self.datacenterId, transportScheme: scheme)
                }
            }
        case .authKeyCreated:
            if self.runsPfs {
                self.handleEngineMadeKey(event)
            } else {
                rustEngineImportantLog("\(self.logPrefix) unexpected engine-generated auth key ignored")
            }
        case .temporaryKeyBound:
            rustEngineLog("\(self.logPrefix) temporary key bound")
        case .temporaryKeyBindFailed:
            rustEngineImportantLog("\(self.logPrefix) binding the temporary key failed: \(event.code) \(event.text)")
        case .permanentKeyInvalid:
            rustEngineImportantLog("\(self.logPrefix) the server does not know the permanent key \(self.installedKeyId.map(String.init) ?? "none")")
            self.handlePermanentKeyInvalid()
        case .temporaryKeyInUse:
            self.handleTemporaryKeyInUse(event)
        case .temporaryKeyDropped:
            self.handleTemporaryKeyDropped(event)
        case .routeMemoryChanged:
            break
        case .authKeyCreationFailed:
            rustEngineLog("\(self.logPrefix) auth key creation failed: \(event.text)")
        case .transportFlood:
            rustEngineLog("\(self.logPrefix) transport flood (-429)")
        case .connectionDropped:
            let drop = NetworkEngineConnectionDrop(reason: event.text, answered: (event.flags & 1) != 0, age: event.value1)
            rustEngineLog("\(self.logPrefix) connection dropped: \(drop.reason), answered \(drop.answered), after \(drop.age) s")
            for observer in self.dropObservers {
                observer(drop)
            }
        case .closed:
            break
        }
    }

    private func responseInfo(_ event: RustEngineEvent) -> NetworkEngineResponseInfo {
        return NetworkEngineResponseInfo(timestamp: event.value1, networkType: self.lastNetworkIsCellular ? 1 : 0, duration: event.value2)
    }

    private func handleCompleted(_ event: RustEngineEvent) {
        guard let pending = self.pendingById[event.requestId] else {
            return
        }
        self.pendingById.removeValue(forKey: event.requestId)
        pending.isInEngine = false
        if pending.isCancelled || pending.isFinished {
            self.finish(pending)
            return
        }
        let info = self.responseInfo(event)
        let data = event.payload ?? Data()
        if let result = pending.request.parse(data) {
            rustEngineLog("\(self.logPrefix) completed #\(event.requestId)")
            self.finish(pending)
            pending.request.completed(.success(NetworkEngineResponse(result: result, info: info)))
        } else {
            self.handleParseFailure(pending, info: info)
        }
    }

    private func handleParseFailure(_ pending: RustPendingRequest, info: NetworkEngineResponseInfo) {
        rustEngineImportantLog("\(self.logPrefix) response for #\(pending.engineId) \(pending.request.shortMetadata.description) could not be parsed")
        self.invalidateInitialization()
        let errorContext = pending.errorState.applyParseFailure()
        let gateAllowsRetry = pending.errorState.parseFailures < RustEngineParseFailurePolicy.maxAttempts && pending.request.shouldContinueAfterError(NetworkEngineErrorContext(floodWaitSeconds: errorContext.floodWaitSeconds, floodWaitErrorText: errorContext.floodWaitErrorText, internalServerErrorCount: errorContext.internalServerErrorCount))
        if pending.isCancelled || pending.isFinished {
            return
        }
        if RustEngineParseFailurePolicy.shouldResubmit(parseFailures: pending.errorState.parseFailures, gateAllowsRetry: gateAllowsRetry) {
            pending.errorState.didResubmit()
            pending.resubmitTimer?.invalidate()
            let timer = SwiftSignalKit.Timer(timeout: RustEngineParseFailurePolicy.retryDelay, repeat: false, completion: { [weak self, weak pending] in
                guard let self = self, let pending = pending else {
                    return
                }
                pending.resubmitTimer = nil
                if pending.isFinished || pending.isCancelled || self.isStopped.with({ $0 }) {
                    return
                }
                self.sendToEngine(pending)
            }, queue: self.queue)
            pending.resubmitTimer = timer
            timer.start()
        } else {
            self.finish(pending)
            pending.request.completed(.failure(NetworkEngineRequestFailure(error: MTRpcError(errorCode: RustEngineParseFailurePolicy.errorCode, errorDescription: RustEngineParseFailurePolicy.errorText), info: info)))
        }
    }

    private func handleFailed(_ event: RustEngineEvent, previousKind: RustEngineEventKind?) {
        guard let pending = self.pendingById[event.requestId] else {
            return
        }
        self.pendingById.removeValue(forKey: event.requestId)
        pending.isInEngine = false
        if pending.isCancelled || pending.isFinished {
            self.finish(pending)
            return
        }
        rustEngineLog("\(self.logPrefix) failed #\(event.requestId) \(event.code) \(event.text)")
        if rustEngineKeepsWaitingAfterLostAnswer(code: event.code, text: event.text) {
            rustEngineImportantLog("\(self.logPrefix) #\(event.requestId) ran on the server but its answer is gone; it stays waiting")
            self.finish(pending)
            return
        }
        if rustEngineResubmitsAfterKeyRotation(code: event.code, text: event.text) {
            let errorContext = pending.errorState.applyServerError()
            if pending.request.shouldContinueAfterError(NetworkEngineErrorContext(floodWaitSeconds: errorContext.floodWaitSeconds, floodWaitErrorText: errorContext.floodWaitErrorText, internalServerErrorCount: errorContext.internalServerErrorCount)) && !pending.isCancelled && !pending.isFinished {
                if self.verifyingRequests.removeValue(forKey: event.requestId) != nil {
                    pending.releaseResources()
                }
                pending.errorState.didResubmit()
                rustEngineLog("\(self.logPrefix) #\(event.requestId) goes again under the new temporary key")
                self.sendToEngine(pending)
                return
            }
        }
        if !self.isMain && previousKind != .authTokenRequired && rustEngineWorkerShouldTransferAuthToken(code: event.code, text: event.text) {
            rustEngineImportantLog("\(self.logPrefix) worker received 401 \(event.text)")
            self.workerAuthorizationRequired()
        }
        self.finish(pending)
        pending.request.completed(.failure(NetworkEngineRequestFailure(error: MTRpcError(errorCode: event.code, errorDescription: event.text), info: self.responseInfo(event))))
    }

    private func handleRetryDecision(_ event: RustEngineEvent) {
        guard let engine = self.engine else {
            return
        }
        guard let pending = self.pendingById[event.requestId], !pending.isCancelled, !pending.isFinished else {
            mt_session_decide_retry(engine, self.handle, event.requestId, 0)
            return
        }
        let floodWaitText = rustEngineOptionalText(event.text2)
        let errorContext = pending.errorState.applyRetryDecision(floodWaitSeconds: event.integer1, floodWaitErrorText: floodWaitText, serverErrors: event.integer2)
        let retryable = rustEngineRetryDecisionIsRetryable(code: event.code, floodWaitText: floodWaitText)
        let retry = retryable && pending.request.shouldContinueAfterError(NetworkEngineErrorContext(floodWaitSeconds: errorContext.floodWaitSeconds, floodWaitErrorText: errorContext.floodWaitErrorText, internalServerErrorCount: errorContext.internalServerErrorCount))
        rustEngineLog("\(self.logPrefix) #\(event.requestId) \(event.code) \(event.text): \(retry ? "retry" : "fail")")
        mt_session_decide_retry(engine, self.handle, event.requestId, retry ? 1 : 0)
    }

    private func handleVerificationRequired(_ event: RustEngineEvent) {
        guard let engine = self.engine else {
            return
        }
        guard let kind = RustEngineVerificationKind(rawValue: event.code) else {
            return
        }
        let requestId = event.requestId
        guard let pending = self.pendingById[requestId], !pending.isCancelled, !pending.isFinished else {
            mt_session_fail_request(engine, self.handle, requestId, RustEngineVerificationKind.failureCode, MTString(data: nil, length: 0))
            return
        }
        pending.releaseResources()
        self.verifyingRequests[requestId] = pending

        let signal: MTSignal?
        switch kind {
        case .apns:
            rustEngineImportantLog("\(self.logPrefix) #\(requestId) requires APNS verification")
            signal = self.context.performExternalRequestVerification(withNonce: event.text)
        case .recaptcha:
            rustEngineImportantLog("\(self.logPrefix) #\(requestId) requires reCAPTCHA verification")
            signal = self.context.performExternalRecaptchaRequestVerification(withMethod: event.text, siteKey: event.text2)
        }
        let nonce = event.text
        let queue = self.queue
        let resolved = Atomic<Bool>(value: false)

        let resolve: (String?) -> Void = { [weak self] value in
            queue.async {
                guard let self = self, let engine = self.engine, !resolved.swap(true) else {
                    return
                }
                guard let pending = self.verifyingRequests.removeValue(forKey: requestId) else {
                    return
                }
                pending.releaseResources()
                if pending.isFinished || pending.isCancelled {
                    return
                }
                let arena = RustEngineArena()
                withExtendedLifetime(arena) {
                    switch kind {
                    case .apns:
                        mt_session_resolve_apns(engine, self.handle, requestId, arena.string(nonce), arena.string(value))
                    case .recaptcha:
                        mt_session_resolve_recaptcha(engine, self.handle, requestId, arena.string(value))
                    }
                }
            }
        }
        let fail: () -> Void = { [weak self] in
            queue.async {
                guard let self = self, let engine = self.engine, !resolved.swap(true) else {
                    return
                }
                guard let pending = self.verifyingRequests.removeValue(forKey: requestId) else {
                    return
                }
                pending.releaseResources()
                if pending.isFinished || pending.isCancelled {
                    return
                }
                rustEngineImportantLog("\(self.logPrefix) #\(requestId) verification did not resolve: \(kind.timeoutErrorText)")
                let arena = RustEngineArena()
                withExtendedLifetime(arena) {
                    mt_session_fail_request(engine, self.handle, requestId, RustEngineVerificationKind.failureCode, arena.string(kind.timeoutErrorText))
                }
            }
        }

        let timer = SwiftSignalKit.Timer(timeout: RustEngineVerificationKind.timeout, repeat: false, completion: {
            fail()
        }, queue: queue)
        pending.verificationTimer = timer
        timer.start()

        if let signal = signal {
            pending.verificationDisposable = signal.start(next: { value in
                resolve(value as? String)
            }, error: { _ in
                fail()
            }, completed: {
                fail()
            })
        } else {
            resolve(nil)
        }
    }

    private func handleUpdate(_ event: RustEngineEvent, previousWasUpdatesReset: Bool) {
        guard let data = event.payload else {
            return
        }
        if previousWasUpdatesReset && rustEngineIsUpdatesTooLong(data) {
            return
        }
        if self.sinks.isEmpty {
            return
        }
        guard let message = self.context.serialization.parseMessage(data) else {
            rustEngineLog("\(self.logPrefix) could not parse an incoming message of \(data.count) bytes")
            return
        }
        for sink in self.sinks {
            sink.networkSessionDidReceive(message: message)
        }
    }

    private func workerAuthorizationRequired() {
        if self.isMain {
            return
        }
        self.context.updateAuthTokenForDatacenter(withId: self.datacenterId, authToken: nil)
        self.context.authTokenForDatacenter(withIdRequired: self.datacenterId, authToken: self.requiredAuthToken, masterDatacenterId: self.requiredAuthToken != nil ? self.masterDatacenterId : 0)
    }

    private func applyPaused() {
        guard let engine = self.engine, self.handle != 0 else {
            return
        }
        let paused = self.externallyPaused || self.holdForReplacementKey || self.holdForUnsupportedProxy
        if paused != self.appliedPaused {
            self.appliedPaused = paused
            mt_session_set_paused(engine, self.handle, paused ? 1 : 0)
        }
    }

    private func resetConnection() {
        guard let engine = self.engine, self.handle != 0, !self.appliedPaused else {
            return
        }
        mt_session_set_paused(engine, self.handle, 1)
        mt_session_set_paused(engine, self.handle, 0)
    }

    private func handleAuthKeyRequired() {
        self.installedKeyId = nil
        self.updateConnectionWatchdog()
        if let authInfo = self.context.authInfoForDatacenter(withId: self.datacenterId, selector: self.keySelector), authInfo.authKeyId != self.rejectedKeyId {
            self.install(authInfo)
            return
        }
        if self.awaitingKey {
            return
        }
        self.awaitingKey = true
        rustEngineLog("\(self.logPrefix) waiting for an auth key (selector \(self.selector.rawValue))")
        if !self.externallyPaused {
            self.requestAwaitedKey()
        }
    }

    private func handleMissingKey(rejectedKeyId: Int64?, engineStillHoldsKey: Bool) {
        if self.runsPfs {
            return
        }
        let selector = self.selector
        let selectorIsEphemeral = selector == .ephemeralMain || selector == .ephemeralMedia
        let action = rustEngineMissingKeyAction(isCdn: self.isCdn, requiresForeignAuthToken: self.requiresForeignAuthToken, selectorIsEphemeral: selectorIsEphemeral)
        rustEngineImportantLog("\(self.logPrefix) missing key, selector \(selector.rawValue): \(action)")
        switch action {
        case let .dropAndRequire(isCdn):
            self.dropAndRequireKey(isCdn: isCdn, rejectedKeyId: rejectedKeyId, engineStillHoldsKey: engineStillHoldsKey)
        case .removeTokenDropAndRequire:
            self.context.removeTokenForDatacenter(withId: self.datacenterId)
            if self.authTokenReady {
                self.authTokenReady = false
                if let engine = self.engine, self.handle != 0 {
                    mt_session_set_auth_token_ready(engine, self.handle, 0)
                }
            }
            self.dropAndRequireKey(isCdn: false, rejectedKeyId: rejectedKeyId, engineStillHoldsKey: engineStillHoldsKey)
        case .checkIfLoggedOut:
            self.context.checkIfLoggedOut(self.datacenterId)
        }
    }

    /// The engine's binds say the server no longer knows the permanent key (a session terminated from
    /// another device, a key the server dropped). On another datacenter the key and its authorization
    /// token are made anew. On the home datacenter it is MtProtoKit's call, as with MtProtoKit:
    /// `checkIfLoggedOut` probes the key and logs an authorized account out once the probe confirms it is
    /// gone; until then the session waits, reported as updating. A key that replaced another less than a
    /// minute ago is left alone: the engine reports a key it just got only after it kept failing past
    /// that, so the report is about the key it replaced.
    private func handlePermanentKeyInvalid() {
        guard self.runsPfs, let keyId = self.installedKeyId else {
            return
        }
        if CFAbsoluteTimeGetCurrent() - self.installedKeyAt < RustNetworkSession.permanentKeyImmunity {
            rustEngineLog("\(self.logPrefix) permanent key reported unknown right after it was installed; keeping it")
            return
        }
        if self.requiresForeignAuthToken {
            self.context.removeTokenForDatacenter(withId: self.datacenterId)
            if self.authTokenReady {
                self.authTokenReady = false
                if let engine = self.engine, self.handle != 0 {
                    mt_session_set_auth_token_ready(engine, self.handle, 0)
                }
            }
            self.dropAndRequireKey(isCdn: false, rejectedKeyId: keyId, engineStillHoldsKey: true, selector: .persistent)
        } else {
            self.context.checkIfLoggedOut(self.datacenterId)
        }
    }

    private func dropAndRequireKey(isCdn: Bool, rejectedKeyId: Int64?, engineStillHoldsKey: Bool, selector explicitSelector: MTDatacenterAuthInfoSelector? = nil) {
        let context = self.context
        let datacenterId = self.datacenterId
        let selector = explicitSelector ?? self.selector
        if let rejectedKeyId = rejectedKeyId {
            self.rejectedKeyId = rejectedKeyId
        }
        self.awaitingKey = true
        if engineStillHoldsKey {
            self.holdForReplacementKey = true
            self.applyPaused()
            self.reportConnectionState()
        }
        let queue = self.queue
        context.performBatchUpdates { [weak self] in
            if let rejectedKeyId = rejectedKeyId, let current = context.authInfoForDatacenter(withId: datacenterId, selector: selector), current.authKeyId != rejectedKeyId {
                queue.async {
                    self?.contextAuthInfoUpdated(datacenterId: datacenterId, authInfo: current, selector: selector)
                }
                return
            }
            context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: nil, selector: selector)
            context.authInfoForDatacenter(withIdRequired: datacenterId, isCdn: isCdn, selector: selector, allowUnboundEphemeralKeys: false)
        }
    }

    private func requestAwaitedKey() {
        if !self.awaitingKey {
            return
        }
        self.context.authInfoForDatacenter(withIdRequired: self.datacenterId, isCdn: self.isCdn, selector: self.keySelector, allowUnboundEphemeralKeys: false)
    }

    private func install(_ authInfo: MTDatacenterAuthInfo) {
        guard let engine = self.engine, self.handle != 0 else {
            return
        }
        let arena = RustEngineArena()
        guard let material = RustNetworkSession.makeKeyMaterial(authInfo, includeInitHash: !self.runsPfs, arena: arena) else {
            rustEngineImportantLog("\(self.logPrefix) auth key for selector \(self.keySelector.rawValue) has an unexpected size")
            return
        }
        withExtendedLifetime(arena) {
            mt_session_set_auth_key(engine, self.handle, material.key, material.salts, material.saltCount, material.hasInitHash, material.initHash)
        }
        rustEngineLog("\(self.logPrefix) installed auth key \(authInfo.authKeyId) selector \(self.keySelector.rawValue)")
        if self.installedKeyId != authInfo.authKeyId {
            self.installedKeyAt = CFAbsoluteTimeGetCurrent()
        }
        self.installedKeyId = authInfo.authKeyId
        self.awaitingKey = false
        self.rejectedKeyId = nil
        if self.runsPfs {
            self.offerStoredTemporaryKey()
        }
        if self.requiresForeignAuthToken {
            mt_session_set_auth_token_ready(engine, self.handle, self.authTokenReady ? 1 : 0)
        }
        if self.holdForReplacementKey {
            self.holdForReplacementKey = false
            self.applyPaused()
            self.reportConnectionState()
        }
        self.flushHeldRequests()
        if !self.externallyPaused {
            self.ensureAuthToken()
        }
        self.updateConnectionWatchdog()
    }

    private var keySelector: MTDatacenterAuthInfoSelector {
        return self.runsPfs ? .persistent : self.selector
    }

    private func handleEngineMadeKey(_ event: RustEngineEvent) {
        guard let key = event.payload, key.count == 256 else {
            return
        }
        let keyId = RustNetworkSession.authKeyId(key)
        if event.integer2 == 0 {
            rustEngineImportantLog("\(self.logPrefix) unexpected engine-made permanent key \(keyId) ignored")
        } else {
            self.madeTemporaryKey = (keyId, key, event.integer1)
        }
    }

    private func handleTemporaryKeyInUse(_ event: RustEngineEvent) {
        let keyId = event.integer1
        let adopted = (event.flags & 1) != 0
        self.temporaryKeyId = keyId
        rustEngineLog("\(self.logPrefix) talking under temporary key \(keyId)\(adopted ? " from the context" : "")")
        guard !adopted else {
            return
        }
        guard let made = self.madeTemporaryKey, made.keyId == keyId else {
            self.markContextKeyBound(keyId: keyId, permanentKeyId: Int64(bitPattern: event.requestId), datacenterOfKey: event.code)
            return
        }
        self.madeTemporaryKey = nil
        guard event.code == Int32(self.obfuscationDatacenterId) else {
            rustEngineLog("\(self.logPrefix) temporary key \(keyId) was made for dc \(event.code), not kept for \(self.obfuscationDatacenterId)")
            return
        }
        let permanentKeyId = Int64(bitPattern: event.requestId)
        guard permanentKeyId != 0, permanentKeyId == self.installedKeyId else {
            return
        }
        let validUntil = rustEngineLocalValidUntil(serverExpiry: event.integer2, timeDifference: self.context.globalTimeDifference())
        let info = RustEngineTemporaryKeyInfo(keyId: keyId, validUntil: validUntil, boundTo: permanentKeyId)
        guard let authInfo = MTDatacenterAuthInfo(authKey: made.key, authKeyId: keyId, validUntilTimestamp: validUntil, saltSet: [RustNetworkSession.freshSalt(made.salt, serverTime: self.context.globalTime())], authKeyAttributes: [rustEngineBoundToAttribute: NSNumber(value: permanentKeyId)]) else {
            return
        }
        let context = self.context
        let datacenterId = self.datacenterId
        let selector = self.selector
        context.performBatchUpdates {
            let stored = context.authInfoForDatacenter(withId: datacenterId, selector: selector).map(RustNetworkSession.temporaryKeyInfo)
            if rustEngineStoresTemporaryKey(stored: stored, made: info) {
                context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: authInfo, selector: selector)
            }
        }
    }

    /// A key from the context (MtProtoKit's, its binding unknown) that the engine bound to the installed
    /// permanent key: the context's copy says so from now on, so that later sessions take it without
    /// binding it again and MtProtoKit's refresher leaves it to the engine.
    private func markContextKeyBound(keyId: Int64, permanentKeyId: Int64, datacenterOfKey: Int32) {
        guard permanentKeyId != 0, permanentKeyId == self.installedKeyId, datacenterOfKey == Int32(self.obfuscationDatacenterId) else {
            return
        }
        let context = self.context
        let datacenterId = self.datacenterId
        let selector = self.selector
        context.performBatchUpdates {
            guard let stored = context.authInfoForDatacenter(withId: datacenterId, selector: selector), stored.authKeyId == keyId, stored.authKeyAttributes?[rustEngineBoundToAttribute] == nil, let authKey = stored.authKey else {
                return
            }
            var attributes = stored.authKeyAttributes ?? [:]
            attributes[rustEngineBoundToAttribute] = NSNumber(value: permanentKeyId)
            if let updated = MTDatacenterAuthInfo(authKey: authKey, authKeyId: keyId, validUntilTimestamp: stored.validUntilTimestamp, saltSet: stored.saltSet ?? [], authKeyAttributes: attributes) {
                context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: updated, selector: selector)
            }
        }
    }

    private func handleTemporaryKeyDropped(_ event: RustEngineEvent) {
        let keyId = event.integer1
        rustEngineImportantLog("\(self.logPrefix) the server no longer takes temporary key \(keyId)")
        if self.temporaryKeyId == keyId {
            self.temporaryKeyId = nil
        }
        let context = self.context
        let datacenterId = self.datacenterId
        let selector = self.selector
        context.performBatchUpdates {
            if let stored = context.authInfoForDatacenter(withId: datacenterId, selector: selector), stored.authKeyId == keyId {
                context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: nil, selector: selector)
            }
        }
    }

    private func contextPermanentKeyUpdated(_ authInfo: MTDatacenterAuthInfo?) {
        guard let authInfo = authInfo else {
            guard self.installedKeyId != nil, let engine = self.engine, self.handle != 0 else {
                return
            }
            rustEngineImportantLog("\(self.logPrefix) the permanent key was removed from the context")
            self.installedKeyId = nil
            self.temporaryKeyId = nil
            mt_session_set_auth_key(engine, self.handle, MTBytes(data: nil, length: 0), nil, 0, 0, MTString(data: nil, length: 0))
            self.updateConnectionWatchdog()
            return
        }
        if authInfo.authKeyId != self.installedKeyId {
            self.install(authInfo)
        }
    }

    private func storedTemporaryKey() -> MTDatacenterAuthInfo? {
        guard let stored = self.context.authInfoForDatacenter(withId: self.datacenterId, selector: self.selector) else {
            return nil
        }
        let offered = rustEngineOffersTemporaryKey(stored: RustNetworkSession.temporaryKeyInfo(stored), permanentKeyId: self.installedKeyId, now: Int32(clamping: Int64(Date().timeIntervalSince1970)), minimumLifetime: RustNetworkSession.temporaryKeyMinimumLifetime)
        return offered ? stored : nil
    }

    private func offerStoredTemporaryKey() {
        if let stored = self.storedTemporaryKey(), stored.authKeyId != self.temporaryKeyId {
            self.offerTemporaryKey(stored)
        }
    }

    private func offerTemporaryKey(_ authInfo: MTDatacenterAuthInfo) {
        guard let engine = self.engine, self.handle != 0 else {
            return
        }
        let info = RustNetworkSession.temporaryKeyInfo(authInfo)
        guard rustEngineOffersTemporaryKey(stored: info, permanentKeyId: self.installedKeyId, now: Int32(clamping: Int64(Date().timeIntervalSince1970)), minimumLifetime: RustNetworkSession.temporaryKeyMinimumLifetime) else {
            return
        }
        let arena = RustEngineArena()
        guard var temporaryKey = RustNetworkSession.makeTemporaryKey(authInfo, timeDifference: self.context.globalTimeDifference(), arena: arena) else {
            return
        }
        withExtendedLifetime(arena) {
            mt_session_offer_temporary_key(engine, self.handle, &temporaryKey)
        }
        rustEngineLog("\(self.logPrefix) offered temporary key \(authInfo.authKeyId)")
    }

    private func ensureAuthToken() {
        guard self.requiresForeignAuthToken, !self.authTokenReady, let requiredAuthToken = self.requiredAuthToken else {
            return
        }
        if requiredAuthToken.isEqual(self.context.authTokenForDatacenter(withId: self.datacenterId)) {
            self.markAuthTokenReady()
            return
        }
        if self.externallyPaused {
            return
        }
        rustEngineLog("\(self.logPrefix) requesting auth token transfer from dc\(self.masterDatacenterId)")
        self.context.authTokenForDatacenter(withIdRequired: self.datacenterId, authToken: requiredAuthToken, masterDatacenterId: self.masterDatacenterId)
    }

    private func markAuthTokenReady() {
        if self.authTokenReady {
            return
        }
        self.authTokenReady = true
        rustEngineLog("\(self.logPrefix) auth token ready")
        if let engine = self.engine, self.handle != 0 {
            mt_session_set_auth_token_ready(engine, self.handle, 1)
        }
    }

    func contextAuthInfoUpdated(datacenterId: Int, authInfo: MTDatacenterAuthInfo?, selector: MTDatacenterAuthInfoSelector) {
        if self.isStopped.with({ $0 }) || datacenterId != self.datacenterId {
            return
        }
        if self.runsPfs {
            if selector == .persistent {
                self.contextPermanentKeyUpdated(authInfo)
            } else if selector == self.selector, let authInfo = authInfo, authInfo.authKeyId != self.temporaryKeyId {
                self.offerTemporaryKey(authInfo)
            }
            return
        }
        if selector != self.selector {
            return
        }
        if self.awaitingKey {
            if let authInfo = authInfo, authInfo.authKeyId != self.rejectedKeyId {
                self.install(authInfo)
            }
            return
        }
        guard let installedKeyId = self.installedKeyId else {
            return
        }
        if authInfo == nil {
            rustEngineImportantLog("\(self.logPrefix) auth key for selector \(selector.rawValue) was removed from the context")
            self.rejectedKeyId = installedKeyId
            self.awaitingKey = true
            self.holdForReplacementKey = true
            self.applyPaused()
            self.reportConnectionState()
        }
    }

    func contextAuthTokenUpdated(datacenterId: Int, authToken: Any?) {
        if self.isStopped.with({ $0 }) || datacenterId != self.datacenterId {
            return
        }
        guard let requiredAuthToken = self.requiredAuthToken, requiredAuthToken.isEqual(authToken) else {
            return
        }
        self.markAuthTokenReady()
    }

    func contextAuthInfoRequestFailed(datacenterId: Int, selector: MTDatacenterAuthInfoSelector) {
        if self.isStopped.with({ $0 }) || datacenterId != self.datacenterId || selector != self.keySelector {
            return
        }
        if self.awaitingKey && !self.externallyPaused {
            self.requestAwaitedKey()
        }
    }

    func contextAuthTokenTransferFailed(datacenterId: Int) {
        if self.isStopped.with({ $0 }) || datacenterId != self.datacenterId {
            return
        }
        if !self.externallyPaused {
            self.ensureAuthToken()
        }
    }

    func contextTransportSchemesUpdated(datacenterId: Int, shouldReset: Bool) {
        if self.isStopped.with({ $0 }) || datacenterId != self.datacenterId {
            return
        }
        self.requestedSchemes = false
        self.refreshSchemes()
    }

    func contextApiEnvironmentUpdated(_ apiEnvironment: MTApiEnvironment) {
        if self.isStopped.with({ $0 }) {
            return
        }
        guard let engine = self.engine, self.handle != 0 else {
            return
        }
        let previous = self.apiEnvironment
        self.apiEnvironment = apiEnvironment

        let arena = RustEngineArena()
        var environment = RustNetworkSession.makeEnvironment(apiEnvironment, layer: RustNetworkSession.currentLayer(self.context), arena: arena)
        var noopData: NSData?
        let _ = self.context.serialization.requestNoop(&noopData)
        var noop = MTProtoEngineFFI.MTRequest()
        noop.id = self.runtime.nextRequestId()
        noop.body = arena.bytes(noopData.flatMap { Data(referencing: $0) })
        noop.flags = rustEngineNoopFlags(withoutUpdates: !self.isMain || apiEnvironment.disableUpdates)
        noop.expected_response_size = 0
        noop.invoke_after = 0
        withExtendedLifetime(arena) {
            mt_session_update_environment(engine, self.handle, &environment, &noop)
        }

        let proxyChanged = !RustNetworkSession.isSameProxy(previous.socksProxySettings, apiEnvironment.socksProxySettings)
        if proxyChanged {
            let unsupported = (apiEnvironment.socksProxySettings?.webProxy ?? false) && !self.runtime.carriesWebProxy
            rustEngineImportantLog("\(self.logPrefix) proxy changed\(unsupported ? " to a WEB proxy, which this engine cannot carry: staying disconnected" : "")")
            if unsupported {
                self.holdForUnsupportedProxy = true
                self.applyPaused()
            }
            let proxyArena = RustEngineArena()
            var proxy = RustNetworkSession.makeProxy(apiEnvironment.socksProxySettings, arena: proxyArena)
            withExtendedLifetime(proxyArena) {
                mt_session_set_proxy(engine, self.handle, &proxy)
            }
            self.refreshSchemes()
            if !unsupported {
                self.holdForUnsupportedProxy = false
                self.applyPaused()
            }
            self.reportConnectionState()
        } else if previous.langPackCode != apiEnvironment.langPackCode {
            self.resetConnection()
        }
    }

    private func refreshSchemes() {
        guard let engine = self.engine, self.handle != 0 else {
            return
        }
        let schemes = RustNetworkSession.loadSchemes(context: self.context, datacenterId: self.datacenterId, isMedia: self.isMedia, apiEnvironment: self.apiEnvironment)
        if schemes.isEmpty {
            if !self.requestedSchemes {
                self.requestedSchemes = true
                self.context.transportSchemeForDatacenter(withIdRequired: self.datacenterId, media: self.isMedia)
            }
        } else {
            self.requestedSchemes = false
        }
        let fingerprint = RustNetworkSession.fingerprint(schemes)
        if fingerprint == self.addressFingerprint {
            return
        }
        self.schemes = schemes
        self.addressFingerprint = fingerprint
        var selector = self.selector
        var obfuscationDatacenterId = self.obfuscationDatacenterId
        if let preferForMedia = schemes.first?.address.preferForMedia {
            selector = RustNetworkSession.authInfoSelector(context: self.context, isCdn: self.isCdn, preferForMedia: preferForMedia)
            obfuscationDatacenterId = rustEngineObfuscationDatacenterId(datacenterId: self.datacenterId, isTestingEnvironment: self.context.isTestingEnvironment, preferForMedia: preferForMedia)
        }
        let suspended = (selector != self.selector || obfuscationDatacenterId != self.obfuscationDatacenterId) && !self.appliedPaused
        if suspended {
            mt_session_set_paused(engine, self.handle, 1)
        }
        if obfuscationDatacenterId != self.obfuscationDatacenterId {
            self.obfuscationDatacenterId = obfuscationDatacenterId
            mt_session_set_obfuscation_dc_id(engine, self.handle, obfuscationDatacenterId)
        }
        let arena = RustEngineArena()
        let addresses = RustNetworkSession.makeAddresses(schemes, arena: arena)
        withExtendedLifetime(arena) {
            mt_session_set_addresses(engine, self.handle, arena.array(addresses), addresses.count)
        }
        rustEngineLog("\(self.logPrefix) addresses updated: \(fingerprint.joined(separator: ", "))")
        if selector != self.selector {
            self.switchSelector(to: selector)
        }
        if suspended && !self.appliedPaused {
            mt_session_set_paused(engine, self.handle, 0)
        }
    }

    private func switchSelector(to selector: MTDatacenterAuthInfoSelector) {
        rustEngineImportantLog("\(self.logPrefix) addresses moved from selector \(self.selector.rawValue) to \(selector.rawValue)")
        self.selector = selector
        if self.runsPfs {
            self.temporaryKeyId = nil
            self.madeTemporaryKey = nil
            self.offerStoredTemporaryKey()
            return
        }
        self.rejectedKeyId = nil
        if let authInfo = self.context.authInfoForDatacenter(withId: self.datacenterId, selector: selector) {
            self.install(authInfo)
            return
        }
        self.awaitingKey = true
        self.holdForReplacementKey = true
        self.applyPaused()
        self.reportConnectionState()
        self.updateConnectionWatchdog()
        rustEngineLog("\(self.logPrefix) waiting for an auth key (selector \(selector.rawValue))")
        if !self.externallyPaused {
            self.requestAwaitedKey()
        }
    }

    private func invalidateInitialization() {
        if let engine = self.engine, self.handle != 0 {
            mt_session_invalidate_initialization(engine, self.handle)
        }
        self.updateContextAuthKeyAttributes { attributes in
            attributes["apiInitializationHash"] = ""
        }
    }

    private func updateContextInitializationHash(_ hash: String?) {
        self.updateContextAuthKeyAttributes { attributes in
            if let hash = hash {
                attributes["apiInitializationHash"] = hash
            } else {
                attributes.removeValue(forKey: "apiInitializationHash")
            }
        }
    }

    private func updateContextAuthKeyAttributes(_ update: @escaping (inout [AnyHashable: Any]) -> Void) {
        guard let keyId = self.runsPfs ? self.temporaryKeyId : self.installedKeyId else {
            return
        }
        let context = self.context
        let datacenterId = self.datacenterId
        let selector = self.selector
        context.performBatchUpdates {
            guard let authInfo = context.authInfoForDatacenter(withId: datacenterId, selector: selector), authInfo.authKeyId == keyId else {
                return
            }
            var attributes: [AnyHashable: Any] = authInfo.authKeyAttributes ?? [:]
            let previousHash = attributes["apiInitializationHash"] as? String
            let hadHash = attributes["apiInitializationHash"] != nil
            update(&attributes)
            let updatedHash = attributes["apiInitializationHash"] as? String
            let hasHash = attributes["apiInitializationHash"] != nil
            if previousHash == updatedHash && hadHash == hasHash {
                return
            }
            context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: authInfo.withUpdatedAuthKeyAttributes(attributes), selector: selector)
        }
    }

    private func mergeSalts(_ salts: [RustEngineSalt]) {
        guard let keyId = self.runsPfs ? self.temporaryKeyId : self.installedKeyId else {
            return
        }
        var saltInfos: [MTDatacenterSaltInfo] = []
        for salt in salts {
            if let range = rustEngineMessageIdRange(salt) {
                saltInfos.append(MTDatacenterSaltInfo(salt: salt.salt, firstValidMessageId: range.first, lastValidMessageId: range.last))
            }
        }
        if saltInfos.isEmpty {
            return
        }
        let context = self.context
        let datacenterId = self.datacenterId
        let selector = self.selector
        context.performBatchUpdates {
            guard let authInfo = context.authInfoForDatacenter(withId: datacenterId, selector: selector), authInfo.authKeyId == keyId else {
                return
            }
            let merged = authInfo.mergeSaltSet(saltInfos, forTimestamp: context.globalTime())
            context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: merged, selector: selector)
        }
    }

    private func resetConnectionWatchdogBackoff() {
        self.connectionWatchdogDelay = RustNetworkSession.connectionWatchdogInitialDelay
    }

    private func updateConnectionWatchdog() {
        let isHealthy = self.lastConnectionFlags.map { $0.isConnected && (!$0.isUpdatingConnectionContext || $0.isAwaitingKeyBinding) } ?? false
        if isHealthy {
            if self.connectionProblemsReported, let scheme = self.schemes.first {
                self.context.revalidateTransportScheme(forDatacenterId: self.datacenterId, transportScheme: scheme, media: self.isMedia)
            }
            self.connectionProblemsReported = false
            self.resetConnectionWatchdogBackoff()
            self.connectionWatchdog?.invalidate()
            self.connectionWatchdog = nil
            return
        }
        let wantsConnection = !self.appliedPaused && self.installedKeyId != nil && !self.schemes.isEmpty && (self.isMain || !self.activeRequests.isEmpty) && self.runtime.isNetworkAvailable
        if !wantsConnection {
            self.connectionWatchdog?.invalidate()
            self.connectionWatchdog = nil
            return
        }
        if self.connectionWatchdog != nil {
            return
        }
        let delay = self.connectionWatchdogDelay
        let timer = SwiftSignalKit.Timer(timeout: delay, repeat: false, completion: { [weak self] in
            guard let self = self else {
                return
            }
            self.connectionWatchdog = nil
            if self.isStopped.with({ $0 }) {
                return
            }
            self.connectionProblemsReported = true
            self.connectionWatchdogDelay = min(delay * 2.0, RustNetworkSession.connectionWatchdogMaxDelay)
            guard let scheme = self.schemes.first else {
                return
            }
            rustEngineImportantLog("\(self.logPrefix) no response for \(Int(delay)) s, invalidating the transport scheme")
            self.context.reportTransportSchemeFailure(forDatacenterId: self.datacenterId, transportScheme: scheme)
            self.context.invalidateTransportScheme(forDatacenterId: self.datacenterId, transportScheme: scheme, isProbablyHttp: false, media: self.isMedia)
            self.updateConnectionWatchdog()
        }, queue: self.queue)
        self.connectionWatchdog = timer
        timer.start()
    }

    private func reportConnectionState() {
        guard self.isMain, let delegate = self.delegate else {
            return
        }
        let state: NetworkEngineConnectionState
        if !self.externallyPaused && (self.holdForReplacementKey || self.holdForUnsupportedProxy) {
            state = NetworkEngineConnectionState(
                isNetworkAvailable: self.runtime.isNetworkAvailable,
                isConnected: false,
                isUpdatingConnectionContext: false,
                isPerformingServiceTasks: false,
                proxyAddress: self.apiEnvironment.socksProxySettings?.ip,
                proxyHasConnectionIssues: self.holdForUnsupportedProxy
            )
        } else if let flags = self.lastConnectionFlags {
            var proxyAddress: String?
            if let engineProxyAddress = self.lastEngineProxyAddress {
                proxyAddress = self.apiEnvironment.socksProxySettings?.ip ?? engineProxyAddress
            }
            state = NetworkEngineConnectionState(
                isNetworkAvailable: flags.isNetworkAvailable,
                isConnected: flags.isConnected,
                isUpdatingConnectionContext: flags.isUpdatingConnectionContext,
                isPerformingServiceTasks: flags.isPerformingServiceTasks,
                proxyAddress: proxyAddress,
                proxyHasConnectionIssues: flags.proxyHasConnectionIssues
            )
        } else {
            return
        }
        if state == self.lastReportedState {
            return
        }
        self.lastReportedState = state
        delegate.networkSessionConnectionStateChanged(state)
    }
}

private struct RustKeyMaterial {
    let key: MTBytes
    let salts: UnsafePointer<MTSaltEntry>?
    let saltCount: Int
    let hasInitHash: UInt8
    let initHash: MTString
}

extension RustNetworkSession {
    fileprivate static func currentLayer(_ context: MTContext) -> Int32 {
        return Int32(clamping: context.serialization.currentLayer())
    }

    fileprivate static func authKeyId(_ key: Data) -> Int64 {
        let hash = MTSha1(key)
        var keyId: Int64 = 0
        _ = withUnsafeMutableBytes(of: &keyId) { buffer in
            hash.copyBytes(to: buffer, from: hash.count - 8 ..< hash.count)
        }
        return keyId
    }

    fileprivate static func freshSalt(_ salt: Int64, serverTime: Double) -> MTDatacenterSaltInfo {
        let now = Int64(serverTime)
        return MTDatacenterSaltInfo(salt: salt, firstValidMessageId: now << 32, lastValidMessageId: (now + 29 * 60) << 32)
    }

    fileprivate static func temporaryKeyInfo(_ authInfo: MTDatacenterAuthInfo) -> RustEngineTemporaryKeyInfo {
        let boundTo = (authInfo.authKeyAttributes?[rustEngineBoundToAttribute] as? NSNumber)?.int64Value
        return RustEngineTemporaryKeyInfo(keyId: authInfo.authKeyId, validUntil: authInfo.validUntilTimestamp, boundTo: boundTo)
    }

    fileprivate static func makeTemporaryKey(_ authInfo: MTDatacenterAuthInfo, timeDifference: Double, arena: RustEngineArena) -> MTTemporaryKey? {
        guard let material = RustNetworkSession.makeKeyMaterial(authInfo, includeInitHash: true, arena: arena) else {
            return nil
        }
        return MTTemporaryKey(
            key: material.key,
            expires_at: rustEngineServerExpiry(validUntil: authInfo.validUntilTimestamp, timeDifference: timeDifference),
            bound_to: RustNetworkSession.temporaryKeyInfo(authInfo).boundTo ?? 0,
            salts: material.salts,
            salt_count: material.saltCount,
            has_init_hash: material.hasInitHash,
            init_hash: material.initHash
        )
    }

    fileprivate static func makeKeyMaterial(_ authInfo: MTDatacenterAuthInfo, includeInitHash: Bool, arena: RustEngineArena) -> RustKeyMaterial? {
        guard let authKey = authInfo.authKey, authKey.count == 256 else {
            return nil
        }
        var salts: [MTSaltEntry] = []
        for item in authInfo.saltSet ?? [] {
            if let saltInfo = item as? MTDatacenterSaltInfo {
                let salt = rustEngineSalt(salt: saltInfo.salt, firstValidMessageId: saltInfo.firstValidMessageId, lastValidMessageId: saltInfo.lastValidMessageId)
                salts.append(MTSaltEntry(salt: salt.salt, valid_since: salt.validSince, valid_until: salt.validUntil))
            }
        }
        let initHash = includeInitHash ? authInfo.authKeyAttributes?["apiInitializationHash"] as? String : nil
        return RustKeyMaterial(
            key: arena.bytes(authKey),
            salts: arena.array(salts),
            saltCount: salts.count,
            hasInitHash: initHash != nil ? 1 : 0,
            initHash: arena.string(initHash)
        )
    }

    fileprivate static func authInfoSelector(context: MTContext, isCdn: Bool, preferForMedia: Bool) -> MTDatacenterAuthInfoSelector {
        if isCdn || !context.useTempAuthKeys {
            return .persistent
        }
        return preferForMedia ? .ephemeralMedia : .ephemeralMain
    }

    fileprivate static func loadSchemes(context: MTContext, datacenterId: Int, isMedia: Bool, apiEnvironment: MTApiEnvironment) -> [MTTransportScheme] {
        let schemes = context.transportSchemesForDatacenter(withId: datacenterId, media: isMedia, enforceMedia: false, isProxy: apiEnvironment.socksProxySettings != nil)
        if schemes.isEmpty {
            return []
        }
        let isIpv6 = schemes.map { $0.address.isIpv6() }
        var preferredIndex: Int?
        if let preferred = context.chooseTransportSchemeForConnection(toDatacenterId: datacenterId, schemes: schemes) {
            preferredIndex = schemes.firstIndex(where: { $0 === preferred || $0.isEqual(to: preferred) })
        }
        var allowIpv6 = false
        let ipv6Schemes = schemes.filter { $0.address.isIpv6() }
        if !ipv6Schemes.isEmpty {
            allowIpv6 = context.chooseTransportSchemeForConnection(toDatacenterId: datacenterId, schemes: ipv6Schemes) != nil
        }
        return rustEngineAddressOrder(isIpv6: isIpv6, preferredIndex: preferredIndex, allowIpv6: allowIpv6).map { schemes[$0] }
    }

    fileprivate static func fingerprint(_ schemes: [MTTransportScheme]) -> [String] {
        return schemes.map { scheme in
            let address = scheme.address
            return "\(address.ip ?? address.host ?? ""):\(address.port)\(address.secret != nil ? "+s" : "")\(address.preferForMedia ? "+m" : "")"
        }
    }

    fileprivate static func makeAddresses(_ schemes: [MTTransportScheme], arena: RustEngineArena) -> [MTAddress] {
        return schemes.map { scheme in
            let address = scheme.address
            return MTAddress(host: arena.string(address.ip ?? address.host), port: address.port, secret: arena.bytes(address.secret))
        }
    }

    static var webEndpointOverride: (host: String, port: UInt16, path: String, wsPath: String, address: String)?

    fileprivate static func setWebEndpoint(engine: OpaquePointer, handle: MTSessionHandle, isTestingEnvironment: Bool) {
        guard let override = RustNetworkSession.webEndpointOverride else {
            mt_session_use_telegram_web(engine, handle, isTestingEnvironment ? 1 : 0)
            return
        }
        let arena = RustEngineArena()
        var endpoint = MTWebEndpoint(host: arena.string(override.host), port: override.port, path: arena.string(override.path), address: arena.string(override.address), ws_path: arena.string(override.wsPath))
        withExtendedLifetime(arena) {
            mt_session_set_web_endpoint(engine, handle, &endpoint)
        }
    }

    fileprivate static func makeProxy(_ settings: MTSocksProxySettings?, arena: RustEngineArena) -> MTProxy {
        var proxy = MTProxy()
        proxy.kind = UInt8(MTProxyKindNone)
        guard let settings = settings else {
            return proxy
        }
        proxy.host = arena.string(settings.ip)
        proxy.port = settings.port
        if settings.webProxy {
            proxy.kind = UInt8(MTProxyKindWeb)
            proxy.secret = arena.bytes(settings.secret)
        } else if let secret = settings.secret {
            proxy.kind = UInt8(MTProxyKindMTProxy)
            proxy.secret = arena.bytes(secret)
        } else {
            proxy.kind = UInt8(MTProxyKindSocks5)
            proxy.username = arena.string(settings.username)
            proxy.password = arena.string(settings.password)
        }
        return proxy
    }

    fileprivate static func isSameProxy(_ lhs: MTSocksProxySettings?, _ rhs: MTSocksProxySettings?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.ip == rhs.ip && lhs.port == rhs.port && lhs.username == rhs.username && lhs.password == rhs.password && lhs.secret == rhs.secret && lhs.webProxy == rhs.webProxy
        default:
            return false
        }
    }

    fileprivate static func makeEnvironment(_ apiEnvironment: MTApiEnvironment, layer: Int32, arena: RustEngineArena) -> MTEnvironment {
        var environment = MTEnvironment()
        environment.layer = layer
        environment.api_id = apiEnvironment.apiId
        environment.device_model = arena.string(apiEnvironment.deviceModel)
        environment.system_version = arena.string(apiEnvironment.systemVersion)
        environment.app_version = arena.string(apiEnvironment.appVersion)
        environment.system_lang_code = arena.string(apiEnvironment.systemLangCode)
        environment.lang_pack = arena.string(apiEnvironment.langPack)
        environment.lang_code = arena.string(apiEnvironment.langPackCode)
        if let proxy = apiEnvironment.socksProxySettings, proxy.secret != nil {
            environment.has_proxy = 1
            environment.proxy_address = arena.string(proxy.ip)
            environment.proxy_port = Int32(proxy.port)
        }
        if let systemCode = apiEnvironment.systemCode {
            environment.has_params = 1
            environment.params = arena.bytes(systemCode)
        }
        environment.init_hash = arena.string(apiEnvironment.apiInitializationHash)
        environment.disable_updates = apiEnvironment.disableUpdates ? 1 : 0
        return environment
    }
}
