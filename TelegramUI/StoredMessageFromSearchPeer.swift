import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

func storedMessageFromSearchPeer(account: Account, peer: Peer) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        if modifier.getPeer(peer.id) == nil {
            updatePeers(modifier: modifier, peers: [peer], update: { previousPeer, updatedPeer in
                return updatedPeer
            })
        }
    }
}
