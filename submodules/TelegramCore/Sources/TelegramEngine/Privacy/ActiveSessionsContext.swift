import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

public struct ActiveSessionsContextState: Equatable {
    public var isLoadingMore: Bool
    public var sessions: [RecentAccountSession]
    public var ttlDays: Int32
}

private final class ActiveSessionsContextImpl {
    private let account: Account
    private var _state: ActiveSessionsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<ActiveSessionsContextState>()
    var state: Signal<ActiveSessionsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    private var authorizationListUpdatesDisposable: Disposable?
    
    init(account: Account) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self._state = ActiveSessionsContextState(isLoadingMore: false, sessions: [], ttlDays: 1)
        self._statePromise.set(.single(self._state))
        
        self.loadMore()
        
        self.authorizationListUpdatesDisposable = (account.stateManager.authorizationListUpdates
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?.loadMore()
        })
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
        self.authorizationListUpdatesDisposable?.dispose()
    }
    
    func loadMore() {
        assert(Queue.mainQueue().isCurrent())
        
        if self._state.isLoadingMore {
            return
        }
        self._state = ActiveSessionsContextState(isLoadingMore: true, sessions: self._state.sessions, ttlDays: self._state.ttlDays)
        self.disposable.set((requestRecentAccountSessions(account: self.account)
        |> map { result -> (sessions: [RecentAccountSession], ttlDays: Int32, canLoadMore: Bool) in
            return (result.0, result.1, false)
        }
        |> deliverOnMainQueue).start(next: { [weak self] (sessions, ttlDays, canLoadMore) in
            guard let strongSelf = self else {
                return
            }
        
            strongSelf._state = ActiveSessionsContextState(isLoadingMore: false, sessions: sessions, ttlDays: ttlDays)
        }))
    }
    
    func addSession(_ session: RecentAccountSession) {
        var mergedSessions = self._state.sessions
        var found = false
        for i in 0 ..< mergedSessions.count {
            if mergedSessions[i].hash == session.hash {
                found = true
                break
            }
        }
        if !found {
            mergedSessions.insert(session, at: 0)
        }
        
        self._state = ActiveSessionsContextState(isLoadingMore: self._state.isLoadingMore, sessions: mergedSessions, ttlDays: self._state.ttlDays)
    }
    
    func remove(hash: Int64) -> Signal<Never, TerminateSessionError> {
        assert(Queue.mainQueue().isCurrent())
        
        return terminateAccountSession(account: self.account, hash: hash)
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] _ -> Signal<Never, TerminateSessionError> in
            guard let strongSelf = self else {
                return .complete()
            }
            
            var mergedSessions = strongSelf._state.sessions
            for i in 0 ..< mergedSessions.count {
                if mergedSessions[i].hash == hash {
                    mergedSessions.remove(at: i)
                    break
                }
            }
            
            strongSelf._state = ActiveSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: mergedSessions, ttlDays: strongSelf._state.ttlDays)
            return .complete()
        }
    }
        
    func removeOther() -> Signal<Never, TerminateSessionError> {
        return terminateOtherAccountSessions(account: self.account)
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] _ -> Signal<Never, TerminateSessionError> in
            guard let strongSelf = self else {
                return .complete()
            }
            
            let mergedSessions = strongSelf._state.sessions.filter({ $0.hash == 0 })
            
            strongSelf._state = ActiveSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: mergedSessions, ttlDays: strongSelf._state.ttlDays)
            return .complete()
        }
    }
    
    func updateSessionAcceptsSecretChats(_ session: RecentAccountSession, accepts: Bool) -> Signal<Never, UpdateSessionError> {
        var mergedSessions = self._state.sessions
        for i in 0 ..< mergedSessions.count {
            if mergedSessions[i].hash == session.hash {
                let updatedSession = mergedSessions[i].withUpdatedAcceptsSecretChats(accepts)
                mergedSessions.remove(at: i)
                mergedSessions.insert(updatedSession, at: i)
                break
            }
        }
        self._state = ActiveSessionsContextState(isLoadingMore: self._state.isLoadingMore, sessions: mergedSessions, ttlDays: self._state.ttlDays)
        
        return updateAccountSessionAcceptsSecretChats(account: self.account, hash: session.hash, accepts: accepts)
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] _ -> Signal<Never, UpdateSessionError> in
            if let strongSelf = self {
                strongSelf._state = ActiveSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: mergedSessions, ttlDays: strongSelf._state.ttlDays)
            }
            return .complete()
        }
    }
    
    func updateSessionAcceptsIncomingCalls(_ session: RecentAccountSession, accepts: Bool) -> Signal<Never, UpdateSessionError> {
        var mergedSessions = self._state.sessions
        for i in 0 ..< mergedSessions.count {
            if mergedSessions[i].hash == session.hash {
                let updatedSession = mergedSessions[i].withUpdatedAcceptsIncomingCalls(accepts)
                mergedSessions.remove(at: i)
                mergedSessions.insert(updatedSession, at: i)
                break
            }
        }
        self._state = ActiveSessionsContextState(isLoadingMore: self._state.isLoadingMore, sessions: mergedSessions, ttlDays: self._state.ttlDays)
        
        return updateAccountSessionAcceptsIncomingCalls(account: self.account, hash: session.hash, accepts: accepts)
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] _ -> Signal<Never, UpdateSessionError> in
            if let strongSelf = self {
                strongSelf._state = ActiveSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: mergedSessions, ttlDays: strongSelf._state.ttlDays)
            }
            return .complete()
        }
    }
    
    func updateAuthorizationTTL(days: Int32) -> Signal<Never, UpadteAuthorizationTTLError> {
        self._state = ActiveSessionsContextState(isLoadingMore: self._state.isLoadingMore, sessions: self._state.sessions, ttlDays: days)
        
        return setAuthorizationTTL(account: self.account, ttl: days)
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] _ -> Signal<Never, UpadteAuthorizationTTLError> in
            if let strongSelf = self {
                strongSelf._state = ActiveSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: strongSelf._state.sessions, ttlDays: days)
            }
            return .complete()
        }
    }
}

public final class ActiveSessionsContext {
    private let impl: QueueLocalObject<ActiveSessionsContextImpl>
    
    public var state: Signal<ActiveSessionsContextState, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    init(account: Account) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return ActiveSessionsContextImpl(account: account)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    func addSession(_ session: RecentAccountSession) {
        self.impl.with { impl in
            impl.addSession(session)
        }
    }
    
    public func remove(hash: Int64) -> Signal<Never, TerminateSessionError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.remove(hash: hash).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func removeOther() -> Signal<Never, TerminateSessionError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.removeOther().start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func updateSessionAcceptsSecretChats(_ session: RecentAccountSession, accepts: Bool) -> Signal<Never, UpdateSessionError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.updateSessionAcceptsSecretChats(session, accepts: accepts).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func updateSessionAcceptsIncomingCalls(_ session: RecentAccountSession, accepts: Bool) -> Signal<Never, UpdateSessionError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.updateSessionAcceptsIncomingCalls(session, accepts: accepts).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func updateAuthorizationTTL(days: Int32) -> Signal<Never, UpadteAuthorizationTTLError> {
        let days = max(1, min(365, days))
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.updateAuthorizationTTL(days: days).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
}

public struct WebSessionsContextState: Equatable {
    public var isLoadingMore: Bool
    public var sessions: [WebAuthorization]
    public var peers: [PeerId: Peer]
    
    public static func ==(lhs: WebSessionsContextState, rhs: WebSessionsContextState) -> Bool {
        if lhs.isLoadingMore != rhs.isLoadingMore {
            return false
        }
        if lhs.sessions != rhs.sessions {
            return false
        }
        if !arePeerDictionariesEqual(lhs.peers, rhs.peers) {
            return false
        }
        return true
    }
}

public final class WebSessionsContext {
    private let account: Account
    private var _state: WebSessionsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<WebSessionsContextState>()
    public var state: Signal<WebSessionsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    
    init(account: Account) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self._state = WebSessionsContextState(isLoadingMore: false, sessions: [], peers: [:])
        self._statePromise.set(.single(self._state))
        
        self.loadMore()
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
    }
    
    public func loadMore() {
        assert(Queue.mainQueue().isCurrent())
        
        if self._state.isLoadingMore {
            return
        }
        self._state = WebSessionsContextState(isLoadingMore: true, sessions: self._state.sessions, peers: self._state.peers)
        self.disposable.set((webSessions(network: account.network)
            |> map { result -> (sessions: [WebAuthorization], peers: [PeerId: Peer], canLoadMore: Bool) in
                return (result.0, result.1, false)
        }
        |> deliverOnMainQueue).start(next: { [weak self] (sessions, peers, canLoadMore) in
            guard let strongSelf = self else {
                return
            }
        
            strongSelf._state = WebSessionsContextState(isLoadingMore: false, sessions: sessions, peers: peers)
        }))
    }
    
    public func remove(hash: Int64) -> Signal<Never, NoError> {
        assert(Queue.mainQueue().isCurrent())
        
        return terminateWebSession(network: self.account.network, hash: hash)
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] _ -> Signal<Never, NoError> in
            guard let strongSelf = self else {
                return .complete()
            }
            
            var mergedSessions = strongSelf._state.sessions
            for i in 0 ..< mergedSessions.count {
                if mergedSessions[i].hash == hash {
                    mergedSessions.remove(at: i)
                    break
                }
            }
            
            strongSelf._state = WebSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: mergedSessions, peers: strongSelf._state.peers)
            return .complete()
        }
    }
    
    public func removeAll() -> Signal<Never, NoError> {
        return terminateAllWebSessions(network: self.account.network)
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] _ -> Signal<Never, NoError> in
            guard let strongSelf = self else {
                return .complete()
            }
            
            strongSelf._state = WebSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: [], peers: [:])
            return .complete()
        }
    }
}

