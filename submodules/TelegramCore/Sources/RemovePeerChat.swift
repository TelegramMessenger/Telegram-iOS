import Foundation
import Postbox
import SwiftSignalKit

import SyncCore

public func removePeerChat(account: Account, peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool = false) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        removePeerChat(account: account, transaction: transaction, mediaBox: account.postbox.mediaBox, peerId: peerId, reportChatSpam: reportChatSpam, deleteGloballyIfPossible: deleteGloballyIfPossible)
    }
}

public func terminateSecretChat(transaction: Transaction, peerId: PeerId) {
    if let state = transaction.getPeerChatState(peerId) as? SecretChatState, state.embeddedState != .terminated {
        let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: SecretChatOutgoingOperationContents.terminate(reportSpam: false), state: state).withUpdatedEmbeddedState(.terminated)
        if updatedState != state {
            transaction.setPeerChatState(peerId, state: updatedState)
            if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                updatePeers(transaction: transaction, peers: [peer.withUpdatedEmbeddedState(updatedState.embeddedState.peerState)], update: { _, updated in
                    return updated
                })
            }
        }
    }
}

public func removePeerChat(account: Account, transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool) {
    if let _ = transaction.getPeerChatInterfaceState(peerId) {
        transaction.updatePeerChatInterfaceState(peerId, update: { current in
            if let current = current {
                return account.auxiliaryMethods.updatePeerChatInputState(current, nil)
            } else {
                return nil
            }
        })
    }
    if peerId.namespace == Namespaces.Peer.SecretChat {
        if let state = transaction.getPeerChatState(peerId) as? SecretChatState, state.embeddedState != .terminated {
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
        clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId, namespaces: .all)
        transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
        transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, itemId: RecentPeerItemId(peerId).rawValue)
    } else {
        cloudChatAddRemoveChatOperation(transaction: transaction, peerId: peerId, reportChatSpam: reportChatSpam, deleteGloballyIfPossible: deleteGloballyIfPossible)
        if peerId.namespace == Namespaces.Peer.CloudUser  {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
            clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId, namespaces: .all)
        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
            clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId, namespaces: .all)
        } else {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
        }
    }
    transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, itemId: RecentPeerItemId(peerId).rawValue)
}
