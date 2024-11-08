import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public struct PreparedInlineMessage: Equatable {
    let queryId: Int64
    let result: ChatContextResult
    let peerTypes: [ReplyMarkupButtonAction.PeerTypes]
}

func _internal_getPreparedInlineMessage(account: Account, botId: EnginePeer.Id, id: String) -> Signal<PreparedInlineMessage?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(botId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputBot -> Signal<PreparedInlineMessage?, NoError> in
        guard let inputBot else {
            return .single(nil)
        }
        return account.network.request(Api.functions.messages.getPreparedInlineMessage(bot: inputBot, id: id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.PreparedInlineMessage?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<PreparedInlineMessage?, NoError> in
            guard let result else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> PreparedInlineMessage? in
                switch result {
                case let .preparedInlineMessage(queryId, result, peerTypes, users):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: users))
                    
                    return PreparedInlineMessage(queryId: queryId, result: ChatContextResult(apiResult: result, queryId: queryId), peerTypes: peerTypes.compactMap { ReplyMarkupButtonAction.PeerTypes(apiType: $0) })
                }
            }
        }
    }
}
