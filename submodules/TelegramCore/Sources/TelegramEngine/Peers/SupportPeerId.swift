import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_supportPeerId(account: Account) -> Signal<PeerId?, NoError> {
    let accountPeerId = account.peerId
    
    return account.network.request(Api.functions.help.getSupport())
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.help.Support?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<PeerId?, NoError> in
        if let support = support {
            switch support {
            case let .support(_, user):
                return account.postbox.transaction { transaction -> PeerId in
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [], users: [user])
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                    return user.peerId
                }
            }
        }
        return .single(nil)
    }
}
