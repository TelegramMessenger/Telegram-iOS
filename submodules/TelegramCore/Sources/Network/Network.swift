import Foundation
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

private struct MTProtoConnectionFlags: OptionSet {
    let rawValue: Int
    
    static let NetworkAvailable = MTProtoConnectionFlags(rawValue: 1)
    static let Connected = MTProtoConnectionFlags(rawValue: 2)
    static let UpdatingConnectionContext = MTProtoConnectionFlags(rawValue: 4)
    static let PerformingServiceTasks = MTProtoConnectionFlags(rawValue: 8)
    static let ProxyHasConnectionIssues = MTProtoConnectionFlags(rawValue: 16)
}

private struct MTProtoConnectionInfo: Equatable {
    var flags: MTProtoConnectionFlags
    var proxyAddress: String?
}

final class WrappedFunctionDescription: CustomStringConvertible {
    private let desc: FunctionDescription
    
    init(_ desc: FunctionDescription) {
        self.desc = desc
    }
    
    var description: String {
        return apiFunctionDescription(of: self.desc)
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
}

class WrappedRequestMetadata: NSObject {
    let metadata: CustomStringConvertible
    let tag: NetworkRequestDependencyTag?
    
    init(metadata: CustomStringConvertible, tag: NetworkRequestDependencyTag?) {
        self.metadata = metadata
        self.tag = tag
    }
    
    override var description: String {
        return self.metadata.description
    }
}

class WrappedRequestShortMetadata: NSObject {
    let shortMetadata: CustomStringConvertible
    
    init(shortMetadata: CustomStringConvertible) {
        self.shortMetadata = shortMetadata
    }
    
    override var description: String {
        return self.shortMetadata.description
    }
}

public protocol NetworkRequestDependencyTag {
    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool
}

private class MTProtoConnectionStatusDelegate: NSObject, MTProtoDelegate {
    var action: (MTProtoConnectionInfo) -> () = { _ in }
    let info = Atomic<MTProtoConnectionInfo>(value: MTProtoConnectionInfo(flags: [], proxyAddress: nil))
    
    @objc func mtProtoNetworkAvailabilityChanged(_ mtProto: MTProto!, isNetworkAvailable: Bool) {
        self.action(self.info.modify { info in
            var info = info
            if isNetworkAvailable {
                info.flags = info.flags.union([.NetworkAvailable])
            } else {
                info.flags = info.flags.subtracting([.NetworkAvailable])
            }
            return info
        })
    }
    
    @objc func mtProtoConnectionStateChanged(_ mtProto: MTProto!, state: MTProtoConnectionState!) {
        self.action(self.info.modify { info in
            var info = info
            if let state = state {
                if state.isConnected {
                    info.flags.insert(.Connected)
                    info.flags.remove(.ProxyHasConnectionIssues)
                } else {
                    info.flags.remove(.Connected)
                    if state.proxyHasConnectionIssues {
                        info.flags.insert(.ProxyHasConnectionIssues)
                    } else {
                        info.flags.remove(.ProxyHasConnectionIssues)
                    }
                }
            } else {
                info.flags.remove(.Connected)
                info.flags.remove(.ProxyHasConnectionIssues)
            }
            info.proxyAddress = state?.proxyAddress
            return info
        })
    }
    
    @objc func mtProtoConnectionContextUpdateStateChanged(_ mtProto: MTProto!, isUpdatingConnectionContext: Bool) {
        self.action(self.info.modify { info in
            var info = info
            if isUpdatingConnectionContext {
                info.flags = info.flags.union([.UpdatingConnectionContext])
            } else {
                info.flags = info.flags.subtracting([.UpdatingConnectionContext])
            }
            return info
        })
    }
    
    @objc func mtProtoServiceTasksStateChanged(_ mtProto: MTProto!, isPerformingServiceTasks: Bool) {
        self.action(self.info.modify { info in
            var info = info
            if isPerformingServiceTasks {
                info.flags = info.flags.union([.PerformingServiceTasks])
            } else {
                info.flags = info.flags.subtracting([.PerformingServiceTasks])
            }
            return info
        })
    }
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
    public let generic: NetworkUsageStatsConnectionsEntry
    public let image: NetworkUsageStatsConnectionsEntry
    public let video: NetworkUsageStatsConnectionsEntry
    public let audio: NetworkUsageStatsConnectionsEntry
    public let file: NetworkUsageStatsConnectionsEntry
    public let call: NetworkUsageStatsConnectionsEntry
    
    public let resetWifiTimestamp: Int32
    public let resetCellularTimestamp: Int32
    
    public static func ==(lhs: NetworkUsageStats, rhs: NetworkUsageStats) -> Bool {
        return lhs.generic == rhs.generic && lhs.image == rhs.image && lhs.video == rhs.video && lhs.audio == rhs.audio && lhs.file == rhs.file && lhs.call == rhs.call && lhs.resetWifiTimestamp == rhs.resetWifiTimestamp && lhs.resetCellularTimestamp == rhs.resetCellularTimestamp
    }
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
            UsageCalculationTag(connection: .wifi, direction: .outgoing, category: .call)
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
    public let autolockDeadine: Signal<Int32?, NoError>
    public let encryptionProvider: EncryptionProvider
    public let resolvedDeviceName:[String: String]?
    public init(apiId: Int32, apiHash: String, languagesCategory: String, appVersion: String, voipMaxLayer: Int32, voipVersions: [CallSessionManagerImplementationVersion], appData: Signal<Data?, NoError>, autolockDeadine: Signal<Int32?, NoError>, encryptionProvider: EncryptionProvider, resolvedDeviceName:[String: String]?) {
        self.apiId = apiId
        self.apiHash = apiHash
        self.languagesCategory = languagesCategory
        self.appVersion = appVersion
        self.voipMaxLayer = voipMaxLayer
        self.voipVersions = voipVersions
        self.appData = appData
        self.autolockDeadine = autolockDeadine
        self.encryptionProvider = encryptionProvider
        self.resolvedDeviceName = resolvedDeviceName
    }
}
#if os(iOS)
private let cloudDataContext = Atomic<CloudDataContext?>(value: nil)
#endif

func initializedNetwork(accountId: AccountRecordId, arguments: NetworkInitializationArguments, supplementary: Bool, datacenterId: Int, keychain: Keychain, basePath: String, testingEnvironment: Bool, languageCode: String?, proxySettings: ProxySettings?, networkSettings: NetworkSettings?, phoneNumber: String?) -> Signal<Network, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        queue.async {
            let _ = registeredLoggingFunctions
            
            let serialization = Serialization()
            
            var apiEnvironment = MTApiEnvironment(resolvedDeviceName: arguments.resolvedDeviceName)
            
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
            if #available(iOS 10.0, *), !supplementary {
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
                context.setDiscoverBackupAddressListSignal(MTBackupAddressSignals.fetchBackupIps(testingEnvironment, currentContext: context, additionalSource: wrappedAdditionalSource, phoneNumber: phoneNumber))
            }
            
            /*#if DEBUG
            context.beginExplicitBackupAddressDiscovery()
            #endif*/
            
            let mtProto = MTProto(context: context, datacenterId: datacenterId, usageCalculationInfo: usageCalculationInfo(basePath: basePath, category: nil), requiredAuthToken: nil, authTokenMasterDatacenterId: 0)!
            mtProto.useTempAuthKeys = context.useTempAuthKeys
            mtProto.checkForProxyConnectionIssues = true
            
            let connectionStatus = Promise<ConnectionStatus>(.waitingForNetwork)
            
            let requestService = MTRequestMessageService(context: context)!
            let connectionStatusDelegate = MTProtoConnectionStatusDelegate()
            connectionStatusDelegate.action = { [weak connectionStatus] info in
                if info.flags.contains(.Connected) {
                    if !info.flags.intersection([.UpdatingConnectionContext, .PerformingServiceTasks]).isEmpty {
                        connectionStatus?.set(.single(.updating(proxyAddress: info.proxyAddress)))
                    } else {
                        connectionStatus?.set(.single(.online(proxyAddress: info.proxyAddress)))
                    }
                } else {
                    if !info.flags.contains(.NetworkAvailable) {
                        connectionStatus?.set(.single(ConnectionStatus.waitingForNetwork))
                    } else if !info.flags.contains(.Connected) {
                        connectionStatus?.set(.single(.connecting(proxyAddress: info.proxyAddress, proxyHasConnectionIssues: info.flags.contains(.ProxyHasConnectionIssues))))
                    } else if !info.flags.intersection([.UpdatingConnectionContext, .PerformingServiceTasks]).isEmpty {
                        connectionStatus?.set(.single(.updating(proxyAddress: info.proxyAddress)))
                    } else {
                        connectionStatus?.set(.single(.online(proxyAddress: info.proxyAddress)))
                    }
                }
            }
            mtProto.delegate = connectionStatusDelegate
            mtProto.add(requestService)
            
            let network = Network(queue: queue, datacenterId: datacenterId, context: context, mtProto: mtProto, requestService: requestService, connectionStatusDelegate: connectionStatusDelegate, _connectionStatus: connectionStatus, basePath: basePath, appDataDisposable: appDataDisposable, encryptionProvider: arguments.encryptionProvider)
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

public final class Network: NSObject, MTRequestMessageServiceDelegate {
    public let encryptionProvider: EncryptionProvider
    
    private let queue: Queue
    public let datacenterId: Int
    public let context: MTContext
    let mtProto: MTProto
    let requestService: MTRequestMessageService
    let basePath: String
    private let connectionStatusDelegate: MTProtoConnectionStatusDelegate
    
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
    
    public func dropConnectionStatus() {
        _connectionStatus.set(.single(.waitingForNetwork))
    }
    
    public let shouldKeepConnection = Promise<Bool>(false)
    private let shouldKeepConnectionDisposable = MetaDisposable()
    
    public let shouldExplicitelyKeepWorkerConnections = Promise<Bool>(false)
    public let shouldKeepBackgroundDownloadConnections = Promise<Bool>(false)
    
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
    
    fileprivate init(queue: Queue, datacenterId: Int, context: MTContext, mtProto: MTProto, requestService: MTRequestMessageService, connectionStatusDelegate: MTProtoConnectionStatusDelegate, _connectionStatus: Promise<ConnectionStatus>, basePath: String, appDataDisposable: Disposable, encryptionProvider: EncryptionProvider) {
        self.encryptionProvider = encryptionProvider
        
        self.queue = queue
        self.datacenterId = datacenterId
        self.context = context
        self._contextProxyId = ValuePromise((context.apiEnvironment.socksProxySettings as MTSocksProxySettings?).flatMap(NetworkContextProxyId.init(settings:)), ignoreRepeated: true)
        self.mtProto = mtProto
        self.requestService = requestService
        self.connectionStatusDelegate = connectionStatusDelegate
        self._connectionStatus = _connectionStatus
        self.appDataDisposable = appDataDisposable
        self.basePath = basePath
        
        super.init()
        
        self.requestService.didReceiveSoftAuthResetError = { [weak self] in
            self?.didReceiveSoftAuthResetError?()
        }
        
        let _contextProxyId = self._contextProxyId
        context.add(NetworkHelper(requestPublicKeys: { [weak self] id in
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
                            case let .cdnConfig(publicKeys):
                                for key in publicKeys {
                                    switch key {
                                        case let .cdnPublicKey(dcId, publicKey):
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
        }))
        requestService.delegate = self
        
        self._multiplexedRequestManager = MultiplexedRequestManager(takeWorker: { [weak self] target, tag, continueInBackground in
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
                return strongSelf.makeWorker(datacenterId: datacenterId, isCdn: isCdn, isMedia: isMedia, tag: tag, continueInBackground: continueInBackground)
            }
            return nil
        })
        
        let shouldKeepConnectionSignal = self.shouldKeepConnection.get()
            |> distinctUntilChanged |> deliverOn(queue)
        self.shouldKeepConnectionDisposable.set(shouldKeepConnectionSignal.start(next: { [weak self] value in
            if let strongSelf = self {
                if value {
                    Logger.shared.log("Network", "Resume network connection")
                    strongSelf.mtProto.resume()
                } else {
                    Logger.shared.log("Network", "Pause network connection")
                    strongSelf.mtProto.pause()
                }
            }
        }))
    }
    
    deinit {
        self.shouldKeepConnectionDisposable.dispose()
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
    
    public func requestMessageServiceAuthorizationRequired(_ requestMessageService: MTRequestMessageService!) {
        Logger.shared.log("Network", "requestMessageServiceAuthorizationRequired")
        self.loggedOut?()
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
        return Download(queue: self.queue, datacenterId: datacenterId, isMedia: isMedia, isCdn: isCdn, context: self.context, masterDatacenterId: self.datacenterId, usageInfo: usageCalculationInfo(basePath: self.basePath, category: (tag as? TelegramMediaResourceFetchTag)?.statsCategory), shouldKeepConnection: shouldKeepWorkerConnection)
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
    
    public func requestWithAdditionalInfo<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), info: NetworkRequestAdditionalInfo, tag: NetworkRequestDependencyTag? = nil, automaticFloodWait: Bool = true) -> Signal<NetworkRequestResult<T>, MTRpcError> {
        let requestService = self.requestService
        return Signal { subscriber in
            let request = MTRequest()
            
            request.setPayload(data.1.makeData() as Data, metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: tag), shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)), responseParser: { response in
                if let result = data.2.parse(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
            request.shouldContinueExecutionWithErrorContext = { errorContext in
                guard let errorContext = errorContext else {
                    return true
                }
                if errorContext.floodWaitSeconds > 0 && !automaticFloodWait {
                    return false
                }
                return true
            }
            
            request.acknowledgementReceived = {
                if info.contains(.acknowledgement) {
                    subscriber.putNext(.acknowledged)
                }
            }
            
            request.progressUpdated = { progress, packetSize in
                if info.contains(.progress) {
                    subscriber.putNext(.progress(progress, Int32(clamping: packetSize)))
                }
            }
            
            request.completed = { (boxedResponse, timestamp, error) -> () in
                if let error = error {
                    subscriber.putError(error)
                } else {
                    if let result = (boxedResponse as! BoxedMessage).body as? T {
                        subscriber.putNext(.result(result))
                        subscriber.putCompletion()
                    }
                    else {
                        subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                    }
                }
            }
            
            if let tag = tag {
                request.shouldDependOnRequest = { other in
                    if let other = other, let metadata = other.metadata as? WrappedRequestMetadata, let otherTag = metadata.tag {
                        return tag.shouldDependOn(other: otherTag)
                    }
                    return false
                }
            }
            
            let internalId: Any! = request.internalId
            
            requestService.add(request)
            
            return ActionDisposable { [weak requestService] in
                requestService?.removeRequest(byInternalId: internalId)
            }
        }
    }
        
    public func request<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), tag: NetworkRequestDependencyTag? = nil, automaticFloodWait: Bool = true) -> Signal<T, MTRpcError> {
        let requestService = self.requestService
        return Signal { subscriber in
            let request = MTRequest()
            
            request.setPayload(data.1.makeData() as Data, metadata: WrappedRequestMetadata(metadata: WrappedFunctionDescription(data.0), tag: tag), shortMetadata: WrappedRequestShortMetadata(shortMetadata: WrappedShortFunctionDescription(data.0)), responseParser: { response in
                if let result = data.2.parse(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
            request.shouldContinueExecutionWithErrorContext = { errorContext in
                guard let errorContext = errorContext else {
                    return true
                }
                if errorContext.floodWaitSeconds > 0 && !automaticFloodWait {
                    return false
                }
                return true
            }
            
            request.completed = { (boxedResponse, timestamp, error) -> () in
                if let error = error {
                    subscriber.putError(error)
                } else {
                    if let result = (boxedResponse as! BoxedMessage).body as? T {
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                    }
                    else {
                        subscriber.putError(MTRpcError(errorCode: 500, errorDescription: "TL_VERIFICATION_ERROR"))
                    }
                }
            }
            
            if let tag = tag {
                request.shouldDependOnRequest = { other in
                    if let other = other, let metadata = other.metadata as? WrappedRequestMetadata, let otherTag = metadata.tag {
                        return tag.shouldDependOn(other: otherTag)
                    }
                    return false
                }
            }
            
            let internalId: Any! = request.internalId
            
            requestService.add(request)
            
            return ActionDisposable { [weak requestService] in
                requestService?.removeRequest(byInternalId: internalId)
            }
        }
    }
}

public func retryRequest<T>(signal: Signal<T, MTRpcError>) -> Signal<T, NoError> {
    return signal
    |> retry(0.2, maxDelay: 5.0, onQueue: Queue.concurrentDefaultQueue())
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
            let data = NSKeyedArchiver.archivedData(withRootObject: object)
            self.set(group + ":" + aKey, data)
        })
    }
    
    func object(forKey aKey: String!, group: String!) -> Any! {
        guard let aKey = aKey, let group = group else {
            return nil
        }
        if let data = self.get(group + ":" + aKey) {
            var result: Any?
            MTContext.perform(objCTry: {
                result = NSKeyedUnarchiver.unarchiveObject(with: data as Data)
            })
            return result
        }
        return nil
    }
    
    func removeObject(forKey aKey: String!, group: String!) {
        self.remove(group + ":" + aKey)
    }
    
    func dropGroup(_ group: String!) {
        
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
