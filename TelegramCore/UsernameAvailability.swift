
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif


public enum UsernameAvailabilityError {
    case underscopeStart
    case underscopeEnd
    case digitStart
    case invalid
    case short
    case alreadyTaken
}

public enum UsernameAvailabilityState : Equatable {
    case none(username: String?)
    case success(username: String?)
    case progress(username: String?)
    case fail(username: String?, error: UsernameAvailabilityError)
    
    public var username:String? {
        switch self {
        case let .none(username:username):
            return username
        case let .success(username:username):
            return username
        case let .progress(username:username):
            return username
        case let .fail(fail):
            return fail.username
        }
    }
}



public func ==(lhs:UsernameAvailabilityState, rhs:UsernameAvailabilityState) -> Bool {
    switch lhs {
    case let .none(username:lhsName):
        if case let .none(username:rhsName) = rhs, lhsName == rhsName {
            return true
        }
        return false
    case let .success(username:lhsName):
        if case let .success(username:rhsName) = rhs, lhsName == rhsName {
            return true
        }
        return false
    case let .progress(username:lhsName):
        if case let .progress(username:rhsName) = rhs, lhsName == rhsName {
            return true
        }
        return false
    case let .fail(lhsText):
        if case let .fail(rhsText) = rhs, lhsText.error == rhsText.error && lhsText.username == rhsText.username {
            return true
        }
        return false
    }
}


public func usernameAvailability(account:Account, def:String?, current:String) -> Signal<UsernameAvailabilityState,Void> {
    
    return Signal { subscriber in
        
        let none = { () -> Disposable in
            subscriber.putNext(.none(username: current))
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        let success = { () -> Disposable in
            subscriber.putNext(.success(username: current))
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        let fail:(UsernameAvailabilityError)->Disposable = { (value) -> Disposable in
            subscriber.putNext(.fail(username: current, error:value))
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        if def == current {
            return success()
        }
        
        for char in current.characters {
            if char == "_" {
                if char == current.characters.first {
                    return fail(.underscopeStart);
                } else if char == current.characters.last {
                    return fail(current.characters.count < 5 ? .short : .underscopeEnd);
                }
                
            }
            if char == current.characters.first && char >= "0" && char <= "9" {
                return fail(.digitStart);
            }
            if (!((char >= "a" && char <= "z") || (char >= "A" && char <= "Z") || (char >= "0" && char <= "9"))) {
                return fail(.invalid);
            }
        }
        
        if current.characters.count < 5 {
            if current.isEmpty {
                return none()
            }
            return fail(.short)
        }
        
        
        subscriber.putNext(.progress(username: current))
        
        let disposable:Disposable
        
        let req = account.network.request(Api.functions.account.checkUsername(username: current)) |> delay(0.3, queue: Queue.concurrentDefaultQueue()) |> map {result in
            switch result {
            case .boolFalse:
                return .fail(username: current, error:.alreadyTaken)
            case .boolTrue:
                return .success(username: current)
            }
        }
        |> `catch` { error -> Signal<UsernameAvailabilityState, MTRpcError> in
            return Signal <UsernameAvailabilityState,MTRpcError> { subscriber in
                subscriber.putNext(.fail(username: current, error:.invalid))
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }
        |> retryRequest
        
        
        disposable = req.start(next: { (status) in
            subscriber.putNext(status)
        }, completed:{
            subscriber.putCompletion()
        })
        
        return disposable
    }
}

public func updateUsername(account:Account, username:String) -> Signal<Bool,Void> {

    return account.network.request(Api.functions.account.updateUsername(username: username)) |> map { result in
            return TelegramUser(user: result)
        }
        |> `catch` { error -> Signal<TelegramUser?, MTRpcError> in
            return Signal <TelegramUser?,MTRpcError> { subscriber in
                subscriber.putNext(nil)
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }
        |> retryRequest
        |> mapToSignal({ (user) -> Signal<Bool, Void> in
            if let user = user {
                return account.postbox.modify { modifier -> Void in
                    updatePeers(modifier: modifier, peers: [user], update: { (previous, updated) -> Peer? in
                        return updated
                    })
                } |> map({true})
            } else {
                return .single(false)
            }
        })
    
    
}
