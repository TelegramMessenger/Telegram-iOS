import Foundation
import Postbox
internal import TelegramApi
import SwiftSignalKit

public struct ExportedNoPaidMessagesToken: Equatable {
    public let token: String
    public let url: String
    public let expires: Int32?

    public init(token: String, url: String, expires: Int32?) {
        self.token = token
        self.url = url
        self.expires = expires
    }
}

public enum ImportNoPaidMessagesTokenError {
    case invalidToken
    case generic
}

func _internal_exportNoPaidMessagesToken(account: Account, revoke: Bool, temporary: Bool) -> Signal<ExportedNoPaidMessagesToken?, NoError> {
    var flags: Int32 = 0
    if revoke {
        flags |= 1 << 0
    }
    if temporary {
        flags |= 1 << 1
    }
    return account.network.request(Api.functions.contacts.exportNoPaidMessagesToken(flags: flags))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.ExportedNoPaidMessagesToken?, NoError> in
        return .single(nil)
    }
    |> map { result -> ExportedNoPaidMessagesToken? in
        guard let result, case let .exportedNoPaidMessagesToken(data) = result else {
            return nil
        }
        return ExportedNoPaidMessagesToken(token: data.token, url: data.url, expires: data.expires)
    }
}

func _internal_importNoPaidMessagesToken(account: Account, peerId: PeerId, token: String) -> Signal<EnginePeer, ImportNoPaidMessagesTokenError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> castError(ImportNoPaidMessagesTokenError.self)
    |> mapToSignal { inputUser -> Signal<EnginePeer, ImportNoPaidMessagesTokenError> in
        guard let inputUser else {
            return .fail(.invalidToken)
        }
        return account.network.request(Api.functions.contacts.importNoPaidMessagesToken(userId: inputUser, token: token))
        |> mapError { error -> ImportNoPaidMessagesTokenError in
            if error.errorDescription == "NO_PAID_MESSAGES_TOKEN_INVALID" || error.errorDescription == "USER_ID_INVALID" {
                return .invalidToken
            }
            return .generic
        }
        |> mapToSignal { user -> Signal<EnginePeer, ImportNoPaidMessagesTokenError> in
            return account.postbox.transaction { transaction -> EnginePeer? in
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: [user]))
                return transaction.getPeer(user.peerId).flatMap(EnginePeer.init)
            }
            |> castError(ImportNoPaidMessagesTokenError.self)
            |> mapToSignal { peer -> Signal<EnginePeer, ImportNoPaidMessagesTokenError> in
                guard let peer else {
                    return .fail(.generic)
                }
                return .single(peer)
            }
        }
    }
}
