//
//  JoinGroup.swift
//  Telegram
//
//  Created by keepcoder on 11/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif


public func returnGroup(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
        |> take(1)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputUser = apiInputUser(peer) {
                return account.network.request(Api.functions.messages.addChatUser(chatId: peerId.id, userId: inputUser, fwdLimit: 50))
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
                return account.network.request(Api.functions.messages .deleteChatUser(chatId: peerId.id, userId: inputUser))
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

//[TLAPI_messages_addChatUser createWithChat_id:dialog.chat.n_id user_id:input fwd_limit:50]
