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
            case let .updateNewChannelMessage(updateNewChannelMessageData):
                let (message, _, _) = (updateNewChannelMessageData.message, updateNewChannelMessageData.pts, updateNewChannelMessageData.ptsCount)
                peerId = apiMessagePeerId(message)
            case let .updateDeleteChannelMessages(updateDeleteChannelMessagesData):
                let (channelId, _, _, _) = (updateDeleteChannelMessagesData.channelId, updateDeleteChannelMessagesData.messages, updateDeleteChannelMessagesData.pts, updateDeleteChannelMessagesData.ptsCount)
                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
            case let .updateEditChannelMessage(updateEditChannelMessageData):
                let (message, _, _) = (updateEditChannelMessageData.message, updateEditChannelMessageData.pts, updateEditChannelMessageData.ptsCount)
                peerId = apiMessagePeerId(message)
            case let .updateChannelWebPage(updateChannelWebPageData):
                let (channelId, _, _, _) = (updateChannelWebPageData.channelId, updateChannelWebPageData.webpage, updateChannelWebPageData.pts, updateChannelWebPageData.ptsCount)
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
