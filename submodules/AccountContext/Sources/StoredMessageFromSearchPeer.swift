import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public func storedMessageFromSearchPeer(account: Account, peer: Peer) -> Signal<PeerId, NoError> {
    return account.postbox.transaction { transaction -> PeerId in
        if transaction.getPeer(peer.id) == nil {
            updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                return updatedPeer
            })
        }
        if let group = transaction.getPeer(peer.id) as? TelegramGroup, let migrationReference = group.migrationReference {
            return migrationReference.peerId
        }
        return peer.id
    }
}

public func storedMessageFromSearch(account: Account, message: Message) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        if transaction.getMessage(message.id) == nil {
            for (_, peer) in message.peers {
                if transaction.getPeer(peer.id) == nil {
                    updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                        return updatedPeer
                    })
                }
            }
            
            let storeMessage = StoreMessage(id: .Id(message.id), globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: message.attributes, media: message.media)
            
            let _ = transaction.addMessages([storeMessage], location: .Random)
        }
    }
}

public func storeMessageFromSearch(transaction: Transaction, message: Message) {
    if transaction.getMessage(message.id) == nil {
        for (_, peer) in message.peers {
            if transaction.getPeer(peer.id) == nil {
                updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                    return updatedPeer
                })
            }
        }
        
        let storeMessage = StoreMessage(id: .Id(message.id), globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: message.attributes, media: message.media)
        
        let _ = transaction.addMessages([storeMessage], location: .Random)
    }
}
