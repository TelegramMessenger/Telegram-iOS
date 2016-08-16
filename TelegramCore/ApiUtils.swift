import Foundation
import Postbox

func apiInputPeer(_ peer: Peer) -> Api.InputPeer? {
    switch peer {
        case let user as TelegramUser where user.accessHash != nil:
            return Api.InputPeer.inputPeerUser(userId: user.id.id, accessHash: user.accessHash!)
        case let group as TelegramGroup:
            if group.id.namespace == Namespaces.Peer.CloudGroup {
                return Api.InputPeer.inputPeerChat(chatId: group.id.id)
            } else if group.id.namespace == Namespaces.Peer.CloudChannel {
                return Api.InputPeer.inputPeerChannel(channelId: group.id.id, accessHash: group.accessHash)
            } else {
                return nil
            }
        default:
            return nil
    }
}

func apiInputChannel(_ peer: Peer) -> Api.InputChannel? {
    if let channel = peer as? TelegramGroup, channel.accessHash != 0 {
        return Api.InputChannel.inputChannel(channelId: channel.id.id, accessHash: channel.accessHash)
    } else {
        return nil
    }
}
