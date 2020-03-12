import Foundation

public struct ChatListEntryMessageTagSummaryComponent {
    public let tag: MessageTags
    public let namespace: MessageId.Namespace
    
    public init(tag: MessageTags, namespace: MessageId.Namespace) {
        self.tag = tag
        self.namespace = namespace
    }
}

public struct ChatListEntryPendingMessageActionsSummaryComponent {
    public let type: PendingMessageActionType
    public let namespace: MessageId.Namespace
    
    public init(type: PendingMessageActionType, namespace: MessageId.Namespace) {
        self.type = type
        self.namespace = namespace
    }
}

public struct ChatListEntrySummaryComponents {
    public let tagSummary: ChatListEntryMessageTagSummaryComponent?
    public let actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent?
    
    public init(tagSummary: ChatListEntryMessageTagSummaryComponent? = nil, actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent? = nil) {
        self.tagSummary = tagSummary
        self.actionsSummary = actionsSummary
    }
}

public struct ChatListMessageTagSummaryInfo: Equatable {
    public let tagSummaryCount: Int32?
    public let actionsSummaryCount: Int32?
    
    public init(tagSummaryCount: Int32? = nil, actionsSummaryCount: Int32? = nil) {
        self.tagSummaryCount = tagSummaryCount
        self.actionsSummaryCount = actionsSummaryCount
    }
    
    public static func ==(lhs: ChatListMessageTagSummaryInfo, rhs: ChatListMessageTagSummaryInfo) -> Bool {
        return lhs.tagSummaryCount == rhs.tagSummaryCount && lhs.actionsSummaryCount == rhs.actionsSummaryCount
    }
}

public final class ChatListGroupReferencePeer: Equatable {
    public let peer: RenderedPeer
    public let isUnread: Bool
    
    init(peer: RenderedPeer, isUnread: Bool) {
        self.peer = peer
        self.isUnread = isUnread
    }
    
    public static func ==(lhs: ChatListGroupReferencePeer, rhs: ChatListGroupReferencePeer) -> Bool {
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.isUnread != rhs.isUnread {
            return false
        }
        return true
    }
}

public struct ChatListGroupReferenceEntry: Equatable {
    public let groupId: PeerGroupId
    public let message: Message?
    public let renderedPeers: [ChatListGroupReferencePeer]
    public let unreadState: PeerGroupUnreadCountersCombinedSummary
    
    public static func ==(lhs: ChatListGroupReferenceEntry, rhs: ChatListGroupReferenceEntry) -> Bool {
        if lhs.groupId != rhs.groupId {
            return false
        }
        if lhs.unreadState != rhs.unreadState {
            return false
        }
        if lhs.message?.stableVersion != rhs.message?.stableVersion {
            return false
        }
        if lhs.renderedPeers != rhs.renderedPeers {
            return false
        }
        return true
    }
}

public enum ChatListEntry: Comparable {
    case MessageEntry(index: ChatListIndex, message: Message?, readState: CombinedPeerReadState?, isRemovedFromTotalUnreadCount: Bool, embeddedInterfaceState: PeerChatListEmbeddedInterfaceState?, renderedPeer: RenderedPeer, presence: PeerPresence?, summaryInfo: ChatListMessageTagSummaryInfo, hasFailed: Bool, isContact: Bool)
    case HoleEntry(ChatListHole)
    
    public var index: ChatListIndex {
        switch self {
            case let .MessageEntry(index, _, _, _, _, _, _, _, _, _):
                return index
            case let .HoleEntry(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
        }
    }

    public static func ==(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
        switch lhs {
            case let .MessageEntry(lhsIndex, lhsMessage, lhsReadState, lhsIsRemovedFromTotalUnreadCount, lhsEmbeddedState, lhsPeer, lhsPresence, lhsInfo, lhsHasFailed, lhsIsContact):
                switch rhs {
                    case let .MessageEntry(rhsIndex, rhsMessage, rhsReadState, rhsIsRemovedFromTotalUnreadCount, rhsEmbeddedState, rhsPeer, rhsPresence, rhsInfo, rhsHasFailed, rhsIsContact):
                        if lhsIndex != rhsIndex {
                            return false
                        }
                        if lhsReadState != rhsReadState {
                            return false
                        }
                        if lhsMessage?.stableVersion != rhsMessage?.stableVersion {
                            return false
                        }
                        if lhsIsRemovedFromTotalUnreadCount != rhsIsRemovedFromTotalUnreadCount {
                            return false
                        }
                        if let lhsEmbeddedState = lhsEmbeddedState, let rhsEmbeddedState = rhsEmbeddedState {
                            if !lhsEmbeddedState.isEqual(to: rhsEmbeddedState) {
                                return false
                            }
                        } else if (lhsEmbeddedState != nil) != (rhsEmbeddedState != nil) {
                            return false
                        }
                        if lhsPeer != rhsPeer {
                            return false
                        }
                        if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                            if !lhsPresence.isEqual(to: rhsPresence) {
                                return false
                            }
                        } else if (lhsPresence != nil) != (rhsPresence != nil) {
                            return false
                        }
                        if lhsInfo != rhsInfo {
                            return false
                        }
                        if lhsHasFailed != rhsHasFailed {
                            return false
                        }
                        if lhsIsContact != rhsIsContact {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .HoleEntry(hole):
                if case .HoleEntry(hole) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }

    public static func <(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
        return lhs.index < rhs.index
    }
}

/*private func processedChatListEntry(_ entry: MutableChatListEntry, cachedDataTable: CachedPeerDataTable, readStateTable: MessageHistoryReadStateTable, messageHistoryTable: MessageHistoryTable) -> MutableChatListEntry {
    switch entry {
        case let .IntermediateMessageEntry(index, messageIndex):
            var updatedMessage = message
            if let message = message, let cachedData = cachedDataTable.get(message.id.peerId), let associatedHistoryMessageId = cachedData.associatedHistoryMessageId, message.id.id == 1 {
                if let messageIndex = messageHistoryTable.messageHistoryIndexTable.earlierEntries(id: associatedHistoryMessageId, count: 1).first {
                    if let associatedMessage = messageHistoryTable.getMessage(messageIndex) {
                        updatedMessage = associatedMessage
                    }
                }
            }
            return .IntermediateMessageEntry(index, updatedMessage, readState, embeddedState)
        default:
            return entry
    }
}*/

enum MutableChatListEntry: Equatable {
    case IntermediateMessageEntry(index: ChatListIndex, messageIndex: MessageIndex?)
    case MessageEntry(index: ChatListIndex, message: Message?, readState: CombinedPeerReadState?, notificationSettings: PeerNotificationSettings?, isRemovedFromTotalUnreadCount: Bool, embeddedInterfaceState: PeerChatListEmbeddedInterfaceState?, renderedPeer: RenderedPeer, presence: PeerPresence?, tagSummaryInfo: ChatListMessageTagSummaryInfo, hasFailedMessages: Bool, isContact: Bool)
    case HoleEntry(ChatListHole)
    
    init(_ intermediateEntry: ChatListIntermediateEntry, cachedDataTable: CachedPeerDataTable, readStateTable: MessageHistoryReadStateTable, messageHistoryTable: MessageHistoryTable) {
        switch intermediateEntry {
            case let .message(index, messageIndex):
                self = .IntermediateMessageEntry(index: index, messageIndex: messageIndex)
            case let .hole(hole):
                self = .HoleEntry(hole)
        }
    }
    
    var index: ChatListIndex {
        switch self {
            case let .IntermediateMessageEntry(intermediateMessageEntry):
                return intermediateMessageEntry.index
            case let .MessageEntry(index, _, _, _, _, _, _, _, _, _, _):
                return index
            case let .HoleEntry(hole):
                return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
        }
    }

    static func ==(lhs: MutableChatListEntry, rhs: MutableChatListEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        
        switch lhs {
            case .IntermediateMessageEntry:
                switch rhs {
                    case .IntermediateMessageEntry:
                        return true
                    default:
                        return false
                }
            case .MessageEntry:
                switch rhs {
                    case .MessageEntry:
                        return true
                    default:
                        return false
                }
            case .HoleEntry:
                switch rhs {
                    case .HoleEntry:
                        return true
                    default:
                        return false
                }
        }
    }
}

final class MutableChatListViewReplayContext {
    var invalidEarlier: Bool = false
    var invalidLater: Bool = false
    var removedEntries: Bool = false
    
    func empty() -> Bool {
        return !self.removedEntries && !invalidEarlier && !invalidLater
    }
}

private enum ChatListEntryType {
    case message
    case hole
    case groupReference
}

public struct ChatListFilterPredicate {
    public var includePeerIds: Set<PeerId>
    public var excludePeerIds: Set<PeerId>
    public var messageTagSummary: ChatListMessageTagSummaryResultCalculation?
    public var includeAdditionalPeerGroupIds: [PeerGroupId]
    public var include: (Peer, Bool, Bool, Bool, Bool?) -> Bool
    
    public init(includePeerIds: Set<PeerId>, excludePeerIds: Set<PeerId>, messageTagSummary: ChatListMessageTagSummaryResultCalculation?, includeAdditionalPeerGroupIds: [PeerGroupId], include: @escaping (Peer, Bool, Bool, Bool, Bool?) -> Bool) {
        self.includePeerIds = includePeerIds
        self.excludePeerIds = excludePeerIds
        self.messageTagSummary = messageTagSummary
        self.includeAdditionalPeerGroupIds = includeAdditionalPeerGroupIds
        self.include = include
    }
    
    func includes(peer: Peer, groupId: PeerGroupId, isRemovedFromTotalUnreadCount: Bool, isUnread: Bool, isContact: Bool, messageTagSummaryResult: Bool?) -> Bool {
        let includePeerId = peer.associatedPeerId ?? peer.id
        if self.excludePeerIds.contains(includePeerId) {
            return false
        }
        if self.includePeerIds.contains(includePeerId) {
            return true
        }
        if groupId != .root {
            if !self.includeAdditionalPeerGroupIds.contains(groupId) {
                return false
            }
        }
        return self.include(peer, isRemovedFromTotalUnreadCount, isUnread, isContact, messageTagSummaryResult)
    }
}

final class MutableChatListView {
    let groupId: PeerGroupId
    let filterPredicate: ChatListFilterPredicate?
    private let summaryComponents: ChatListEntrySummaryComponents
    fileprivate var groupEntries: [ChatListGroupReferenceEntry]
    private var count: Int
    
    private let spaces: [ChatListViewSpace]
    fileprivate var state: ChatListViewState
    fileprivate var sampledState: ChatListViewSample
    
    init(postbox: Postbox, groupId: PeerGroupId, filterPredicate: ChatListFilterPredicate?, aroundIndex: ChatListIndex, count: Int, summaryComponents: ChatListEntrySummaryComponents) {
        self.groupId = groupId
        self.filterPredicate = filterPredicate
        self.summaryComponents = summaryComponents
        
        var spaces: [ChatListViewSpace] = [
            .group(groupId: self.groupId, pinned: .notPinned)
        ]
        if let filterPredicate = self.filterPredicate {
            spaces.append(.group(groupId: self.groupId, pinned: .includePinnedAsUnpinned))
            for additionalGroupId in filterPredicate.includeAdditionalPeerGroupIds {
                spaces.append(.group(groupId: additionalGroupId, pinned: .notPinned))
                spaces.append(.group(groupId: additionalGroupId, pinned: .includePinnedAsUnpinned))
            }
        } else {
            spaces.append(.group(groupId: self.groupId, pinned: .includePinned))
        }
        self.spaces = spaces
        self.state = ChatListViewState(postbox: postbox, spaces: self.spaces, anchorIndex: aroundIndex, filterPredicate: self.filterPredicate, summaryComponents: self.summaryComponents, halfLimit: count)
        self.sampledState = self.state.sample(postbox: postbox)
        
        self.count = count
        
        if case .root = groupId, self.filterPredicate == nil {
            /*let itemIds = postbox.additionalChatListItemsTable.get()
            self.additionalItemIds = Set(itemIds)
            for peerId in itemIds {
                if let entry = postbox.chatListTable.getStandalone(peerId: peerId, messageHistoryTable: postbox.messageHistoryTable) {
                    self.additionalItemEntries.append(MutableChatListEntry(entry, cachedDataTable: postbox.cachedPeerDataTable, readStateTable: postbox.readStateTable, messageHistoryTable: postbox.messageHistoryTable))
                }
            }*/
            self.groupEntries = []
            self.reloadGroups(postbox: postbox)
        } else {
            //self.additionalItemIds = Set()
            self.groupEntries = []
        }
    }
    
    private func reloadGroups(postbox: Postbox) {
        self.groupEntries.removeAll()
        if case .root = self.groupId, self.filterPredicate == nil {
            for groupId in postbox.chatListTable.existingGroups() {
                var foundIndices: [(ChatListIndex, MessageIndex)] = []
                var unpinnedCount = 0
                let maxCount = 8
                
                var upperBound: (ChatListIndex, Bool)?
                inner: while true {
                    if let entry = postbox.chatListTable.earlierEntryInfos(groupId: groupId, index: upperBound, messageHistoryTable: postbox.messageHistoryTable, peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable, count: 1).first {
                        switch entry {
                            case let .message(index, messageIndex):
                                if let messageIndex = messageIndex {
                                    foundIndices.append((index, messageIndex))
                                    if index.pinningIndex == nil {
                                        unpinnedCount += 1
                                    }
                                    
                                    if unpinnedCount >= maxCount {
                                        break inner
                                    }
                                    
                                    upperBound = (entry.index, true)
                                } else {
                                    upperBound = (entry.index.predecessor, true)
                                }
                            case .hole:
                                upperBound = (entry.index, false)
                        }
                    } else {
                        break inner
                    }
                }
                
                foundIndices.sort(by: { $0.1 > $1.1 })
                if foundIndices.count > maxCount {
                    foundIndices.removeSubrange(maxCount...)
                }
                
                if !foundIndices.isEmpty {
                    var message: Message?
                    var renderedPeers: [ChatListGroupReferencePeer] = []
                    for (index, messageIndex) in foundIndices {
                        if let peer = postbox.peerTable.get(index.messageIndex.id.peerId) {
                            var peers = SimpleDictionary<PeerId, Peer>()
                            peers[peer.id] = peer
                            if let associatedPeerId = peer.associatedPeerId {
                                if let associatedPeer = postbox.peerTable.get(associatedPeerId) {
                                    peers[associatedPeer.id] = associatedPeer
                                }
                            }
                            
                            let renderedPeer = RenderedPeer(peerId: peer.id, peers: peers)
                            let isUnread = postbox.readStateTable.getCombinedState(peer.id)?.isUnread ?? false
                            renderedPeers.append(ChatListGroupReferencePeer(peer: renderedPeer, isUnread: isUnread))
                            
                            if foundIndices.count == 1 && message == nil {
                                message = postbox.messageHistoryTable.getMessage(messageIndex).flatMap({ postbox.messageHistoryTable.renderMessage($0, peerTable: postbox.peerTable) })
                            }
                        }
                    }
                    
                    self.groupEntries.append(ChatListGroupReferenceEntry(groupId: groupId, message: message, renderedPeers: renderedPeers, unreadState: postbox.groupMessageStatsTable.get(groupId: groupId)))
                }
            }
        }
    }
    
    func refreshDueToExternalTransaction(postbox: Postbox) -> Bool {
        var updated = false
        
        self.state = ChatListViewState(postbox: postbox, spaces: self.spaces, anchorIndex: .absoluteUpperBound, filterPredicate: self.filterPredicate, summaryComponents: self.summaryComponents, halfLimit: self.count)
        self.sampledState = self.state.sample(postbox: postbox)
        updated = true
        
        let currentGroupEntries = self.groupEntries
        
        self.reloadGroups(postbox: postbox)
        
        if self.groupEntries != currentGroupEntries {
            updated = true
        }
        
        return updated
    }
    
    func replay(postbox: Postbox, operations: [PeerGroupId: [ChatListOperation]], updatedPeerNotificationSettings: [PeerId: (PeerNotificationSettings?, PeerNotificationSettings)], updatedPeers: [PeerId: Peer], updatedPeerPresences: [PeerId: PeerPresence], transaction: PostboxTransaction, context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        
        if transaction.updatedGlobalNotificationSettings && self.filterPredicate != nil {
            self.state = ChatListViewState(postbox: postbox, spaces: self.spaces, anchorIndex: .absoluteUpperBound, filterPredicate: self.filterPredicate, summaryComponents: self.summaryComponents, halfLimit: self.count)
            self.sampledState = self.state.sample(postbox: postbox)
            hasChanges = true
        } else {
            if self.state.replay(postbox: postbox, transaction: transaction) {
                self.sampledState = self.state.sample(postbox: postbox)
                hasChanges = true
            }
        }
        
        if case .root = self.groupId, self.filterPredicate == nil {
            var invalidatedGroups = false
            for (groupId, groupOperations) in operations {
                if case .group = groupId, !groupOperations.isEmpty {
                    invalidatedGroups = true
                }
            }
            
            if invalidatedGroups {
                self.reloadGroups(postbox: postbox)
                hasChanges = true
            } else {
                for i in 0 ..< self.groupEntries.count {
                    if let updatedState = transaction.currentUpdatedTotalUnreadSummaries[self.groupEntries[i].groupId] {
                        self.groupEntries[i] = ChatListGroupReferenceEntry(groupId: self.groupEntries[i].groupId, message: self.groupEntries[i].message, renderedPeers: self.groupEntries[i].renderedPeers, unreadState: updatedState)
                        hasChanges = true
                    }
                }
                
                if !transaction.alteredInitialPeerCombinedReadStates.isEmpty {
                    for i in 0 ..< self.groupEntries.count {
                        for j in 0 ..< groupEntries[i].renderedPeers.count {
                            if transaction.alteredInitialPeerCombinedReadStates[groupEntries[i].renderedPeers[j].peer.peerId] != nil {
                                let isUnread = postbox.readStateTable.getCombinedState(groupEntries[i].renderedPeers[j].peer.peerId)?.isUnread ?? false
                                if isUnread != groupEntries[i].renderedPeers[j].isUnread {
                                    var renderedPeers = self.groupEntries[i].renderedPeers
                                    renderedPeers[j] = ChatListGroupReferencePeer(peer: groupEntries[i].renderedPeers[j].peer, isUnread: isUnread)
                                    self.groupEntries[i] = ChatListGroupReferenceEntry(groupId: self.groupEntries[i].groupId, message: self.groupEntries[i].message, renderedPeers: renderedPeers, unreadState: self.groupEntries[i].unreadState)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        /*
        
        
        var updateAdditionalItems = false
        if let itemIds = transaction.replacedAdditionalChatListItems {
            self.additionalItemIds = Set(itemIds)
            updateAdditionalItems = true
        }
        for peerId in self.additionalItemIds {
            if transaction.currentOperationsByPeerId[peerId] != nil {
                updateAdditionalItems = true
            }
            if transaction.currentUpdatedPeers[peerId] != nil {
                updateAdditionalItems = true
            }
            if transaction.currentUpdatedChatListInclusions[peerId] != nil {
                updateAdditionalItems = true
            }
        }
        if updateAdditionalItems {
            self.additionalItemEntries.removeAll()
            for peerId in postbox.additionalChatListItemsTable.get() {
                if let entry = postbox.chatListTable.getStandalone(peerId: peerId, messageHistoryTable: postbox.messageHistoryTable) {
                    self.additionalItemEntries.append(MutableChatListEntry(entry, cachedDataTable: postbox.cachedPeerDataTable, readStateTable: postbox.readStateTable, messageHistoryTable: postbox.messageHistoryTable))
                }
            }
            hasChanges = true
        }
        var updateAdditionalMixedItems = false
        for peerId in self.additionalMixedItemIds.union(self.additionalMixedPinnedItemIds) {
            if transaction.currentOperationsByPeerId[peerId] != nil {
                updateAdditionalMixedItems = true
            }
            if transaction.currentUpdatedPeers[peerId] != nil {
                updateAdditionalMixedItems = true
            }
            if transaction.currentUpdatedChatListInclusions[peerId] != nil {
                updateAdditionalMixedItems = true
            }
        }
        if updateAdditionalMixedItems {
            self.additionalMixedItemEntries.removeAll()
            for peerId in self.additionalMixedItemIds {
                if let entry = postbox.chatListTable.getEntry(peerId: peerId, messageHistoryTable: postbox.messageHistoryTable, peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable) {
                    self.additionalMixedItemEntries.append(MutableChatListEntry(entry, cachedDataTable: postbox.cachedPeerDataTable, readStateTable: postbox.readStateTable, messageHistoryTable: postbox.messageHistoryTable))
                }
            }
            self.additionalMixedPinnedEntries.removeAll()
            for peerId in self.additionalMixedPinnedItemIds {
                if let entry = postbox.chatListTable.getEntry(peerId: peerId, messageHistoryTable: postbox.messageHistoryTable, peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable) {
                    self.additionalMixedPinnedEntries.append(MutableChatListEntry(entry, cachedDataTable: postbox.cachedPeerDataTable, readStateTable: postbox.readStateTable, messageHistoryTable: postbox.messageHistoryTable))
                }
            }
            
            hasChanges = true
        }*/
        return hasChanges
    }
    
    func complete(postbox: Postbox, context: MutableChatListViewReplayContext) {
        
    }
    
    func firstHole() -> (PeerGroupId, ChatListHole)? {
        return self.sampledState.hole
    }
    
    /*private func renderEntry(_ entry: MutableChatListEntry, postbox: Postbox, renderMessage: (IntermediateMessage) -> Message, getPeer: (PeerId) -> Peer?, getPeerNotificationSettings: (PeerId) -> PeerNotificationSettings?, getPeerPresence: (PeerId) -> PeerPresence?) -> MutableChatListEntry? {
        switch entry {
        case let .IntermediateMessageEntry(index, messageIndex):
            let renderedMessage: Message?
            if let messageIndex = messageIndex {
                renderedMessage = postbox.messageHistoryTable.getMessage(messageIndex).flatMap(renderMessage)
            } else {
                renderedMessage = nil
            }
            var peers = SimpleDictionary<PeerId, Peer>()
            var notificationSettings: PeerNotificationSettings?
            var presence: PeerPresence?
            var isContact: Bool = false
            if let peer = getPeer(index.messageIndex.id.peerId) {
                peers[peer.id] = peer
                if let associatedPeerId = peer.associatedPeerId {
                    if let associatedPeer = getPeer(associatedPeerId) {
                        peers[associatedPeer.id] = associatedPeer
                    }
                    notificationSettings = getPeerNotificationSettings(associatedPeerId)
                    presence = getPeerPresence(associatedPeerId)
                    isContact = postbox.contactsTable.isContact(peerId: associatedPeerId)
                } else {
                    notificationSettings = getPeerNotificationSettings(index.messageIndex.id.peerId)
                    presence = getPeerPresence(index.messageIndex.id.peerId)
                    isContact = postbox.contactsTable.isContact(peerId: peer.id)
                }
            }
            
            var tagSummaryCount: Int32?
            var actionsSummaryCount: Int32?
            
            if let tagSummary = self.summaryComponents.tagSummary {
                let key = MessageHistoryTagsSummaryKey(tag: tagSummary.tag, peerId: index.messageIndex.id.peerId, namespace: tagSummary.namespace)
                if let summary = postbox.messageHistoryTagsSummaryTable.get(key) {
                    tagSummaryCount = summary.count
                }
            }
            
            if let actionsSummary = self.summaryComponents.actionsSummary {
                let key = PendingMessageActionsSummaryKey(type: actionsSummary.type, peerId: index.messageIndex.id.peerId, namespace: actionsSummary.namespace)
                actionsSummaryCount = postbox.pendingMessageActionsMetadataTable.getCount(.peerNamespaceAction(key.peerId, key.namespace, key.type))
            }
            
            return .MessageEntry(index: index, message: renderedMessage, readState: postbox.readStateTable.getCombinedState(index.messageIndex.id.peerId), notificationSettings: notificationSettings, embeddedInterfaceState: postbox.peerChatInterfaceStateTable.get(index.messageIndex.id.peerId)?.chatListEmbeddedState, renderedPeer: RenderedPeer(peerId: index.messageIndex.id.peerId, peers: peers), presence: presence, tagSummaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: tagSummaryCount, actionsSummaryCount: actionsSummaryCount), hasFailedMessages: postbox.messageHistoryFailedTable.contains(peerId: index.messageIndex.id.peerId), isContact: isContact)
        default:
            return nil
        }
    }*/
    
    func render(postbox: Postbox, renderMessage: (IntermediateMessage) -> Message, getPeer: (PeerId) -> Peer?, getPeerNotificationSettings: (PeerId) -> PeerNotificationSettings?, getPeerPresence: (PeerId) -> PeerPresence?) {
        /*for i in 0 ..< self.entries.count {
            if let updatedEntry = self.renderEntry(self.entries[i], postbox: postbox, renderMessage: renderMessage, getPeer: getPeer, getPeerNotificationSettings: getPeerNotificationSettings, getPeerPresence: getPeerPresence) {
                self.entries[i] = updatedEntry
            }
        }
        for i in 0 ..< self.additionalItemEntries.count {
            if let updatedEntry = self.renderEntry(self.additionalItemEntries[i], postbox: postbox, renderMessage: renderMessage, getPeer: getPeer, getPeerNotificationSettings: getPeerNotificationSettings, getPeerPresence: getPeerPresence) {
                self.additionalItemEntries[i] = updatedEntry
            }
        }
        for i in 0 ..< self.additionalMixedItemEntries.count {
            if let updatedEntry = self.renderEntry(self.additionalMixedItemEntries[i], postbox: postbox, renderMessage: renderMessage, getPeer: getPeer, getPeerNotificationSettings: getPeerNotificationSettings, getPeerPresence: getPeerPresence) {
                self.additionalMixedItemEntries[i] = updatedEntry
            }
        }
        for i in 0 ..< self.additionalMixedPinnedEntries.count {
            if let updatedEntry = self.renderEntry(self.additionalMixedPinnedEntries[i], postbox: postbox, renderMessage: renderMessage, getPeer: getPeer, getPeerNotificationSettings: getPeerNotificationSettings, getPeerPresence: getPeerPresence) {
                self.additionalMixedPinnedEntries[i] = updatedEntry
            }
        }*/
    }
}

public final class ChatListView {
    public let groupId: PeerGroupId
    public let additionalItemEntries: [ChatListEntry]
    public let entries: [ChatListEntry]
    public let groupEntries: [ChatListGroupReferenceEntry]
    public let earlierIndex: ChatListIndex?
    public let laterIndex: ChatListIndex?
    
    init(_ mutableView: MutableChatListView) {
        self.groupId = mutableView.groupId
        
        var entries: [ChatListEntry] = []
        for entry in mutableView.sampledState.entries {
            switch entry {
            case let .MessageEntry(index, message, combinedReadState, _, isRemovedFromTotalUnreadCount, embeddedState, peer, peerPresence, summaryInfo, hasFailed, isContact):
                entries.append(.MessageEntry(index: index, message: message, readState: combinedReadState, isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount, embeddedInterfaceState: embeddedState, renderedPeer: peer, presence: peerPresence, summaryInfo: summaryInfo, hasFailed: hasFailed, isContact: isContact))
            case let .HoleEntry(hole):
                entries.append(.HoleEntry(hole))
            case .IntermediateMessageEntry:
                assertionFailure()
            }
        }
        
        self.entries = entries
        self.earlierIndex = mutableView.sampledState.lower?.index
        self.laterIndex = mutableView.sampledState.upper?.index
        
        self.groupEntries = mutableView.groupEntries
        
        var additionalItemEntries: [ChatListEntry] = []
        /*for entry in mutableView.additionalItemEntries {
            switch entry {
                case let .MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, peerPresence, summaryInfo, hasFailed, isContact):
                    additionalItemEntries.append(.MessageEntry(index, message, combinedReadState, notificationSettings, embeddedState, peer, peerPresence, summaryInfo, hasFailed, isContact))
                case .HoleEntry:
                    assertionFailure()
                case .IntermediateMessageEntry:
                    assertionFailure()
            }
        }*/
        
        self.additionalItemEntries = additionalItemEntries
    }
}
