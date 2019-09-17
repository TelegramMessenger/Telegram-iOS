import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
#else
import Postbox
import SwiftSignalKit
#if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
#endif

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
            
            var mergedSessions = strongSelf._state.sessions
            for i in (0 ..< mergedSessions.count).reversed() {
                if mergedSessions[i].hash != 0 {
                    mergedSessions.remove(at: i)
                    break
                }
            }
            
            strongSelf._state = ActiveSessionsContextState(isLoadingMore: strongSelf._state.isLoadingMore, sessions: mergedSessions)
            return .complete()
        }
    }
}
