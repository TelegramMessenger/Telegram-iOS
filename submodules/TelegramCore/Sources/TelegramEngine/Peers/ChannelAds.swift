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

public enum AdMessagesEnableError {
    case generic
}

func _internal_updateAdMessagesEnabled(account: Account, enabled: Bool) -> Signal<Never, AdMessagesEnableError> {
    return account.network.request(Api.functions.account.toggleSponsoredMessages(enabled: enabled ? .boolTrue : .boolFalse))
    |> `catch` { error -> Signal<Api.Bool, AdMessagesEnableError> in
        return .fail(.generic)
    }
    |> mapToSignal { result -> Signal<Never, AdMessagesEnableError> in
        guard case .boolTrue = result else {
            return .fail(.generic)
        }
        return account.postbox.transaction { transaction -> Void in
            transaction.updatePeerCachedData(peerIds: [account.peerId], update: { peerId, currentData in
                if let currentData = currentData as? CachedUserData {
                    var flags = currentData.flags
                    if enabled {
                        flags.insert(.adsEnabled)
                    } else {
                        flags.remove(.adsEnabled)
                    }
                    return currentData.withUpdatedFlags(flags)
                } else {
                    return currentData
                }
            })
        }
        |> castError(AdMessagesEnableError.self)
        |> ignoreValues
    }
}
