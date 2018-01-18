import Foundation

public enum UnreadMessageCountsItem: Equatable {
    case total
    case peer(PeerId)
    case group(PeerGroupId)
    
    public static func ==(lhs: UnreadMessageCountsItem, rhs: UnreadMessageCountsItem) -> Bool {
        switch lhs {
            case .total:
                if case .total = rhs {
                    return true
                } else {
                    return false
                }
            case let .peer(peerId):
                if case .peer(peerId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .group(groupId):
                if case .group(groupId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum MutableUnreadMessageCountsItemEntry {
    case total(Int32)
    case peer(PeerId, Int32)
    case group(PeerGroupId, ChatListGroupReferenceUnreadCounters)
}

enum UnreadMessageCountsItemEntry {
    case total(Int32)
    case peer(PeerId, Int32)
    case group(PeerGroupId, Int32)
}

final class MutableUnreadMessageCountsView: MutablePostboxView {
    fileprivate var entries: [MutableUnreadMessageCountsItemEntry]
    
    init(postbox: Postbox, items: [UnreadMessageCountsItem]) {
        self.entries = items.map { item in
            switch item {
                case .total:
                    return .total(postbox.messageHistoryMetadataTable.getChatListTotalUnreadCount())
                case let .peer(peerId):
                    var count: Int32 = 0
                    if let combinedState = postbox.readStateTable.getCombinedState(peerId) {
                        count = combinedState.count
                    }
                    return .peer(peerId, count)
                case let .group(groupId):
                    return .group(groupId, ChatListGroupReferenceUnreadCounters(postbox: postbox, groupId: groupId))
            }
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if transaction.currentUpdatedTotalUnreadCount != nil || !transaction.peerIdsWithUpdatedUnreadCounts.isEmpty {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .total(count):
                        if transaction.currentUpdatedTotalUnreadCount != nil {
                            let updatedCount = postbox.messageHistoryMetadataTable.getChatListTotalUnreadCount()
                            if updatedCount != count {
                                self.entries[i] = .total(updatedCount)
                                updated = true
                            }
                        }
                    case let .peer(peerId, _):
                        if transaction.peerIdsWithUpdatedUnreadCounts.contains(peerId) {
                            var updatedCount: Int32 = 0
                            if let combinedState = postbox.readStateTable.getCombinedState(peerId) {
                                updatedCount = combinedState.count
                            }
                            self.entries[i] = .peer(peerId, updatedCount)
                            updated = true
                        }
                    case let .group(_, counters):
                        if counters.replay(postbox: postbox, transaction: transaction) {
                            updated = true
                        }
                }
            }
        }
        
        return updated
    }
    
    func immutableView() -> PostboxView {
        return UnreadMessageCountsView(self)
    }
}

public final class UnreadMessageCountsView: PostboxView {
    private let entries: [UnreadMessageCountsItemEntry]
    
    init(_ view: MutableUnreadMessageCountsView) {
        self.entries = view.entries.map { entry in
            switch entry {
                case let .total(count):
                    return .total(count)
                case let .peer(peerId, count):
                    return .peer(peerId, count)
                case let .group(groupId, counters):
                    let (unread, mutedUnread) = counters.getCounters()
                    return .group(groupId, unread + mutedUnread)
            }
        }
    }
    
    public func count(for item: UnreadMessageCountsItem) -> Int32? {
        for entry in self.entries {
            switch entry {
                case let .total(count):
                    if case .total = item {
                        return count
                    }
                case let .peer(peerId, count):
                    if case .peer(peerId) = item {
                        return count
                    }
                case let .group(groupId, count):
                    if case .group(groupId) = item {
                        return count
                    }
            }
        }
        return nil
    }
}
