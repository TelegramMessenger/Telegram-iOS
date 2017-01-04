import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

func storedMessageFromSearchPeer(account: Account, peer: Peer) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        if modifier.getPeer(peer.id) == nil {
            modifier.updatePeers([peer], update: { previousPeer, updatedPeer in
                return updatedPeer
            })
        }
    }
}
