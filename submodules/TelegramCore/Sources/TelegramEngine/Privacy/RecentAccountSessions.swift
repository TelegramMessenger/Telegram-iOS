import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

func requestRecentAccountSessions(account: Account) -> Signal<[RecentAccountSession], NoError> {
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
