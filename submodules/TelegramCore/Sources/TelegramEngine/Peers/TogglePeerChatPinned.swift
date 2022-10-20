import Foundation
import Postbox
import SwiftSignalKit

public enum TogglePeerChatPinnedLocation {
    case group(PeerGroupId)
    case filter(Int32)
}

public enum TogglePeerChatPinnedResult {
    case done
    case limitExceeded(count: Int, limit: Int)
}

func _internal_toggleItemPinned(postbox: Postbox, accountPeerId: PeerId, location: TogglePeerChatPinnedLocation, itemId: PinnedItemId) -> Signal<TogglePeerChatPinnedResult, NoError> {
    return postbox.transaction { transaction -> TogglePeerChatPinnedResult in
        let isPremium = transaction.getPeer(accountPeerId)?.isPremium ?? false
        
        let appConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? .defaultValue
        let limitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration)?.get(LimitsConfiguration.self) ?? LimitsConfiguration.defaultValue
        let userLimitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: isPremium)
        
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
            
            let limitCount: Int
            if case .root = groupId {
                limitCount = Int(userLimitsConfiguration.maxPinnedChatCount)
            } else {
                limitCount = Int(limitsConfiguration.maxArchivedPinnedChatCount)
            }
            
            let count = sameKind.count + additionalCount
            if count > limitCount, itemIds.firstIndex(of: itemId) == nil {
                return .limitExceeded(count: sameKind.count, limit: limitCount)
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
                if let index = filters.firstIndex(where: { $0.id == filterId }), case let .filter(id, title, emoticon, data) = filters[index] {
                    switch itemId {
                    case let .peer(peerId):
                        var updatedData = data
                        if updatedData.includePeers.pinnedPeers.contains(peerId) {
                            updatedData.includePeers.removePinnedPeer(peerId)
                        } else {
                            let _ = updatedData.includePeers.addPinnedPeer(peerId)
                            if updatedData.includePeers.peers.count > userLimitsConfiguration.maxFolderChatsCount {
                                result = .limitExceeded(count: updatedData.includePeers.peers.count, limit: Int(userLimitsConfiguration.maxFolderChatsCount))
                                updatedData = data
                            }
                        }
                        filters[index] = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
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
            if let index = filters.firstIndex(where: { $0.id == filterId }), case let .filter(_, _, _, data) = filters[index] {
                itemIds = data.includePeers.pinnedPeers.map { peerId in
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
            if let index = filters.firstIndex(where: { $0.id == filterId }), case let .filter(id, title, emoticon, data) = filters[index] {
                let peerIds: [PeerId] = itemIds.map { itemId -> PeerId in
                    switch itemId {
                    case let .peer(peerId):
                        return peerId
                    }
                }
                
                var updatedData = data
                if updatedData.includePeers.pinnedPeers != peerIds {
                    updatedData.includePeers.reorderPinnedPeers(peerIds)
                    filters[index] = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
                    result = true
                }
            }
            return filters
        })
        return result
    }
}
