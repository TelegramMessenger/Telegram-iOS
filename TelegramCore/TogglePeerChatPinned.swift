import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public enum TogglePeerChatPinnedResult {
    case done
    case limitExceeded
}

public func toggleItemPinned(postbox: Postbox, groupId: PeerGroupId?, itemId: PinnedItemId) -> Signal<TogglePeerChatPinnedResult, NoError> {
    return postbox.transaction { transaction -> TogglePeerChatPinnedResult in
        var itemIds = transaction.getPinnedItemIds(groupId: groupId)
        let sameKind = itemIds.filter { item in
            switch itemId {
                case let .peer(lhsPeerId):
                    if case let .peer(rhsPeerId) = item {
                        return (lhsPeerId.namespace == Namespaces.Peer.SecretChat) == (rhsPeerId.namespace == Namespaces.Peer.SecretChat) && lhsPeerId != rhsPeerId
                    } else {
                        return false
                    }
                case let .group(lhsGroupId):
                    if case let .group(rhsGroupId) = item {
                        return lhsGroupId != rhsGroupId
                    } else {
                        return false
                    }
            }
            
        }
        
        let additionalCount: Int
        if let _ = itemIds.index(of: itemId) {
            additionalCount = -1
        } else {
            additionalCount = 1
        }
        
        let limitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
        let limitCount: Int
        if groupId != nil {
            limitCount = Int(limitsConfiguration.maxPinnedChatCount)
        } else {
            limitCount = Int(limitsConfiguration.maxArchivedPinnedChatCount)
        }
        
        if sameKind.count + additionalCount > limitCount {
            return .limitExceeded
        } else {
            if let index = itemIds.index(of: itemId) {
                itemIds.remove(at: index)
            } else {
                itemIds.insert(itemId, at: 0)
            }
            transaction.setPinnedItemIds(groupId: groupId, itemIds: itemIds)
            addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
            return .done
        }
    }
}

public func reorderPinnedItemIds(transaction: Transaction, groupId: PeerGroupId?, itemIds: [PinnedItemId]) -> Bool {
    if transaction.getPinnedItemIds(groupId: groupId) != itemIds {
        transaction.setPinnedItemIds(groupId: groupId, itemIds: itemIds)
        addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
        return true
    } else {
        return false
    }
}
