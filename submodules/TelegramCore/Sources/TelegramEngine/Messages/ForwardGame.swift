import Foundation
import Postbox
internal import TelegramApi
import SwiftSignalKit

public enum SendBotGameError {
    case generic
}

func _internal_sendBotGame(account: Account, botPeerId: PeerId, game: String, to peerId: PeerId, threadId: Int64?) -> Signal<Void, SendBotGameError> {
    return account.postbox.transaction { transaction -> Signal<Void, SendBotGameError> in
        guard !game.isEmpty, let botPeer = transaction.getPeer(botPeerId), let inputBot = apiInputUser(botPeer), let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }

        var flags: Int32 = 1 << 7
        var replyTo: Api.InputReplyTo?
        if let threadId {
            flags |= 1 << 0
            let threadMessageId = Int32(clamping: threadId)
            let replyFlags: Int32 = 1 << 0
            replyTo = .inputReplyToMessage(.init(flags: replyFlags, replyToMsgId: threadMessageId, topMsgId: threadMessageId, replyToPeerId: nil, quoteText: nil, quoteEntities: nil, quoteOffset: nil, monoforumPeerId: nil, todoItemId: nil, pollOption: nil, quoteRich: nil))
        }

        return account.network.request(Api.functions.messages.sendMedia(flags: flags, peer: inputPeer, replyTo: replyTo, media: .inputMediaGame(.init(id: .inputGameShortName(.init(botId: inputBot, shortName: game)))), message: "", randomId: Int64.random(in: Int64.min ... Int64.max), replyMarkup: nil, entities: nil, scheduleDate: nil, scheduleRepeatPeriod: nil, sendAs: nil, quickReplyShortcut: nil, effect: nil, allowPaidStars: nil, suggestedPost: nil))
        |> mapError { _ -> SendBotGameError in
            return .generic
        }
        |> mapToSignal { updates -> Signal<Void, SendBotGameError> in
            account.stateManager.addUpdates(updates)
            return .complete()
        }
    }
    |> castError(SendBotGameError.self)
    |> switchToLatest
}

func _internal_forwardGameWithScore(account: Account, messageId: MessageId, to peerId: PeerId, threadId: Int64?, as sendAsPeerId: PeerId?) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let _ = transaction.getMessage(messageId), let fromPeer = transaction.getPeer(messageId.peerId), let fromInputPeer = apiInputPeer(fromPeer), let toPeer = transaction.getPeer(peerId), let toInputPeer = apiInputPeer(toPeer) {
            var flags: Int32 = 1 << 8
            
            var sendAsInputPeer: Api.InputPeer?
            if let sendAsPeerId = sendAsPeerId, let sendAsPeer = transaction.getPeer(sendAsPeerId), let inputPeer = apiInputPeerOrSelf(sendAsPeer, accountPeerId: account.peerId) {
                sendAsInputPeer = inputPeer
                flags |= (1 << 13)
            }
            
            return account.network.request(Api.functions.messages.forwardMessages(flags: flags, fromPeer: fromInputPeer, id: [messageId.id], randomId: [Int64.random(in: Int64.min ... Int64.max)], toPeer: toInputPeer, topMsgId: threadId.flatMap { Int32(clamping: $0) }, replyTo: nil, scheduleDate: nil, scheduleRepeatPeriod: nil, sendAs: sendAsInputPeer, quickReplyShortcut: nil, effect: nil, videoTimestamp: nil, allowPaidStars: nil, suggestedPost: nil))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                if let updates = updates {
                    account.stateManager.addUpdates(updates)
                }
                return .complete()
            }
        }
        return .complete()
    } |> switchToLatest
}
