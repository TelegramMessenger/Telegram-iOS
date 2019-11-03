import Foundation
import SwiftSignalKit
import MtProtoKit
#if os(iOS)
import CoreTelephony
#endif

#if os(iOS)
public enum CellularNetworkType {
    case unknown
    case gprs
    case edge
    case thirdG
    case lte
}

extension CellularNetworkType {
    init(accessTechnology: String) {
        switch accessTechnology {
            case CTRadioAccessTechnologyGPRS:
                self = .gprs
            case CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
                self = .edge
            case CTRadioAccessTechnologyLTE:
                self = .lte
            case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD:
                self = .thirdG
            default:
                self = .unknown
        }
    }
}

#endif

enum InternalNetworkType: Equatable {
    case none
    case wifi
    case cellular
}

public enum NetworkType: Equatable {
    case none
    case wifi
#if os(iOS)
    case cellular(CellularNetworkType)
#endif
}

extension NetworkType {
#if os(iOS)
    init(internalType: InternalNetworkType, cellularType: CellularNetworkType) {
        switch internalType {
            case .none:
                self = .none
            case .wifi:
                self = .wifi
            case .cellular:
                self = .cellular(cellularType)
        }
    }
#else
    init(internalType: InternalNetworkType) {
        switch internalType {
            case .none:
                self = .none
            case .wifi, .cellular:
                self = .wifi
        }
    }
#endif
}

private final class WrappedReachability: NSObject {
    @objc private static func threadImpl() {
        while true {
            RunLoop.current.run(until: .distantFuture)
        }
    }
    
    static let thread: Thread = {
        let thread = Thread(target: WrappedReachability.self, selector: #selector(WrappedReachability.threadImpl), object: nil)
        thread.start()
        return thread
    }()
    
    @objc private static func dispatchOnThreadImpl(_ f: @escaping () -> Void) {
        f()
    }
    
    private static func dispatchOnThread(_ f: @escaping @convention(block) () -> Void) {
        WrappedReachability.perform(#selector(WrappedReachability.dispatchOnThreadImpl(_:)), on: WrappedReachability.thread, with: f, waitUntilDone: false)
    }
    
    private let reachability: Reachability
    
    let value: ValuePromise<InternalNetworkType>
    
    override init() {
        assert(Thread.current === WrappedReachability.thread)
        self.reachability = Reachability.forInternetConnection()
        let type: InternalNetworkType
        switch self.reachability.currentReachabilityStatus() {
            case NotReachable:
                type = .none
            case ReachableViaWiFi:
                type = .wifi
            case ReachableViaWWAN:
                type = .cellular
            default:
                type = .none
        }
        self.value = ValuePromise<InternalNetworkType>(type)
        
        super.init()
        
        self.reachability.reachabilityChanged = { [weak self] status in
            WrappedReachability.dispatchOnThread {
                guard let strongSelf = self else {
                    return
                }
                let internalNetworkType: InternalNetworkType
                switch status {
                    case NotReachable:
                        internalNetworkType = .none
                    case ReachableViaWiFi:
                        internalNetworkType = .wifi
                    case ReachableViaWWAN:
                        internalNetworkType = .cellular
                    default:
                        internalNetworkType = .none
                }
                strongSelf.value.set(internalNetworkType)
            }
        }
        self.reachability.startNotifier()
    }
    
    static var valueRef: Unmanaged<WrappedReachability>?
    
    static func withInstance(_ f: @escaping (WrappedReachability) -> Void) {
        WrappedReachability.dispatchOnThread {
            if self.valueRef == nil {
                self.valueRef = Unmanaged.passRetained(WrappedReachability())
            }
            if let valueRef = self.valueRef {
                let value = valueRef.takeUnretainedValue()
                f(value)
            }
        }
    }
}

private final class NetworkTypeManagerImpl {
    let queue: Queue
    let updated: (NetworkType) -> Void
    var networkTypeDisposable: Disposable?
    var currentNetworkType: InternalNetworkType?
    var networkType: NetworkType?
    #if os(iOS)
    var currentCellularType: CellularNetworkType
    var cellularTypeObserver: NSObjectProtocol?
    #endif
        
    init(queue: Queue, updated: @escaping (NetworkType) -> Void) {
        self.queue = queue
        self.updated = updated
        
        #if os(iOS)
        let telephonyInfo = CTTelephonyNetworkInfo()
        let accessTechnology = telephonyInfo.currentRadioAccessTechnology ?? ""
        self.currentCellularType = CellularNetworkType(accessTechnology: accessTechnology)
        self.cellularTypeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.CTRadioAccessTechnologyDidChange, object: nil, queue: nil, using: { [weak self] notification in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                let accessTechnology = telephonyInfo.currentRadioAccessTechnology ?? ""
                let cellularType = CellularNetworkType(accessTechnology: accessTechnology)
                if strongSelf.currentCellularType != cellularType {
                    strongSelf.currentCellularType = cellularType
                    
                    if let currentNetworkType = strongSelf.currentNetworkType {
                        let networkType = NetworkType(internalType: currentNetworkType, cellularType: cellularType)
                
                        if strongSelf.networkType != networkType {
                            strongSelf.networkType = networkType
                            strongSelf.updated(networkType)
                        }
                    }
                }
            }
        })
        #endif
        
        let networkTypeDisposable = MetaDisposable()
        self.networkTypeDisposable = networkTypeDisposable
            
        WrappedReachability.withInstance({ [weak self] impl in
            networkTypeDisposable.set((impl.value.get()
            |> deliverOn(queue)).start(next: { networkStatus in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.currentNetworkType != networkStatus {
                    strongSelf.currentNetworkType = networkStatus
                    
                    let networkType: NetworkType
                    #if os(iOS)
                    networkType = NetworkType(internalType: networkStatus, cellularType: strongSelf.currentCellularType)
                    #else
                    networkType = NetworkType(internalType:  networkStatus)
                    #endif
                    if strongSelf.networkType != networkType {
                        strongSelf.networkType = networkType
                        updated(networkType)
                    }
                }
            }))
        })
    }
    
    func stop() {
        self.networkTypeDisposable?.dispose()
        #if os(iOS)
        if let observer = self.cellularTypeObserver {
            NotificationCenter.default.removeObserver(observer, name: NSNotification.Name.CTRadioAccessTechnologyDidChange, object: nil)
        }
        #endif
    }
}

func currentNetworkType() -> Signal<NetworkType, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        let disposable = MetaDisposable()
        queue.async {
            let impl = QueueLocalObject(queue: queue, generate: {
                return NetworkTypeManagerImpl(queue: queue, updated: { value in
                    subscriber.putNext(value)
                })
            })
            disposable.set(ActionDisposable {
                impl.with({ impl in
                    impl.stop()
                })
            })
        }
        return disposable
    }
}
