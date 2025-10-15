import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

private func _internal_updateExtendedMediaById(account: Account, peerId: EnginePeer.Id, messageIds: [EngineMessage.Id]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Peer? in
        if let peer = transaction.getPeer(peerId) {
            return peer
        } else {
            return nil
        }
    }
    |> mapToSignal { peer -> Signal<Never, NoError> in
        guard let peer = peer, let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.getExtendedMedia(peer: inputPeer, id: messageIds.map { $0.id }))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Never, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
            }
            return .complete()
        }
    }
}

func _internal_updateExtendedMedia(account: Account, messageIds: [EngineMessage.Id]) -> Signal<Never, NoError> {
    var signals: [Signal<Never, NoError>] = []
    for (peerId, messageIds) in messagesIdsGroupedByPeerId(messageIds) {
        signals.append(_internal_updateExtendedMediaById(account: account, peerId: peerId, messageIds: messageIds))
    }
    return combineLatest(signals)
    |> ignoreValues
}
