import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

func storedMessageFromSearchPeer(account: Account, peer: Peer) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        if transaction.getPeer(peer.id) == nil {
            updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                return updatedPeer
            })
        }
    }
}

func storedMessageFromSearch(account: Account, message: Message) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        if transaction.getMessage(message.id) == nil {
            for (_, peer) in message.peers {
                if transaction.getPeer(peer.id) == nil {
                    updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                        return updatedPeer
                    })
                }
            }
            
            let storeMessage = StoreMessage(id: .Id(message.id), globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: message.attributes, media: message.media)
            
            let _ = transaction.addMessages([storeMessage], location: .Random)
        }
    }
}
