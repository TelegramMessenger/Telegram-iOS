import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

public struct ActiveSessionsContextState: Equatable {
    public var isLoadingMore: Bool
    public var sessions: [RecentAccountSession]
}

public final class ActiveSessionsContext {
    private let account: Account
    private var _state: ActiveSessionsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<ActiveSessionsContextState>()
    public var state: Signal<ActiveSessionsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    
    public init(account: Account) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self._state = ActiveSessionsContextState(isLoadingMore: false, sessions: [])
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
        self._state = ActiveSessionsContextState(isLoadingMore: true, sessions: self._state.sessions)
        self.disposable.set((requestRecentAccountSessions(account: account)
        |> map { result -> (sessions: [RecentAccountSession], canLoadMore: Bool) in
            return (result, false)
        }
        |> deliverOnMainQueue).start(next: { [weak self] (sessions, canLoadMore) in
            guard let strongSelf = self else {
                return
            }
        
            strongSelf._state = ActiveSessionsContextState(isLoadingMore: false, sessions: sessions)
        }))
    }
    
    public func remove(hash: Int64) -> Signal<Never, TerminateSessionError> {
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
            
            strongSelf._state = ActiveSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: mergedSessions)
            return .complete()
        }
    }
    
    public func removeOther() -> Signal<Never, TerminateSessionError> {
        return terminateOtherAccountSessions(account: self.account)
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] _ -> Signal<Never, TerminateSessionError> in
            guard let strongSelf = self else {
                return .complete()
            }
            
            let mergedSessions = strongSelf._state.sessions.filter({ $0.hash == 0 })
            
            strongSelf._state = ActiveSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: mergedSessions)
            return .complete()
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
    
    public init(account: Account) {
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

