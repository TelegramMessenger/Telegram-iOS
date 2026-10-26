import Foundation

/// Bits of `MTRequest.flags` in `mtproto_engine.h`.
public enum RustEngineRequestFlags {
    public static let automaticFloodWait: UInt32 = 1 << 0
    public static let reportFloodWait: UInt32 = 1 << 1
    public static let retryServerErrors: UInt32 = 1 << 2
    public static let quickAck: UInt32 = 1 << 3
    public static let progress: UInt32 = 1 << 4
    public static let timeoutTimer: UInt32 = 1 << 5
    public static let withoutUpdates: UInt32 = 1 << 6
    public static let delegateRetryDecisions: UInt32 = 1 << 7
}

/// Values of `MTSessionSetup.role` in `mtproto_engine.h`.
public enum RustEngineSessionRole: UInt8, Equatable {
    case main = 0
    case worker = 1
    case workerRequiringAuthToken = 2
    case cdn = 3
}

/// Bits of `MTEvent.flags` for `MTEventKindConnectionState`.
public struct RustEngineConnectionFlags: Equatable {
    public var isNetworkAvailable: Bool
    public var isConnected: Bool
    public var isUpdatingConnectionContext: Bool
    public var isPerformingServiceTasks: Bool
    public var proxyHasConnectionIssues: Bool
    public var isAwaitingKeyBinding: Bool

    public init(rawValue: UInt32) {
        self.isNetworkAvailable = (rawValue & (1 << 0)) != 0
        self.isConnected = (rawValue & (1 << 1)) != 0
        self.isUpdatingConnectionContext = (rawValue & (1 << 2)) != 0
        self.isPerformingServiceTasks = (rawValue & (1 << 3)) != 0
        self.proxyHasConnectionIssues = (rawValue & (1 << 4)) != 0
        self.isAwaitingKeyBinding = (rawValue & (1 << 5)) != 0
    }
}

/// A server salt with its validity window in server seconds, as the engine stores it.
public struct RustEngineSalt: Equatable {
    public var salt: Int64
    public var validSince: Double
    public var validUntil: Double

    public init(salt: Int64, validSince: Double, validUntil: Double) {
        self.salt = salt
        self.validSince = validSince
        self.validUntil = validUntil
    }
}

/// MtProtoKit keeps salt windows as message ids (`seconds * 2^32`).
public let rustEngineMessageIdsPerSecond: Double = 4294967296.0

public func rustEngineSalt(salt: Int64, firstValidMessageId: Int64, lastValidMessageId: Int64) -> RustEngineSalt {
    return RustEngineSalt(
        salt: salt,
        validSince: Double(firstValidMessageId) / rustEngineMessageIdsPerSecond,
        validUntil: Double(lastValidMessageId) / rustEngineMessageIdsPerSecond
    )
}

public func rustEngineMessageId(seconds: Double) -> Int64? {
    if !seconds.isFinite {
        return nil
    }
    let value = (seconds * rustEngineMessageIdsPerSecond).rounded(.towardZero)
    if value <= Double(Int64.min) || value >= Double(Int64.max) {
        return nil
    }
    return Int64(value)
}

/// The `MTDatacenterSaltInfo` window of an engine salt, or nil when the engine reports a placeholder
/// without a finite window.
public func rustEngineMessageIdRange(_ salt: RustEngineSalt) -> (first: Int64, last: Int64)? {
    guard let first = rustEngineMessageId(seconds: salt.validSince), let last = rustEngineMessageId(seconds: salt.validUntil) else {
        return nil
    }
    if last <= first {
        return nil
    }
    return (first, last)
}

public func rustEngineRequestFlags(wantsQuickAck: Bool, wantsProgress: Bool, needsTimeoutTimer: Bool, withoutUpdates: Bool) -> UInt32 {
    var flags = RustEngineRequestFlags.delegateRetryDecisions
    if wantsQuickAck {
        flags |= RustEngineRequestFlags.quickAck
    }
    if wantsProgress {
        flags |= RustEngineRequestFlags.progress
    }
    if needsTimeoutTimer {
        flags |= RustEngineRequestFlags.timeoutTimer
    }
    if withoutUpdates {
        flags |= RustEngineRequestFlags.withoutUpdates
    }
    return flags
}

/// The no-op `help.test` sent after an API environment change. MtProtoKit gives it no error gate, so
/// server errors complete it and flood waits are waited out.
public func rustEngineNoopFlags(withoutUpdates: Bool) -> UInt32 {
    var flags = RustEngineRequestFlags.automaticFloodWait
    if withoutUpdates {
        flags |= RustEngineRequestFlags.withoutUpdates
    }
    return flags
}

public func rustEngineExpectedResponseSize(_ value: Int32) -> UInt32 {
    return UInt32(max(0, value))
}

/// Index of the latest candidate the dependency closure accepts, scanning newest first.
public func rustEngineDependencyIndex<T>(candidates: [T], accepts: (T) -> Bool) -> Int? {
    var index = candidates.count - 1
    while index >= 0 {
        if accepts(candidates[index]) {
            return index
        }
        index -= 1
    }
    return nil
}

/// Cumulative per-request error state that `NetworkEngineErrorContext` is built from. A request may
/// be resubmitted to the engine under a new id; counters of earlier submissions stay included.
public struct RustEngineErrorState: Equatable {
    public struct Context: Equatable {
        public var floodWaitSeconds: Int
        public var floodWaitErrorText: String?
        public var internalServerErrorCount: Int

        public init(floodWaitSeconds: Int, floodWaitErrorText: String?, internalServerErrorCount: Int) {
            self.floodWaitSeconds = floodWaitSeconds
            self.floodWaitErrorText = floodWaitErrorText
            self.internalServerErrorCount = internalServerErrorCount
        }
    }

    public private(set) var floodWaitSeconds: Int = 0
    public private(set) var floodWaitErrorText: String?
    public private(set) var serverErrorsOfEarlierSubmissions: Int = 0
    public private(set) var serverErrorsOfCurrentSubmission: Int = 0
    public private(set) var parseFailures: Int = 0

    public init() {
    }

    public var context: Context {
        return Context(
            floodWaitSeconds: self.floodWaitSeconds,
            floodWaitErrorText: self.floodWaitErrorText,
            internalServerErrorCount: self.serverErrorsOfEarlierSubmissions + self.serverErrorsOfCurrentSubmission + self.parseFailures
        )
    }

    public mutating func applyRetryDecision(floodWaitSeconds: Int64, floodWaitErrorText: String?, serverErrors: Int64) -> Context {
        if floodWaitSeconds != 0 || floodWaitErrorText != nil {
            self.floodWaitSeconds = Int(clamping: floodWaitSeconds)
            self.floodWaitErrorText = floodWaitErrorText
        }
        self.serverErrorsOfCurrentSubmission = Int(clamping: max(0, serverErrors))
        return self.context
    }

    public mutating func applyServerError() -> Context {
        self.serverErrorsOfCurrentSubmission += 1
        return self.context
    }

    public mutating func applyParseFailure() -> Context {
        self.parseFailures += 1
        return self.context
    }

    public mutating func didResubmit() {
        self.serverErrorsOfEarlierSubmissions += self.serverErrorsOfCurrentSubmission
        self.serverErrorsOfCurrentSubmission = 0
    }
}

/// With PFS in the engine, a call the server may already have fails as `500 TEMP_KEY_ROTATED` when its
/// temporary key had to go (an address class change, or no quiet moment before the key's end): the
/// engine never re-sends it under the new session by itself. MtProtoKit re-sends such calls after a key
/// change, so the bridge does too, under the request's own server-error policy
/// (`shouldContinueAfterError`), as for any other 500.
public func rustEngineResubmitsAfterKeyRotation(code: Int32, text: String) -> Bool {
    return code == 500 && text == "TEMP_KEY_ROTATED"
}

/// `500 PROTOCOL_ERROR_ANSWER_LOST`: the server ran the call and announced its answer, then said it no
/// longer has it. The caller is never told: a failure would mark a message that went out as failed (and
/// a resend would post it twice), and the many callers that retry on any error would run the call
/// again. The call stays waiting, as with MtProtoKit and tdlib, until its caller gives it up.
public func rustEngineKeepsWaitingAfterLostAnswer(code: Int32, text: String) -> Bool {
    return code == 500 && text == "PROTOCOL_ERROR_ANSWER_LOST"
}

/// An unparsable `rpc_result` is a `500 TL_PARSING_ERROR`. MtProtoKit retries it every 2 seconds
/// for as long as the error gate allows; the Rust adapter caps it at three attempts in total.
public enum RustEngineParseFailurePolicy {
    public static let errorCode: Int32 = 500
    public static let errorText = "TL_PARSING_ERROR"
    public static let retryDelay: Double = 2.0
    public static let maxAttempts: Int = 3

    public static func shouldResubmit(parseFailures: Int, gateAllowsRetry: Bool) -> Bool {
        return gateAllowsRetry && parseFailures < self.maxAttempts
    }
}

/// `-[MTProto handleMissingKey:]` without the explicit-key and `canResetAuthData` branches, which
/// TelegramCore never uses.
public enum RustEngineMissingKeyAction: Equatable {
    case dropAndRequire(isCdn: Bool)
    case removeTokenDropAndRequire
    case checkIfLoggedOut
}

public func rustEngineMissingKeyAction(isCdn: Bool, requiresForeignAuthToken: Bool, selectorIsEphemeral: Bool) -> RustEngineMissingKeyAction {
    if isCdn {
        return .dropAndRequire(isCdn: true)
    } else if requiresForeignAuthToken {
        return .removeTokenDropAndRequire
    } else if selectorIsEphemeral {
        return .dropAndRequire(isCdn: false)
    } else {
        return .checkIfLoggedOut
    }
}

/// What a main-session `401` (other than `SESSION_PASSWORD_NEEDED` / `AUTH_KEY_PERM_EMPTY`) does.
/// It logs the account out, exactly as `MtProtoKitEngine` does, because that is how a session
/// terminated from another device drops the account and its local data.
///
/// Do not route it through `MTContext.checkIfLoggedOut` (integration.md R1's suggestion). The `401`
/// is already the server's verdict, and the probe, a fresh key exchange and bind, can only say less:
/// it gives no verdict when it gets no answer, and with the Rust engine it logs out only with the
/// evidence of `rustEnginePermanentKeyUnknownDenial`, so a session terminated from another device could
/// stay logged in. (Until 2026-10 the probe was worse: it completed on the stored `EphemeralMain` key
/// without contacting the server and always answered "not removed".)
public enum RustEngineAuthorizationRequiredAction: Equatable {
    case logOut
    /// Workers re-transfer their authorization through `authTokenRequired` instead.
    case ignore
}

public func rustEngineAuthorizationRequiredAction(isMain: Bool) -> RustEngineAuthorizationRequiredAction {
    return isMain ? .logOut : .ignore
}

/// A worker re-transfers its authorization after every `401` except `SESSION_PASSWORD_NEEDED`
/// (`MTRequestMessageService` calls `requestMessageServiceAuthorizationRequired:` for those).
public func rustEngineWorkerShouldTransferAuthToken(code: Int32, text: String) -> Bool {
    return code == 401 && !text.contains("SESSION_PASSWORD_NEEDED")
}

/// A session that imports the authorization itself (`auth.importAuthorization`, the bridge's own transfer)
/// needs no token: the token is what it brings about.
public func rustEngineRequiresForeignAuthToken(isMain: Bool, isCdn: Bool, datacenterId: Int, masterDatacenterId: Int, importsAuthorization: Bool = false) -> Bool {
    return !isMain && !isCdn && !importsAuthorization && datacenterId != masterDatacenterId
}

/// Whether a session's clock becomes the app's (`MTContext.globalTimeDifference`). A CDN is run by a
/// third party and only serves encrypted file parts, so its time stays inside its own session: it
/// must not move auto-delete timers, outgoing dates or the clock other sessions start from.
public func rustEngineSharesTimeDifference(isCdn: Bool) -> Bool {
    return !isCdn
}

public func rustEngineSessionRole(isMain: Bool, isCdn: Bool, datacenterId: Int, masterDatacenterId: Int, importsAuthorization: Bool = false) -> RustEngineSessionRole {
    if isMain {
        return .main
    } else if isCdn {
        return .cdn
    } else if rustEngineRequiresForeignAuthToken(isMain: isMain, isCdn: isCdn, datacenterId: datacenterId, masterDatacenterId: masterDatacenterId, importsAuthorization: importsAuthorization) {
        return .workerRequiringAuthToken
    } else {
        return .worker
    }
}

/// The datacenter tag of the obfuscated transport header (`MTTcpConnection._datacenterTag`).
public func rustEngineObfuscationDatacenterId(datacenterId: Int, isTestingEnvironment: Bool, preferForMedia: Bool) -> Int16 {
    var value = datacenterId
    if isTestingEnvironment {
        value += 10000
    }
    if preferForMedia {
        value = -value
    }
    return Int16(clamping: value)
}

/// Connection order for the engine's address list: the scheme MTContext would pick first, then the
/// other IPv4 addresses, then IPv6 ones only when MTContext would consider IPv6 at all (or when
/// nothing else is left).
public func rustEngineAddressOrder(isIpv6: [Bool], preferredIndex: Int?, allowIpv6: Bool) -> [Int] {
    var result: [Int] = []
    if let preferredIndex = preferredIndex, preferredIndex >= 0, preferredIndex < isIpv6.count {
        result.append(preferredIndex)
    }
    for index in 0 ..< isIpv6.count where !isIpv6[index] && !result.contains(index) {
        result.append(index)
    }
    let hasIpv4 = isIpv6.contains(false)
    if allowIpv6 || !hasIpv4 {
        for index in 0 ..< isIpv6.count where isIpv6[index] && !result.contains(index) {
            result.append(index)
        }
    }
    return result
}

private let updatesTooLongConstructor: UInt32 = 0xe317af7e

public func rustEngineIsUpdatesTooLong(_ data: Data) -> Bool {
    if data.count < 4 {
        return false
    }
    var value: UInt32 = 0
    for index in 0 ..< 4 {
        value |= UInt32(data[data.startIndex + index]) << (8 * UInt32(index))
    }
    return value == updatesTooLongConstructor
}

/// External verification for `APNS_VERIFY_CHECK_` / `RECAPTCHA_CHECK_`.
public enum RustEngineVerificationKind: Int32, Equatable {
    case apns = 1
    case recaptcha = 2

    /// The literal TelegramCore's verifiers produce on their 15 second timeout.
    public var timeoutErrorText: String {
        switch self {
        case .apns:
            return "APNS_PUSH_TIMEOUT"
        case .recaptcha:
            return "RECAPTCHA_TIMEOUT"
        }
    }

    public static let failureCode: Int32 = 403
    public static let timeout: Double = 20.0
}

/// Whether a delegated retry decision may retry at all, before the request's own
/// `shouldContinueAfterError` is asked. MtProtoKit retries `500`/`-500` and every `FLOOD_WAIT_X` /
/// `FLOOD_PREMIUM_WAIT_X`, `X = 0` included (`MTRequestMessageService`). The engine marks a flood wait
/// by sending its text (`MTEvent.text2`) with the decision, so this decides on that text and never on
/// the wait length: `FLOOD_WAIT_0` arrives with 0 seconds. It looks only at the current event, not at
/// the request's cumulative error state, so an earlier flood wait cannot make a later error retryable.
public func rustEngineRetryDecisionIsRetryable(code: Int32, floodWaitText: String?) -> Bool {
    return code == 500 || code == -500 || floodWaitText != nil
}

/// `NetworkEngineErrorContext.floodWaitErrorText` from the event's `text2`, which is empty when unset.
public func rustEngineOptionalText(_ text: String) -> String? {
    return text.isEmpty ? nil : text
}

/// Whether a session runs PFS in the engine: it makes and binds its temporary keys itself, over
/// whichever transport works, instead of taking them from `MTContext`. CDN sessions talk under their
/// permanent key, as with MtProtoKit.
public func rustEngineRunsPfs(isCdn: Bool, useTempAuthKeys: Bool, publicKeyCount: Int) -> Bool {
    return !isCdn && useTempAuthKeys && publicKeyCount > 0
}

/// `MTDatacenterAuthInfo.validUntilTimestamp` of a temporary key is local time; the engine and
/// `auth.bindTempAuthKey` use server time.
public func rustEngineServerExpiry(validUntil: Int32, timeDifference: Double) -> Int32 {
    return Int32(clamping: Int64((Double(validUntil) + timeDifference).rounded(.down)))
}

public func rustEngineLocalValidUntil(serverExpiry: Int64, timeDifference: Double) -> Int32 {
    return Int32(clamping: Int64((Double(serverExpiry) - timeDifference).rounded(.down)))
}

/// A temporary key as `MTContext` keeps it: `boundTo` is the permanent key it was bound to when the
/// Rust engine stored it, nil for a key MtProtoKit made.
public struct RustEngineTemporaryKeyInfo: Equatable {
    public var keyId: Int64
    public var validUntil: Int32
    public var boundTo: Int64?

    public init(keyId: Int64, validUntil: Int32, boundTo: Int64?) {
        self.keyId = keyId
        self.validUntil = validUntil
        self.boundTo = boundTo
    }
}

/// `MTDatacenterAuthInfo.authKeyAttributes` key holding `RustEngineTemporaryKeyInfo.boundTo`.
public let rustEngineBoundToAttribute = "rustEngineBoundTo"

/// Whether a temporary key a session made and bound replaces the one the context keeps for its
/// address class: when there is none, when the kept one belongs to another permanent key, or when
/// the new one lives longer.
public func rustEngineStoresTemporaryKey(stored: RustEngineTemporaryKeyInfo?, made: RustEngineTemporaryKeyInfo) -> Bool {
    guard let stored = stored else {
        return true
    }
    if stored.keyId == made.keyId {
        return false
    }
    if let boundTo = stored.boundTo, boundTo != made.boundTo {
        return true
    }
    return stored.validUntil < made.validUntil
}

/// Whether a temporary key the context keeps can be given to a session: bound to the session's
/// permanent key as far as is known, and with more than `minimumLifetime` seconds left.
public func rustEngineOffersTemporaryKey(stored: RustEngineTemporaryKeyInfo, permanentKeyId: Int64?, now: Int32, minimumLifetime: Int32) -> Bool {
    guard let permanentKeyId = permanentKeyId else {
        return false
    }
    if let boundTo = stored.boundTo, boundTo != permanentKeyId {
        return false
    }
    return stored.validUntil != Int32.max && Int64(stored.validUntil) - Int64(now) > Int64(minimumLifetime)
}

/// An address of an active interface, as `getifaddrs` reports it.
public struct RustEngineNetworkInterface: Equatable {
    public var name: String
    public var address: [UInt8]
    public var netmask: [UInt8]

    public init(name: String, address: [UInt8], netmask: [UInt8]) {
        self.name = name
        self.address = address
        self.netmask = netmask
    }
}

/// The router of an active network service, as the system configuration reports it.
public struct RustEngineNetworkRouter: Equatable {
    public var interface: String
    public var address: String

    public init(interface: String, address: String) {
        self.interface = interface
        self.address = address
    }
}

/// Interfaces that say nothing about the network the device is on: VPN tunnels, peer-to-peer, bridge
/// and virtual machine links. A VPN coming and going must not make the same network look new.
private let rustEngineIgnoredInterfacePrefixes = ["utun", "ipsec", "ppp", "awdl", "llw", "gif", "stf", "anpi", "ap", "bridge", "vmnet", "vnic", "vboxnet", "feth", "lo"]
/// Cellular data interfaces: their addresses change with every attach, and they stay up next to Wi-Fi.
private let rustEngineCellularInterfacePrefix = "pdp_ip"

private func rustEngineIgnoresInterface(_ name: String) -> Bool {
    return rustEngineIgnoredInterfacePrefixes.contains(where: { name.hasPrefix($0) })
}

/// Whether a service's router goes into the fingerprint: not on a VPN, virtual or cellular interface.
public func rustEngineNetworkRouterCounts(_ router: RustEngineNetworkRouter) -> Bool {
    return !router.address.isEmpty && !rustEngineIgnoresInterface(router.interface) && !router.interface.hasPrefix(rustEngineCellularInterfacePrefix)
}

/// What identifies the network the device is on, as text to be hashed with a per-install salt: every
/// active interface with its IPv4 network and prefix and its global or unique-local IPv6 /64, and the
/// routers of the services on them. Cellular alone is one network, whatever its addresses. Nil when
/// nothing identifies it.
public func rustEngineNetworkFingerprint(interfaces: [RustEngineNetworkInterface], routers: [RustEngineNetworkRouter]) -> String? {
    var parts: [String] = []
    var cellular = false
    for interface in interfaces {
        if rustEngineIgnoresInterface(interface.name) {
            continue
        }
        if interface.name.hasPrefix(rustEngineCellularInterfacePrefix) {
            cellular = true
            continue
        }
        if interface.address.count == 4 && interface.netmask.count == 4 {
            if interface.address[0] == 169 && interface.address[1] == 254 {
                continue
            }
            let network = zip(interface.address, interface.netmask).map { $0 & $1 }
            let prefix = interface.netmask.reduce(0) { $0 + $1.nonzeroBitCount }
            parts.append("\(interface.name) \(network.map(String.init).joined(separator: "."))/\(prefix)")
        } else if interface.address.count == 16 {
            let global = interface.address[0] & 0xe0 == 0x20
            let uniqueLocal = interface.address[0] & 0xfe == 0xfc
            if !global && !uniqueLocal {
                continue
            }
            parts.append("\(interface.name) \(interface.address.prefix(8).map { String(format: "%02x", $0) }.joined())/64")
        }
    }
    if parts.isEmpty {
        return cellular ? "cellular" : nil
    }
    for router in routers where rustEngineNetworkRouterCounts(router) {
        parts.append("router \(router.interface) \(router.address)")
    }
    return Array(Set(parts)).sorted().joined(separator: "\n")
}

/// The engine's own threads are `mtproto-main`, `mtproto-worker-N` and `mtproto-resolver`. The engine
/// aborts on a panic (`panic = "abort"`) on the panicking thread. The app counts a crash on an engine
/// thread or queue (`rustEngineOwnsQueue(label:)`), including the bridge callbacks that run there, as an
/// engine crash and reports it with `recordRustEngineCrash` to fall back to MtProtoKit after repeated
/// crashes.
public func rustEngineOwnsThread(named name: String) -> Bool {
    return name.hasPrefix("mtproto-")
}

/// The bridge's own dispatch queues: `org.telegram.MTProtoRust.streams` (`RustStreamHost`),
/// `.carrier` (`RustCarrierStreams`), `.session` (each `RustNetworkSession`) and `.network`
/// (`RustEngineRuntime`'s network watcher). A crash while one of them is the current queue is an engine
/// crash, as for `rustEngineOwnsThread(named:)`.
public func rustEngineOwnsQueue(label: String) -> Bool {
    return label.hasPrefix("org.telegram.MTProtoRust.")
}

/// Bits of `MTEvent.flags` for `MTEventKindAuthKeyCreated` (ABI 4): exactly one is set.
public enum RustEngineAuthKeyCreatedFlags {
    public static let temporary: UInt32 = 1 << 0
    public static let permanent: UInt32 = 1 << 1
}

public enum RustEngineCreatedKeyKind: Equatable {
    case permanent
    case temporary
}

/// Which key an `AuthKeyCreated` event carries; nil when its flags say neither (an engine older than ABI 4,
/// which the runtime refuses to start).
public func rustEngineCreatedKeyKind(flags: UInt32) -> RustEngineCreatedKeyKind? {
    let permanent = (flags & RustEngineAuthKeyCreatedFlags.permanent) != 0
    let temporary = (flags & RustEngineAuthKeyCreatedFlags.temporary) != 0
    switch (permanent, temporary) {
    case (true, false):
        return .permanent
    case (false, true):
        return .temporary
    default:
        return nil
    }
}

/// What a bind made only to check a permanent key (`MTContext.checkIfLoggedOut`) says.
public enum RustEngineKeyProbeOutcome: Equatable {
    /// The server refused the fresh temporary key with `ENCRYPTED_MESSAGE_INVALID`: as far as this probe
    /// goes, it does not know the permanent key.
    case keyUnknown
    /// A transient failure (`5xx`, `420`): the engine binds the same key again.
    case retrying
    /// Any other refusal says nothing about the permanent key.
    case noVerdict
}

public func rustEngineKeyProbeOutcome(code: Int32, text: String) -> RustEngineKeyProbeOutcome {
    if code == 400 && text == "ENCRYPTED_MESSAGE_INVALID" {
        return .keyUnknown
    }
    if code >= 500 || code == 420 || code < 0 {
        return .retrying
    }
    return .noVerdict
}

/// Transient bind failures a key probe waits through before it gives up without a verdict, as
/// MtProtoKit's probe binds one key three times.
public let rustEngineKeyProbeTransientFailures = 3

/// The evidence that the home datacenter's permanent key is unknown to the server. With it, the bridge asks
/// the server under the key itself, and only that call's `AuthKeyInvalid` logs the account out. A false
/// logout is the worst outcome there is, so every one of these must hold first:
/// - the engine reported the key unknown (two fresh temporary keys refused with `ENCRYPTED_MESSAGE_INVALID`
///   while the key was older than the engine's 60 s immunity), and the bridge took the report, which it
///   does not for a key installed into the session less than a minute ago, since the session last had
///   none (`reportedKeyId`, `reportedAt`);
/// - the report is recent (`maximumReportAge`);
/// - a separate probe, with its own fresh temporary key on its own connection, was refused the same way
///   (the caller only asks once that happened, for `probedKeyId`);
/// - a session saw the key's first refusal at least `observationWindow` ago (`firstRefusalAt`): the
///   engine's two refusals and the probe can all come within a few round trips, too soon for calls in
///   flight on other sessions to answer;
/// - the server has not shown in this context, within `immunity`, that it knows the key (`lastKnownAt`:
///   an answered call, a server error that `rustEngineFailureIsServerAnswer` takes, an update, or an
///   accepted bind under it, and any answer to an earlier validation call, a 401 included). This is
///   tdlib's immunity (`Session::on_bind_result`): a key the server bound or answered under within the last
///   day is never validated, so refusals during a datacenter incident, even with -404s for the key, log
///   nobody out. tdlib also requires the key to be older than a day. MTContext keeps no creation date, so
///   the bridge gives the immunity to younger keys too. tdlib (with PFS) counts only accepted binds; the
///   bridge also counts answers because a launch reuses the stored temporary key and binds nothing. One
///   consequence: a temporary key of a permanent key the server destroyed still answers calls that need
///   no authorization (R5-2), which keeps the immunity going until that key expires. An authorized account
///   is logged out by its main session's 401 meanwhile; a key before login waits for a restart or the
///   immunity's end.
public struct RustEnginePermanentKeyEvidence: Equatable {
    public var reportedKeyId: Int64?
    public var reportedAt: Double?
    public var firstRefusalAt: Double?
    public var lastKnownAt: Double?

    public init(reportedKeyId: Int64?, reportedAt: Double?, firstRefusalAt: Double?, lastKnownAt: Double?) {
        self.reportedKeyId = reportedKeyId
        self.reportedAt = reportedAt
        self.firstRefusalAt = firstRefusalAt
        self.lastKnownAt = lastKnownAt
    }

    public static let maximumReportAge: Double = 300.0
    public static let observationWindow: Double = 10.0
    /// Refused binds further apart than this start a new episode: a refusal long ago, with the key working
    /// since, says nothing about the refusals now.
    public static let refusalEpisodeGap: Double = 300.0
    /// How long the server showing it knows a key keeps the key from being validated (tdlib: a day).
    public static let immunity: Double = 24.0 * 60.0 * 60.0
}

/// Whether a refusal at `at` continues the episode of refusals that last saw one at `lastRefusalAt`.
public func rustEngineRefusalContinuesEpisode(lastRefusalAt: Double, at: Double) -> Bool {
    return at >= lastRefusalAt && at - lastRefusalAt <= RustEnginePermanentKeyEvidence.refusalEpisodeGap
}

/// Seconds to wait before deciding, so that the decision covers `observationWindow` after the first refusal.
public func rustEnginePermanentKeyDecisionDelay(firstRefusalAt: Double?, now: Double) -> Double {
    guard let firstRefusalAt = firstRefusalAt else {
        return 0.0
    }
    return min(RustEnginePermanentKeyEvidence.observationWindow, max(0.0, firstRefusalAt + RustEnginePermanentKeyEvidence.observationWindow - now))
}

/// Nil when the probe's refusal is confirmed, and the key is to be validated with a call under it.
/// Otherwise the reason it is not confirmed.
public func rustEnginePermanentKeyUnknownDenial(_ evidence: RustEnginePermanentKeyEvidence, probedKeyId: Int64, now: Double) -> String? {
    guard let reportedKeyId = evidence.reportedKeyId, let reportedAt = evidence.reportedAt else {
        return "the engine did not report the key unknown"
    }
    if reportedKeyId != probedKeyId {
        return "the engine reported another key unknown"
    }
    if now - reportedAt > RustEnginePermanentKeyEvidence.maximumReportAge || now < reportedAt {
        return "the engine's report is too old"
    }
    guard let firstRefusalAt = evidence.firstRefusalAt, firstRefusalAt <= now else {
        return "no refused bind was seen for the key"
    }
    if now - firstRefusalAt < RustEnginePermanentKeyEvidence.observationWindow {
        return "the key was watched for less than \(Int(RustEnginePermanentKeyEvidence.observationWindow)) s since its first refusal"
    }
    if let lastKnownAt = evidence.lastKnownAt, now - lastKnownAt < RustEnginePermanentKeyEvidence.immunity {
        return "the server answered under the key or bound it \(Int(max(0.0, now - lastKnownAt))) s ago"
    }
    return nil
}

/// What a failed `auth.importAuthorization` leads to. Whether Telegram takes the same exported bytes twice
/// is not known, so after a failure the bridge never sends them again (a flood wait, which the server
/// answers without running the call, is waited out; the engine retransmits under the same message id,
/// which the server runs once): `AUTH_BYTES_INVALID` and server errors (`500`, the engine's
/// `500 TEMP_KEY_ROTATED` when the import may have reached the server under a key that had to go) get one
/// fresh export; anything else, and a second failure, fails the transfer, which MTContext retries with its
/// backoff. Importing an authorization twice is harmless.
public enum RustEngineImportFailureAction: Equatable {
    case exportAgain
    case fail
}

public let rustEngineTransferExportsPerAttempt = 2

public func rustEngineImportFailureAction(code: Int32, text: String, exportsSoFar: Int) -> RustEngineImportFailureAction {
    if exportsSoFar >= rustEngineTransferExportsPerAttempt {
        return .fail
    }
    if (code == 400 && text == "AUTH_BYTES_INVALID") || code == 500 || code == -500 {
        return .exportAgain
    }
    return .fail
}

/// Whether a transfer request is retried after an error the engine delegates: flood waits are always waited
/// out (as MtProtoKit's transfer does); a server error is retried for the export, which carries nothing
/// single-use, and never for the import, whose bytes are not sent again after a server error.
public func rustEngineTransferRetries(isImport: Bool, floodWaitErrorText: String?) -> Bool {
    if floodWaitErrorText != nil {
        return true
    }
    return !isImport
}

/// Errors the engine or the bridge make up for a call that may never have reached the server, or that
/// they gave up on: none of them is the server's answer.
private let rustEngineUnansweredErrorTexts: Set<String> = [
    "TEMP_KEY_ROTATED",
    "SESSION_RESET",
    "REQUEST_INVALID_SIZE",
    "REQUEST_ID_INVALID",
    "SESSION_CLOSED",
    "APNS_PUSH_TIMEOUT",
    "RECAPTCHA_TIMEOUT"
]

/// Whether a failed call's error comes from the server, under the key the call went under, as opposed to
/// a transport failure (code ≤ 0) or an error the engine or the bridge made up for a call that may never
/// have reached it. `PROTOCOL_ERROR_*` counts: the engine raises it after service messages the server
/// encrypted under the key (`bad_msg_notification` and the like). `RESPONSE_UNPACK_FAILED: …` and
/// `TL_PARSING_ERROR` count too: they are answers the server encrypted under the key, just unreadable.
/// The logout check's validation call takes any such error as the server knowing the permanent key, as
/// tdlib keeps the key on any answer but `-404`.
public func rustEngineFailureIsAnswerUnderKey(code: Int32, text: String) -> Bool {
    if code <= 0 || text.isEmpty {
        return false
    }
    return !rustEngineUnansweredErrorTexts.contains(text)
}

/// Whether a failed call on an account session shows that the server knows the permanent key, which gives
/// the key the logout check's day-long immunity. It counts less than the validation call does:
/// - not a `401`: a temporary key bound to a permanent key the server destroyed still answers
///   `401 AUTH_KEY_UNREGISTERED` (real-server probe R5-2);
/// - not `PROTOCOL_ERROR_*`, which is the engine's own reading of service messages.
public func rustEngineFailureIsServerAnswer(code: Int32, text: String) -> Bool {
    return code != 401 && !text.hasPrefix("PROTOCOL_ERROR_") && rustEngineFailureIsAnswerUnderKey(code: code, text: text)
}

/// `MTEventKindReleased` (ABI 5): the bit of `MTEvent.flags` saying the request may have reached the
/// server under the draining session (`MTReleasedMayHaveRun`).
public let rustEngineReleasedMayHaveRunFlag: UInt32 = 1 << 0

public func rustEngineReleasedMayHaveRun(flags: UInt32) -> Bool {
    return (flags & rustEngineReleasedMayHaveRunFlag) != 0
}

/// The session has a connection the server answered on (connected and past the connection's context
/// update, or only waiting for its temporary key's bind): what the local health check calls connected.
public func rustEngineHasAnsweredConnection(_ flags: RustEngineConnectionFlags) -> Bool {
    return flags.isConnected && (!flags.isUpdatingConnectionContext || flags.isAwaitingKeyBinding)
}

/// Whether the local health check's silence starts again at this connection state: the server answered
/// on the connection just now, or the session just lost a connection the server had answered on (an idle
/// session pings rarely, so its last packet can be long ago while it worked until this moment).
public func rustEngineConnectionStateRestartsSilence(previous: RustEngineConnectionFlags?, current: RustEngineConnectionFlags) -> Bool {
    if current.isConnected && !current.isUpdatingConnectionContext {
        return true
    }
    return previous.map(rustEngineHasAnsweredConnection) == true && !rustEngineHasAnsweredConnection(current)
}

/// The context's temporary key is one the engine made and bound (`rustEngineBoundToAttribute`), not one
/// MtProtoKit made.
public func rustEngineMadeTemporaryKey(attributes: [AnyHashable: Any]?) -> Bool {
    return attributes?[rustEngineBoundToAttribute] != nil
}

/// What a session does with the engine's `PermanentKeyInvalid`.
public enum RustEnginePermanentKeyReportAction: Equatable {
    /// The session drains into another (a live switch): the logout check is the replacement's to start,
    /// with whatever engine then runs the context (B2 review L7: after a switch to MtProtoKit, MtProtoKit's
    /// probe would judge the old session's report on a single refusal).
    case leaveToReplacement
    /// The key replaced another less than the immunity ago: the report is about the old one.
    case keepYoungKey
    case handle
}

public func rustEnginePermanentKeyReportAction(draining: Bool, keyAge: Double, immunity: Double) -> RustEnginePermanentKeyReportAction {
    if draining {
        return .leaveToReplacement
    }
    if keyAge < immunity {
        return .keepYoungKey
    }
    return .handle
}
