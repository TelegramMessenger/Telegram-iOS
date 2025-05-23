import Foundation

final class MutableMessageHistorySavedMessagesIndexView: MutablePostboxView {
    final class Item {
        let id: Int64
        let peer: Peer?
        let pinnedIndex: Int?
        let index: MessageIndex
        let topMessage: Message?
        let unreadCount: Int
        let markedUnread: Bool
        let embeddedInterfaceState: StoredPeerChatInterfaceState?
        
        init(
            id: Int64,
            peer: Peer?,
            pinnedIndex: Int?,
            index: MessageIndex,
            topMessage: Message?,
            unreadCount: Int,
            markedUnread: Bool,
            embeddedInterfaceState: StoredPeerChatInterfaceState?
        ) {
            self.id = id
            self.peer = peer
            self.pinnedIndex = pinnedIndex
            self.index = index
            self.topMessage = topMessage
            self.unreadCount = unreadCount
            self.markedUnread = markedUnread
            self.embeddedInterfaceState = embeddedInterfaceState
        }
    }
    
    fileprivate let peerId: PeerId
    fileprivate var peer: Peer?
    fileprivate var items: [Item] = []
    private var hole: ForumTopicListHolesEntry?
    fileprivate var isLoading: Bool = false
    
    init(postbox: PostboxImpl, peerId: PeerId) {
        self.peerId = peerId
        
        self.reload(postbox: postbox)
    }
    
    private func reload(postbox: PostboxImpl) {
        self.items.removeAll()
        
        self.peer = postbox.peerTable.get(self.peerId)
        
        let validIndexBoundary = postbox.peerThreadCombinedStateTable.get(peerId: self.peerId)?.validIndexBoundary
        self.isLoading = validIndexBoundary == nil
        
        if let validIndexBoundary = validIndexBoundary {
            if validIndexBoundary.messageId != 1 {
                self.hole = ForumTopicListHolesEntry(peerId: self.peerId, index: validIndexBoundary)
            } else {
                self.hole = nil
            }
        } else {
            self.hole = ForumTopicListHolesEntry(peerId: self.peerId, index: nil)
        }
        
        if !self.isLoading {
            let pinnedThreadIds = postbox.messageHistoryThreadPinnedTable.get(peerId: self.peerId)
        
            for item in postbox.messageHistoryThreadIndexTable.getAll(peerId: self.peerId) {
                var pinnedIndex: Int?
                if let index = pinnedThreadIds.firstIndex(of: item.threadId) {
                    pinnedIndex = index
                }
                
                let embeddedInterfaceState = postbox.peerChatThreadInterfaceStateTable.get(PeerChatThreadId(peerId: self.peerId, threadId: item.threadId))
                
                self.items.append(Item(
                    id: item.threadId,
                    peer: postbox.peerTable.get(PeerId(item.threadId)),
                    pinnedIndex: pinnedIndex,
                    index: item.index,
                    topMessage: postbox.getMessage(item.index.id),
                    unreadCount: Int(item.info.summary.totalUnreadCount),
                    markedUnread: item.info.summary.isMarkedUnread,
                    embeddedInterfaceState: embeddedInterfaceState
                ))
            }
            
            self.items.sort(by: { lhs, rhs in
                if let lhsPinnedIndex = lhs.pinnedIndex, let rhsPinnedIndex = rhs.pinnedIndex {
                    return lhsPinnedIndex < rhsPinnedIndex
                } else if (lhs.pinnedIndex == nil) != (rhs.pinnedIndex == nil) {
                    if lhs.pinnedIndex != nil {
                        return true
                    } else {
                        return false
                    }
                }
                
                return lhs.index > rhs.index
            })
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if transaction.updatedMessageThreadPeerIds.contains(self.peerId) || transaction.updatedPinnedThreads.contains(self.peerId) || transaction.updatedPeerThreadCombinedStates.contains(self.peerId) || transaction.currentUpdatedMessageTagSummaries.contains(where: { $0.key.peerId == self.peerId }) || transaction.currentUpdatedMessageActionsSummaries.contains(where: { $0.key.peerId == self.peerId }) || transaction.currentUpdatedPeerChatListEmbeddedStates.contains(self.peerId) || transaction.currentUpdatedPeerNotificationSettings[self.peerId] != nil || transaction.updatedPinnedThreads.contains(self.peerId) {
            self.reload(postbox: postbox)
            updated = true
        }
        
        return updated
    }
    
    func topHole() -> ForumTopicListHolesEntry? {
        return self.hole
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        self.reload(postbox: postbox)
        
        return true
    }
    
    func immutableView() -> PostboxView {
        return MessageHistorySavedMessagesIndexView(self)
    }
}

public final class EngineMessageHistorySavedMessagesThread {
    public final class Item: Equatable {
        public let id: Int64
        public let peer: Peer?
        public let pinnedIndex: Int?
        public let index: MessageIndex
        public let topMessage: Message?
        public let unreadCount: Int
        public let markedUnread: Bool
        public let embeddedInterfaceState: StoredPeerChatInterfaceState?
        
        public init(
            id: Int64,
            peer: Peer?,
            pinnedIndex: Int?,
            index: MessageIndex,
            topMessage: Message?,
            unreadCount: Int,
            markedUnread: Bool,
            embeddedInterfaceState: StoredPeerChatInterfaceState?
        ) {
            self.id = id
            self.peer = peer
            self.pinnedIndex = pinnedIndex
            self.index = index
            self.topMessage = topMessage
            self.unreadCount = unreadCount
            self.markedUnread = markedUnread
            self.embeddedInterfaceState = embeddedInterfaceState
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if !arePeersEqual(lhs.peer, rhs.peer) {
                return false
            }
            if lhs.pinnedIndex != rhs.pinnedIndex {
                return false
            }
            if lhs.index != rhs.index {
                return false
            }
            if let lhsMessage = lhs.topMessage, let rhsMessage = rhs.topMessage {
                if lhsMessage.index != rhsMessage.index {
                    return false
                }
                if lhsMessage.stableVersion != rhsMessage.stableVersion {
                    return false
                }
            } else if (lhs.topMessage == nil) != (rhs.topMessage == nil) {
                return false
            }
            if lhs.unreadCount != rhs.unreadCount {
                return false
            }
            if lhs.markedUnread != rhs.markedUnread {
                return false
            }
            if lhs.embeddedInterfaceState != rhs.embeddedInterfaceState {
                return false
            }
            
            return true
        }
    }
}

public final class MessageHistorySavedMessagesIndexView: PostboxView {
    public let peer: Peer?
    public let items: [EngineMessageHistorySavedMessagesThread.Item]
    public let isLoading: Bool
    
    init(_ view: MutableMessageHistorySavedMessagesIndexView) {
        self.peer = view.peer
        
        var items: [EngineMessageHistorySavedMessagesThread.Item] = []
        for item in view.items {
            items.append(EngineMessageHistorySavedMessagesThread.Item(
                id: item.id,
                peer: item.peer,
                pinnedIndex: item.pinnedIndex,
                index: item.index,
                topMessage: item.topMessage,
                unreadCount: item.unreadCount,
                markedUnread: item.markedUnread,
                embeddedInterfaceState: item.embeddedInterfaceState
            ))
        }
        self.items = items
        
        self.isLoading = view.isLoading
    }
}
