import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func removePeerChat(postbox: Postbox, peerId: PeerId, reportChatSpam: Bool) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        removePeerChat(transaction: transaction, mediaBox: postbox.mediaBox, peerId: peerId, reportChatSpam: reportChatSpam)
    }
}

public func removePeerChat(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, reportChatSpam: Bool) {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        if let state = transaction.getPeerChatState(peerId) as? SecretChatState {
            
            let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: SecretChatOutgoingOperationContents.terminate(reportSpam: reportChatSpam), state: state).withUpdatedEmbeddedState(.terminated)
            if updatedState != state {
                transaction.setPeerChatState(peerId, state: updatedState)
                if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                    updatePeers(transaction: transaction, peers: [peer.withUpdatedEmbeddedState(updatedState.embeddedState.peerState)], update: { _, updated in
                        return updated
                    })
                }
            }
        }
        clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId)
        transaction.updatePeerChatListInclusion(peerId, inclusion: .never)
        transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, itemId: RecentPeerItemId(peerId).rawValue)
    } else {
        cloudChatAddRemoveChatOperation(transaction: transaction, peerId: peerId, reportChatSpam: reportChatSpam)
        if peerId.namespace == Namespaces.Peer.CloudUser  {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessages)
            clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId)
        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .never)
            clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId)
        } else {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .never)
        }
    }
    transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, itemId: RecentPeerItemId(peerId).rawValue)
}
