import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_toggleChatCustomRanks(account: Account, peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.toggleChatCustomRanks(peer: inputPeer, enabled: enabled ? .boolTrue : .boolFalse))
            |> `catch` { _ in
                return .complete()
            }
            |> map { updates -> Void in
                account.stateManager.addUpdates(updates)
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public enum UpdateChatRankError {
    case generic
}

func _internal_updateChatRank(account: Account, peerId: PeerId, userId: PeerId, rank: String?) -> Signal<Never, UpdateChatRankError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdateChatRankError> in
        if let user = transaction.getPeer(userId), let inputUser = apiInputPeer(user), let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.editChatParticipantRank(peer: inputPeer, participant: inputUser, rank: rank ?? ""))
            |> mapError { _ -> UpdateChatRankError in
                return .generic
            }
            |> map { updates -> Void in
                account.stateManager.addUpdates(updates)
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> UpdateChatRankError in }
    |> switchToLatest
    |> ignoreValues
}


