import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox

import TelegramUIPrivateModule

private func callConnectionDescription(_ connection: CallSessionConnection) -> OngoingCallConnectionDescription {
    return OngoingCallConnectionDescription(connectionId: connection.id, ip: connection.ip, ipv6: connection.ipv6, port: connection.port, peerTag: connection.peerTag)
}

private let setupLogs: Bool = {
    OngoingCallThreadLocalContext.setupLoggingFunction({ value in
        if let value = value {
            Logger.shared.log("TGVOIP", value)
        }
    })
    return true
}()

enum OngoingCallContextState {
    case initializing
    case connected
    case failed
}

private final class OngoingCallThreadLocalContextQueueImpl: NSObject, OngoingCallThreadLocalContextQueue {
    private let queue: Queue
    
    init(queue: Queue) {
        self.queue = queue
        
        super.init()
    }
    
    func dispatch(_ f: @escaping () -> Void) {
        self.queue.async {
            f()
        }
    }
    
    func isCurrent() -> Bool {
        return self.queue.isCurrent()
    }
}

private func ongoingNetworkTypeForType(_ type: NetworkType) -> OngoingCallNetworkType {
    switch type {
        case .none:
            return .wifi
        case .wifi:
            return .wifi
        case let .cellular(cellular):
            switch cellular {
                case .edge:
                    return .cellularEdge
                case .gprs:
                    return .cellularGprs
                case .thirdG, .unknown:
                    return .cellular3g
                case .lte:
                    return .cellularLte
            }
    }
}

final class OngoingCallContext {
    let internalId: CallSessionInternalId
    
    private let queue = Queue()
    private let callSessionManager: CallSessionManager
    
    private var contextRef: Unmanaged<OngoingCallThreadLocalContext>?
    
    private let contextState = Promise<OngoingCallState?>(nil)
    var state: Signal<OngoingCallContextState?, NoError> {
        return self.contextState.get()
        |> map {
            $0.flatMap {
                switch $0 {
                    case .initializing:
                        return .initializing
                    case .connected:
                        return .connected
                    case .failed:
                        return .failed
                }
            }
        }
    }
    
    private let audioSessionDisposable = MetaDisposable()
    private var networkTypeDisposable: Disposable?
    
    init(callSessionManager: CallSessionManager, internalId: CallSessionInternalId, allowP2P: Bool, proxyServer: ProxyServerSettings?, initialNetworkType: NetworkType, updatedNetworkType: Signal<NetworkType, NoError>) {
        let _ = setupLogs
        
        self.internalId = internalId
        self.callSessionManager = callSessionManager
        
        let queue = self.queue
        self.queue.async {
            var voipProxyServer: VoipProxyServer?
            if let proxyServer = proxyServer {
                switch proxyServer.connection {
                    case let .socks5(username, password):
                        voipProxyServer = VoipProxyServer(host: proxyServer.host, port: proxyServer.port, username: username, password: password)
                    case .mtp:
                        break
                }
            }
            let context = OngoingCallThreadLocalContext(queue: OngoingCallThreadLocalContextQueueImpl(queue: queue), allowP2P: allowP2P, proxy: voipProxyServer, networkType: ongoingNetworkTypeForType(initialNetworkType))
            self.contextRef = Unmanaged.passRetained(context)
            context.stateChanged = { [weak self] state in
                self?.contextState.set(.single(state))
            }
        }
        
        self.networkTypeDisposable = (updatedNetworkType
        |> deliverOn(self.queue)).start(next: { [weak self] networkType in
            self?.withContext { context in
                context.setNetworkType(ongoingNetworkTypeForType(networkType))
            }
        })
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
        
        self.audioSessionDisposable.dispose()
        self.networkTypeDisposable?.dispose()
    }
    
    private func withContext(_ f: @escaping (OngoingCallThreadLocalContext) -> Void) {
        self.queue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                f(context)
            }
        }
    }
    
    func start(key: Data, isOutgoing: Bool, connections: CallSessionConnectionSet, maxLayer: Int32, audioSessionActive: Signal<Bool, NoError>) {
        self.audioSessionDisposable.set((audioSessionActive
        |> filter { $0 }
        |> take(1)).start(next: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.withContext { context in
                    context.start(withKey: key, isOutgoing: isOutgoing, primaryConnection: callConnectionDescription(connections.primary), alternativeConnections: connections.alternatives.map(callConnectionDescription), maxLayer: maxLayer)
                }
            }
        }))
    }
    
    func stop() {
        self.withContext { context in
            context.stop()
        }
    }
    
    func setIsMuted(_ value: Bool) {
        self.withContext { context in
            context.setIsMuted(value)
        }
    }
}
