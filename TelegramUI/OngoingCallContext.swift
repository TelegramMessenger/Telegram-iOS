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

final class OngoingCallContext {
    let internalId: CallSessionInternalId
    
    private let queue = Queue()
    private let callSessionManager: CallSessionManager
    
    private var contextRef: Unmanaged<OngoingCallThreadLocalContext>?
    
    private let contextState = Promise<OngoingCallState?>(nil)
    var state: Signal<OngoingCallContextState?, NoError> {
        return self.contextState.get() |> map {
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
    
    init(callSessionManager: CallSessionManager, internalId: CallSessionInternalId) {
        let _ = setupLogs
        
        self.internalId = internalId
        self.callSessionManager = callSessionManager
        
        let queue = self.queue
        self.queue.async {
            let context = OngoingCallThreadLocalContext(queue: OngoingCallThreadLocalContextQueueImpl(queue: queue))
            self.contextRef = Unmanaged.passRetained(context)
            context.stateChanged = { [weak self] state in
                self?.contextState.set(.single(state))
            }
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
        
        self.audioSessionDisposable.dispose()
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
        self.audioSessionDisposable.set((audioSessionActive |> filter { $0 } |> take(1)).start(next: { [weak self] _ in
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
