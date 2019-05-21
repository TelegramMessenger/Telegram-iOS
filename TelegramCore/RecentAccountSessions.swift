import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func requestRecentAccountSessions(account: Account) -> Signal<[RecentAccountSession], NoError> {
    return account.network.request(Api.functions.account.getAuthorizations())
    |> retryRequest
    |> map { result -> [RecentAccountSession] in
        var sessions: [RecentAccountSession] = []
        switch result {
            case let .authorizations(authorizations):
                for authorization in authorizations {
                    sessions.append(RecentAccountSession(apiAuthorization: authorization))
                }
        }
        return sessions
    }
}

public enum TerminateSessionError {
    case generic
    case freshReset
}

public func terminateAccountSession(account: Account, hash: Int64) -> Signal<Void, TerminateSessionError> {
    return account.network.request(Api.functions.account.resetAuthorization(hash: hash))
    |> mapError { error -> TerminateSessionError in
        if error.errorCode == 406 {
            return .freshReset
        }
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, TerminateSessionError> in
        return .single(Void())
    }
}

public func terminateOtherAccountSessions(account: Account) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.auth.resetAuthorizations())
    |> retryRequest
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .single(Void())
    }
}
