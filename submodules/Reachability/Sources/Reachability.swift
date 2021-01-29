import Foundation
import SwiftSignalKit

import LegacyReachability
import Network

private final class WrappedLegacyReachability: NSObject {
    @objc private static func threadImpl() {
        while true {
            RunLoop.current.run(until: .distantFuture)
        }
    }
    
    private static let thread: Thread = {
        let thread = Thread(target: WrappedLegacyReachability.self, selector: #selector(WrappedLegacyReachability.threadImpl), object: nil)
        thread.start()
        return thread
    }()
    
    @objc private static func dispatchOnThreadImpl(_ f: @escaping () -> Void) {
        f()
    }
    
    private static func dispatchOnThread(_ f: @escaping @convention(block) () -> Void) {
        WrappedLegacyReachability.perform(#selector(WrappedLegacyReachability.dispatchOnThreadImpl(_:)), on: WrappedLegacyReachability.thread, with: f, waitUntilDone: false)
    }
    
    private let reachability: LegacyReachability
    
    let value: ValuePromise<Reachability.NetworkType>
    
    override init() {
        assert(Thread.current === WrappedLegacyReachability.thread)
        self.reachability = LegacyReachability.forInternetConnection()
        let type: Reachability.NetworkType
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
        self.value = ValuePromise<Reachability.NetworkType>(type)
        
        super.init()
        
        self.reachability.reachabilityChanged = { [weak self] status in
            WrappedLegacyReachability.dispatchOnThread {
                guard let strongSelf = self else {
                    return
                }
                let internalNetworkType: Reachability.NetworkType
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
    
    private static var valueRef: Unmanaged<WrappedLegacyReachability>?
    
    static func withInstance(_ f: @escaping (WrappedLegacyReachability) -> Void) {
        WrappedLegacyReachability.dispatchOnThread {
            if self.valueRef == nil {
                self.valueRef = Unmanaged.passRetained(WrappedLegacyReachability())
            }
            if let valueRef = self.valueRef {
                let value = valueRef.takeUnretainedValue()
                f(value)
            }
        }
    }
}

@available(iOSApplicationExtension 12.0, iOS 12.0, OSX 10.14, *)
private final class PathMonitor {
    private let queue: Queue
    private let monitor: NWPathMonitor
    
    let networkType = Promise<Reachability.NetworkType>()
    
    init(queue: Queue) {
        self.queue = queue
        self.monitor = NWPathMonitor()
        
        self.monitor.pathUpdateHandler = { [weak self] path in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                let networkType: Reachability.NetworkType
                if path.status == .satisfied {
                    if path.usesInterfaceType(.cellular) {
                        networkType = .cellular
                    } else {
                        networkType = .wifi
                    }
                } else {
                    networkType = .none
                }
                
                strongSelf.networkType.set(.single(networkType))
            }
        }
        
        self.monitor.start(queue: self.queue.queue)
        
        let networkType: Reachability.NetworkType
        let path = self.monitor.currentPath
        if path.status == .satisfied {
            if path.usesInterfaceType(.cellular) {
                networkType = .cellular
            } else {
                networkType = .wifi
            }
        } else {
            networkType = .none
        }
        
        self.networkType.set(.single(networkType))
    }
}

@available(iOSApplicationExtension 12.0, iOS 12.0, OSX 10.14, *)
private final class SharedPathMonitor {
    static let queue = Queue()
    static let impl = QueueLocalObject<PathMonitor>(queue: queue, generate: {
        return PathMonitor(queue: queue)
    })
}

public enum Reachability {
    public enum NetworkType: Equatable {
        case none
        case wifi
        case cellular
    }
    
    public static var networkType: Signal<NetworkType, NoError> {
        if #available(iOSApplicationExtension 12.0, iOS 12.0, OSX 10.14, *) {
            return Signal { subscriber in
                let disposable = MetaDisposable()

                SharedPathMonitor.impl.with { impl in
                    disposable.set(impl.networkType.get().start(next: { value in
                        subscriber.putNext(value)
                    }))
                }

                return disposable
            }
            |> distinctUntilChanged
        } else {
            return Signal { subscriber in
                let disposable = MetaDisposable()
                
                WrappedLegacyReachability.withInstance({ impl in
                    disposable.set(impl.value.get().start(next: { next in
                        subscriber.putNext(next)
                    }))
                })
                
                return disposable
            }
            |> distinctUntilChanged
        }
    }
}
