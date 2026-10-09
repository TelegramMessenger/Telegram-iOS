import Foundation
import SwiftSignalKit
import MtProtoKit
import TelegramCore
import MTProtoRustEngineMapping

final class RustNetworkEngine: NetworkEngine {
    let kind: NetworkEngineKind = .rust

    private let runtime: RustEngineRuntime
    private let context: MTContext
    private let serverPublicKeys: [String]
    private let httpPort: UInt16
    private let actions: RustEngineActions
    private let mainDatacenterIds = Atomic<Set<Int>>(value: Set())

    init(runtime: RustEngineRuntime, context: MTContext, serverPublicKeys: [String]? = nil, httpPort: UInt16 = 80) {
        self.runtime = runtime
        self.context = context
        let serverPublicKeys: [String] = serverPublicKeys ?? MTDatacenterAuthDefaultPublicKeys(!context.isTestingEnvironment)
        self.serverPublicKeys = serverPublicKeys
        self.httpPort = httpPort
        self.actions = RustEngineActions(runtime: runtime, context: context, serverPublicKeys: serverPublicKeys, httpPort: httpPort)
    }

    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        if case .main = role {
            let _ = self.mainDatacenterIds.modify { $0.union([datacenterId]) }
        }
        return RustNetworkSession(runtime: self.runtime, context: self.context, datacenterId: datacenterId, role: role, usageCalculationInfo: usageCalculationInfo, delegate: delegate, serverPublicKeys: self.serverPublicKeys, httpPort: self.httpPort)
    }

    /// The salted name of the network the device is on (`RustNetworkIdentity`), hex.
    func networkIdentity() -> String? {
        let key = RustNetworkIdentity.currentKey()
        if key.isEmpty {
            return nil
        }
        return key.map { String(format: "%02x", $0) }.joined()
    }

    /// Permanent keys, the logout check and authorization transfers of the context go over this engine.
    func activate() {
        self.actions.install()
    }

    /// The network moves to another engine (`SwitchingNetworkEngine`). Besides the context's actions,
    /// the temporary key this engine's main sessions made and kept in the context for their datacenter
    /// goes: the main session that replaces one while it drains makes a key of its own, so that two main
    /// sessions of the account never talk under one temporary key (the plan's AUTH_KEY_DUPLICATED risk).
    /// The draining session keeps using its copy in the engine.
    func deactivate() {
        self.actions.uninstall()
        let context = self.context
        for datacenterId in self.mainDatacenterIds.with({ $0 }) {
            context.performBatchUpdates {
                guard let stored = context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain), rustEngineMadeTemporaryKey(attributes: stored.authKeyAttributes) else {
                    return
                }
                rustEngineImportantLog("[MTProtoRust] the engine's temporary key \(stored.authKeyId) for dc\(datacenterId) leaves the context with the engine")
                context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: nil, selector: .ephemeralMain)
            }
        }
    }
}

/// Supplies the Rust MTProto engine (`third-party/mtproto-engine`) to `NetworkInitializationArguments`.
///
/// Declines (the network then stays on MtProtoKit) in app extensions, when the engine library
/// cannot start, and for the one configuration the engine cannot carry yet: developer datacenter
/// address overrides. A WEB proxy is carried through `WebProxyTransport`'s raw streams.
public struct RustNetworkEngineFactory: NetworkEngineFactory {
    public init() {
    }

    public var supportsWebProxy: Bool {
        return true
    }

    public func makeEngine(context: MTContext, isAppExtension: Bool) -> NetworkEngine? {
        if isAppExtension {
            rustEngineImportantLog("[MTProtoRust] declined: app extension")
            return nil
        }
        let apiEnvironment = context.apiEnvironment
        if let overrides = apiEnvironment.datacenterAddressOverrides, !overrides.isEmpty {
            rustEngineImportantLog("[MTProtoRust] declined: datacenter address overrides are not supported")
            return nil
        }
        guard let runtime = RustEngineRuntime.shared else {
            rustEngineImportantLog("[MTProtoRust] declined: engine is unavailable")
            return nil
        }
        return RustNetworkEngine(runtime: runtime, context: context)
    }
}
