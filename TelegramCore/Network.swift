import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif
import TelegramCorePrivateModule

public enum ConnectionStatus {
    case WaitingForNetwork
    case Connecting
    case Updating
    case Online
}

private struct MTProtoConnectionFlags: OptionSet {
    let rawValue: Int
    
    static let NetworkAvailable = MTProtoConnectionFlags(rawValue: 1)
    static let Connected = MTProtoConnectionFlags(rawValue: 2)
    static let UpdatingConnectionContext = MTProtoConnectionFlags(rawValue: 4)
    static let PerformingServiceTasks = MTProtoConnectionFlags(rawValue: 8)
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

public protocol NetworkRequestDependencyTag {
    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool
}

private class MTProtoConnectionStatusDelegate: NSObject, MTProtoDelegate {
    var action: (MTProtoConnectionFlags) -> () = { _ in }
    let state = Atomic<MTProtoConnectionFlags>(value: [])
    
    @objc func mtProtoNetworkAvailabilityChanged(_ mtProto: MTProto!, isNetworkAvailable: Bool) {
        self.action(self.state.modify { flags in
            if isNetworkAvailable {
                return flags.union([.NetworkAvailable])
            } else {
                return flags.subtracting([.NetworkAvailable])
            }
        })
    }
    
    @objc func mtProtoConnectionStateChanged(_ mtProto: MTProto!, isConnected: Bool) {
        self.action(self.state.modify { flags in
            if isConnected {
                return flags.union([.Connected])
            } else {
                return flags.subtracting([.Connected])
            }
        })
    }
    
    @objc func mtProtoConnectionContextUpdateStateChanged(_ mtProto: MTProto!, isUpdatingConnectionContext: Bool) {
        self.action(self.state.modify { flags in
            if isUpdatingConnectionContext {
                return flags.union([.UpdatingConnectionContext])
            } else {
                return flags.subtracting([.UpdatingConnectionContext])
            }
        })
    }
    
    @objc func mtProtoServiceTasksStateChanged(_ mtProto: MTProto!, isPerformingServiceTasks: Bool) {
        self.action(self.state.modify { flags in
            if isPerformingServiceTasks {
                return flags.union([.PerformingServiceTasks])
            } else {
                return flags.subtracting([.PerformingServiceTasks])
            }
        })
    }
}

private var registeredLoggingFunctions: Void = {
    NetworkRegisterLoggingFunction()
    registerLoggingFunctions()
}()

func initializedNetwork(datacenterId: Int, keychain: Keychain) -> Signal<Network, NoError> {
    return Signal { subscriber in
        Queue.concurrentDefaultQueue().async {
            let _ = registeredLoggingFunctions
            
            let serialization = Serialization()
            
            let apiEnvironment = MTApiEnvironment()
            
            apiEnvironment.apiId = 1
            apiEnvironment.layer = NSNumber(value: Int(serialization.currentLayer()))
            
            let context = MTContext(serialization: serialization, apiEnvironment: apiEnvironment)!
            
            let seedAddressList = [
                1: "149.154.175.50",
                2: "149.154.167.50",
                3: "149.154.175.100",
                4: "149.154.167.91",
                5: "149.154.171.5"
            ]
            
            /*let seedAddressList = [
                1: "149.154.175.10",
                2: "149.154.167.40"
            ]*/
            
            for (id, ip) in seedAddressList {
                context.setSeedAddressSetForDatacenterWithId(id, seedAddressSet: MTDatacenterAddressSet(addressList: [MTDatacenterAddress(ip: ip, port: 443, preferForMedia: false, restrictToTcp: false)]))
            }
            
            context.keychain = keychain
            let mtProto = MTProto(context: context, datacenterId: datacenterId)!
            
            let connectionStatus = Promise<ConnectionStatus>(.WaitingForNetwork)
            
            let requestService = MTRequestMessageService(context: context)!
            let connectionStatusDelegate = MTProtoConnectionStatusDelegate()
            connectionStatusDelegate.action = { [weak connectionStatus] flags in
                if !flags.contains(.NetworkAvailable) {
                    connectionStatus?.set(single(ConnectionStatus.WaitingForNetwork, NoError.self))
                } else if !flags.contains(.Connected) {
                    connectionStatus?.set(single(ConnectionStatus.Connecting, NoError.self))
                } else if !flags.intersection([.UpdatingConnectionContext, .PerformingServiceTasks]).isEmpty {
                    connectionStatus?.set(single(ConnectionStatus.Updating, NoError.self))
                } else {
                    connectionStatus?.set(single(ConnectionStatus.Online, NoError.self))
                }
            }
            mtProto.delegate = connectionStatusDelegate
            mtProto.add(requestService)
            
            subscriber.putNext(Network(datacenterId: datacenterId, context: context, mtProto: mtProto, requestService: requestService, connectionStatusDelegate: connectionStatusDelegate, _connectionStatus: connectionStatus))
            subscriber.putCompletion()
        }
        
        return EmptyDisposable
    }
}

public class Network {
    let datacenterId: Int
    let context: MTContext
    let mtProto: MTProto
    let requestService: MTRequestMessageService
    private let connectionStatusDelegate: MTProtoConnectionStatusDelegate
    
    private let _connectionStatus: Promise<ConnectionStatus>
    public var connectionStatus: Signal<ConnectionStatus, NoError> {
        return self._connectionStatus.get() |> distinctUntilChanged
    }
    
    public let shouldKeepConnection = Promise<Bool>(false)
    private let shouldKeepConnectionDisposable = MetaDisposable()
    
    fileprivate init(datacenterId: Int, context: MTContext, mtProto: MTProto, requestService: MTRequestMessageService, connectionStatusDelegate: MTProtoConnectionStatusDelegate, _connectionStatus: Promise<ConnectionStatus>) {
        self.datacenterId = datacenterId
        self.context = context
        self.mtProto = mtProto
        self.requestService = requestService
        self.connectionStatusDelegate = connectionStatusDelegate
        self._connectionStatus = _connectionStatus
        
        let shouldKeepConnectionSignal = self.shouldKeepConnection.get()
            |> distinctUntilChanged
        self.shouldKeepConnectionDisposable.set(shouldKeepConnectionSignal.start(next: { [weak self] value in
            if let strongSelf = self {
                if true || value {
                    trace("Network", what: "Resume network connection")
                    strongSelf.mtProto.resume()
                } else {
                    trace("Network", what: "Pause network connection")
                    strongSelf.mtProto.pause()
                }
            }
        }))
    }
    
    deinit {
        self.shouldKeepConnectionDisposable.dispose()
    }
    
    func download(datacenterId: Int) -> Signal<Download, NoError> {
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext(Download(datacenterId: datacenterId, context: strongSelf.context, masterDatacenterId: strongSelf.datacenterId))
            }
            subscriber.putCompletion()
            
            return ActionDisposable {
                
            }
        }
    }
    
    public func request<T>(_ data: (CustomStringConvertible, Buffer, (Buffer) -> T?), tag: NetworkRequestDependencyTag? = nil) -> Signal<T, MTRpcError> {
        let requestService = self.requestService
        return Signal { subscriber in
            let request = MTRequest()
            
            request.setPayload(data.1.makeData() as Data!, metadata: WrappedRequestMetadata(metadata: data.0, tag: tag), responseParser: { response in
                if let result = data.2(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = false
            
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
            
            return ActionDisposable {
                self.requestService.removeRequest(byInternalId: internalId)
            }
        }
    }
}

public func retryRequest<T>(signal: Signal<T, MTRpcError>) -> Signal<T, NoError> {
    return signal |> retry(0.2, maxDelay: 5.0, onQueue: Queue.concurrentDefaultQueue())
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
        let data = NSKeyedArchiver.archivedData(withRootObject: object)
        self.set(group + ":" + aKey, data)
    }
    
    func object(forKey aKey: String!, group: String!) -> Any! {
        if let data = self.get(group + ":" + aKey) {
            return NSKeyedUnarchiver.unarchiveObject(with: data as Data)
        }
        return nil
    }
    
    func removeObject(forKey aKey: String!, group: String!) {
        self.remove(group + ":" + aKey)
    }
    
    func dropGroup(_ group: String!) {
        
    }
}
