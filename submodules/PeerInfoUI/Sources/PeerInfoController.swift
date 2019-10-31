import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore
import AccountContext

public func peerInfoControllerImpl(context: AccountContext, peer: Peer, mode: PeerInfoControllerMode) -> ViewController? {
    if let _ = peer as? TelegramGroup  {
        return groupInfoController(context: context, peerId: peer.id)
    } else if let channel = peer as? TelegramChannel {
        if case .group = channel.info {
            return groupInfoController(context: context, peerId: peer.id)
        } else {
            return channelInfoController(context: context, peerId: peer.id)
        }
    } else if peer is TelegramUser || peer is TelegramSecretChat {
        return userInfoController(context: context, peerId: peer.id, mode: mode)
    }
    return nil
}
