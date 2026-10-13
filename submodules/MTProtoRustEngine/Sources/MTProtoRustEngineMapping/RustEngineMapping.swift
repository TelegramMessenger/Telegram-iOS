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
/// Do not route it through `MTContext.checkIfLoggedOut` (integration.md R1's suggestion): that probe
/// runs an `EphemeralMain` auth action, and `-[MTDatacenterAuthAction execute:]` completes at once,
/// without contacting the server, when the context already stores a key for that selector, which the
/// main session's own temporary key always is. The probe then reports "not removed" every time, and
/// a terminated session never logs out.
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

public func rustEngineRequiresForeignAuthToken(isMain: Bool, isCdn: Bool, datacenterId: Int, masterDatacenterId: Int) -> Bool {
    return !isMain && !isCdn && datacenterId != masterDatacenterId
}

/// Whether a session's clock becomes the app's (`MTContext.globalTimeDifference`). A CDN is run by a
/// third party and only serves encrypted file parts, so its time stays inside its own session: it
/// must not move auto-delete timers, outgoing dates or the clock other sessions start from.
public func rustEngineSharesTimeDifference(isCdn: Bool) -> Bool {
    return !isCdn
}

public func rustEngineSessionRole(isMain: Bool, isCdn: Bool, datacenterId: Int, masterDatacenterId: Int) -> RustEngineSessionRole {
    if isMain {
        return .main
    } else if isCdn {
        return .cdn
    } else if rustEngineRequiresForeignAuthToken(isMain: isMain, isCdn: isCdn, datacenterId: datacenterId, masterDatacenterId: masterDatacenterId) {
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
