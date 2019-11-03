import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit

import SyncCore

public enum RequestMessageSelectPollOptionError {
    case generic
}

public func requestMessageSelectPollOption(account: Account, messageId: MessageId, opaqueIdentifier: Data?) -> Signal<Never, RequestMessageSelectPollOptionError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> castError(RequestMessageSelectPollOptionError.self)
    |> mapToSignal { peer in
        if let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.sendVote(peer: inputPeer, msgId: messageId.id, options: opaqueIdentifier.flatMap({ [Buffer(data: $0)] }) ?? []))
            |> mapError { _ -> RequestMessageSelectPollOptionError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Never, RequestMessageSelectPollOptionError> in
                account.stateManager.addUpdates(result)
                return .complete()
            }
        } else {
            return .complete()
        }
    }
}

public func requestClosePoll(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> (TelegramMediaPoll, Api.InputPeer)? in
        guard let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer) else {
            return nil
        }
        guard let message = transaction.getMessage(messageId) else {
            return nil
        }
        for media in message.media {
            if let poll = media as? TelegramMediaPoll {
                return (poll, inputPeer)
            }
        }
        return nil
    }
    |> mapToSignal { pollAndInputPeer -> Signal<Void, NoError> in
        guard let (poll, inputPeer) = pollAndInputPeer, poll.pollId.namespace == Namespaces.Media.CloudPoll else {
            return .complete()
        }
        var flags: Int32 = 0
        flags |= 1 << 14
        return network.request(Api.functions.messages.editMessage(flags: flags, peer: inputPeer, id: messageId.id, message: nil, media: .inputMediaPoll(poll: .poll(id: poll.pollId.id, flags: 1 << 0, question: poll.text, answers: poll.options.map({ $0.apiOption }))), replyMarkup: nil, entities: nil, scheduleDate: nil))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Void, NoError> in
            if let updates = updates {
                stateManager.addUpdates(updates)
            }
            return .complete()
        }
    }
}
