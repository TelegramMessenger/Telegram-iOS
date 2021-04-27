import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum CreateGroupError {
    case generic
    case privacy
    case restricted
    case tooMuchJoined
    case tooMuchLocationBasedGroups
    case serverProvided(String)
}

func _internal_createGroup(account: Account, title: String, peerIds: [PeerId]) -> Signal<PeerId?, CreateGroupError> {
    return account.postbox.transaction { transaction -> Signal<PeerId?, CreateGroupError> in
        var inputUsers: [Api.InputUser] = []
        for peerId in peerIds {
            if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
                inputUsers.append(inputUser)
            } else {
                return .single(nil)
            }
        }
        return account.network.request(Api.functions.messages.createChat(users: inputUsers, title: title))
        |> mapError { error -> CreateGroupError in
            if error.errorDescription == "USERS_TOO_FEW" {
                return .privacy
            }
            return .generic
        }
        |> mapToSignal { updates -> Signal<PeerId?, CreateGroupError> in
            account.stateManager.addUpdates(updates)
            if let message = updates.messages.first, let peerId = apiMessagePeerId(message) {
                return account.postbox.multiplePeersView([peerId])
                |> filter { view in
                    return view.peers[peerId] != nil
                }
                |> take(1)
                |> castError(CreateGroupError.self)
                |> map { _ in
                    return peerId
                }
            } else {
                return .single(nil)
            }
        }
    }
    |> castError(CreateGroupError.self)
    |> switchToLatest
}
