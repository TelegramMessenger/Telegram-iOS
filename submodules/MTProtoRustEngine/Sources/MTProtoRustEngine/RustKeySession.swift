import Foundation
import SwiftSignalKit
import MtProtoKit
import MTProtoEngineFFI
import MTProtoRustEngineMapping

private final class RustKeySessionListener: NSObject, MTContextChangeListener {
    weak var session: RustKeySession?

    @objc(contextDatacenterTransportSchemesUpdated:datacenterId:shouldReset:)
    func contextDatacenterTransportSchemesUpdated(_ context: MTContext, datacenterId: Int, shouldReset: Bool) {
        guard let session = self.session else {
            return
        }
        session.queue.async { [weak session] in
            session?.transportSchemesUpdated(datacenterId: datacenterId)
        }
    }

    @objc(contextApiEnvironmentUpdated:apiEnvironment:)
    func contextApiEnvironmentUpdated(_ context: MTContext, apiEnvironment: MTApiEnvironment) {
        guard let session = self.session else {
            return
        }
        session.queue.async { [weak session] in
            session?.apiEnvironmentUpdated(apiEnvironment)
        }
    }
}

/// An engine session for MTContext's key actions. It makes the datacenter's permanent key, or binds one
/// fresh temporary key to a given permanent key to learn whether the server still knows it, sending no
/// request either way. For the logout check's last step, it sends one call under a permanent key itself.
/// It reaches the datacenter as the account's sessions do (its main addresses, the context's proxy, Auto
/// transport with Telegram Web), so keys come over HTTP, HTTPS or WSS when TCP is blocked. Nothing it makes
/// is stored by it: the action that owns it reports to MTContext.
final class RustKeySession: RustEngineEventHandler {
    enum Purpose {
        case makePermanentKey
        case checkPermanentKey(key: Data)
        /// Talks under the permanent key itself, without PFS, as tdlib's `Session` validates its main key
        /// after a refused bind: any answer means the server knows the key, and only `AuthKeyInvalid`
        /// (-404 twice, the second on a fresh connection) means it does not.
        case validatePermanentKey(key: Data)
    }

    /// Lifetime of the temporary key a check binds; the key is thrown away after the bind.
    static let checkKeyLifetime: Int32 = 3600

    let queue: Queue
    private let runtime: RustEngineRuntime
    private let engine: OpaquePointer?
    private weak var context: MTContext?
    private let datacenterId: Int
    private let mailbox: RustEngineMailbox
    private let listener = RustKeySessionListener()
    private let onEvent: (RustEngineEvent) -> Void
    private var handle: MTSessionHandle = 0
    private var apiEnvironment: MTApiEnvironment
    private var addressFingerprint: [String]
    private var requestedSchemes = false
    private var holdsForUnsupportedProxy = false
    private var isStopped = false
    let logPrefix: String

    init(runtime: RustEngineRuntime, context: MTContext, datacenterId: Int, purpose: Purpose, serverPublicKeys: [String], httpPort: UInt16, queue: Queue, onEvent: @escaping (RustEngineEvent) -> Void) {
        self.runtime = runtime
        self.engine = runtime.engine
        self.context = context
        self.datacenterId = datacenterId
        self.queue = queue
        self.onEvent = onEvent
        self.mailbox = RustEngineMailbox(queue: queue)
        self.apiEnvironment = context.apiEnvironment

        let schemes = RustNetworkSession.loadSchemes(context: context, datacenterId: datacenterId, isMedia: false, apiEnvironment: self.apiEnvironment)
        self.addressFingerprint = RustNetworkSession.fingerprint(schemes)
        self.holdsForUnsupportedProxy = (self.apiEnvironment.socksProxySettings?.webProxy ?? false) && !runtime.carriesWebProxy
        let purposeName: String
        switch purpose {
        case .makePermanentKey:
            purposeName = "key maker"
        case .checkPermanentKey:
            purposeName = "key check"
        case .validatePermanentKey:
            purposeName = "key validation"
        }

        let arena = RustEngineArena()
        var setup = MTSessionSetup()
        setup.datacenter_id = Int32(datacenterId)
        setup.obfuscation_dc_id = rustEngineObfuscationDatacenterId(datacenterId: datacenterId, isTestingEnvironment: context.isTestingEnvironment, preferForMedia: false)
        setup.role = RustEngineSessionRole.worker.rawValue
        setup.framing = UInt8(MTFramingAbridged)
        let addresses = RustNetworkSession.makeAddresses(schemes, arena: arena)
        setup.addresses = arena.array(addresses)
        setup.address_count = addresses.count
        setup.proxy = RustNetworkSession.makeProxy(self.apiEnvironment.socksProxySettings, arena: arena)
        setup.environment = arena.value(RustNetworkSession.makeEnvironment(self.apiEnvironment, layer: RustNetworkSession.currentLayer(context), arena: arena))
        setup.time_difference = context.globalTimeDifference()
        setup.online = 0
        setup.paused = self.holdsForUnsupportedProxy ? 1 : 0
        setup.keep_connected = 0
        setup.idle_disconnect_after = 60.0
        setup.request_timeout = 5.0
        switch purpose {
        case .makePermanentKey, .checkPermanentKey:
            let publicKeys = serverPublicKeys.map { arena.string($0) }
            setup.public_keys_pem = arena.array(publicKeys)
            setup.public_key_count = publicKeys.count
        case .validatePermanentKey:
            break
        }
        switch purpose {
        case .makePermanentKey:
            setup.generate_key = 1
            setup.temp_key_expires_in = 0
        case let .checkPermanentKey(key):
            setup.auth_key = arena.bytes(key)
            setup.generate_key = 0
            setup.pfs_lifetime = RustKeySession.checkKeyLifetime
            setup.pfs_make_permanent_key = 0
        case let .validatePermanentKey(key):
            setup.auth_key = arena.bytes(key)
            setup.generate_key = 0
            setup.pfs_lifetime = 0
        }

        let mailbox = self.mailbox
        let handle: MTSessionHandle = withExtendedLifetime(arena) {
            return withUnsafePointer(to: &setup) { pointer in
                return runtime.createSession(setup: pointer, mailbox: mailbox)
            }
        }
        self.handle = handle
        self.logPrefix = "[MTProtoRust#\(handle) dc\(datacenterId) \(purposeName)]"
        self.mailbox.attach(self)
        self.listener.session = self
        context.add(self.listener)

        if handle == 0 {
            rustEngineImportantLog("\(self.logPrefix) mt_session_create failed")
            return
        }
        rustEngineImportantLog("\(self.logPrefix) created, \(addresses.count) addresses\(self.holdsForUnsupportedProxy ? ", waiting: a WEB proxy this engine cannot carry" : "")")
        if let engine = self.engine {
            mt_session_set_transport(engine, handle, UInt8(MTTransportAuto), httpPort)
            if #available(macOS 10.14, iOS 12.0, *) {
                RustNetworkSession.setWebEndpoint(engine: engine, handle: handle, isTestingEnvironment: context.isTestingEnvironment)
            }
        }
        if schemes.isEmpty {
            self.requestedSchemes = true
            context.transportSchemeForDatacenter(withIdRequired: datacenterId, media: false)
        }
    }

    deinit {
        self.teardown()
    }

    /// Only on `queue`.
    func stop() {
        self.teardown()
    }

    private func teardown() {
        if self.isStopped {
            return
        }
        self.isStopped = true
        self.runtime.destroySession(handle: self.handle)
        self.context?.remove(self.listener)
    }

    /// Sends one call; only on `queue`. Its answer comes as an event with the returned request id (0: not sent).
    func send(_ payload: Data, flags: UInt32) -> UInt64 {
        guard !self.isStopped, let engine = self.engine, self.handle != 0 else {
            return 0
        }
        let requestId = self.runtime.nextRequestId()
        if requestId == 0 {
            return 0
        }
        payload.withUnsafeBytes { bytes in
            var request = MTProtoEngineFFI.MTRequest()
            request.id = requestId
            request.body = MTBytes(data: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), length: bytes.count)
            request.flags = flags
            request.expected_response_size = 0
            request.invoke_after = 0
            mt_session_send(engine, self.handle, &request)
        }
        return requestId
    }

    func handleEngineEvent(_ event: RustEngineEvent) {
        if self.isStopped {
            return
        }
        self.onEvent(event)
    }

    fileprivate func transportSchemesUpdated(datacenterId: Int) {
        guard !self.isStopped, datacenterId == self.datacenterId, let engine = self.engine, self.handle != 0, let context = self.context else {
            return
        }
        let schemes = RustNetworkSession.loadSchemes(context: context, datacenterId: self.datacenterId, isMedia: false, apiEnvironment: self.apiEnvironment)
        if schemes.isEmpty {
            if !self.requestedSchemes {
                self.requestedSchemes = true
                context.transportSchemeForDatacenter(withIdRequired: self.datacenterId, media: false)
            }
            return
        }
        self.requestedSchemes = false
        let fingerprint = RustNetworkSession.fingerprint(schemes)
        if fingerprint == self.addressFingerprint {
            return
        }
        self.addressFingerprint = fingerprint
        let arena = RustEngineArena()
        let addresses = RustNetworkSession.makeAddresses(schemes, arena: arena)
        withExtendedLifetime(arena) {
            mt_session_set_addresses(engine, self.handle, arena.array(addresses), addresses.count)
        }
        rustEngineLog("\(self.logPrefix) addresses updated: \(fingerprint.joined(separator: ", "))")
    }

    fileprivate func apiEnvironmentUpdated(_ apiEnvironment: MTApiEnvironment) {
        guard !self.isStopped, let engine = self.engine, self.handle != 0 else {
            return
        }
        let previous = self.apiEnvironment
        self.apiEnvironment = apiEnvironment
        if RustNetworkSession.isSameProxy(previous.socksProxySettings, apiEnvironment.socksProxySettings) {
            return
        }
        let arena = RustEngineArena()
        var proxy = RustNetworkSession.makeProxy(apiEnvironment.socksProxySettings, arena: arena)
        withExtendedLifetime(arena) {
            mt_session_set_proxy(engine, self.handle, &proxy)
        }
        let holds = (apiEnvironment.socksProxySettings?.webProxy ?? false) && !self.runtime.carriesWebProxy
        if holds != self.holdsForUnsupportedProxy {
            self.holdsForUnsupportedProxy = holds
            mt_session_set_paused(engine, self.handle, holds ? 1 : 0)
        }
        rustEngineLog("\(self.logPrefix) proxy changed")
    }
}
