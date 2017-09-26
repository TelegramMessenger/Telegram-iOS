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

func storedMessageFromSearch(account: Account, message: Message) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        if modifier.getMessage(message.id) == nil {
            for (_, peer) in message.peers {
                if modifier.getPeer(peer.id) == nil {
                    updatePeers(modifier: modifier, peers: [peer], update: { previousPeer, updatedPeer in
                        return updatedPeer
                    })
                }
            }
            
            let storeMessage = StoreMessage(id: .Id(message.id), globallyUniqueId: message.globallyUniqueId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: message.attributes, media: message.media)
            
            let _ = modifier.addMessages([storeMessage], location: .Random)
        }
    }
}
