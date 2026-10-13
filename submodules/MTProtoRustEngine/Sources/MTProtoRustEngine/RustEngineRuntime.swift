import Foundation
#if canImport(AppKit)
import AppKit
#endif
import SwiftSignalKit
import MtProtoKit
import TelegramCore
import MTProtoEngineFFI
import MTProtoRustEngineMapping

let rustEngineLogTag = "MTProtoRust"

func rustEngineLog(_ text: @autoclosure () -> String) {
    if MTLogEnabled() {
        Logger.shared.log(rustEngineLogTag, text())
    }
}

func rustEngineImportantLog(_ text: String) {
    Logger.shared.log(rustEngineLogTag, text)
    Logger.shared.shortLog(rustEngineLogTag, text)
}

final class RustEngineLock {
    private let pointer: UnsafeMutablePointer<os_unfair_lock>

    init() {
        self.pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self.pointer.initialize(to: os_unfair_lock())
    }

    deinit {
        self.pointer.deinitialize(count: 1)
        self.pointer.deallocate()
    }

    func lock() {
        os_unfair_lock_lock(self.pointer)
    }

    func unlock() {
        os_unfair_lock_unlock(self.pointer)
    }
}

final class RustEngineMailbox {
    let queue: Queue
    private let lock = RustEngineLock()
    private weak var session: RustNetworkSession?
    private var isAttached = false
    private var pending: [RustEngineEvent] = []
    private var isDrainScheduled = false

    init(queue: Queue) {
        self.queue = queue
    }

    func attach(_ session: RustNetworkSession) {
        self.lock.lock()
        self.session = session
        self.isAttached = true
        let schedule = !self.pending.isEmpty && !self.isDrainScheduled
        if schedule {
            self.isDrainScheduled = true
        }
        self.lock.unlock()
        if schedule {
            self.queue.async {
                self.drain()
            }
        }
    }

    func post(_ event: RustEngineEvent) {
        self.lock.lock()
        self.pending.append(event)
        let schedule = self.isAttached && !self.isDrainScheduled
        if schedule {
            self.isDrainScheduled = true
        }
        self.lock.unlock()
        if schedule {
            self.queue.async {
                self.drain()
            }
        }
    }

    private func drain() {
        self.lock.lock()
        let events = self.pending
        self.pending = []
        self.isDrainScheduled = false
        let session = self.session
        self.lock.unlock()
        guard let session = session else {
            return
        }
        for event in events {
            session.handleEngineEvent(event)
        }
    }
}

private func rustEngineEventCallback(context: UnsafeMutableRawPointer?, session: MTSessionHandle, event: UnsafePointer<MTEvent>?) {
    guard let event = event else {
        return
    }
    let copied = RustEngineEvent(event)
    guard let context = context else {
        return
    }
    let runtime = Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue()
    runtime.dispatch(handle: session, event: copied)
}

private func rustEngineLogCallback(context: UnsafeMutableRawPointer?, level: Int32, message: MTString) {
    if level > 1 && !MTLogEnabled() {
        return
    }
    let text = rustEngineString(message)
    if level <= 1 {
        Logger.shared.log(rustEngineLogTag, text)
        Logger.shared.shortLog(rustEngineLogTag, text)
    } else {
        Logger.shared.log(rustEngineLogTag, text)
    }
}

final class RustEngineRuntime: NSObject, MTNetworkAvailabilityDelegate {
    static let shared: RustEngineRuntime? = {
        let runtime = RustEngineRuntime()
        if runtime.engine == nil {
            rustEngineImportantLog("[MTProtoRust] mt_engine_create failed")
            return nil
        }
        runtime.start()
        return runtime
    }()

    private(set) var engine: OpaquePointer?
    private let lock = RustEngineLock()
    private var wakeObserver: NSObjectProtocol?
    private var mailboxes: [MTSessionHandle: RustEngineMailbox] = [:]
    private var networkAvailability: MTNetworkAvailability?
    private var isNetworkAvailableValue: Bool = true
    private let networkQueue = DispatchQueue(label: "org.telegram.MTProtoRust.network")
    private var networkWatcher: RustNetworkWatcher?
    private var streamHost: AnyObject?
    private var carrierStreams: RustCarrierStreams?
    private var carrierStreamIds = Set<UInt64>()
    private var networkKey: Data?
    private var unresolvedRoutersSince: [String: Double] = [:]
    private static let routerResolveWait: Double = 2.0

    private override init() {
        super.init()

        rustEngineVerifyAssumptions()

        let abiVersion = mt_engine_abi_version()
        if abiVersion != 3 {
            rustEngineImportantLog("[MTProtoRust] unsupported engine ABI version \(abiVersion)")
            return
        }
        self.engine = mt_engine_create(0, Unmanaged.passUnretained(self).toOpaque(), rustEngineEventCallback, rustEngineLogCallback)
    }

    private func start() {
        if let engine = self.engine, let memory = RustNetworkIdentity.storedMemory() {
            memory.withUnsafeBytes { bytes in
                mt_engine_set_route_memory(engine, MTBytes(data: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), length: bytes.count))
            }
        }
        self.networkQueue.sync {
            self.applyNetworkKey()
        }
        let networkWatcher = RustNetworkWatcher(queue: self.networkQueue, changed: { [weak self] in
            self?.applyNetworkKey()
        })
        self.networkQueue.sync {
            self.networkWatcher = networkWatcher
        }
        networkWatcher.start()
        if let engine = self.engine {
            if #available(macOS 10.14, iOS 12.0, *) {
                self.streamHost = RustStreamHost(engine: engine)
            }
            self.carrierStreams = RustCarrierStreams(engine: engine)
            var callbacks = rustStreamHostCallbacks()
            mt_engine_set_stream_host(engine, &callbacks)
        }
        self.networkAvailability = MTNetworkAvailability(delegate: self)
        #if canImport(AppKit)
        let engine = self.engine
        self.wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let engine = engine else {
                return
            }
            self?.updateNetworkKey()
            rustEngineImportantLog("[MTProtoRust] system woke up, resetting connections")
            mt_engine_reset_connections(engine)
        })
        #endif
    }

    var isNetworkAvailable: Bool {
        self.lock.lock()
        let value = self.isNetworkAvailableValue
        self.lock.unlock()
        return value
    }

    func nextRequestId() -> UInt64 {
        guard let engine = self.engine else {
            return 0
        }
        return mt_engine_next_request_id(engine)
    }

    func createSession(setup: UnsafePointer<MTSessionSetup>, mailbox: RustEngineMailbox) -> MTSessionHandle {
        guard let engine = self.engine else {
            return 0
        }
        self.lock.lock()
        let handle = mt_session_create(engine, setup)
        if handle != 0 {
            self.mailboxes[handle] = mailbox
        }
        self.lock.unlock()
        return handle
    }

    func destroySession(handle: MTSessionHandle) {
        guard let engine = self.engine, handle != 0 else {
            return
        }
        self.lock.lock()
        self.mailboxes.removeValue(forKey: handle)
        self.lock.unlock()
        mt_session_destroy(engine, handle)
    }

    /// WEB proxies go over the WEB proxy carrier, which this engine drives itself.
    var carriesWebProxy: Bool {
        return self.carrierStreams != nil
    }

    private func isCarrierStream(_ stream: UInt64) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.carrierStreamIds.contains(stream)
    }

    func openStream(_ stream: UInt64, host: String, port: UInt16, serverName: String?, alpn: [String], carrier: Bool) {
        if carrier, let carrierStreams = self.carrierStreams {
            self.lock.lock()
            self.carrierStreamIds.insert(stream)
            self.lock.unlock()
            carrierStreams.open(stream: stream)
        } else if !carrier, #available(macOS 10.14, iOS 12.0, *), let streamHost = self.streamHost as? RustStreamHost {
            streamHost.open(stream: stream, host: host, port: port, serverName: serverName, alpn: alpn)
        } else if let engine = self.engine {
            "unavailable".withCString { pointer in
                mt_stream_closed(engine, stream, MTString(data: pointer, length: strlen(pointer)))
            }
        }
    }

    func writeStream(_ stream: UInt64, data: Data) {
        if self.isCarrierStream(stream) {
            self.carrierStreams?.write(stream: stream, data: data)
        } else if #available(macOS 10.14, iOS 12.0, *), let streamHost = self.streamHost as? RustStreamHost {
            streamHost.write(stream: stream, data: data)
        }
    }

    func closeStream(_ stream: UInt64) {
        self.lock.lock()
        let carrier = self.carrierStreamIds.remove(stream) != nil
        self.lock.unlock()
        if carrier {
            self.carrierStreams?.close(stream: stream)
        } else if #available(macOS 10.14, iOS 12.0, *), let streamHost = self.streamHost as? RustStreamHost {
            streamHost.close(stream: stream)
        }
    }

    func resumeStream(_ stream: UInt64) {
        if self.isCarrierStream(stream) {
            self.carrierStreams?.resume(stream: stream)
        } else if #available(macOS 10.14, iOS 12.0, *), let streamHost = self.streamHost as? RustStreamHost {
            streamHost.resume(stream: stream)
        }
    }

    fileprivate func dispatch(handle: MTSessionHandle, event: RustEngineEvent) {
        if handle == 0 {
            if event.kind == .routeMemoryChanged, let memory = event.payload {
                RustNetworkIdentity.storeMemory(Data(memory))
            }
            return
        }
        self.lock.lock()
        let mailbox = self.mailboxes[handle]
        self.lock.unlock()
        mailbox?.post(event)
    }

    private func updateNetworkKey() {
        self.networkQueue.async { [weak self] in
            self?.applyNetworkKey()
        }
    }

    private func applyNetworkKey() {
        guard let engine = self.engine else {
            return
        }
        let key = self.networkIdentityComplete() ? RustNetworkIdentity.currentKey(gateways: self.networkWatcher?.gateways ?? []) : Data()
        if self.networkKey == key {
            return
        }
        self.networkKey = key
        rustEngineLog("[MTProtoRust] network \(key.isEmpty ? "unknown" : key.prefix(4).map { String(format: "%02x", $0) }.joined())")
        key.withUnsafeBytes { bytes in
            mt_engine_set_network(engine, MTBytes(data: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), length: bytes.count))
        }
    }

    private func networkIdentityComplete() -> Bool {
        #if os(macOS)
        let unresolved = RustNetworkIdentity.unresolvedRouters()
        let now = ProcessInfo.processInfo.systemUptime
        self.unresolvedRoutersSince = self.unresolvedRoutersSince.filter { unresolved.contains($0.key) }
        for router in unresolved where self.unresolvedRoutersSince[router] == nil {
            self.unresolvedRoutersSince[router] = now
        }
        guard let since = self.unresolvedRoutersSince.values.max() else {
            return true
        }
        let deadline = since + RustEngineRuntime.routerResolveWait
        if now >= deadline {
            return true
        }
        self.networkQueue.asyncAfter(deadline: .now() + (deadline - now)) { [weak self] in
            self?.applyNetworkKey()
        }
        return false
        #else
        return self.networkWatcher?.hasPath ?? false
        #endif
    }

    func networkAvailabilityChanged(_ networkAvailability: MTNetworkAvailability!, networkIsAvailable: Bool) {
        guard let engine = self.engine else {
            return
        }
        self.lock.lock()
        self.isNetworkAvailableValue = networkIsAvailable
        self.lock.unlock()

        rustEngineImportantLog("[MTProtoRust] network availability changed: \(networkIsAvailable ? "available" : "unavailable")")
        if networkIsAvailable {
            self.updateNetworkKey()
        }
        mt_engine_set_network_available(engine, networkIsAvailable ? 1 : 0)
        if networkIsAvailable {
            mt_engine_reset_connections(engine)
        }
    }
}

private func rustEngineVerifyAssumptions() {
    assert(RustEngineRequestFlags.automaticFloodWait == UInt32(MTRequestFlagAutomaticFloodWait))
    assert(RustEngineRequestFlags.reportFloodWait == UInt32(MTRequestFlagReportFloodWait))
    assert(RustEngineRequestFlags.retryServerErrors == UInt32(MTRequestFlagRetryServerErrors))
    assert(RustEngineRequestFlags.quickAck == UInt32(MTRequestFlagQuickAck))
    assert(RustEngineRequestFlags.progress == UInt32(MTRequestFlagProgress))
    assert(RustEngineRequestFlags.timeoutTimer == UInt32(MTRequestFlagTimeoutTimer))
    assert(RustEngineRequestFlags.withoutUpdates == UInt32(MTRequestFlagWithoutUpdates))
    assert(RustEngineRequestFlags.delegateRetryDecisions == UInt32(MTRequestFlagDelegateRetryDecisions))
    assert(RustEngineSessionRole.main.rawValue == UInt8(MTSessionRoleMain))
    assert(RustEngineSessionRole.worker.rawValue == UInt8(MTSessionRoleWorker))
    assert(RustEngineSessionRole.workerRequiringAuthToken.rawValue == UInt8(MTSessionRoleWorkerRequiringAuthToken))
    assert(RustEngineSessionRole.cdn.rawValue == UInt8(MTSessionRoleCdn))
    assert(RustEngineEventKind.retryDecisionRequired.rawValue == MTEventKindRetryDecisionRequired.rawValue)
    assert(RustEngineEventKind.completed.rawValue == MTEventKindCompleted.rawValue)
    assert(RustEngineEventKind.update.rawValue == MTEventKindUpdate.rawValue)
    assert(RustEngineEventKind.connectionState.rawValue == MTEventKindConnectionState.rawValue)
    assert(RustEngineVerificationKind.apns.rawValue == Int32(MTVerificationKindApns))
    assert(RustEngineVerificationKind.recaptcha.rawValue == Int32(MTVerificationKindRecaptcha))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterAuthInfoUpdated:datacenterId:authInfo:selector:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterAuthTokenUpdated:datacenterId:authToken:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterAuthInfoRequestFailed:datacenterId:selector:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterAuthTokenTransferFailed:datacenterId:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterTransportSchemesUpdated:datacenterId:shouldReset:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextApiEnvironmentUpdated:apiEnvironment:")))
    assert(!RustContextListener.instancesRespond(to: NSSelectorFromString("isContextNetworkAccessAllowed:")))
    assert(!RustContextListener.instancesRespond(to: NSSelectorFromString("contextLoggedOut:")))
}
