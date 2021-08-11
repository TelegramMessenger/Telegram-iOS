import Foundation
import Postbox
import SwiftSignalKit


public enum TogglePeerChatPinnedLocation {
    case group(PeerGroupId)
    case filter(Int32)
}

public enum TogglePeerChatPinnedResult {
    case done
    case limitExceeded(Int)
}

func _internal_toggleItemPinned(postbox: Postbox, location: TogglePeerChatPinnedLocation, itemId: PinnedItemId) -> Signal<TogglePeerChatPinnedResult, NoError> {
    return postbox.transaction { transaction -> TogglePeerChatPinnedResult in
        switch location {
        case let .group(groupId):
            var itemIds = transaction.getPinnedItemIds(groupId: groupId)
            let sameKind = itemIds.filter { item in
                switch itemId {
                    case let .peer(lhsPeerId):
                        if case let .peer(rhsPeerId) = item {
                            return (lhsPeerId.namespace == Namespaces.Peer.SecretChat) == (rhsPeerId.namespace == Namespaces.Peer.SecretChat) && lhsPeerId != rhsPeerId
                        } else {
                            return false
                        }
                }
                
            }
            
            let additionalCount: Int
            if let _ = itemIds.firstIndex(of: itemId) {
                additionalCount = -1
            } else {
                additionalCount = 1
            }
            
            let limitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
            let limitCount: Int
            if case .root = groupId {
                limitCount = Int(limitsConfiguration.maxPinnedChatCount)
            } else {
                limitCount = Int(limitsConfiguration.maxArchivedPinnedChatCount)
            }
            
            if sameKind.count + additionalCount > limitCount {
                return .limitExceeded(limitCount)
            } else {
                if let index = itemIds.firstIndex(of: itemId) {
                    itemIds.remove(at: index)
                } else {
                    itemIds.insert(itemId, at: 0)
                }
                addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
                transaction.setPinnedItemIds(groupId: groupId, itemIds: itemIds)
                return .done
            }
        case let .filter(filterId):
            var result: TogglePeerChatPinnedResult = .done
            _internal_updateChatListFiltersInteractively(transaction: transaction, { filters in
                var filters = filters
                if let index = filters.firstIndex(where: { $0.id == filterId }) {
                    switch itemId {
                    case let .peer(peerId):
                        if filters[index].data.includePeers.pinnedPeers.contains(peerId) {
                            filters[index].data.includePeers.removePinnedPeer(peerId)
                        } else {
                            if !filters[index].data.includePeers.addPinnedPeer(peerId) {
                                result = .limitExceeded(100)
                            }
                        }
                    }
                }
                return filters
            })
            return result
        }
    }
}

func _internal_getPinnedItemIds(transaction: Transaction, location: TogglePeerChatPinnedLocation) -> [PinnedItemId] {
    switch location {
    case let .group(groupId):
        return transaction.getPinnedItemIds(groupId: groupId)
    case let .filter(filterId):
        var itemIds: [PinnedItemId] = []
        let _ = _internal_updateChatListFiltersInteractively(transaction: transaction, { filters in
            if let index = filters.firstIndex(where: { $0.id == filterId }) {
                itemIds = filters[index].data.includePeers.pinnedPeers.map { peerId in
                    return .peer(peerId)
                }
            }
            return filters
        })
        return itemIds
    }
}

func _internal_reorderPinnedItemIds(transaction: Transaction, location: TogglePeerChatPinnedLocation, itemIds: [PinnedItemId]) -> Bool {
    switch location {
    case let .group(groupId):
        if transaction.getPinnedItemIds(groupId: groupId) != itemIds {
            transaction.setPinnedItemIds(groupId: groupId, itemIds: itemIds)
            addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
            return true
        } else {
            return false
        }
    case let .filter(filterId):
        var result: Bool = false
        _internal_updateChatListFiltersInteractively(transaction: transaction, { filters in
            var filters = filters
            if let index = filters.firstIndex(where: { $0.id == filterId }) {
                let peerIds: [PeerId] = itemIds.map { itemId -> PeerId in
                    switch itemId {
                    case let .peer(peerId):
                        return peerId
                    }
                }
                
                if filters[index].data.includePeers.pinnedPeers != peerIds {
                    filters[index].data.includePeers.reorderPinnedPeers(peerIds)
                    result = true
                }
            }
            return filters
        })
        return result
    }
}
