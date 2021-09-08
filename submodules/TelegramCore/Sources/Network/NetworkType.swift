import Foundation
import SwiftSignalKit
import MtProtoKit
import Reachability
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

public enum NetworkType: Equatable {
    case none
    case wifi
#if os(iOS)
    case cellular(CellularNetworkType)
#endif
}

extension NetworkType {
#if os(iOS)
    init(internalType: Reachability.NetworkType, cellularType: CellularNetworkType) {
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
    init(internalType: Reachability.NetworkType) {
        switch internalType {
            case .none:
                self = .none
            case .wifi, .cellular:
                self = .wifi
        }
    }
#endif
}

private final class NetworkTypeManagerImpl {
    let queue: Queue
    let updated: (NetworkType) -> Void
    var networkTypeDisposable: Disposable?
    var currentNetworkType: Reachability.NetworkType?
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
        
        networkTypeDisposable.set((Reachability.networkType
        |> deliverOn(queue)).start(next: { [weak self] networkStatus in
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
