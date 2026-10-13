import Foundation
import WebProxyTransport
import Postbox
import TelegramApi
import SwiftSignalKit
import MtProtoKit
import NetworkLogging

#if os(iOS)
    import CloudData
#endif

import EncryptionProvider

public enum ConnectionStatus: Equatable {
    case waitingForNetwork
    case connecting(proxyAddress: String?, proxyHasConnectionIssues: Bool)
    case updating(proxyAddress: String?)
    case online(proxyAddress: String?)
}

public func legacy_unarchiveDeprecated(data: Data) -> Any? {
    return MTDeprecated.unarchiveDeprecated(with: data)
}

final class WrappedFunctionDescription: CustomStringConvertible {
    private let desc: FunctionDescription
    
    init(_ desc: FunctionDescription) {
        self.desc = desc
    }
    
    var description: String {
        return apiFunctionDescription(of: self.desc)
    }
    
    var name: String {
        return self.desc.name
    }
}

final class WrappedShortFunctionDescription: CustomStringConvertible {
    private let desc: FunctionDescription
    
    init(_ desc: FunctionDescription) {
        self.desc = desc
    }
    
    var description: String {
        return apiShortFunctionDescription(of: self.desc)
    }
    
    var name: String {
        return self.desc.name
    }
}

public class WrappedRequestMetadata: NSObject {
    let metadata: CustomStringConvertible
    let tag: NetworkRequestDependencyTag?
    
    init(metadata: CustomStringConvertible, tag: NetworkRequestDependencyTag?) {
        self.metadata = metadata
        self.tag = tag
    }
    
    override public var description: String {
        return self.metadata.description
    }
}

public class WrappedRequestShortMetadata: NSObject {
    let shortMetadata: CustomStringConvertible
    
    init(shortMetadata: CustomStringConvertible) {
        self.shortMetadata = shortMetadata
    }
    
    override public var description: String {
        return self.shortMetadata.description
    }
    
    /// The API method name alone, without parameters, or nil when the request is not an API function.
    var functionName: String? {
        if let value = self.shortMetadata as? WrappedShortFunctionDescription {
            return value.name
        } else if let value = self.shortMetadata as? WrappedFunctionDescription {
            return value.name
        } else {
            return nil
        }
    }
}

public protocol NetworkRequestDependencyTag {
    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool
}

private var registeredLoggingFunctions: Void = {
    NetworkRegisterLoggingFunction()
    registerLoggingFunctions()
}()

private enum UsageCalculationConnection: Int32 {
    case cellular = 0
    case wifi = 1
}

private enum UsageCalculationDirection: Int32 {
    case incoming = 0
    case outgoing = 1
}

private struct UsageCalculationTag {
    let connection: UsageCalculationConnection
    let direction: UsageCalculationDirection
    let category: MediaResourceStatsCategory
    
    var key: Int32 {
        switch category {
            case .generic:
                return 0 * 4 + self.connection.rawValue * 2 + self.direction.rawValue * 1
            case .image:
                return 1 * 4 + self.connection.rawValue * 2 + self.direction.rawValue * 1
            case .video:
                return 2 * 4 + self.connection.rawValue * 2 + self.direction.rawValue * 1
            case .audio:
                return 3 * 4 + self.connection.rawValue * 2 + self.direction.rawValue * 1
            case .file:
                return 4 * 4 + self.connection.rawValue * 2 + self.direction.rawValue * 1
            case .call:
                return 5 * 4 + self.connection.rawValue * 2 + self.direction.rawValue * 1
            case .stickers:
                return 6 * 4 + self.connection.rawValue * 2 + self.direction.rawValue * 1
            case .voiceMessages:
                return 7 * 4 + self.connection.rawValue * 2 + self.direction.rawValue * 1
        }
    }
}

private enum UsageCalculationResetKey: Int32 {
    case wifi = 80 //20 * 4 + 0
    case cellular = 81 //20 * 4 + 2
}

private func usageCalculationInfo(basePath: String, category: MediaResourceStatsCategory?) -> MTNetworkUsageCalculationInfo {
    let categoryValue: MediaResourceStatsCategory
    if let category = category {
        categoryValue = category
    } else {
        categoryValue = .generic
    }
    return MTNetworkUsageCalculationInfo(filePath: basePath + "/network-stats", incomingWWANKey: UsageCalculationTag(connection: .cellular, direction: .incoming, category: categoryValue).key, outgoingWWANKey: UsageCalculationTag(connection: .cellular, direction: .outgoing, category: categoryValue).key, incomingOtherKey: UsageCalculationTag(connection: .wifi, direction: .incoming, category: categoryValue).key, outgoingOtherKey: UsageCalculationTag(connection: .wifi, direction: .outgoing, category: categoryValue).key)
}

public struct NetworkUsageStatsDirectionsEntry: Equatable {
    public let incoming: Int64
    public let outgoing: Int64
    
    public init(incoming: Int64, outgoing: Int64) {
        self.incoming = incoming
        self.outgoing = outgoing
    }
    
    public static func ==(lhs: NetworkUsageStatsDirectionsEntry, rhs: NetworkUsageStatsDirectionsEntry) -> Bool {
        return lhs.incoming == rhs.incoming && lhs.outgoing == rhs.outgoing
    }
}

public struct NetworkUsageStatsConnectionsEntry: Equatable {
    public let cellular: NetworkUsageStatsDirectionsEntry
    public let wifi: NetworkUsageStatsDirectionsEntry
    
    public init(cellular: NetworkUsageStatsDirectionsEntry, wifi: NetworkUsageStatsDirectionsEntry) {
        self.cellular = cellular
        self.wifi = wifi
    }
    
    public static func ==(lhs: NetworkUsageStatsConnectionsEntry, rhs: NetworkUsageStatsConnectionsEntry) -> Bool {
        return lhs.cellular == rhs.cellular && lhs.wifi == rhs.wifi
    }
}

public struct NetworkUsageStats: Equatable {
    public var generic: NetworkUsageStatsConnectionsEntry
    public var image: NetworkUsageStatsConnectionsEntry
    public var video: NetworkUsageStatsConnectionsEntry
    public var audio: NetworkUsageStatsConnectionsEntry
    public var file: NetworkUsageStatsConnectionsEntry
    public var call: NetworkUsageStatsConnectionsEntry
    public var sticker: NetworkUsageStatsConnectionsEntry
    public var voiceMessage: NetworkUsageStatsConnectionsEntry
    
    public var resetWifiTimestamp: Int32
    public var resetCellularTimestamp: Int32
}

public struct ResetNetworkUsageStats: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let wifi = ResetNetworkUsageStats(rawValue: 1 << 0)
    public static let cellular = ResetNetworkUsageStats(rawValue: 1 << 1)
}

private func interfaceForConnection(_ connection: UsageCalculationConnection) -> MTNetworkUsageManagerInterface {
    return MTNetworkUsageManagerInterface(rawValue: UInt32(connection.rawValue))
}

func updateNetworkUsageStats(basePath: String, category: MediaResourceStatsCategory, delta: NetworkUsageStatsConnectionsEntry) {
    let info = usageCalculationInfo(basePath: basePath, category: category)
    let manager = MTNetworkUsageManager(info: info)!
    
    manager.addIncomingBytes(UInt(clamping: delta.wifi.incoming), interface: interfaceForConnection(.wifi))
    manager.addOutgoingBytes(UInt(clamping: delta.wifi.outgoing), interface: interfaceForConnection(.wifi))
    
    manager.addIncomingBytes(UInt(clamping: delta.cellular.incoming), interface: interfaceForConnection(.cellular))
    manager.addOutgoingBytes(UInt(clamping: delta.cellular.outgoing), interface: interfaceForConnection(.cellular))
}

func networkUsageStats(basePath: String, reset: ResetNetworkUsageStats) -> Signal<NetworkUsageStats, NoError> {
    return ((Signal<NetworkUsageStats, NoError> { subscriber in
        let info = usageCalculationInfo(basePath: basePath, category: nil)
        let manager = MTNetworkUsageManager(info: info)!
        
        let rawKeys: [UsageCalculationTag] = [
            UsageCalculationTag(connection: .cellular, direction: .incoming, category: .generic),
            UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .generic),
            UsageCalculationTag(connection: .wifi, direction: .incoming, category: .generic),
            UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .generic),
            
            UsageCalculationTag(connection: .cellular, direction: .incoming, category: .image),
            UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .image),
            UsageCalculationTag(connection: .wifi, direction: .incoming, category: .image),
            UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .image),
            
            UsageCalculationTag(connection: .cellular, direction: .incoming, category: .video),
            UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .video),
            UsageCalculationTag(connection: .wifi, direction: .incoming, category: .video),
            UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .video),
            
            UsageCalculationTag(connection: .cellular, direction: .incoming, category: .audio),
            UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .audio),
            UsageCalculationTag(connection: .wifi, direction: .incoming, category: .audio),
            UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .audio),
            
            UsageCalculationTag(connection: .cellular, direction: .incoming, category: .file),
            UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .file),
            UsageCalculationTag(connection: .wifi, direction: .incoming, category: .file),
            UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .file),
            
            UsageCalculationTag(connection: .cellular, direction: .incoming, category: .call),
            UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .call),
            UsageCalculationTag(connection: .wifi, direction: .incoming, category: .call),
            UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .call),
            
            UsageCalculationTag(connection: .cellular, direction: .incoming, category: .stickers),
            UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .stickers),
            UsageCalculationTag(connection: .wifi, direction: .incoming, category: .stickers),
            UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .stickers),
            
            UsageCalculationTag(connection: .cellular, direction: .incoming, category: .voiceMessages),
            UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .voiceMessages),
            UsageCalculationTag(connection: .wifi, direction: .incoming, category: .voiceMessages),
            UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .voiceMessages)
        ]
        
        var keys: [NSNumber] = rawKeys.map { $0.key as NSNumber }
        
        var resetKeys: [NSNumber] = []
        var resetAddKeys: [NSNumber: NSNumber] = [:]
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if reset.contains(.wifi) {
            resetKeys += rawKeys.filter({ $0.connection == .wifi }).map({ $0.key as NSNumber })
            resetAddKeys[UsageCalculationResetKey.wifi.rawValue as NSNumber] = Int64(timestamp) as NSNumber
        }
        if reset.contains(.cellular) {
            resetKeys += rawKeys.filter({ $0.connection == .cellular }).map({ $0.key as NSNumber })
            resetAddKeys[UsageCalculationResetKey.cellular.rawValue as NSNumber] = Int64(timestamp) as NSNumber
        }
        if !resetKeys.isEmpty {
            manager.resetKeys(resetKeys, setKeys: resetAddKeys, completion: {})
        }
        keys.append(UsageCalculationResetKey.cellular.rawValue as NSNumber)
        keys.append(UsageCalculationResetKey.wifi.rawValue as NSNumber)
        
        let disposable = manager.currentStats(forKeys: keys).start(next: { next in
            var dict: [Int32: Int64] = [:]
            for key in keys {
                dict[key.int32Value] = 0
            }
            (next as! NSDictionary).enumerateKeysAndObjects({ key, value, _ in
                dict[(key as! NSNumber).int32Value] = (value as! NSNumber).int64Value
            })
            subscriber.putNext(NetworkUsageStats(
                generic: NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .cellular, direction: .incoming, category: .generic).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .generic).key]!),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .wifi, direction: .incoming, category: .generic).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .generic).key]!)),
                image: NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .cellular, direction: .incoming, category: .image).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .image).key]!),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .wifi, direction: .incoming, category: .image).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .image).key]!)),
                video: NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .cellular, direction: .incoming, category: .video).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .video).key]!),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .wifi, direction: .incoming, category: .video).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .video).key]!)),
                audio: NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .cellular, direction: .incoming, category: .audio).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .audio).key]!),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .wifi, direction: .incoming, category: .audio).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .audio).key]!)),
                file: NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .cellular, direction: .incoming, category: .file).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .file).key]!),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .wifi, direction: .incoming, category: .file).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .file).key]!)),
                call: NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .cellular, direction: .incoming, category: .call).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .call).key]!),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .wifi, direction: .incoming, category: .call).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .call).key]!)),
                sticker: NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .cellular, direction: .incoming, category: .stickers).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .stickers).key]!),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .wifi, direction: .incoming, category: .stickers).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .stickers).key]!)),
                voiceMessage: NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .cellular, direction: .incoming, category: .voiceMessages).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .cellular, direction: .outgoing, category: .voiceMessages).key]!),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: dict[UsageCalculationTag(connection: .wifi, direction: .incoming, category: .voiceMessages).key]!,
                        outgoing: dict[UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .voiceMessages).key]!)),
                resetWifiTimestamp: Int32(dict[UsageCalculationResetKey.wifi.rawValue]!),
                resetCellularTimestamp: Int32(dict[UsageCalculationResetKey.cellular.rawValue]!)
            ))
        })!
        return ActionDisposable {
            disposable.dispose()
        }
    }) |> then(Signal<NetworkUsageStats, NoError>.complete() |> delay(5.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

public struct NetworkInitializationArguments {
    public let apiId: Int32
    public let apiHash: String
    public let languagesCategory: String
    public let appVersion: String
    public let voipMaxLayer: Int32
    public let voipVersions: [CallSessionManagerImplementationVersion]
    public let appData: Signal<Data?, NoError>
    public let externalRequestVerificationStream: Signal<[String: String], NoError>
    public let externalRecaptchaRequestVerification: (String, String) -> Signal<String?, NoError>
    public let autolockDeadine: Signal<Int32?, NoError>
    public let encryptionProvider: EncryptionProvider
    public let deviceModelName: String?
    public let useBetaFeatures: Bool
    public let isICloudEnabled: Bool
    public let networkEngineFactory: NetworkEngineFactory?
    
    public init(apiId: Int32, apiHash: String, languagesCategory: String, appVersion: String, voipMaxLayer: Int32, voipVersions: [CallSessionManagerImplementationVersion], appData: Signal<Data?, NoError>, externalRequestVerificationStream: Signal<[String: String], NoError>, externalRecaptchaRequestVerification: @escaping (String, String) -> Signal<String?, NoError>, autolockDeadine: Signal<Int32?, NoError>, encryptionProvider: EncryptionProvider, deviceModelName: String?, useBetaFeatures: Bool, isICloudEnabled: Bool, networkEngineFactory: NetworkEngineFactory? = nil) {
        self.apiId = apiId
        self.apiHash = apiHash
        self.languagesCategory = languagesCategory
        self.appVersion = appVersion
        self.voipMaxLayer = voipMaxLayer
        self.voipVersions = voipVersions
        self.appData = appData
        self.externalRequestVerificationStream = externalRequestVerificationStream
        self.externalRecaptchaRequestVerification = externalRecaptchaRequestVerification
        self.autolockDeadine = autolockDeadine
        self.encryptionProvider = encryptionProvider
        self.deviceModelName = deviceModelName
        self.useBetaFeatures = useBetaFeatures
        self.isICloudEnabled = isICloudEnabled
        self.networkEngineFactory = networkEngineFactory
    }
}
#if os(iOS)
private let cloudDataContext = Atomic<CloudDataContext?>(value: nil)
#endif

func networkEngineRustDisabled(appConfiguration: AppConfiguration) -> Bool {
    guard let data = appConfiguration.data, let value = data["mtproto_engine_rust_disabled"] else {
        return false
    }
    switch value {
    case let value as Bool:
        return value
    case let value as Double:
        return value != 0.0
    case let value as String:
        return !["", "0", "false", "no"].contains(value.lowercased())
    case is NSNull:
        return false
    default:
        return true
    }
}

private func resolveNetworkEngine(accountId: AccountRecordId, context: MTContext, factory: NetworkEngineFactory?, settings: NetworkEngineSettings?, appConfiguration: AppConfiguration, isAppExtension: Bool) -> NetworkEngine {
    let preferredEngine = settings?.engine ?? NetworkEngineSettings.defaultSettings.engine
    guard let factory = factory else {
        Logger.shared.log("Network", "Account \(accountId.int64): engine mtProtoKit (no factory, preferred \(preferredEngine.rawValue))")
        return MtProtoKitEngine(context: context)
    }
    if networkEngineRustDisabled(appConfiguration: appConfiguration) {
        Logger.shared.log("Network", "Account \(accountId.int64): engine mtProtoKit (mtproto_engine_rust_disabled, preferred \(preferredEngine.rawValue))")
        return MtProtoKitEngine(context: context)
    }
    switch preferredEngine {
    case .mtProtoKit:
        Logger.shared.log("Network", "Account \(accountId.int64): engine mtProtoKit")
        return MtProtoKitEngine(context: context)
    case .rust:
        if let engine = factory.makeEngine(context: context, isAppExtension: isAppExtension) {
            Logger.shared.log("Network", "Account \(accountId.int64): engine \(engine.kind.rawValue)")
            return engine
        } else {
            Logger.shared.log("Network", "Account \(accountId.int64): engine mtProtoKit (factory declined rust)")
            return MtProtoKitEngine(context: context)
        }
    }
}

private final class NetworkMainSessionDelegate: NetworkEngineSessionDelegate {
    private weak var connectionStatus: Promise<ConnectionStatus>?
    weak var network: Network?
    
    init(connectionStatus: Promise<ConnectionStatus>) {
        self.connectionStatus = connectionStatus
    }
    
    func networkSessionConnectionStateChanged(_ state: NetworkEngineConnectionState) {
        let connectionStatus = self.connectionStatus
        if state.isConnected {
            if state.isUpdatingConnectionContext || state.isPerformingServiceTasks {
                connectionStatus?.set(.single(.updating(proxyAddress: state.proxyAddress)))
            } else {
                connectionStatus?.set(.single(.online(proxyAddress: state.proxyAddress)))
            }
        } else {
            if !state.isNetworkAvailable {
                connectionStatus?.set(.single(ConnectionStatus.waitingForNetwork))
            } else if !state.isConnected {
                connectionStatus?.set(.single(.connecting(proxyAddress: state.proxyAddress, proxyHasConnectionIssues: state.proxyHasConnectionIssues)))
            } else if state.isUpdatingConnectionContext || state.isPerformingServiceTasks {
                connectionStatus?.set(.single(.updating(proxyAddress: state.proxyAddress)))
            } else {
                connectionStatus?.set(.single(.online(proxyAddress: state.proxyAddress)))
            }
        }
    }
    
    func networkSessionAuthorizationRequired() {
        self.network?.mainSessionAuthorizationRequired()
    }
    
    func networkSessionSoftAuthReset() {
        self.network?.didReceiveSoftAuthResetError?()
    }
}

func initializedNetwork(accountId: AccountRecordId, arguments: NetworkInitializationArguments, supplementary: Bool, datacenterId: Int, keychain: Keychain, basePath: String, testingEnvironment: Bool, languageCode: String?, proxySettings: ProxySettings?, networkSettings: NetworkSettings?, networkEngineSettings: NetworkEngineSettings?, phoneNumber: String?, useRequestTimeoutTimers: Bool, appConfiguration: AppConfiguration) -> Signal<Network, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        queue.async {
            let _ = registeredLoggingFunctions
            
            let serialization = Serialization()
            
            var apiEnvironment = MTApiEnvironment(deviceModelName: arguments.deviceModelName)
            
            apiEnvironment.apiId = arguments.apiId
            apiEnvironment.langPack = arguments.languagesCategory
            apiEnvironment.layer = NSNumber(value: Int(serialization.currentLayer()))
            apiEnvironment.disableUpdates = supplementary
            apiEnvironment = apiEnvironment.withUpdatedLangPackCode(languageCode ?? "en")
            
            if let effectiveActiveServer = proxySettings?.effectiveActiveServer {
                apiEnvironment = apiEnvironment.withUpdatedSocksProxySettings(effectiveActiveServer.mtProxySettings)
            }
            
            apiEnvironment = apiEnvironment.withUpdatedNetworkSettings((networkSettings ?? NetworkSettings.defaultSettings).mtNetworkSettings)
            apiEnvironment.accessHostOverride = networkSettings?.backupHostOverride
            
            var appDataUpdatedImpl: ((Data?) -> Void)?
            let syncValue = Atomic<Data?>(value: nil)
            let appDataDisposable = (arguments.appData
            |> deliverOn(queue)).start(next: { value in
                let _ = syncValue.swap(value)
                appDataUpdatedImpl?(value)
            })
            if let currentAppData = syncValue.swap(Data()) {
                if let jsonData = JSON(data: currentAppData) {
                    if let value = apiJson(jsonData) {
                        let buffer = Buffer()
                        value.serialize(buffer, true)
                        apiEnvironment = apiEnvironment.withUpdatedSystemCode(buffer.makeData())
                    }
                }
            }
            
            let useTempAuthKeys: Bool = true
            
            let context = MTContext(serialization: serialization, encryptionProvider: arguments.encryptionProvider, apiEnvironment: apiEnvironment, isTestingEnvironment: testingEnvironment, useTempAuthKeys: useTempAuthKeys)
            context.refreshesTemporaryKeys = !supplementary
            
            if let networkSettings = networkSettings {
                let useNetworkFramework: Bool
                if let customValue = networkSettings.useNetworkFramework {
                    useNetworkFramework = customValue
                } else if arguments.useBetaFeatures {
                    useNetworkFramework = true
                } else {
                    useNetworkFramework = false
                }
                
                if useNetworkFramework {
                    if #available(iOS 12.0, macOS 14.0, *) {
                        context.makeTcpConnectionInterface = { delegate, delegateQueue in
                            return NetworkFrameworkTcpConnectionInterface(delegate: delegate, delegateQueue: delegateQueue)
                        }
                    }
                }
            }

            let baseTcpConnectionInterfaceFactory = context.makeTcpConnectionInterface
            let isAppExtension = Bundle.main.bundlePath.hasSuffix(".appex")
            let initialActiveServer = proxySettings?.effectiveActiveServer
            let initialWebProxyConfiguration = initialActiveServer?.webProxyConfiguration
            WebProxyTransport.shared.apply(configuration: isAppExtension ? nil : initialWebProxyConfiguration)
            if initialActiveServer?.isWebProxy == true {
                context.makeTcpConnectionInterface = { delegate, delegateQueue in
                    return WebProxyTransport.shared.makeConnectionInterface(delegate: delegate, delegateQueue: delegateQueue)
                }
            }
            
            let seedAddressList: [Int: [String]]
            
            if testingEnvironment {
                seedAddressList = [
                    1: ["149.154.175.10"],
                    2: ["149.154.167.40"],
                    3: ["149.154.175.117"]
                ]
            } else {
                seedAddressList = [
                    1: ["149.154.175.50", "2001:b28:f23d:f001::a"],
                    2: ["149.154.167.50", "95.161.76.100", "2001:67c:4e8:f002::a"],
                    3: ["149.154.175.100", "2001:b28:f23d:f003::a"],
                    4: ["149.154.167.91", "2001:67c:4e8:f004::a"],
                    5: ["149.154.171.5", "2001:b28:f23f:f005::a"]
                ]
            }
            
            for (id, ips) in seedAddressList {
                context.setSeedAddressSetForDatacenterWithId(id, seedAddressSet: MTDatacenterAddressSet(addressList: ips.map { MTDatacenterAddress(ip: $0, port: 443, preferForMedia: false, restrictToTcp: false, cdn: false, preferForProxy: false, secret: nil) }))
            }
            
            context.keychain = keychain
            var wrappedAdditionalSource: MTSignal?
            #if os(iOS)
            if #available(iOS 10.0, *), !supplementary, arguments.isICloudEnabled {
                var cloudDataContextValue: CloudDataContext?
                if let value = cloudDataContext.with({ $0 }) {
                    cloudDataContextValue = value
                } else {
                    cloudDataContextValue = makeCloudDataContext(encryptionProvider: arguments.encryptionProvider)
                    let _ = cloudDataContext.swap(cloudDataContextValue)
                }
                
                if let cloudDataContext = cloudDataContextValue {
                    wrappedAdditionalSource = MTSignal(generator: { subscriber in
                        let disposable = cloudDataContext.get(phoneNumber: .single(phoneNumber)).start(next: { value in
                            subscriber?.putNext(value)
                        }, completed: {
                            subscriber?.putCompletion()
                        })
                        return MTBlockDisposable(block: {
                            disposable.dispose()
                        })
                    })
                }
            }
            #endif
            
            if !supplementary {
                context.setDiscoverBackupAddressListSignal(MTBackupAddressSignals.fetchBackupIps(testingEnvironment, currentContext: context, additionalSource: wrappedAdditionalSource, phoneNumber: phoneNumber, mainDatacenterId: datacenterId))
                let externalRequestVerificationStream = arguments.externalRequestVerificationStream
                context.setExternalRequestVerification({ nonce in
                    return MTSignal(generator: { subscriber in
                        let disposable = (externalRequestVerificationStream
                        |> map { dict -> String? in
                            return dict[nonce]
                        }
                        |> filter { $0 != nil }
                        |> take(1)
                        |> timeout(15.0, queue: .mainQueue(), alternate: .single("APNS_PUSH_TIMEOUT"))).start(next: { secret in
                            subscriber?.putNext(secret)
                            subscriber?.putCompletion()
                        })
                        
                        return MTBlockDisposable(block: {
                            disposable.dispose()
                        })
                    })
                })
                let externalRecaptchaRequestVerification = arguments.externalRecaptchaRequestVerification
                context.setExternalRecaptchaRequestVerification({ method, siteKey in
                    return MTSignal(generator: { subscriber in
                        let disposable = (externalRecaptchaRequestVerification(method, siteKey)
                        |> filter { $0 != nil }
                        |> take(1)
                        |> timeout(15.0, queue: .mainQueue(), alternate: .single("RECAPTCHA_TIMEOUT"))).start(next: { token in
                            subscriber?.putNext(token)
                            subscriber?.putCompletion()
                        })
                        
                        return MTBlockDisposable(block: {
                            disposable.dispose()
                        })
                    })
                })
            }
            
            /*#if DEBUG
            context.beginExplicitBackupAddressDiscovery()
            #endif*/
            
            let resolvedEngine = resolveNetworkEngine(accountId: accountId, context: context, factory: arguments.networkEngineFactory, settings: networkEngineSettings, appConfiguration: appConfiguration, isAppExtension: isAppExtension)
            let rustEngineDisabled = networkEngineRustDisabled(appConfiguration: appConfiguration)
            // Live engine switching (the server kill switch, a WEB proxy turned on and off) is macOS only.
            // On iOS the engine changes only through the Debug Settings switch, at the next launch: no
            // wrapper is created, so switchEngine/disableRustEngine have nothing to act on and the
            // network runs the resolved engine directly, exactly as without a factory.
            #if os(macOS)
            let prefersRustEngine = (networkEngineSettings?.engine ?? NetworkEngineSettings.defaultSettings.engine) == .rust
            let rustEngineWaitsForWebProxy = arguments.networkEngineFactory != nil && !rustEngineDisabled && resolvedEngine.kind == .mtProtoKit && prefersRustEngine && initialActiveServer?.isWebProxy == true && arguments.networkEngineFactory?.supportsWebProxy != true
            // Live switching only ever moves a network off Rust, or back to Rust after a WEB proxy, so it
            // is needed only while Rust is in play; otherwise MtProtoKit runs directly.
            let switchingEngine = arguments.networkEngineFactory != nil && (resolvedEngine.kind == .rust || rustEngineWaitsForWebProxy) ? SwitchingNetworkEngine(engine: resolvedEngine) : nil
            #else
            let rustEngineWaitsForWebProxy = false
            let switchingEngine: SwitchingNetworkEngine? = nil
            #endif
            let telemetryDirectory = basePath + "/network-telemetry"
            let telemetryConfiguration = NetworkTelemetryConfiguration.with(appConfiguration: appConfiguration)
            let telemetry: NetworkTelemetry?
            if networkTelemetryShouldRecord(supplementary: supplementary, isAppExtension: isAppExtension, configuration: telemetryConfiguration) {
                telemetry = NetworkTelemetry.shared(directory: telemetryDirectory, layer: Int32(serialization.currentLayer()), app: arguments.appVersion, system: networkTelemetrySystemVersion(), variant: telemetryConfiguration.variant, stalledAfter: networkTelemetryOverrides.stalledAfter ?? NetworkTelemetry.stalledAfter, watchEvery: networkTelemetryOverrides.watchEvery ?? NetworkTelemetry.watchEvery)
            } else {
                telemetry = nil
                if !supplementary && !isAppExtension {
                    Queue.concurrentBackgroundQueue().async {
                        try? FileManager.default.removeItem(atPath: telemetryDirectory)
                    }
                }
            }
            let engine: NetworkEngine = telemetry.flatMap { RecordingNetworkEngine(engine: switchingEngine ?? resolvedEngine, telemetry: $0) } ?? switchingEngine ?? resolvedEngine
            
            let connectionStatus = Promise<ConnectionStatus>(.waitingForNetwork)
            
            let mainSessionDelegate = NetworkMainSessionDelegate(connectionStatus: connectionStatus)
            let mainSession = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: usageCalculationInfo(basePath: basePath, category: nil), delegate: mainSessionDelegate)
            
            var useExperimentalFeatures = networkSettings?.useExperimentalDownload ?? true
            if let data = appConfiguration.data, let _ = data["ios_killswitch_disable_downloadv2"] {
                useExperimentalFeatures = false
            }
            
            let network = Network(queue: queue, datacenterId: datacenterId, context: context, engine: engine, switchingEngine: switchingEngine, engineFactory: arguments.networkEngineFactory, rustEngineDisabled: rustEngineDisabled, rustEngineWaitsForWebProxy: rustEngineWaitsForWebProxy, mainSession: mainSession, mainSessionDelegate: mainSessionDelegate, telemetry: telemetry, _connectionStatus: connectionStatus, basePath: basePath, appDataDisposable: appDataDisposable, encryptionProvider: arguments.encryptionProvider, useRequestTimeoutTimers: useRequestTimeoutTimers, useBetaFeatures: arguments.useBetaFeatures, useExperimentalFeatures: useExperimentalFeatures, baseTcpConnectionInterfaceFactory: baseTcpConnectionInterfaceFactory, isAppExtension: isAppExtension, initialWebProxyActive: initialActiveServer?.isWebProxy == true)
            
            if let data = appConfiguration.data, let notifyInterval = data["upload_premium_speedup_notify_period"] as? Double {
                network.updateNetworkSpeedLimitedEventNotifyInterval(value: notifyInterval)
            }
            
            appDataUpdatedImpl = { [weak network] data in
                guard let data = data else {
                    return
                }
                guard let jsonData = JSON(data: data) else {
                    return
                }
                guard let value = apiJson(jsonData) else {
                    return
                }
                let buffer = Buffer()
                value.serialize(buffer, true)
                let systemCode = buffer.makeData()
                
                network?.context.updateApiEnvironment { environment in
                    let current = environment?.systemCode
                    let updateNetwork: Bool
                    if let current = current {
                        updateNetwork = systemCode != current
                    } else {
                        updateNetwork = true
                    }
                    if updateNetwork {
                        return environment?.withUpdatedSystemCode(systemCode)
                    } else {
                        return nil
                    }
                }
            }
            subscriber.putNext(network)
            subscriber.putCompletion()
        }
        
        return EmptyDisposable
    }
}

private final class NetworkHelper: NSObject, MTContextChangeListener {
    private let requestPublicKeys: (Int) -> Signal<NSArray, NoError>
    private let isContextNetworkAccessAllowedImpl: () -> Signal<Bool, NoError>
    private let contextProxyIdUpdated: (NetworkContextProxyId?) -> Void
    private let contextLoggedOutUpdated: () -> Void
    
    init(requestPublicKeys: @escaping (Int) -> Signal<NSArray, NoError>, isContextNetworkAccessAllowed: @escaping () -> Signal<Bool, NoError>, contextProxyIdUpdated: @escaping (NetworkContextProxyId?) -> Void, contextLoggedOutUpdated: @escaping () -> Void) {
        self.requestPublicKeys = requestPublicKeys
        self.isContextNetworkAccessAllowedImpl = isContextNetworkAccessAllowed
        self.contextProxyIdUpdated = contextProxyIdUpdated
        self.contextLoggedOutUpdated = contextLoggedOutUpdated
    }
    
    deinit {
    }
    
    func fetchContextDatacenterPublicKeys(_ context: MTContext, datacenterId: Int) -> MTSignal {
        return MTSignal { subscriber in
            let disposable = self.requestPublicKeys(datacenterId).start(next: { next in
                subscriber?.putNext(next)
                subscriber?.putCompletion()
            })
            
            return MTBlockDisposable(block: {
                disposable.dispose()
            })
        }
    }
    
    func isContextNetworkAccessAllowed(_ context: MTContext) -> MTSignal {
        return MTSignal { subscriber in
            let disposable = self.isContextNetworkAccessAllowedImpl().start(next: { next in
                subscriber?.putNext(next as NSNumber)
                subscriber?.putCompletion()
            })
            
            return MTBlockDisposable(block: {
                disposable.dispose()
            })
        }
    }
    
    func contextApiEnvironmentUpdated(_ context: MTContext, apiEnvironment: MTApiEnvironment) {
        let settings: MTSocksProxySettings? = apiEnvironment.socksProxySettings
        self.contextProxyIdUpdated(settings.flatMap(NetworkContextProxyId.init(settings:)))
    }
    
    func contextLoggedOut(_ context: MTContext) {
        self.contextLoggedOutUpdated()
    }
}

struct NetworkContextProxyId: Equatable {
    private let ip: String
    private let port: Int
    private let secret: Data
}

private extension NetworkContextProxyId {
    init?(settings: MTSocksProxySettings) {
        if let secret = settings.secret, !secret.isEmpty {
            self.init(ip: settings.ip, port: Int(settings.port), secret: secret)
        } else {
            return nil
        }
    }
}

public struct NetworkRequestAdditionalInfo: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let acknowledgement = NetworkRequestAdditionalInfo(rawValue: 1 << 0)
    public static let progress = NetworkRequestAdditionalInfo(rawValue: 1 << 1)
}

public enum NetworkRequestResult<T> {
    case result(T)
    case acknowledged
    case progress(Float, Int32)
}

private final class NetworkSpeedLimitedEventState {
    var notifyInterval: Double = 60.0 * 60.0
    var lastNotifyTimestamp: Double = 0.0
    
    func add(event: NetworkSpeedLimitedEvent) -> Bool {
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        if self.lastNotifyTimestamp + self.notifyInterval < timestamp {
            return true
        } else {
            return false
        }
    }
    
    func markNotifyTimestamp() {
        let timestamp = CFAbsoluteTimeGetCurrent()
        self.lastNotifyTimestamp = timestamp
    }
}

public final class Network: NSObject {
    public let encryptionProvider: EncryptionProvider
    
    private let queue: Queue
    public let datacenterId: Int
    public let context: MTContext
    private var networkHelper: NetworkHelper?
    private let engine: NetworkEngine
    private let switchingEngine: SwitchingNetworkEngine?
    private let engineFactory: NetworkEngineFactory?
    private let rustEngineDisabled: Atomic<Bool>
    private let rustEngineWaitsForWebProxy: Atomic<Bool>
    let mainSession: NetworkEngineSession
    let requestService: NetworkEngineRequestService
    let basePath: String
    private let mainSessionDelegate: NetworkMainSessionDelegate
    /// Records requests and failures of every session, whichever engine runs them. Nil unless
    /// `network_telemetry_enabled` was set when the network started (always set in Debug builds).
    public let telemetry: NetworkTelemetry?
    private let useRequestTimeoutTimers: Bool
    private let baseTcpConnectionInterfaceFactory: ((MTTcpConnectionInterfaceDelegate, DispatchQueue) -> MTTcpConnectionInterface)?
    private let isAppExtension: Bool
    private let webProxyLeaseToken = UUID()
    private let webProxyActive: ValuePromise<Bool>
    private let webProxyCarrierDemandDisposable = MetaDisposable()
    public let useBetaFeatures: Bool
    public let useExperimentalFeatures: Bool
    
    private let appDataDisposable: Disposable
    
    private var _multiplexedRequestManager: MultiplexedRequestManager?
    var multiplexedRequestManager: MultiplexedRequestManager {
        return self._multiplexedRequestManager!
    }
    
    private let _contextProxyId: ValuePromise<NetworkContextProxyId?>
    var contextProxyId: Signal<NetworkContextProxyId?, NoError> {
        return self._contextProxyId.get()
    }
    
    private let _connectionStatus: Promise<ConnectionStatus>
    public var connectionStatus: Signal<ConnectionStatus, NoError> {
        return self._connectionStatus.get() |> distinctUntilChanged
    }
    
    public var networkSpeedLimitedEvents: Signal<NetworkSpeedLimitedEvent, NoError> {
        return self.networkSpeedLimitedEventPipe.signal()
    }
    private let networkSpeedLimitedEventPipe = ValuePipe<NetworkSpeedLimitedEvent>()
    private let networkSpeedLimitedEventState = Atomic<NetworkSpeedLimitedEventState>(value: NetworkSpeedLimitedEventState())
    
    public func dropConnectionStatus() {
        _connectionStatus.set(.single(.waitingForNetwork))
    }
    
    public let shouldKeepConnection = Promise<Bool>(false)
    private let shouldKeepConnectionDisposable = MetaDisposable()
    
    public let shouldExplicitelyKeepWorkerConnections = Promise<Bool>(false)
    public let shouldKeepBackgroundDownloadConnections = Promise<Bool>(false)

    /// The user is actively using this account: the app is in the foreground and this is the
    /// primary account (`Account.shouldKeepOnlinePresence`). Forwarded to every session through
    /// `NetworkEngineSession.setOnline`, which engines use to choose keepalive timing.
    public let isUserOnline = Promise<Bool>(false)
    private let isUserOnlineDisposable = MetaDisposable()
    
    public var mockConnectionStatus: ConnectionStatus? {
        didSet {
            if let mockConnectionStatus = self.mockConnectionStatus {
                self._connectionStatus.set(.single(mockConnectionStatus))
            }
        }
    }
    
    var loggedOut: (() -> Void)?
    var didReceiveSoftAuthResetError: (() -> Void)?
    
    override public var description: String {
        return "Network context: \(self.context)"
    }
    
    public var engineKind: NetworkEngineKind {
        return self.engine.kind
    }
    
    fileprivate init(queue: Queue, datacenterId: Int, context: MTContext, engine: NetworkEngine, switchingEngine: SwitchingNetworkEngine?, engineFactory: NetworkEngineFactory?, rustEngineDisabled: Bool, rustEngineWaitsForWebProxy: Bool, mainSession: NetworkEngineSession, mainSessionDelegate: NetworkMainSessionDelegate, telemetry: NetworkTelemetry?, _connectionStatus: Promise<ConnectionStatus>, basePath: String, appDataDisposable: Disposable, encryptionProvider: EncryptionProvider, useRequestTimeoutTimers: Bool, useBetaFeatures: Bool, useExperimentalFeatures: Bool, baseTcpConnectionInterfaceFactory: ((MTTcpConnectionInterfaceDelegate, DispatchQueue) -> MTTcpConnectionInterface)?, isAppExtension: Bool, initialWebProxyActive: Bool) {
        self.encryptionProvider = encryptionProvider
        
        self.queue = queue
        self.datacenterId = datacenterId
        self.context = context
        self._contextProxyId = ValuePromise((context.apiEnvironment.socksProxySettings as MTSocksProxySettings?).flatMap(NetworkContextProxyId.init(settings:)), ignoreRepeated: true)
        self.engine = engine
        self.switchingEngine = switchingEngine
        self.engineFactory = engineFactory
        self.rustEngineDisabled = Atomic(value: rustEngineDisabled)
        self.rustEngineWaitsForWebProxy = Atomic(value: rustEngineWaitsForWebProxy)
        self.mainSession = mainSession
        self.requestService = mainSession.requestService
        self.mainSessionDelegate = mainSessionDelegate
        self.telemetry = telemetry
        self._connectionStatus = _connectionStatus
        self.appDataDisposable = appDataDisposable
        self.basePath = basePath
        self.useRequestTimeoutTimers = useRequestTimeoutTimers
        self.baseTcpConnectionInterfaceFactory = baseTcpConnectionInterfaceFactory
        self.isAppExtension = isAppExtension
        self.webProxyActive = ValuePromise<Bool>(initialWebProxyActive, ignoreRepeated: true)
        self.useBetaFeatures = useBetaFeatures
        self.useExperimentalFeatures = useExperimentalFeatures
        
        super.init()
        
        mainSessionDelegate.network = self
        
        let _contextProxyId = self._contextProxyId
        let networkHelper = NetworkHelper(requestPublicKeys: { [weak self] id in
            if let strongSelf = self {
                return strongSelf.request(Api.functions.help.getCdnConfig())
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.CdnConfig?, NoError> in
                    return .single(nil)
                }
                |> map { result -> NSArray in
                    let array = NSMutableArray()
                    if let result = result {
                        switch result {
                        case let .cdnConfig(cdnConfigData):
                            let publicKeys = cdnConfigData.publicKeys
                            for key in publicKeys {
                                switch key {
                                case let .cdnPublicKey(cdnPublicKeyData):
                                    let (dcId, publicKey) = (cdnPublicKeyData.dcId, cdnPublicKeyData.publicKey)
                                    if id == Int(dcId) {
                                        let dict = NSMutableDictionary()
                                        dict["key"] = publicKey
                                        dict["fingerprint"] = MTRsaFingerprint(encryptionProvider, publicKey)
                                        array.add(dict)
                                    }
                                }
                            }
                        }
                    }
                    return array
                }
            } else {
                return .never()
            }
        }, isContextNetworkAccessAllowed: { [weak self] in
            if let strongSelf = self {
                return strongSelf.shouldKeepConnection.get() |> distinctUntilChanged
            } else {
                return .single(false)
            }
        }, contextProxyIdUpdated: { value in
            _contextProxyId.set(value)
        }, contextLoggedOutUpdated: { [weak self] in
            Logger.shared.log("Network", "contextLoggedOut")
            self?.loggedOut?()
        })
        self.networkHelper = networkHelper
        context.add(networkHelper)
        
        let fastDownloads = engine.kind == .rust
        self._multiplexedRequestManager = MultiplexedRequestManager(cdnMaxRequestsPerWorker: fastDownloads ? 4 : 3, cdnMaxWorkersPerTarget: fastDownloads ? 8 : 4, takeWorker: { [weak self] target, tag, continueInBackground in
            if let strongSelf = self {
                let datacenterId: Int
                let isCdn: Bool
                let isMedia: Bool = true
                switch target {
                case let .main(id):
                    datacenterId = id
                    isCdn = false
                case let .cdn(id):
                    datacenterId = id
                    isCdn = true
                }
                if datacenterId != 0 {
                    return strongSelf.makeWorker(datacenterId: datacenterId, isCdn: isCdn, isMedia: isMedia, tag: tag, continueInBackground: continueInBackground)
                } else {
                    return nil
                }
            }
            return nil
        })
        
        let shouldKeepConnectionSignal = self.shouldKeepConnection.get()
        |> distinctUntilChanged |> deliverOn(queue)
        self.shouldKeepConnectionDisposable.set(shouldKeepConnectionSignal.start(next: { [weak self] value in
            if let strongSelf = self {
                if value {
                    Logger.shared.log("Network", "Resume network connection")
                    strongSelf.mainSession.setPaused(false)
                } else {
                    Logger.shared.log("Network", "Pause network connection")
                    strongSelf.mainSession.setPaused(true)
                }
            }
        }))

        self.isUserOnlineDisposable.set((self.isUserOnline.get() |> distinctUntilChanged |> deliverOn(queue)).start(next: { [weak self] value in
            self?.mainSession.setOnline(value)
        }))

        // The carrier runs exactly while MTProto does. SharedWakeupManager already folds
        // foreground state, audio sessions, background extensions, processing tasks and the
        // explicit-extension grace timer into shouldBeServiceTaskMaster, which reaches us as
        // shouldKeepConnection - so riding it inherits every grace window that machinery
        // implements, without a background mode or a timer of our own.
        let webProxyCarrierDemand = combineLatest(queue: queue, self.webProxyActive.get(), self.shouldKeepConnection.get())
        |> map { active, keepConnection -> Bool in
            return active && keepConnection
        }
        |> distinctUntilChanged
        let leaseToken = self.webProxyLeaseToken
        let leaseIsAppExtension = self.isAppExtension
        self.webProxyCarrierDemandDisposable.set(webProxyCarrierDemand.start(next: { wanted in
            WebProxyTransport.shared.setCarrierDemand(leaseToken, wanted: wanted && !leaseIsAppExtension)
        }))
    }

    func updateProxySettings(_ activeServer: ProxyServerSettings?) {
        let webConfiguration = activeServer?.webProxyConfiguration
        WebProxyTransport.shared.apply(configuration: self.isAppExtension ? nil : webConfiguration)
        self.webProxyActive.set(activeServer?.isWebProxy == true)
        if activeServer?.isWebProxy == true {
            self.context.makeTcpConnectionInterface = { delegate, delegateQueue in
                return WebProxyTransport.shared.makeConnectionInterface(delegate: delegate, delegateQueue: delegateQueue)
            }
        } else {
            self.context.makeTcpConnectionInterface = self.baseTcpConnectionInterfaceFactory
        }

        let updated = activeServer?.mtProxySettings
        self.context.updateApiEnvironment { environment in
            let current = environment?.socksProxySettings
            let updateNetwork: Bool
            if let current, let updated {
                updateNetwork = !current.isEqual(updated)
            } else {
                updateNetwork = (current != nil) != (updated != nil)
            }
            if updateNetwork {
                self.dropConnectionStatus()
                return environment?.withUpdatedSocksProxySettings(updated)
            } else {
                return nil
            }
        }
        if activeServer?.isWebProxy == true {
            if self.engineKind == .rust && self.engineFactory?.supportsWebProxy != true && self.switchEngine(to: .mtProtoKit, reason: "WEB proxy") {
                let _ = self.rustEngineWaitsForWebProxy.swap(true)
            }
        } else if self.rustEngineWaitsForWebProxy.swap(false) {
            self.switchEngine(to: .rust, reason: "WEB proxy turned off")
        }
    }
    
    deinit {
        self.shouldKeepConnectionDisposable.dispose()
        self.isUserOnlineDisposable.dispose()
        self.webProxyCarrierDemandDisposable.dispose()
        WebProxyTransport.shared.setCarrierDemand(self.webProxyLeaseToken, wanted: false)
        self.appDataDisposable.dispose()
    }
    
    public var globalTime: TimeInterval {
        return self.context.globalTime()
    }
    
    public var globalTimeDifference: TimeInterval {
        return self.context.globalTimeDifference()
    }
    
    public var currentGlobalTime: Signal<Double, NoError> {
        return Signal { subscriber in
            self.context.performBatchUpdates({
                subscriber.putNext(self.context.globalTime())
                subscriber.putCompletion()
            })
            return EmptyDisposable
        }
    }
    
    public var isRustEngineDisabled: Bool {
        return self.rustEngineDisabled.with { $0 }
    }

    public func disableRustEngine(reason: String) {
        let _ = self.rustEngineDisabled.swap(true)
        let _ = self.rustEngineWaitsForWebProxy.swap(false)
        self.switchEngine(to: .mtProtoKit, reason: reason)
    }

    @discardableResult
    public func switchEngine(to kind: NetworkEngineKind, reason: String) -> Bool {
        guard let switchingEngine = self.switchingEngine else {
            return kind == self.engine.kind
        }
        if kind == .rust && self.rustEngineDisabled.with({ $0 }) {
            Logger.shared.log("Network", "Engine switch to rust refused, the server disabled it: \(reason)")
            return false
        }
        let context = self.context
        let engineFactory = self.engineFactory
        let isAppExtension = self.isAppExtension
        return switchingEngine.switchEngine(to: kind, drainTimeout: 5.0, makeEngine: {
            let replacement: NetworkEngine?
            switch kind {
            case .mtProtoKit:
                replacement = MtProtoKitEngine(context: context)
            case .rust:
                replacement = engineFactory?.makeEngine(context: context, isAppExtension: isAppExtension)
            }
            if replacement == nil {
                Logger.shared.log("Network", "Engine switch to \(kind.rawValue) declined: \(reason)")
            } else {
                Logger.shared.log("Network", "Switching the engine to \(kind.rawValue): \(reason)")
            }
            return replacement
        })
    }

    fileprivate func mainSessionAuthorizationRequired() {
        Logger.shared.log("Network", "requestMessageServiceAuthorizationRequired")
        self.loggedOut?()
    }
    
    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        self.mainSession.addUpdateSink(sink)
    }
    
    func download(datacenterId: Int, isMedia: Bool, isCdn: Bool = false, tag: MediaResourceFetchTag?) -> Signal<Download, NoError> {
        return self.worker(datacenterId: datacenterId, isCdn: isCdn, isMedia: isMedia, tag: tag)
    }
    
    func upload(tag: MediaResourceFetchTag?) -> Signal<Download, NoError> {
        return self.worker(datacenterId: self.datacenterId, isCdn: false, isMedia: false, tag: tag)
    }
    
    func background() -> Signal<Download, NoError> {
        return self.worker(datacenterId: self.datacenterId, isCdn: false, isMedia: false, tag: nil)
    }
    
    private func makeWorker(datacenterId: Int, isCdn: Bool, isMedia: Bool, tag: MediaResourceFetchTag?, continueInBackground: Bool = false) -> Download {
        let queue = Queue.mainQueue()
        let shouldKeepWorkerConnection: Signal<Bool, NoError> = combineLatest(queue: queue, self.shouldKeepConnection.get(), self.shouldExplicitelyKeepWorkerConnections.get(), self.shouldKeepBackgroundDownloadConnections.get())
        |> map { shouldKeepConnection, shouldExplicitelyKeepWorkerConnections, shouldKeepBackgroundDownloadConnections -> Bool in
            return shouldKeepConnection || shouldExplicitelyKeepWorkerConnections || (continueInBackground && shouldKeepBackgroundDownloadConnections)
        }
        |> distinctUntilChanged
        return Download(queue: self.queue, engine: self.engine, datacenterId: datacenterId, isMedia: isMedia, isCdn: isCdn, context: self.context, masterDatacenterId: self.datacenterId, usageInfo: usageCalculationInfo(basePath: self.basePath, category: (tag as? TelegramMediaResourceFetchTag)?.statsCategory), shouldKeepConnection: shouldKeepWorkerConnection, isUserOnline: self.isUserOnline.get(), useRequestTimeoutTimers: self.useRequestTimeoutTimers)
    }
    
    private func worker(datacenterId: Int, isCdn: Bool, isMedia: Bool, tag: MediaResourceFetchTag?) -> Signal<Download, NoError> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext(strongSelf.makeWorker(datacenterId: datacenterId, isCdn: isCdn, isMedia: isMedia, tag: tag))
            }
            subscriber.putCompletion()
            
            return ActionDisposable {
                
            }
        }
    }
    
    public func getApproximateRemoteTimestamp() -> Int32 {
        return Int32(self.context.globalTime())
    }
    
    public func mergeBackupDatacenterAddress(datacenterId: Int32, host: String, port: Int32, secret: Data?) {
        self.context.performBatchUpdates {
            let address = MTDatacenterAddress(ip: host, port: UInt16(port), preferForMedia: false, restrictToTcp: false, cdn: false, preferForProxy: false, secret: secret)
            self.context.addAddressForDatacenter(withId: Int(datacenterId), address: address)
            
            /*let currentScheme = self.context.transportSchemeForDatacenter(withId: Int(datacenterId), media: false, isProxy: false)
             if let currentScheme = currentScheme, currentScheme.address.isEqual(to: address) {
             } else {
             let scheme = MTTransportScheme(transport: MTTcpTransport.self, address: address, media: false)
             self.context.updateTransportSchemeForDatacenter(withId: Int(datacenterId), transportScheme: scheme, media: false, isProxy: false)
             }*/
            
            let currentSchemes = self.context.transportSchemesForDatacenter(withId: Int(datacenterId), media: false, enforceMedia: false, isProxy: false)
            var found = false
            for scheme in currentSchemes {
                if scheme.address.isEqual(to: address) {
                    found = true
                    break
                }
            }
            if !found {
                let scheme = MTTransportScheme(transport: MTTcpTransport.self, address: address, media: false)
                self.context.updateTransportSchemeForDatacenter(withId: Int(datacenterId), transportScheme: scheme, media: false, isProxy: false)
            }
        }
    }
    
    public func getAuthKeyId() -> Signal<Int64, NoError> {
        let mtContext = self.context
        let datacenterId = self.datacenterId
        return Signal { subscriber in
            MTContext.contextQueue().dispatch(onQueue: {
                var result: Int64 = 0
                if let authInfo = mtContext.authInfoForDatacenter(withId: datacenterId, selector: .persistent) {
                    result = authInfo.authKeyId
                }
                subscriber.putNext(result)
            })
            
            return EmptyDisposable
        }
    }
    
    public func requestWithAdditionalInfo<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), info: NetworkRequestAdditionalInfo, tag: NetworkRequestDependencyTag? = nil, automaticFloodWait: Bool = true, onFloodWaitError: ((String) -> Void)? = nil) -> Signal<NetworkRequestResult<T>, MTRpcError> {
        let requestService = self.requestService
        return Signal { [requestService] subscriber in
            let request = NetworkEngineRequest(
                payload: data.1.makeData(),
                metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: tag),
                shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)),
                parse: { response in
                    if let result = data.2.parse(Buffer(data: response)) {
                        return BoxedMessage(result)
                    }
                    return nil
                },
                options: NetworkEngineRequestOptions(),
                shouldContinueAfterError: networkRequestErrorPolicy(automaticFloodWait: automaticFloodWait, onFloodWaitError: onFloodWaitError, failOnServerErrors: false),
                dependsOn: networkRequestDependency(tag: tag),
                acknowledged: {
                    if info.contains(.acknowledgement) {
                        subscriber.putNext(.acknowledged)
                    }
                },
                progress: { progress, packetSize in
                    if info.contains(.progress) {
                        subscriber.putNext(.progress(progress, Int32(clamping: packetSize)))
                    }
                },
                completed: { result in
                    switch result {
                    case let .success(response):
                        if let result = (response.result as! BoxedMessage).body as? T {
                            subscriber.putNext(.result(result))
                            subscriber.putCompletion()
                        }
                        else {
                            subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                        }
                    case let .failure(failure):
                        subscriber.putError(failure.error)
                    }
                }
            )
            
            return requestService.add(request)
        }
    }
    
    public func request<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), tag: NetworkRequestDependencyTag? = nil, automaticFloodWait: Bool = true, onFloodWaitError: ((String) -> Void)? = nil) -> Signal<T, MTRpcError> {
        let requestService = self.requestService
        return Signal { [requestService] subscriber in
            let request = NetworkEngineRequest(
                payload: data.1.makeData(),
                metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: tag),
                shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)),
                parse: { response in
                    if let result = data.2.parse(Buffer(data: response)) {
                        return BoxedMessage(result)
                    }
                    return nil
                },
                options: NetworkEngineRequestOptions(),
                shouldContinueAfterError: networkRequestErrorPolicy(automaticFloodWait: automaticFloodWait, onFloodWaitError: onFloodWaitError, failOnServerErrors: false),
                dependsOn: networkRequestDependency(tag: tag),
                acknowledged: nil,
                progress: nil,
                completed: { result in
                    switch result {
                    case let .success(response):
                        if let result = (response.result as! BoxedMessage).body as? T {
                            subscriber.putNext(result)
                            subscriber.putCompletion()
                        }
                        else {
                            subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                        }
                    case let .failure(failure):
                        subscriber.putError(failure.error)
                    }
                }
            )
            
            return requestService.add(request)
        }
    }
    
    func updateNetworkSpeedLimitedEventNotifyInterval(value: Double) {
        let _ = self.networkSpeedLimitedEventState.with { state in
            state.notifyInterval = value
        }
    }
    
    func addNetworkSpeedLimitedEvent(event: NetworkSpeedLimitedEvent) {
        let notify = self.networkSpeedLimitedEventState.with { state in
            return state.add(event: event)
        }
        if notify {
            self.networkSpeedLimitedEventPipe.putNext(event)
        }
    }
    
    public func markNetworkSpeedLimitDisplayed() {
        self.networkSpeedLimitedEventState.with { state in
            return state.markNotifyTimestamp()
        }
    }
}

func networkRequestErrorPolicy(automaticFloodWait: Bool, onFloodWaitError: ((String) -> Void)?, failOnServerErrors: Bool) -> (NetworkEngineErrorContext) -> Bool {
    return { errorContext in
        if let onFloodWaitError, errorContext.floodWaitSeconds > 0, let errorText = errorContext.floodWaitErrorText {
            onFloodWaitError(errorText)
        }
        if errorContext.floodWaitSeconds > 0 && !automaticFloodWait {
            return false
        }
        if errorContext.internalServerErrorCount > 0 && failOnServerErrors {
            return false
        }
        return true
    }
}

private func networkRequestDependency(tag: NetworkRequestDependencyTag?) -> ((WrappedRequestMetadata) -> Bool)? {
    guard let tag = tag else {
        return nil
    }
    return { metadata in
        if let otherTag = metadata.tag {
            return tag.shouldDependOn(other: otherTag)
        }
        return false
    }
}

public func retryRequest<T>(signal: Signal<T, MTRpcError>) -> Signal<T, NoError> {
    return signal
    |> retry(0.2, maxDelay: 5.0, onQueue: Queue.concurrentDefaultQueue())
}

public func retryRequestIfNotFrozen<T>(signal: Signal<T, MTRpcError>) -> Signal<T?, NoError> {
    return signal
    |> retry(retryOnError: { error in
        if error.errorDescription == "FROZEN_METHOD_INVALID" {
            return false
        }
        return true
    }, delayIncrement: 0.2, maxDelay: 5.0, maxRetries: nil, onQueue: .concurrentDefaultQueue())
    |> map(Optional.init)
    |> `catch` { _ in
        return .single(nil)
    }
}

class Keychain: NSObject, MTKeychain {
    let get: (String) -> Data?
    let set: (String, Data) -> Void
    let remove: (String) -> Void
    
    init(get: @escaping (String) -> Data?, set: @escaping (String, Data) -> Void, remove: @escaping (String) -> Void) {
        self.get = get
        self.set = set
        self.remove = remove
    }
    
    func setObject(_ object: Any!, forKey aKey: String!, group: String!) {
        guard let object = object else {
            return
        }
        MTContext.perform(objCTry: {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false) {
                self.set(group + ":" + aKey, data)
            }
        })
    }
    
    func dictionary(forKey aKey: String!, group: String!) -> [AnyHashable : Any]? {
        guard let aKey = aKey, let group = group else {
            return nil
        }
        if let data = self.get(group + ":" + aKey) {
            var result: NSDictionary?
            result = MTDeprecated.unarchiveDeprecated(with: data as Data) as? NSDictionary
            if let result = result {
                return result as? [AnyHashable : Any]
            }
            assertionFailure("Unexpected keychain entry type")
        }
        return nil
    }
    
    func number(forKey aKey: String!, group: String!) -> NSNumber? {
        guard let aKey = aKey, let group = group else {
            return nil
        }
        if let data = self.get(group + ":" + aKey) {
            var result: NSNumber?
            result = MTDeprecated.unarchiveDeprecated(with: data as Data) as? NSNumber
            if let result = result {
                return result
            }
            assertionFailure("Unexpected keychain entry type")
        }
        return nil
    }
    
    func removeObject(forKey aKey: String!, group: String!) {
        self.remove(group + ":" + aKey)
    }
}
#if os(iOS)
func makeCloudDataContext(encryptionProvider: EncryptionProvider) -> CloudDataContext? {
    if #available(iOS 10.0, *) {
        return CloudDataContextImpl(encryptionProvider: encryptionProvider)
    } else {
        return nil
    }
}
#endif
