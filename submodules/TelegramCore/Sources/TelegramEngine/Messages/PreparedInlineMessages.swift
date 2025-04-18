import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public struct PreparedInlineMessage: Equatable {
    public let botId: EnginePeer.Id
    public let queryId: Int64
    public let result: ChatContextResult
    public let peerTypes: ReplyMarkupButtonAction.PeerTypes
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
                case let .preparedInlineMessage(queryId, result, apiPeerTypes, cacheTime, users):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: users))
                    let _ = cacheTime
                    return PreparedInlineMessage(
                        botId: botId,
                        queryId: queryId,
                        result: ChatContextResult(apiResult: result, queryId: queryId),
                        peerTypes: ReplyMarkupButtonAction.PeerTypes(apiType: apiPeerTypes)
                    )
                }
            }
        }
    }
}

func _internal_checkBotDownload(account: Account, botId: EnginePeer.Id, fileName: String, url: String) -> Signal<Bool, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(botId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputBot -> Signal<Bool, NoError> in
        guard let inputBot else {
            return .single(false)
        }
        return account.network.request(Api.functions.bots.checkDownloadFileParams(bot: inputBot, fileName: fileName, url: url))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> map { value in
            switch value {
            case .boolTrue:
                return true
            case .boolFalse:
                return false
            }
        }
    }
}

