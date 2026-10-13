import Foundation
import SwiftSignalKit
import MtProtoKit
import TelegramCore

final class RustNetworkEngine: NetworkEngine {
    let kind: NetworkEngineKind = .rust

    private let runtime: RustEngineRuntime
    private let context: MTContext
    private let serverPublicKeys: [String]
    private let httpPort: UInt16

    init(runtime: RustEngineRuntime, context: MTContext, serverPublicKeys: [String]? = nil, httpPort: UInt16 = 80) {
        self.runtime = runtime
        self.context = context
        self.serverPublicKeys = serverPublicKeys ?? MTDatacenterAuthDefaultPublicKeys(!context.isTestingEnvironment)
        self.httpPort = httpPort
    }

    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        return RustNetworkSession(runtime: self.runtime, context: self.context, datacenterId: datacenterId, role: role, usageCalculationInfo: usageCalculationInfo, delegate: delegate, serverPublicKeys: self.serverPublicKeys, httpPort: self.httpPort)
    }
}

/// Supplies the Rust MTProto engine (`third-party/mtproto-engine`) to `NetworkInitializationArguments`.
///
/// Declines (the network then stays on MtProtoKit) in app extensions, when the engine library
/// cannot start, and for configurations the engine cannot carry yet: a WEB proxy and developer
/// datacenter address overrides.
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
