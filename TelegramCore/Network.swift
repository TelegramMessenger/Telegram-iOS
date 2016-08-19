import Foundation
import MtProtoKit
import Postbox
import SwiftSignalKit
import TelegramCorePrivateModule

enum ConnectionStatus {
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
    init(metadata: CustomStringConvertible) {
        self.metadata = metadata
    }
    
    override var description: String {
        return self.metadata.description
    }
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

public class Network {
    let datacenterId: Int
    let context: MTContext
    let mtProto: MTProto
    let requestService: MTRequestMessageService
    
    private let connectionStatusDelegate = MTProtoConnectionStatusDelegate()
    
    private let _connectionStatus = Promise<ConnectionStatus>(.WaitingForNetwork)
    var connectionStatus: Signal<ConnectionStatus, NoError> {
        return self._connectionStatus.get() |> distinctUntilChanged
    }
    
    init(datacenterId: Int, keychain: Keychain) {
        NetworkRegisterLoggingFunction()
        registerLoggingFunctions()
        
        self.datacenterId = datacenterId
        
        let serialization = Serialization()
        
        let apiEnvironment = MTApiEnvironment()
        
        apiEnvironment.apiId = 1
        apiEnvironment.layer = NSNumber(value: Int(serialization.currentLayer()))
        
        self.context = MTContext(serialization: serialization, apiEnvironment: apiEnvironment)
        
        let seedAddressList = [
            1: "149.154.175.50",
            2: "149.154.167.50",
            3: "149.154.175.100",
            4: "149.154.167.91",
            5: "149.154.171.5"
        ]
        
        for (id, ip) in seedAddressList {
            self.context.setSeedAddressSetForDatacenterWithId(id, seedAddressSet: MTDatacenterAddressSet(addressList: [MTDatacenterAddress(ip: ip, port: 443, preferForMedia: false, restrictToTcp: false)]))
        }
        
        self.context.keychain = keychain
        self.mtProto = MTProto(context: self.context, datacenterId: datacenterId)
        
        self.requestService = MTRequestMessageService(context: self.context)
        self.connectionStatusDelegate.action = { [weak self] flags in
            if let strongSelf = self {
                if !flags.contains(.NetworkAvailable) {
                    strongSelf._connectionStatus.set(single(ConnectionStatus.WaitingForNetwork, NoError.self))
                } else if !flags.contains(.Connected) {
                    strongSelf._connectionStatus.set(single(ConnectionStatus.Connecting, NoError.self))
                } else if !flags.intersection([.UpdatingConnectionContext, .PerformingServiceTasks]).isEmpty {
                    strongSelf._connectionStatus.set(single(ConnectionStatus.Updating, NoError.self))
                } else {
                    strongSelf._connectionStatus.set(single(ConnectionStatus.Online, NoError.self))
                }
            }
        }
        self.mtProto.delegate = self.connectionStatusDelegate
        
        self.mtProto.add(self.requestService)
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

    func request<T>(_ data: (CustomStringConvertible, Buffer, (Buffer) -> T?)) -> Signal<T, MTRpcError> {
        return self.request(data, dependsOnPasswordEntry: true)
    }
    
    func request<T>(_ data: (CustomStringConvertible, Buffer, (Buffer) -> T?), dependsOnPasswordEntry: Bool) -> Signal<T, MTRpcError> {
        let requestService = self.requestService
        return Signal { subscriber in
            let request = MTRequest()
            
            request.setPayload(data.1.makeData() as Data!, metadata: WrappedRequestMetadata(metadata: data.0), responseParser: { response in
                if let result = data.2(Buffer(data: response)) {
                    return BoxedMessage(result)
                }
                return nil
            })
            
            request.dependsOnPasswordEntry = dependsOnPasswordEntry
            
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
            
            let internalId: AnyObject! = request.internalId
            
            requestService.add(request)
            
            return ActionDisposable {
                self.requestService.removeRequest(byInternalId: internalId)
            }
        }
    }
}

func retryRequest<T>(signal: Signal<T, MTRpcError>) -> Signal<T, NoError> {
    return signal |> retry(0.2, maxDelay: 5.0, onQueue: Queue.concurrentDefaultQueue())
}

class Keychain: NSObject, MTKeychain {
    let get: (String) -> Data?
    let set: (String, Data) -> Void
    let remove: (String) -> Void
    
    init(get: (String) -> Data?, set: (String, Data) -> Void, remove: (String) -> Void) {
        self.get = get
        self.set = set
        self.remove = remove
    }
    
    func setObject(_ object: AnyObject!, forKey aKey: String!, group: String!) {
        let data = NSKeyedArchiver.archivedData(withRootObject: object)
        self.set(group + ":" + aKey, data)
    }
    
    func object(forKey aKey: String!, group: String!) -> AnyObject! {
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
