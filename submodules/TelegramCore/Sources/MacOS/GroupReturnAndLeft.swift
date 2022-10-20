
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public func returnGroup(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(account.peerId)
        |> take(1)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputUser = apiInputUser(peer) {
                return account.network.request(Api.functions.messages.addChatUser(chatId: peerId.id._internalGetInt64Value(), userId: inputUser, fwdLimit: 50))
                    |> retryRequest
                    |> mapToSignal { updates -> Signal<Void, NoError> in
                        account.stateManager.addUpdates(updates)
                        return .complete()
                }
            } else {
                return .complete()
            }
    }
}

public func leftGroup(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(account.peerId)
        |> take(1)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputUser = apiInputUser(peer) {
                return account.network.request(Api.functions.messages.deleteChatUser(flags: 0, chatId: peerId.id._internalGetInt64Value(), userId: inputUser))
                    |> retryRequest
                    |> mapToSignal { updates -> Signal<Void, NoError> in
                        account.stateManager.addUpdates(updates)
                        return .complete()
                }
            } else {
                return .complete()
            }
    }
}

