import Foundation

public enum UnreadMessageCountsItem {
    case total
    case peer(PeerId)
}

enum UnreadMessageCountsItemEntry {
    case total(Int32)
    case peer(PeerId, Int32)
}

final class MutableUnreadMessageCountsView {
    fileprivate var entries: [UnreadMessageCountsItemEntry]
    
    init(entries: [UnreadMessageCountsItemEntry]) {
        self.entries = entries
    }
    
    func replay(peerIdsWithUpdatedUnreadCounts: Set<PeerId>, getTotalUnreadCount: () -> Int32, getPeerReadState: (PeerId) -> CombinedPeerReadState?) -> Bool {
        var updated = false
        
        for i in 0 ..< self.entries.count {
            switch self.entries[i] {
                case let .total(count):
                    let updatedCount = getTotalUnreadCount()
                    if updatedCount != count {
                        self.entries[i] = .total(updatedCount)
                        updated = true
                    }
                case let .peer(peerId, count):
                    if peerIdsWithUpdatedUnreadCounts.contains(peerId) {
                        var updatedCount: Int32 = 0
                        if let combinedState = getPeerReadState(peerId) {
                            updatedCount = combinedState.count
                        }
                        self.entries[i] = .peer(peerId, updatedCount)
                        updated = true
                    }
            }
        }
        
        return updated
    }
}

public final class UnreadMessageCountsView {
    private let entries: [UnreadMessageCountsItemEntry]
    
    init(_ view: MutableUnreadMessageCountsView) {
        self.entries = view.entries
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
            }
        }
        return nil
    }
}
