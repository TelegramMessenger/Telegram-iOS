import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

func requestRecentAccountSessions(account: Account) -> Signal<([RecentAccountSession], Int32), NoError> {
    return account.network.request(Api.functions.account.getAuthorizations())
    |> retryRequest
    |> map { result -> ([RecentAccountSession], Int32) in
        var sessions: [RecentAccountSession] = []
        var ttlDays: Int32 = 1
        switch result {
            case let .authorizations(authorizationTtlDays, authorizations):
                for authorization in authorizations {
                    sessions.append(RecentAccountSession(apiAuthorization: authorization))
                }
            ttlDays = authorizationTtlDays
        }
        return (sessions, ttlDays)
    }
}

public enum TerminateSessionError {
    case generic
    case freshReset
}

func terminateAccountSession(account: Account, hash: Int64) -> Signal<Void, TerminateSessionError> {
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

func terminateOtherAccountSessions(account: Account) -> Signal<Void, TerminateSessionError> {
    return account.network.request(Api.functions.auth.resetAuthorizations())
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

public enum UpadteAuthorizationTTLError {
    case generic
}

func setAuthorizationTTL(account: Account, ttl: Int32) -> Signal<Void, UpadteAuthorizationTTLError> {
    return account.network.request(Api.functions.account.setAuthorizationTTL(authorizationTtlDays: ttl))
    |> mapError { error -> UpadteAuthorizationTTLError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, UpadteAuthorizationTTLError> in
        return .single(Void())
    }
}

public enum UpdateSessionError {
    case generic
}

func updateAccountSessionAcceptsSecretChats(account: Account, hash: Int64, accepts: Bool) -> Signal<Void, UpdateSessionError> {
    return account.network.request(Api.functions.account.changeAuthorizationSettings(flags: 1 << 0, hash: hash, encryptedRequestsDisabled: accepts ? .boolFalse : .boolTrue, callRequestsDisabled: nil))
    |> mapError { error -> UpdateSessionError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, UpdateSessionError> in
        return .single(Void())
    }
}

func updateAccountSessionAcceptsIncomingCalls(account: Account, hash: Int64, accepts: Bool) -> Signal<Void, UpdateSessionError> {
    return account.network.request(Api.functions.account.changeAuthorizationSettings(flags: 1 << 1, hash: hash, encryptedRequestsDisabled: nil, callRequestsDisabled: accepts ? .boolFalse : .boolTrue))
    |> mapError { error -> UpdateSessionError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Void, UpdateSessionError> in
        return .single(Void())
    }
}
