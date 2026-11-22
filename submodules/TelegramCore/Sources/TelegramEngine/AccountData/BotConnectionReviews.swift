import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

func _internal_confirmBotConnectionReview(account: Account, botId: PeerId) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.account.getConnectedBots())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.account.ConnectedBots?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        guard let result else {
            return .complete()
        }
        
        return account.postbox.transaction { transaction -> Api.InputUser? in
            switch result {
            case let .connectedBots(connectedBotsData):
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: connectedBotsData.users))
            }
            return transaction.getPeer(botId).flatMap(apiInputUser)
        }
        |> mapToSignal { inputUser -> Signal<Never, NoError> in
            guard let inputUser else {
                return .complete()
            }
            return account.network.request(Api.functions.account.confirmBotConnection(botId: inputUser))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
        }
    }
}
