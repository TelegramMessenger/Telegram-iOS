import Foundation

final class MutableMessageHistoryThreadIndexView: MutablePostboxView {
    final class Item {
        let id: Int64
        let index: MessageIndex
        var info: CodableEntry
        var tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo]
        var topMessage: Message?
        
        init(
            id: Int64,
            index: MessageIndex,
            info: CodableEntry,
            tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo],
            topMessage: Message?
        ) {
            self.id = id
            self.index = index
            self.info = info
            self.tagSummaryInfo = tagSummaryInfo
            self.topMessage = topMessage
        }
    }
    
    fileprivate let peerId: PeerId
    fileprivate let summaryComponents: ChatListEntrySummaryComponents
    fileprivate var peer: Peer?
    fileprivate var items: [Item] = []
    
    init(postbox: PostboxImpl, peerId: PeerId, summaryComponents: ChatListEntrySummaryComponents) {
        self.peerId = peerId
        self.summaryComponents = summaryComponents
        
        self.reload(postbox: postbox)
    }
    
    private func reload(postbox: PostboxImpl) {
        self.items.removeAll()
        
        self.peer = postbox.peerTable.get(self.peerId)
        
        for item in postbox.messageHistoryThreadIndexTable.getAll(peerId: self.peerId) {
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
            
            self.items.append(Item(
                id: item.threadId,
                index: item.index,
                info: item.info,
                tagSummaryInfo: tagSummaryInfo,
                topMessage: postbox.getMessage(item.index.id)
            ))
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if transaction.updatedMessageThreadPeerIds.contains(self.peerId) || transaction.currentUpdatedMessageTagSummaries.contains(where: { $0.key.peerId == self.peerId }) || transaction.currentUpdatedMessageActionsSummaries.contains(where: { $0.key.peerId == self.peerId }) {
            self.reload(postbox: postbox)
            updated = true
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return MessageHistoryThreadIndexView(self)
    }
}

public final class EngineMessageHistoryThread {
    public final class Item: Equatable {
        public let id: Int64
        public let index: MessageIndex
        public let info: CodableEntry
        public let tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo]
        public let topMessage: Message?
        
        public init(
            id: Int64,
            index: MessageIndex,
            info: CodableEntry,
            tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo],
            topMessage: Message?
        ) {
            self.id = id
            self.index = index
            self.info = info
            self.tagSummaryInfo = tagSummaryInfo
            self.topMessage = topMessage
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
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
            
            return true
        }
    }
}

public final class MessageHistoryThreadIndexView: PostboxView {
    public let peer: Peer?
    public let items: [EngineMessageHistoryThread.Item]
    
    init(_ view: MutableMessageHistoryThreadIndexView) {
        self.peer = view.peer
        
        var items: [EngineMessageHistoryThread.Item] = []
        for item in view.items {
            items.append(EngineMessageHistoryThread.Item(
                id: item.id,
                index: item.index,
                info: item.info,
                tagSummaryInfo: item.tagSummaryInfo,
                topMessage: item.topMessage
            ))
        }
        self.items = items
    }
}

final class MutableMessageHistoryThreadInfoView: MutablePostboxView {
    private let peerId: PeerId
    private let threadId: Int64
    
    fileprivate var info: CodableEntry?
    
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
    public let info: CodableEntry?
    
    init(_ view: MutableMessageHistoryThreadInfoView) {
        self.info = view.info
    }
}
