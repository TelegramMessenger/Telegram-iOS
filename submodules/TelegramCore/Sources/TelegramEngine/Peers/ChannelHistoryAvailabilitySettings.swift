import Postbox
import TelegramApi
import SwiftSignalKit


public enum ChannelHistoryAvailabilityError {
    case generic
    case hasNotPermissions
}

func _internal_updateChannelHistoryAvailabilitySettingsInteractively(postbox: Postbox, network: Network, accountStateManager: AccountStateManager, peerId: PeerId, historyAvailableForNewMembers: Bool) -> Signal<Void, ChannelHistoryAvailabilityError> {
    return postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> castError(ChannelHistoryAvailabilityError.self)
    |> mapToSignal { peer in
        
        guard let peer = peer, let inputChannel = apiInputChannel(peer) else {
            return .fail(.generic)
        }
        
        return network.request(Api.functions.channels.togglePreHistoryHidden(channel: inputChannel, enabled: historyAvailableForNewMembers ? .boolFalse : .boolTrue))
            |> `catch` { error -> Signal<Api.Updates, ChannelHistoryAvailabilityError> in
                if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                    return .fail(.hasNotPermissions)
                }
                return .fail(.generic)
            }
            |> mapToSignal { updates -> Signal<Void, ChannelHistoryAvailabilityError> in
                accountStateManager.addUpdates(updates)
                return postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, currentData in
                        if let currentData = currentData as? CachedChannelData {
                            var flags = currentData.flags
                            if historyAvailableForNewMembers {
                                flags.insert(.preHistoryEnabled)
                            } else {
                                flags.remove(.preHistoryEnabled)
                            }
                            return currentData.withUpdatedFlags(flags)
                        } else {
                            return currentData
                        }
                    })
                } |> castError(ChannelHistoryAvailabilityError.self)
        }
        
    }
}
