import Foundation
import Postbox
import SwiftSignalKit


func _internal_removePeerChat(account: Account, peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool = false) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        _internal_removePeerChat(account: account, transaction: transaction, mediaBox: account.postbox.mediaBox, peerId: peerId, reportChatSpam: reportChatSpam, deleteGloballyIfPossible: deleteGloballyIfPossible)
    }
}

func _internal_terminateSecretChat(transaction: Transaction, peerId: PeerId, requestRemoteHistoryRemoval: Bool) {
    if let state = transaction.getPeerChatState(peerId) as? SecretChatState, state.embeddedState != .terminated {
        let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: SecretChatOutgoingOperationContents.terminate(reportSpam: false, requestRemoteHistoryRemoval: requestRemoteHistoryRemoval), state: state).withUpdatedEmbeddedState(.terminated)
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

func _internal_removePeerChat(account: Account, transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool) {
    if let _ = transaction.getPeerChatInterfaceState(peerId) {
        transaction.setPeerChatInterfaceState(peerId, state: nil)
    }
    _internal_updateChatListFiltersInteractively(transaction: transaction, { filters in
        var updatedFilters: [ChatListFilter] = []
        for i in 0 ..< filters.count {
            let filter = filters[i]
            if case let .filter(id, title, emoticon, data) = filter {
                var updatedData = data
                if updatedData.includePeers.peers.contains(peerId) {
                    updatedData.includePeers.setPeers(data.includePeers.peers.filter { $0 != peerId })
                }
                if updatedData.excludePeers.contains(peerId) {
                    updatedData.excludePeers = data.excludePeers.filter { $0 != peerId }
                }
                updatedFilters.append(.filter(id: id, title: title, emoticon: emoticon, data: updatedData))
            } else {
                updatedFilters.append(filter)
            }
        }
        return updatedFilters
    })
    if peerId.namespace == Namespaces.Peer.SecretChat {
        if let state = transaction.getPeerChatState(peerId) as? SecretChatState, state.embeddedState != .terminated {
            let updatedState = addSecretChatOutgoingOperation(transaction: transaction, peerId: peerId, operation: SecretChatOutgoingOperationContents.terminate(reportSpam: reportChatSpam, requestRemoteHistoryRemoval: deleteGloballyIfPossible), state: state).withUpdatedEmbeddedState(.terminated)
            if updatedState != state {
                transaction.setPeerChatState(peerId, state: updatedState)
                if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                    updatePeers(transaction: transaction, peers: [peer.withUpdatedEmbeddedState(updatedState.embeddedState.peerState)], update: { _, updated in
                        return updated
                    })
                }
            }
        }
        _internal_clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId, namespaces: .all)
        transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
        transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, itemId: RecentPeerItemId(peerId).rawValue)
    } else {
        cloudChatAddRemoveChatOperation(transaction: transaction, peerId: peerId, reportChatSpam: reportChatSpam, deleteGloballyIfPossible: deleteGloballyIfPossible)
        if peerId.namespace == Namespaces.Peer.CloudUser  {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
            _internal_clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId, namespaces: .all)
        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
            _internal_clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId, namespaces: .all)
        } else {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
        }
    }
    transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.RecentlySearchedPeerIds, itemId: RecentPeerItemId(peerId).rawValue)
    
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        transaction.clearItemCacheCollection(collectionId: Namespaces.CachedItemCollection.cachedGroupCallDisplayAsPeers)
    }
}
