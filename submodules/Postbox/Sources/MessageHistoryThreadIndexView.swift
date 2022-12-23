import Foundation

final class MutableMessageHistoryThreadIndexView: MutablePostboxView {
    final class Item {
        let id: Int64
        let pinnedIndex: Int?
        let index: MessageIndex
        var info: CodableEntry
        var tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo]
        var topMessage: Message?
        var embeddedInterfaceState: StoredPeerChatInterfaceState?
        
        init(
            id: Int64,
            pinnedIndex: Int?,
            index: MessageIndex,
            info: CodableEntry,
            tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo],
            topMessage: Message?,
            embeddedInterfaceState: StoredPeerChatInterfaceState?
        ) {
            self.id = id
            self.pinnedIndex = pinnedIndex
            self.index = index
            self.info = info
            self.tagSummaryInfo = tagSummaryInfo
            self.topMessage = topMessage
            self.embeddedInterfaceState = embeddedInterfaceState
        }
    }
    
    fileprivate let peerId: PeerId
    fileprivate let summaryComponents: ChatListEntrySummaryComponents
    fileprivate var peer: Peer?
    fileprivate var peerNotificationSettings: PeerNotificationSettings?
    fileprivate var items: [Item] = []
    private var hole: ForumTopicListHolesEntry?
    fileprivate var isLoading: Bool = false
    
    init(postbox: PostboxImpl, peerId: PeerId, summaryComponents: ChatListEntrySummaryComponents) {
        self.peerId = peerId
        self.summaryComponents = summaryComponents
        
        self.reload(postbox: postbox)
    }
    
    private func reload(postbox: PostboxImpl) {
        self.items.removeAll()
        
        self.peer = postbox.peerTable.get(self.peerId)
        
        self.peerNotificationSettings = postbox.peerNotificationSettingsTable.getEffective(self.peerId)
        
        let validIndexBoundary = postbox.peerThreadCombinedStateTable.get(peerId: peerId)?.validIndexBoundary
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
            var nextPinnedIndex = 0
        
            for item in postbox.messageHistoryThreadIndexTable.getAll(peerId: self.peerId) {
                var pinnedIndex: Int?
                if pinnedThreadIds.contains(item.threadId) {
                    pinnedIndex = nextPinnedIndex
                    nextPinnedIndex += 1
                }
                
                var tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo] = [:]
                for (key, component) in self.summaryComponents.components {
                    var tagSummaryCount: Int32?
                    var actionsSummaryCount: Int32?
                    
                    if let tagSummary = component.tagSummary {
                        let key = MessageHistoryTagsSummaryKey(tag: key.tag, peerId: self.peerId, threadId: item.threadId, namespace: tagSummary.namespace)
                        if let summary = postbox.messageHistoryTagsSummaryTable.get(key) {
                            tagSummaryCount = summary.count
                        }
                    }
                    
                    if let actionsSummary = component.actionsSummary {
                        let key = PendingMessageActionsSummaryKey(type: key.actionType, peerId: self.peerId, namespace: actionsSummary.namespace)
                        actionsSummaryCount = postbox.pendingMessageActionsMetadataTable.getCount(.peerNamespaceAction(key.peerId, key.namespace, key.type))
                    }
                    
                    tagSummaryInfo[key] = ChatListMessageTagSummaryInfo(
                        tagSummaryCount: tagSummaryCount,
                        actionsSummaryCount: actionsSummaryCount
                    )
                }
                
                var embeddedInterfaceState: StoredPeerChatInterfaceState?
                embeddedInterfaceState = postbox.peerChatThreadInterfaceStateTable.get(PeerChatThreadId(peerId: self.peerId, threadId: item.threadId))
                
                self.items.append(Item(
                    id: item.threadId,
                    pinnedIndex: pinnedIndex,
                    index: item.index,
                    info: item.info.data,
                    tagSummaryInfo: tagSummaryInfo,
                    topMessage: postbox.getMessage(item.index.id),
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
        
        if transaction.updatedMessageThreadPeerIds.contains(self.peerId) || transaction.updatedPinnedThreads.contains(self.peerId) || transaction.updatedPeerThreadCombinedStates.contains(self.peerId) || transaction.currentUpdatedMessageTagSummaries.contains(where: { $0.key.peerId == self.peerId }) || transaction.currentUpdatedMessageActionsSummaries.contains(where: { $0.key.peerId == self.peerId }) || transaction.currentUpdatedPeerChatListEmbeddedStates.contains(self.peerId) || transaction.currentUpdatedPeerNotificationSettings[self.peerId] != nil {
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
        return MessageHistoryThreadIndexView(self)
    }
}

public final class EngineMessageHistoryThread {
    public final class Item: Equatable {
        public let id: Int64
        public let pinnedIndex: Int?
        public let index: MessageIndex
        public let info: CodableEntry
        public let tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo]
        public let topMessage: Message?
        public let embeddedInterfaceState: StoredPeerChatInterfaceState?
        
        public init(
            id: Int64,
            pinnedIndex: Int?,
            index: MessageIndex,
            info: CodableEntry,
            tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo],
            topMessage: Message?,
            embeddedInterfaceState: StoredPeerChatInterfaceState?
        ) {
            self.id = id
            self.pinnedIndex = pinnedIndex
            self.index = index
            self.info = info
            self.tagSummaryInfo = tagSummaryInfo
            self.topMessage = topMessage
            self.embeddedInterfaceState = embeddedInterfaceState
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.pinnedIndex != rhs.pinnedIndex {
                return false
            }
            if lhs.index != rhs.index {
                return false
            }
            if lhs.info != rhs.info {
                return false
            }
            if lhs.tagSummaryInfo != rhs.tagSummaryInfo {
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
            if lhs.embeddedInterfaceState != rhs.embeddedInterfaceState {
                return false
            }
            
            return true
        }
    }
}

public final class MessageHistoryThreadIndexView: PostboxView {
    public let peer: Peer?
    public let peerNotificationSettings: PeerNotificationSettings?
    public let items: [EngineMessageHistoryThread.Item]
    public let isLoading: Bool
    
    init(_ view: MutableMessageHistoryThreadIndexView) {
        self.peer = view.peer
        self.peerNotificationSettings = view.peerNotificationSettings
        
        var items: [EngineMessageHistoryThread.Item] = []
        for item in view.items {
            items.append(EngineMessageHistoryThread.Item(
                id: item.id,
                pinnedIndex: item.pinnedIndex,
                index: item.index,
                info: item.info,
                tagSummaryInfo: item.tagSummaryInfo,
                topMessage: item.topMessage,
                embeddedInterfaceState: item.embeddedInterfaceState
            ))
        }
        self.items = items
        
        self.isLoading = view.isLoading
    }
}

final class MutableMessageHistoryThreadInfoView: MutablePostboxView {
    private let peerId: PeerId
    private let threadId: Int64
    
    fileprivate var info: StoredMessageHistoryThreadInfo?
    
    init(postbox: PostboxImpl, peerId: PeerId, threadId: Int64) {
        self.peerId = peerId
        self.threadId = threadId
        
        self.reload(postbox: postbox)
    }
    
    private func reload(postbox: PostboxImpl) {
        self.info = postbox.messageHistoryThreadIndexTable.get(peerId: self.peerId, threadId: self.threadId)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if transaction.updatedMessageThreadPeerIds.contains(self.peerId) {
            let info = postbox.messageHistoryThreadIndexTable.get(peerId: self.peerId, threadId: self.threadId)
            if self.info != info {
                self.info = info
                updated = true
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return MessageHistoryThreadInfoView(self)
    }
}

public final class MessageHistoryThreadInfoView: PostboxView {
    public let info: StoredMessageHistoryThreadInfo?
    
    init(_ view: MutableMessageHistoryThreadInfoView) {
        self.info = view.info
    }
}
