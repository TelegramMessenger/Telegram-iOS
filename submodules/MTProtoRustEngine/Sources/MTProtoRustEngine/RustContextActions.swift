import Foundation
import SwiftSignalKit
import MtProtoKit
import TelegramCore
import MTProtoEngineFFI
import MTProtoRustEngineMapping

/// An action that runs on the engine and must end when the engine stops carrying the context.
protocol RustEngineAbandonableAction: AnyObject {
    /// Stops the action's engine work and reports it failed (without a verdict), so that MTContext asks
    /// again after its backoff, through whichever actions are installed then.
    func abandon()
}

private final class RustWeakAction {
    weak var value: RustEngineAbandonableAction?

    init(_ value: RustEngineAbandonableAction) {
        self.value = value
    }
}

/// MTContext's key and transfer actions while the Rust engine carries the context's network: permanent
/// keys are made, the logout check binds its key, and authorizations are transferred over the engine,
/// so over whatever route reaches Telegram (TCP, HTTP, HTTPS or WSS). MTContext stays the only coordinator
/// (one action per datacenter and selector, its backoff) and the only writer of keys and tokens. Installed
/// by `RustNetworkEngine.activate()` and removed by `deactivate()`, which also ends every action still
/// running on the engine, so that a switch to MtProtoKit (the kill switch) takes their datacenters over at
/// once; app extensions never get it.
final class RustEngineActions {
    let runtime: RustEngineRuntime
    let serverPublicKeys: [String]
    let httpPort: UInt16
    let registry: RustContextRegistry
    private weak var context: MTContext?
    private let lock = RustEngineLock()
    private var running: [RustWeakAction] = []

    init(runtime: RustEngineRuntime, context: MTContext, serverPublicKeys: [String], httpPort: UInt16) {
        self.runtime = runtime
        self.context = context
        self.serverPublicKeys = serverPublicKeys
        self.httpPort = httpPort
        self.registry = RustContextRegistry.of(context)
    }

    /// The registry names these actions at once; the factories are set afterwards on MTContext's queue, as
    /// `uninstall` clears them there, so every factory write is ordered on that one queue. A key action that
    /// MTContext makes on its queue after that block uses these factories.
    func install() {
        guard let context = self.context else {
            return
        }
        let _ = self.registry.setActiveActions(self, replacing: nil)
        MTContext.contextQueue().dispatch(onQueue: { [weak context] in
            guard let context = context, self.registry.isActive(self) else {
                return
            }
            context.authActionFactory = { [self] selector, isCdn, skipBind, completion in
                return RustDatacenterAuthAction(actions: self, selector: selector, isCdn: isCdn, skipBind: skipBind, completion: completion)
            }
            context.transferAuthActionFactory = { [self] in
                return RustDatacenterTransferAuthAction(actions: self)
            }
            self.registry.noteFactories(of: self)
        }, synchronous: false)
        rustEngineImportantLog("[MTProtoRust] keys and authorization transfers of the context go over the engine")
    }

    /// The registry stops naming these actions at once; the factories are cleared afterwards on MTContext's
    /// queue, unless another engine's actions are installed by then (that engine sets its own factories on
    /// the same queue). The logout check's gate and MTContext's factory read run in one block on that queue
    /// (`rustEngineStartLogoutCheck`), and the gate needs the factories to belong to the actions the registry
    /// names: a check it starts gets the active engine's action or none. Any action made from these
    /// factories after this call ends at once (`track`): a key or transfer action is asked for again after
    /// MTContext's backoff, and a logout check started without the gate (MTProto's `-404` path, a non-PFS
    /// session's missing key) ends without a verdict.
    func uninstall() {
        guard let context = self.context, self.registry.setActiveActions(nil, replacing: self) else {
            return
        }
        let registry = self.registry
        MTContext.contextQueue().dispatch(onQueue: { [weak context] in
            guard let context = context, !registry.hasActiveActions() else {
                return
            }
            context.authActionFactory = nil
            context.transferAuthActionFactory = nil
            registry.noteFactories(of: nil)
        }, synchronous: false)
        self.lock.lock()
        let running = self.running.compactMap(\.value)
        self.running.removeAll()
        self.lock.unlock()
        rustEngineImportantLog("[MTProtoRust] keys and authorization transfers of the context go back to MtProtoKit (\(running.count) running on the engine end)")
        for action in running {
            action.abandon()
        }
    }

    /// An action started engine work: `uninstall` ends it. One that MTContext made from these factories
    /// after `uninstall` (until they are cleared or replaced on MTContext's queue) ends at once.
    func track(_ action: RustEngineAbandonableAction) {
        self.lock.lock()
        self.running.removeAll(where: { $0.value == nil })
        self.running.append(RustWeakAction(action))
        self.lock.unlock()
        if !self.registry.isActive(self) {
            action.abandon()
        }
    }
}

/// `MTDatacenterAuthAction` over the Rust engine. Two of its uses run on the engine:
/// - a permanent key (the persistent selector, not a CDN): a key-only engine session makes it, and the
///   base class stores it as MtProtoKit stores its own, keeping a key that appeared meanwhile. An attempt
///   that makes no key within `permanentKeyTimeout` fails, and MTContext asks again with its backoff;
/// - the logout check (`probedPermanentKey`): an engine session binds one fresh temporary key to the
///   probed key and reports the bind, never storing anything. A refusal counts as "the server does not
///   know the key" only with the context registry's evidence (`rustEnginePermanentKeyUnknownDenial`, which
///   includes tdlib's day-long immunity for a key the server answered under or bound), and then only if a
///   call sent under the permanent key itself, as tdlib validates its main key, gets no answer but
///   `AuthKeyInvalid` (-404 twice, the second on a fresh connection), and the evidence still holds after
///   it. Refused binds alone, whether the server's for a while or the engine's own bind code's, never log
///   anyone out.
/// Everything else (temporary keys MtProtoKit itself asks for, CDN keys) is MtProtoKit's base action.
final class RustDatacenterAuthAction: MTDatacenterAuthAction, RustEngineAbandonableAction {
    static var permanentKeyTimeout: Double = 300.0
    /// A time difference measured by the key's handshake replaces the context's only when they disagree by
    /// more than this: the handshake's is coarse (half a round trip), the sessions correct it precisely.
    static let timeDifferenceTolerance: Double = 10.0

    private let actions: RustEngineActions
    private let selector: MTDatacenterAuthInfoSelector
    private let isCdn: Bool
    private let queue = Queue(name: "org.telegram.MTProtoRust.session")
    private let finished = Atomic<Bool>(value: false)
    private var session: RustKeySession?
    private var validationSession: RustKeySession?
    private weak var probeContext: MTContext?
    private var probedKey: Data?
    private var timer: SwiftSignalKit.Timer?
    private var datacenterId: Int = 0
    private var transientFailures = 0
    private var creationFailures = 0

    init(actions: RustEngineActions, selector: MTDatacenterAuthInfoSelector, isCdn: Bool, skipBind: Bool, completion: @escaping (MTDatacenterAuthAction, Bool) -> Void) {
        self.actions = actions
        self.selector = selector
        self.isCdn = isCdn
        super.init(authKeyInfoSelector: selector, isCdn: isCdn, skipBind: skipBind, completion: { action, success in
            if let action = action {
                completion(action, success)
            }
        })
    }

    override func execute(_ context: MTContext!, datacenterId: Int) {
        guard let context = context, datacenterId != 0 else {
            super.execute(context, datacenterId: datacenterId)
            return
        }
        if let probed = self.probedPermanentKey, let key = probed.authKey {
            self.datacenterId = datacenterId
            self.probeContext = context
            self.probedKey = key
            self.attach(to: context, datacenterId: datacenterId)
            self.actions.track(self)
            self.queue.async {
                self.startCheck(context: context, key: key, keyId: probed.authKeyId)
            }
            return
        }
        if self.selector == .persistent && !self.isCdn {
            self.datacenterId = datacenterId
            self.attach(to: context, datacenterId: datacenterId)
            if context.authInfoForDatacenter(withId: datacenterId, selector: .persistent) != nil && !self.replacesExistingKey {
                self.report(success: true)
                return
            }
            self.actions.track(self)
            self.queue.async {
                self.startPermanentKey(context: context)
            }
            return
        }
        super.execute(context, datacenterId: datacenterId)
    }

    override func cancel() {
        let _ = self.finished.swap(true)
        self.queue.async {
            self.stopSessions()
        }
        super.cancel()
    }

    func abandon() {
        self.queue.async {
            if self.finished.with({ $0 }) {
                return
            }
            rustEngineImportantLog("[MTProtoRust dc\(self.datacenterId)] the engine no longer carries the context: the key action ends without a result")
            self.stopSessions()
            self.report(success: false)
        }
    }

    private func report(success: Bool) {
        if self.finished.swap(true) {
            return
        }
        if success {
            self.complete()
        } else {
            self.fail()
        }
    }

    private func stopSessions() {
        self.timer?.invalidate()
        self.timer = nil
        self.session?.stop()
        self.session = nil
        self.validationSession?.stop()
        self.validationSession = nil
    }

    private func fail(_ reason: String) {
        rustEngineImportantLog("[MTProtoRust dc\(self.datacenterId)] \(reason)")
        self.stopSessions()
        self.report(success: false)
    }

    // MARK: Permanent key

    private func startPermanentKey(context: MTContext) {
        if self.session != nil || self.finished.with({ $0 }) {
            return
        }
        self.session = RustKeySession(runtime: self.actions.runtime, context: context, datacenterId: self.datacenterId, purpose: .makePermanentKey, serverPublicKeys: self.actions.serverPublicKeys, httpPort: self.actions.httpPort, queue: self.queue, onEvent: { [weak self, weak context] event in
            guard let self = self, let context = context else {
                return
            }
            self.handleKeyMakerEvent(event, context: context)
        })
        let timer = SwiftSignalKit.Timer(timeout: RustDatacenterAuthAction.permanentKeyTimeout, repeat: false, completion: { [weak self] in
            self?.fail("no permanent key after \(Int(RustDatacenterAuthAction.permanentKeyTimeout)) s; MTContext asks again")
        }, queue: self.queue)
        self.timer = timer
        timer.start()
    }

    private func handleKeyMakerEvent(_ event: RustEngineEvent, context: MTContext) {
        let prefix = self.session?.logPrefix ?? "[MTProtoRust key maker]"
        switch event.kind {
        case .authKeyCreated:
            guard rustEngineCreatedKeyKind(flags: event.flags) == .permanent, !self.finished.with({ $0 }) else {
                return
            }
            guard let key = event.payload, key.count == 256 else {
                self.fail("\(prefix) the engine reported a permanent key of an unexpected size")
                return
            }
            let expectedDatacenterId = Int32(rustEngineObfuscationDatacenterId(datacenterId: self.datacenterId, isTestingEnvironment: context.isTestingEnvironment, preferForMedia: false))
            if event.code != expectedDatacenterId {
                self.fail("\(prefix) the key was made for dc \(event.code), not \(expectedDatacenterId); dropped")
                return
            }
            let keyId = RustNetworkSession.authKeyId(key)
            guard let authKey = MTDatacenterAuthKey(authKey: key, authKeyId: keyId, validUntilTimestamp: Int32.max, notBound: false) else {
                self.fail("\(prefix) the key could not be wrapped")
                return
            }
            self.stopSessions()
            let current = context.globalTimeDifference()
            if event.value1.isFinite && abs(event.value1 - current) > RustDatacenterAuthAction.timeDifferenceTolerance {
                context.setGlobalTimeDifference(event.value1)
            }
            let serverTime = Date().timeIntervalSince1970 + (event.value1.isFinite ? event.value1 : current)
            let timestamp = rustEngineMessageId(seconds: serverTime) ?? 0
            rustEngineImportantLog("\(prefix) made permanent key \(keyId)")
            if self.finished.swap(true) {
                return
            }
            self.complete(with: authKey, timestamp: timestamp, serverSalt: event.integer1)
        case .authKeyCreationFailed:
            self.creationFailures += 1
            if self.creationFailures <= 3 || self.creationFailures % 10 == 0 {
                rustEngineImportantLog("\(prefix) making the key failed (\(self.creationFailures)): \(event.text)")
            }
        default:
            break
        }
    }

    // MARK: Logout check

    private func startCheck(context: MTContext, key: Data, keyId: Int64) {
        if self.session != nil || self.finished.with({ $0 }) {
            return
        }
        rustEngineImportantLog("[MTProtoRust dc\(self.datacenterId)] checking whether the server knows permanent key \(keyId)")
        self.session = RustKeySession(runtime: self.actions.runtime, context: context, datacenterId: self.datacenterId, purpose: .checkPermanentKey(key: key), serverPublicKeys: self.actions.serverPublicKeys, httpPort: self.actions.httpPort, queue: self.queue, onEvent: { [weak self, weak context] event in
            guard let self = self, let context = context else {
                return
            }
            self.handleCheckEvent(event, keyId: keyId, context: context)
        })
    }

    private func handleCheckEvent(_ event: RustEngineEvent, keyId: Int64, context: MTContext) {
        let prefix = self.session?.logPrefix ?? "[MTProtoRust key check]"
        switch event.kind {
        case .temporaryKeyBound:
            rustEngineImportantLog("\(prefix) the server knows permanent key \(keyId)")
            self.actions.registry.noteBound(datacenterId: self.datacenterId, keyId: keyId, at: rustEngineMonotonicNow())
            self.stopSessions()
            self.report(success: true)
        case .temporaryKeyBindFailed:
            switch rustEngineKeyProbeOutcome(code: event.code, text: event.text) {
            case .keyUnknown:
                self.session?.stop()
                self.session = nil
                self.confirmUnknown(keyId: keyId, code: event.code, text: event.text, prefix: prefix)
            case .retrying:
                self.transientFailures += 1
                rustEngineImportantLog("\(prefix) the bind failed with \(event.code) \(event.text) (\(self.transientFailures))")
                if self.transientFailures >= rustEngineKeyProbeTransientFailures {
                    self.stopSessions()
                    self.report(success: false)
                }
            case .noVerdict:
                rustEngineImportantLog("\(prefix) the bind was refused with \(event.code) \(event.text), which says nothing about the key")
                self.stopSessions()
                self.bindError = MTRpcError(errorCode: event.code, errorDescription: event.text)
                self.report(success: false)
            }
        default:
            break
        }
    }

    private func confirmUnknown(keyId: Int64, code: Int32, text: String, prefix: String) {
        self.actions.registry.confirmUnknown(datacenterId: self.datacenterId, keyId: keyId, queue: self.queue, completion: { [weak self] denial in
            guard let self = self else {
                return
            }
            if let denial = denial {
                rustEngineImportantLog("\(prefix) the bind was refused, but the key stays: \(denial)")
                self.report(success: false)
            } else {
                self.validateMainKey(keyId: keyId, code: code, text: text, prefix: prefix)
            }
        })
    }

    /// The last step before a verdict, as in tdlib's `Session` (`need_check_main_key_`): tdlib never logs out
    /// on refused binds alone, it sends a call under the permanent key itself. Any answer from the server,
    /// an error included, means the server knows the key. Only `AuthKeyInvalid` (-404, twice, the second
    /// on a fresh connection) after the refusals confirms it does not, and only if the evidence still holds
    /// then: another session may have had an answer under the key meanwhile. No answer leaves it to
    /// MTContext's deadline, without a verdict.
    private func validateMainKey(keyId: Int64, code: Int32, text: String, prefix: String) {
        guard !self.finished.with({ $0 }), let context = self.probeContext, let key = self.probedKey else {
            self.report(success: false)
            return
        }
        rustEngineImportantLog("\(prefix) the evidence holds; asking the server under permanent key \(keyId) itself")
        var requestId: UInt64 = 0
        let session = RustKeySession(runtime: self.actions.runtime, context: context, datacenterId: self.datacenterId, purpose: .validatePermanentKey(key: key), serverPublicKeys: [], httpPort: self.actions.httpPort, queue: self.queue, onEvent: { [weak self] event in
            guard let self = self, !self.finished.with({ $0 }), self.validationSession != nil else {
                return
            }
            switch event.kind {
            case .completed where event.requestId == requestId && requestId != 0, .failed where event.requestId == requestId && requestId != 0 && rustEngineFailureIsAnswerUnderKey(code: event.code, text: event.text):
                rustEngineImportantLog("\(prefix) the server answered a call under permanent key \(keyId) (\(event.code) \(event.text)): it knows the key, the refused binds were not about it")
                self.actions.registry.noteAnswered(datacenterId: self.datacenterId, keyId: keyId, at: rustEngineMonotonicNow())
                self.stopSessions()
                self.report(success: false)
            case .authKeyInvalid:
                self.validationSession?.stop()
                self.validationSession = nil
                self.actions.registry.confirmUnknown(datacenterId: self.datacenterId, keyId: keyId, queue: self.queue, completion: { [weak self] denial in
                    guard let self = self, !self.finished.with({ $0 }) else {
                        return
                    }
                    if let denial = denial {
                        rustEngineImportantLog("\(prefix) the server refused permanent key \(keyId), but the key stays: \(denial)")
                    } else {
                        rustEngineImportantLog("\(prefix) confirmed: the server does not know permanent key \(keyId)")
                        self.bindError = MTRpcError(errorCode: code, errorDescription: text)
                    }
                    self.report(success: false)
                })
            default:
                break
            }
        })
        self.validationSession = session
        var payload: NSData?
        let _ = context.serialization.requestNoop(&payload)
        if let payload = payload {
            requestId = session.send(payload as Data, flags: RustEngineRequestFlags.withoutUpdates)
        }
        if requestId == 0 {
            self.fail("\(prefix) the key could not be validated: no verdict")
        }
    }
}

/// `MTDatacenterTransferAuthAction` over the Rust engine. `auth.exportAuthorization` goes to the master
/// datacenter through the account's running main session (no new connection or key), or through a
/// short-lived worker there when there is none; `auth.importAuthorization` goes to the destination through
/// a short-lived worker that imports the authorization itself, so it waits for no token. That worker takes
/// the destination's permanent key from MTContext as every session does, and the engine makes one when
/// there is none (`RustDatacenterAuthAction`). The token goes to MTContext only if the destination's
/// permanent key is still the one the import ran under, checked and written in one context transaction.
/// The bridge never sends exported bytes a second time (`rustEngineImportFailureAction`; a flood wait is
/// waited out and the engine retransmits under the same message id, which the server runs once). An
/// attempt that takes longer than `attemptTimeout` fails, and MTContext asks again after its backoff.
final class RustDatacenterTransferAuthAction: MTDatacenterTransferAuthAction, RustEngineAbandonableAction {
    static var attemptTimeout: Double = 120.0

    private let actions: RustEngineActions
    private let queue = Queue(name: "org.telegram.MTProtoRust.session")
    private let finished = Atomic<Bool>(value: false)
    private weak var context: MTContext?
    private var masterDatacenterId = 0
    private var destinationDatacenterId = 0
    private var authToken: AnyObject?
    private var exports = 0
    private var exportWorker: RustNetworkSession?
    private var importWorker: RustNetworkSession?
    private var requestDisposable: Disposable?
    private var timer: SwiftSignalKit.Timer?
    private var logPrefix = "[MTProtoRust transfer]"

    init(actions: RustEngineActions) {
        self.actions = actions
        super.init()
    }

    override func execute(_ context: MTContext!, masterDatacenterId: Int, destinationDatacenterId: Int, authToken: Any!) {
        guard let context = context, destinationDatacenterId != 0, let authToken = authToken else {
            self.report(success: false)
            return
        }
        let token = authToken as AnyObject
        if token.isEqual(context.authTokenForDatacenter(withId: destinationDatacenterId)) {
            self.report(success: true)
            return
        }
        self.actions.track(self)
        self.queue.async { [self] in
            self.context = context
            self.masterDatacenterId = masterDatacenterId
            self.destinationDatacenterId = destinationDatacenterId
            self.authToken = token
            self.logPrefix = "[MTProtoRust transfer dc\(masterDatacenterId)->dc\(destinationDatacenterId)]"
            let timer = SwiftSignalKit.Timer(timeout: RustDatacenterTransferAuthAction.attemptTimeout, repeat: false, completion: { [weak self] in
                guard let self = self else {
                    return
                }
                rustEngineImportantLog("\(self.logPrefix) no outcome after \(Int(RustDatacenterTransferAuthAction.attemptTimeout)) s")
                self.finish(success: false)
            }, queue: self.queue)
            self.timer = timer
            timer.start()
            self.export()
        }
    }

    override func cancel() {
        let _ = self.finished.swap(true)
        self.queue.async {
            self.cleanup()
        }
        super.cancel()
    }

    func abandon() {
        self.queue.async {
            if self.finished.with({ $0 }) {
                return
            }
            rustEngineImportantLog("\(self.logPrefix) the engine no longer carries the context: the transfer ends without a result")
            self.finish(success: false)
        }
    }

    private func report(success: Bool) {
        if self.finished.swap(true) {
            return
        }
        if success {
            self.complete()
        } else {
            self.fail()
        }
    }

    private func cleanup() {
        self.timer?.invalidate()
        self.timer = nil
        self.requestDisposable?.dispose()
        self.requestDisposable = nil
        self.exportWorker?.stop()
        self.exportWorker = nil
        self.importWorker?.stop()
        self.importWorker = nil
    }

    private func finish(success: Bool) {
        self.cleanup()
        self.report(success: success)
    }

    private func worker(datacenterId: Int, importsAuthorization: Bool, context: MTContext) -> RustNetworkSession {
        let session = RustNetworkSession(runtime: self.actions.runtime, context: context, datacenterId: datacenterId, role: .worker(masterDatacenterId: self.masterDatacenterId, isMedia: false, isCdn: false), usageCalculationInfo: nil, delegate: nil, serverPublicKeys: self.actions.serverPublicKeys, httpPort: self.actions.httpPort, importsAuthorization: importsAuthorization)
        session.setPaused(false)
        return session
    }

    private func export() {
        guard let context = self.context, !self.finished.with({ $0 }) else {
            return
        }
        self.exports += 1
        var data: NSData?
        guard let parser = context.serialization.exportAuthorization(Int32(self.destinationDatacenterId), data: &data), let payload = data.map({ Data(referencing: $0) }) else {
            self.finish(success: false)
            return
        }
        let queue = self.queue
        let request = NetworkEngineRequest(payload: payload, name: "auth.exportAuthorization", parse: { data in
            return parser(data)
        }, shouldContinueAfterError: { errorContext in
            return rustEngineTransferRetries(isImport: false, floodWaitErrorText: errorContext.floodWaitErrorText)
        }, completed: { [weak self] result in
            queue.async {
                self?.exported(result)
            }
        })
        let session: RustNetworkSession
        if let main = self.actions.registry.mainSession(datacenterId: self.masterDatacenterId) {
            session = main
            rustEngineLog("\(self.logPrefix) exporting through the main session")
        } else if let exportWorker = self.exportWorker {
            session = exportWorker
        } else {
            session = self.worker(datacenterId: self.masterDatacenterId, importsAuthorization: false, context: context)
            self.exportWorker = session
            rustEngineLog("\(self.logPrefix) exporting through a worker of the master datacenter")
        }
        self.requestDisposable = session.add(request)
    }

    private func exported(_ result: Result<NetworkEngineResponse, NetworkEngineRequestFailure>) {
        if self.finished.with({ $0 }) {
            return
        }
        switch result {
        case let .success(response):
            guard let exported = response.result as? MTExportedAuthorizationData, let bytes = exported.authorizationBytes else {
                self.finish(success: false)
                return
            }
            self.importAuthorization(id: exported.authorizationId, bytes: bytes)
        case let .failure(failure):
            rustEngineImportantLog("\(self.logPrefix) export failed: \(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            self.finish(success: false)
        }
    }

    private func importAuthorization(id: Int64, bytes: Data) {
        guard let context = self.context, let payload = context.serialization.importAuthorization(id, bytes: bytes) else {
            self.finish(success: false)
            return
        }
        let session: RustNetworkSession
        if let importWorker = self.importWorker {
            session = importWorker
        } else {
            session = self.worker(datacenterId: self.destinationDatacenterId, importsAuthorization: true, context: context)
            self.importWorker = session
        }
        let queue = self.queue
        let request = NetworkEngineRequest(payload: payload, name: "auth.importAuthorization", parse: { data in
            return data
        }, shouldContinueAfterError: { errorContext in
            return rustEngineTransferRetries(isImport: true, floodWaitErrorText: errorContext.floodWaitErrorText)
        }, completed: { [weak self, weak session] result in
            let keyId = session?.installedPermanentKeyId
            queue.async {
                self?.imported(result, keyId: keyId)
            }
        })
        self.requestDisposable = session.add(request)
    }

    private func imported(_ result: Result<NetworkEngineResponse, NetworkEngineRequestFailure>, keyId: Int64?) {
        guard let context = self.context, !self.finished.with({ $0 }) else {
            return
        }
        switch result {
        case .success:
            let destinationDatacenterId = self.destinationDatacenterId
            let authToken = self.authToken
            let finished = self.finished
            let queue = self.queue
            let logPrefix = self.logPrefix
            context.performBatchUpdates { [weak self] in
                if finished.with({ $0 }) {
                    return
                }
                let current = context.authInfoForDatacenter(withId: destinationDatacenterId, selector: .persistent)?.authKeyId
                guard let keyId = keyId, keyId == current else {
                    rustEngineImportantLog("\(logPrefix) imported under permanent key \(keyId.map(String.init) ?? "none"), but the datacenter's key is now \(current.map(String.init) ?? "none")")
                    queue.async {
                        self?.finish(success: false)
                    }
                    return
                }
                context.updateAuthTokenForDatacenter(withId: destinationDatacenterId, authToken: authToken)
                rustEngineImportantLog("\(logPrefix) authorization imported")
                queue.async {
                    self?.finish(success: true)
                }
            }
        case let .failure(failure):
            let code = failure.error.errorCode
            let text = failure.error.errorDescription ?? ""
            switch rustEngineImportFailureAction(code: code, text: text, exportsSoFar: self.exports) {
            case .exportAgain:
                rustEngineImportantLog("\(self.logPrefix) import failed with \(code) \(text); exporting again")
                self.export()
            case .fail:
                rustEngineImportantLog("\(self.logPrefix) import failed with \(code) \(text)")
                self.finish(success: false)
            }
        }
    }
}
