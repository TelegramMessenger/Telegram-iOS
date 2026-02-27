import Postbox
import TelegramApi
import SwiftSignalKit


public enum UpdateChannelSlowModeError {
    case generic
    case tooManyChannels
}

func _internal_updateChannelSlowModeInteractively(postbox: Postbox, network: Network, accountStateManager: AccountStateManager, peerId: PeerId, timeout: Int32?) -> Signal<Void, UpdateChannelSlowModeError> {
    return postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> castError(UpdateChannelSlowModeError.self)
    |> mapToSignal { peer in
        guard let peer = peer, let inputChannel = apiInputChannel(peer) else {
            return .fail(.generic)
        }
        
        return network.request(Api.functions.channels.toggleSlowMode(channel: inputChannel, seconds: timeout ?? 0))
        |> `catch` { _ -> Signal<Api.Updates, UpdateChannelSlowModeError> in
            return .fail(.generic)
        }
        |> mapToSignal { updates -> Signal<Void, UpdateChannelSlowModeError> in
            accountStateManager.addUpdates(updates)
            return postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, currentData in
                    let currentData = currentData as? CachedChannelData ?? CachedChannelData()
                    return currentData.withUpdatedSlowModeTimeout(timeout)
                })
            }
            |> castError(UpdateChannelSlowModeError.self)
        }
    }
}
