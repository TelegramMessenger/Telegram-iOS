import Foundation
import Postbox
import TelegramCore
import Display

func chatInfoController(account: Account, peer: Peer) -> ViewController? {
    if let user = peer as? TelegramUser {
        return UserInfoController(account: account, peerId: peer.id)
    } else if let channel = peer as? TelegramChannel {
        switch channel.info {
            case .broadcast:
                return ChannelBroadcastInfoController(account: account, peerId: peer.id)
            case .group:
                break
        }
    } else {
        return PeerMediaCollectionController(account: account, peerId: peer.id)
    }
    return nil
}

func peerSharedMediaController(account: Account, peerId: PeerId) -> ViewController? {
    return PeerMediaCollectionController(account: account, peerId: peerId)
}
