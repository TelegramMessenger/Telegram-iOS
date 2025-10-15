import Foundation
import Postbox
import TelegramApi


struct ChannelUpdate {
    let update: Api.Update
    let ptsRange: (Int32, Int32)?
}

func channelUpdatesByPeerId(updates: [ChannelUpdate]) -> [PeerId: [ChannelUpdate]] {
    var grouped: [PeerId: [ChannelUpdate]] = [:]
    
    for update in updates {
        var peerId: PeerId?
        switch update.update {
            case let .updateNewChannelMessage(message, _, _):
                peerId = apiMessagePeerId(message)
            case let .updateDeleteChannelMessages(channelId, _, _, _):
                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
            case let .updateEditChannelMessage(message, _, _):
                peerId = apiMessagePeerId(message)
            case let .updateChannelWebPage(channelId, _, _, _):
                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
            default:
                break
        }
        
        if let peerId = peerId {
            if grouped[peerId] == nil {
                grouped[peerId] = [update]
            } else {
                grouped[peerId]!.append(update)
            }
        }
    }
    
    return grouped
}
