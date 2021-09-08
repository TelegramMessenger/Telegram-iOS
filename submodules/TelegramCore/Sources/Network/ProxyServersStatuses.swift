import Foundation
import SwiftSignalKit
import MtProtoKit


public enum ProxyServerStatus: Equatable {
    case checking
    case notAvailable
    case available(Double)
}

private final class ProxyServerItemContext {
    private var disposable: Disposable?
    var value: ProxyServerStatus = .checking
    
    init(queue: Queue, context: MTContext, datacenterId: Int, server: ProxyServerSettings, updated: @escaping (ProxyServerStatus) -> Void) {
        self.disposable = (Signal<ProxyServerStatus, NoError> { subscriber in
            let disposable = MTProxyConnectivity.pingProxy(with: context, datacenterId: datacenterId, settings: server.mtProxySettings).start(next: { next in
                if let next = next as? MTProxyConnectivityStatus {
                    if !next.reachable {
                        subscriber.putNext(.notAvailable)
                    } else {
                        subscriber.putNext(.available(next.roundTripTime))
                    }
                }
            })
            
            return ActionDisposable {
                disposable?.dispose()
            }
        } |> runOn(queue)).start(next: { status in
            updated(status)
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
}

final class ProxyServersStatusesImpl {
    private let queue: Queue
    
    private var contexts: [ProxyServerSettings: ProxyServerItemContext] = [:]
    private var serversDisposable: Disposable?
    
    private var currentValues: [ProxyServerSettings: ProxyServerStatus] = [:] {
        didSet {
            self.values.set(.single(self.currentValues))
        }
    }
    let values = Promise<[ProxyServerSettings: ProxyServerStatus]>([:])
    
    init(queue: Queue, network: Network, servers: Signal<[ProxyServerSettings], NoError>) {
        self.queue = queue
        
        self.serversDisposable = (servers
            |> deliverOn(self.queue)).start(next: { [weak self] servers in
                if let strongSelf = self {
                    let validKeys = Set<ProxyServerSettings>(servers)
                    for key in validKeys {
                        if strongSelf.contexts[key] == nil {
                            let context = ProxyServerItemContext(queue: strongSelf.queue, context: network.context, datacenterId: network.datacenterId, server: key, updated: { value in
                                queue.async {
                                    if let strongSelf = self {
                                        strongSelf.contexts[key]?.value = value
                                        strongSelf.updateValues()
                                    }
                                }
                            })
                            strongSelf.contexts[key] = context
                        }
                    }
                    var removeKeys: [ProxyServerSettings] = []
                    for (key, _) in strongSelf.contexts {
                        if !validKeys.contains(key) {
                            removeKeys.append(key)
                        }
                    }
                    for key in removeKeys {
                        let _ = strongSelf.contexts.removeValue(forKey: key)
                    }
                    if !removeKeys.isEmpty {
                        strongSelf.updateValues()
                    }
                }
            })
    }
    
    deinit {
        self.serversDisposable?.dispose()
    }
    
    private func updateValues() {
        assert(self.queue.isCurrent())
        
        var values: [ProxyServerSettings: ProxyServerStatus] = [:]
        for (key, context) in self.contexts {
            values[key] = context.value
        }
        self.currentValues = values
    }
}

public final class ProxyServersStatuses {
    private let impl: QueueLocalObject<ProxyServersStatusesImpl>
    
    public init(network: Network, servers: Signal<[ProxyServerSettings], NoError>) {
        let queue = Queue()
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ProxyServersStatusesImpl(queue: queue, network: network, servers: servers)
        })
    }
    
    public func statuses() -> Signal<[ProxyServerSettings: ProxyServerStatus], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.values.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return ActionDisposable {
                self.impl.with({ _ in })
                disposable.dispose()
            }
        }
    }
}
