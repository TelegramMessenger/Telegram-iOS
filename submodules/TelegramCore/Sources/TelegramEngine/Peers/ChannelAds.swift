import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum ChannelRestrictAdMessagesError {
    case generic
}

func _internal_updateChannelRestrictAdMessages(account: Account, peerId: PeerId, restricted: Bool) -> Signal<Never, ChannelRestrictAdMessagesError> {
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> castError(ChannelRestrictAdMessagesError.self)
    |> mapToSignal { peer in
        guard let peer = peer, let inputChannel = apiInputChannel(peer) else {
            return .fail(.generic)
        }
        
        return account.network.request(Api.functions.channels.restrictSponsoredMessages(channel: inputChannel, restricted: restricted ? .boolTrue : .boolFalse))
            |> `catch` { error -> Signal<Api.Updates, ChannelRestrictAdMessagesError> in
                return .fail(.generic)
            }
            |> mapToSignal { updates -> Signal<Never, ChannelRestrictAdMessagesError> in
                account.stateManager.addUpdates(updates)
                return account.postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, currentData in
                        if let currentData = currentData as? CachedChannelData {
                            var flags = currentData.flags
                            if restricted {
                                flags.insert(.adsRestricted)
                            } else {
                                flags.remove(.adsRestricted)
                            }
                            return currentData.withUpdatedFlags(flags)
                        } else {
                            return currentData
                        }
                    })
                } 
                |> castError(ChannelRestrictAdMessagesError.self)
                |> ignoreValues
        }
        
    }
}
