import Foundation
import Postbox
import SwiftSignalKit

func _internal_storedMessageFromSearchPeer(account: Account, peer: Peer) -> Signal<Peer, NoError> {
    return account.postbox.transaction { transaction -> Peer in
        if transaction.getPeer(peer.id) == nil {
            updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                return updatedPeer
            })
        }
        if let group = transaction.getPeer(peer.id) as? TelegramGroup, let migrationReference = group.migrationReference {
            if let migrationPeer = transaction.getPeer(migrationReference.peerId) {
                return migrationPeer
            } else {
                return peer
            }
        }
        return peer
    }
}

func _internal_storedMessageFromSearchPeers(account: Account, peers: [Peer]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        for peer in peers {
            if transaction.getPeer(peer.id) == nil {
                updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                    return updatedPeer
                })
            }
        }
    }
    |> ignoreValues
}

func _internal_storeMessageFromSearch(transaction: Transaction, message: Message) {
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
