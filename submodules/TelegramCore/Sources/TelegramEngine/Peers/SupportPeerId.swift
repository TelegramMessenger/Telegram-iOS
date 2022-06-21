import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_supportPeerId(account: Account) -> Signal<PeerId?, NoError> {
    return account.network.request(Api.functions.help.getSupport())
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.help.Support?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<PeerId?, NoError> in
        if let support = support {
            switch support {
                case let .support(phoneNumber: _, user: user):
                    let user = TelegramUser(user: user)
                    return account.postbox.transaction { transaction -> PeerId in
                        updatePeers(transaction: transaction, peers: [user], update: { (previous, updated) -> Peer? in
                            return updated
                        })
                        return user.id
                    }
            }
        }
        return .single(nil)
    }
}
