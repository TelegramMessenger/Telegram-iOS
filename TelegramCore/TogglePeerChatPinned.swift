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

public func toggleItemPinned(postbox: Postbox, itemId: PinnedItemId) -> Signal<TogglePeerChatPinnedResult, NoError> {
    return postbox.modify { modifier -> TogglePeerChatPinnedResult in
        var itemIds = modifier.getPinnedItemIds()
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
        
        if sameKind.count + 1 > 5 {
            return .limitExceeded
        } else {
            if let index = itemIds.index(of: itemId) {
                itemIds.remove(at: index)
            } else {
                itemIds.insert(itemId, at: 0)
            }
            modifier.setPinnedItemIds(itemIds)
            addSynchronizePinnedChatsOperation(modifier: modifier)
            return .done
        }
    }
}
