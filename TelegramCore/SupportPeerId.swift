//
//  AskQuestion.swift
//  Telegram
//
//  Created by keepcoder on 10/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

import TelegramCoreMac


public func supportPeerId(account:Account) -> Signal<PeerId?, Void> {
    return account.network.request(Api.functions.help.getSupport())
        |> map { Optional($0) }
        |> `catch` { _ in
            return Signal<Api.help.Support?, NoError>.single(nil)
        }
        |> mapToSignal { support -> Signal<PeerId?, NoError> in
            if let support = support {
                switch support {
                case let .support(phoneNumber: _, user: user):
                    let user = TelegramUser(user: user)
                    return account.postbox.modify { modifier -> PeerId in
                        updatePeers(modifier: modifier, peers: [user], update: { (previous, updated) -> Peer? in
                            return updated
                        })
                        return user.id
                    }
                }
            }
            return .single(nil)
    }
}
