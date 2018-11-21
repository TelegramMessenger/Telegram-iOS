import Foundation
import Display
import Postbox
import SwiftSignalKit
import TelegramCore


/*

 */

func peerInfoController(account: Account, peer: Peer) -> ViewController? {
    if let _ = peer as? TelegramGroup  {
        return groupInfoController(account: account, peerId: peer.id)
    } else if let channel = peer as? TelegramChannel {
        if case .group = channel.info {
            return groupInfoController(account: account, peerId: peer.id)
        } else {
            return channelInfoController(account: account, peerId: peer.id)
        }
    } else if peer is TelegramUser || peer is TelegramSecretChat {
        return userInfoController(account: account, peerId: peer.id)
    }
    return nil
}
