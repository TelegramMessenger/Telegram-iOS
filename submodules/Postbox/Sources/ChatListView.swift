import Foundation

public struct ChatListEntryMessageTagSummaryKey: Hashable {
    public var tag: MessageTags
    public var actionType: PendingMessageActionType
    
    public init(tag: MessageTags, actionType: PendingMessageActionType) {
        self.tag = tag
        self.actionType = actionType
    }
}

public struct ChatListEntryMessageTagSummaryComponent {
    public let namespace: MessageId.Namespace
    
    public init(namespace: MessageId.Namespace) {
        self.namespace = namespace
    }
}

public struct ChatListEntryPendingMessageActionsSummaryComponent {
    public let namespace: MessageId.Namespace
    
    public init(namespace: MessageId.Namespace) {
        self.namespace = namespace
    }
}

public struct ChatListEntrySummaryComponents {
    public struct Component {
        public let tagSummary: ChatListEntryMessageTagSummaryComponent?
        public let actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent?
        
        public init(tagSummary: ChatListEntryMessageTagSummaryComponent? = nil, actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent? = nil) {
            self.tagSummary = tagSummary
            self.actionsSummary = actionsSummary
        }
    }
    public var components: [ChatListEntryMessageTagSummaryKey: Component]
    
    public init(components: [ChatListEntryMessageTagSummaryKey: Component] = [:]) {
        self.components = components
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
    case MessageEntry(index: ChatListIndex, messages: [Message], readState: CombinedPeerReadState?, isRemovedFromTotalUnreadCount: Bool, embeddedInterfaceState: StoredPeerChatInterfaceState?, renderedPeer: RenderedPeer, presence: PeerPresence?, summaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo], hasFailed: Bool, isContact: Bool)
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
            case let .MessageEntry(lhsIndex, lhsMessages, lhsReadState, lhsIsRemovedFromTotalUnreadCount, lhsEmbeddedState, lhsPeer, lhsPresence, lhsInfo, lhsHasFailed, lhsIsContact):
                switch rhs {
                    case let .MessageEntry(rhsIndex, rhsMessages, rhsReadState, rhsIsRemovedFromTotalUnreadCount, rhsEmbeddedState, rhsPeer, rhsPresence, rhsInfo, rhsHasFailed, rhsIsContact):
                        if lhsIndex != rhsIndex {
                            return false
                        }
                        if lhsReadState != rhsReadState {
                            return false
                        }
                        if lhsMessages.count != rhsMessages.count {
                            return false
                        }
                        for i in 0 ..< lhsMessages.count {
                            if lhsMessages[i].stableVersion != rhsMessages[i].stableVersion {
                                return false
                            }
                        }
                        if lhsIsRemovedFromTotalUnreadCount != rhsIsRemovedFromTotalUnreadCount {
                            return false
                        }
                        if let lhsEmbeddedState = lhsEmbeddedState, let rhsEmbeddedState = rhsEmbeddedState {
                            if lhsEmbeddedState != rhsEmbeddedState {
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
    case MessageEntry(index: ChatListIndex, messages: [Message], readState: CombinedPeerReadState?, notificationSettings: PeerNotificationSettings?, isRemovedFromTotalUnreadCount: Bool, embeddedInterfaceState: StoredPeerChatInterfaceState?, renderedPeer: RenderedPeer, presence: PeerPresence?, tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo], hasFailedMessages: Bool, isContact: Bool)
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
            case let .IntermediateMessageEntry(index, _):
                return index
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
    public var pinnedPeerIds: [PeerId]
    public var messageTagSummary: ChatListMessageTagSummaryResultCalculation?
    public var includeAdditionalPeerGroupIds: [PeerGroupId]
    public var include: (Peer, Bool, Bool, Bool, Bool?) -> Bool
    
    public init(includePeerIds: Set<PeerId>, excludePeerIds: Set<PeerId>, pinnedPeerIds: [PeerId], messageTagSummary: ChatListMessageTagSummaryResultCalculation?, includeAdditionalPeerGroupIds: [PeerGroupId], include: @escaping (Peer, Bool, Bool, Bool, Bool?) -> Bool) {
        self.includePeerIds = includePeerIds
        self.excludePeerIds = excludePeerIds
        self.pinnedPeerIds = pinnedPeerIds
        self.messageTagSummary = messageTagSummary
        self.includeAdditionalPeerGroupIds = includeAdditionalPeerGroupIds
        self.include = include
    }
    
    public func includes(peer: Peer, groupId: PeerGroupId, isRemovedFromTotalUnreadCount: Bool, isUnread: Bool, isContact: Bool, messageTagSummaryResult: Bool?) -> Bool {
        if self.pinnedPeerIds.contains(peer.id) {
            return false
        }
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

struct MutableChatListAdditionalItemEntry: Equatable {
    public var entry: MutableChatListEntry
    public var info: AdditionalChatListItem
    
    static func ==(lhs: MutableChatListAdditionalItemEntry, rhs: MutableChatListAdditionalItemEntry) -> Bool {
        if lhs.entry != rhs.entry {
            return false
        }
        if !lhs.info.isEqual(to: rhs.info) {
            return false
        }
        return true
    }
}

public struct ChatListAdditionalItemEntry: Equatable {
    public let entry: ChatListEntry
    public let info: AdditionalChatListItem
    
    public static func ==(lhs: ChatListAdditionalItemEntry, rhs: ChatListAdditionalItemEntry) -> Bool {
        if lhs.entry != rhs.entry {
            return false
        }
        if !lhs.info.isEqual(to: rhs.info) {
            return false
        }
        return true
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
    
    private var additionalItemIds = Set<PeerId>()
    private var additionalItems: [AdditionalChatListItem] = []
    fileprivate var additionalItemEntries: [MutableChatListAdditionalItemEntry] = []
    
    init(postbox: PostboxImpl, currentTransaction: Transaction, groupId: PeerGroupId, filterPredicate: ChatListFilterPredicate?, aroundIndex: ChatListIndex, count: Int, summaryComponents: ChatListEntrySummaryComponents) {
        self.groupId = groupId
        self.filterPredicate = filterPredicate
        self.summaryComponents = summaryComponents
        
        var spaces: [ChatListViewSpace] = [
            .group(groupId: self.groupId, pinned: .notPinned, predicate: filterPredicate)
        ]
        if let filterPredicate = self.filterPredicate {
            spaces.append(.group(groupId: self.groupId, pinned: .includePinnedAsUnpinned, predicate: filterPredicate))
            for additionalGroupId in filterPredicate.includeAdditionalPeerGroupIds {
                spaces.append(.group(groupId: additionalGroupId, pinned: .notPinned, predicate: filterPredicate))
                spaces.append(.group(groupId: additionalGroupId, pinned: .includePinnedAsUnpinned, predicate: filterPredicate))
            }
            if !filterPredicate.pinnedPeerIds.isEmpty {
                spaces.append(.peers(peerIds: filterPredicate.pinnedPeerIds, asPinned: true))
            }
        } else {
            spaces.append(.group(groupId: self.groupId, pinned: .includePinned, predicate: filterPredicate))
        }
        self.spaces = spaces
        self.state = ChatListViewState(postbox: postbox, currentTransaction: currentTransaction, spaces: self.spaces, anchorIndex: aroundIndex, summaryComponents: self.summaryComponents, halfLimit: count)
        self.sampledState = self.state.sample(postbox: postbox, currentTransaction: currentTransaction)
        
        self.count = count
        
        if case .root = groupId, self.filterPredicate == nil {
            let items = postbox.additionalChatListItemsTable.get()
            self.additionalItems = items
            self.additionalItemIds = Set(items.map { $0.peerId })
            for item in items {
                if let entry = postbox.chatListTable.getStandalone(peerId: item.peerId, messageHistoryTable: postbox.messageHistoryTable, includeIfNoHistory: item.includeIfNoHistory) {
                    self.additionalItemEntries.append(MutableChatListAdditionalItemEntry(
                        entry: MutableChatListEntry(entry, cachedDataTable: postbox.cachedPeerDataTable, readStateTable: postbox.readStateTable, messageHistoryTable: postbox.messageHistoryTable),
                        info: item
                    ))
                }
            }
            self.groupEntries = []
            self.reloadGroups(postbox: postbox)
        } else {
            self.groupEntries = []
        }
    }
    
    private func reloadGroups(postbox: PostboxImpl) {
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
    
    func refreshDueToExternalTransaction(postbox: PostboxImpl, currentTransaction: Transaction) -> Bool {
        var updated = false
        
        self.state = ChatListViewState(postbox: postbox, currentTransaction: currentTransaction, spaces: self.spaces, anchorIndex: .absoluteUpperBound, summaryComponents: self.summaryComponents, halfLimit: self.count)
        self.sampledState = self.state.sample(postbox: postbox, currentTransaction: currentTransaction)
        updated = true
        
        let currentGroupEntries = self.groupEntries
        
        self.reloadGroups(postbox: postbox)
        
        if self.groupEntries != currentGroupEntries {
            updated = true
        }
        
        return updated
    }
    
    func replay(postbox: PostboxImpl, currentTransaction: Transaction, operations: [PeerGroupId: [ChatListOperation]], updatedPeerNotificationSettings: [PeerId: (PeerNotificationSettings?, PeerNotificationSettings)], updatedPeers: [PeerId: Peer], updatedPeerPresences: [PeerId: PeerPresence], transaction: PostboxTransaction, context: MutableChatListViewReplayContext) -> Bool {
        var hasChanges = false
        
        if transaction.updatedGlobalNotificationSettings && self.filterPredicate != nil {
            self.state = ChatListViewState(postbox: postbox, currentTransaction: currentTransaction, spaces: self.spaces, anchorIndex: .absoluteUpperBound, summaryComponents: self.summaryComponents, halfLimit: self.count)
            self.sampledState = self.state.sample(postbox: postbox, currentTransaction: currentTransaction)
            hasChanges = true
        } else {
            if self.state.replay(postbox: postbox, currentTransaction: currentTransaction, transaction: transaction) {
                self.sampledState = self.state.sample(postbox: postbox, currentTransaction: currentTransaction)
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
        
        var updateAdditionalItems = false
        if case .root = self.groupId, self.filterPredicate == nil, let items = transaction.replacedAdditionalChatListItems {
            self.additionalItems = items
            self.additionalItemIds = Set(items.map { $0.peerId })
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
            for item in self.additionalItems {
                if let entry = postbox.chatListTable.getStandalone(peerId: item.peerId, messageHistoryTable: postbox.messageHistoryTable, includeIfNoHistory: item.includeIfNoHistory) {
                    self.additionalItemEntries.append(MutableChatListAdditionalItemEntry(
                        entry: MutableChatListEntry(entry, cachedDataTable: postbox.cachedPeerDataTable, readStateTable: postbox.readStateTable, messageHistoryTable: postbox.messageHistoryTable),
                        info: item
                    ))
                }
            }
            hasChanges = true
        }
        return hasChanges
    }
    
    func complete(postbox: PostboxImpl, context: MutableChatListViewReplayContext) {
        
    }
    
    func firstHole() -> (PeerGroupId, ChatListHole)? {
        return self.sampledState.hole
    }
    
    private func renderEntry(_ entry: MutableChatListEntry, postbox: PostboxImpl) -> MutableChatListEntry? {
        switch entry {
        case let .IntermediateMessageEntry(index, messageIndex):
            var renderedMessages: [Message] = []
            if let messageIndex = messageIndex {
                if let messageGroup = postbox.messageHistoryTable.getMessageGroup(at: messageIndex, limit: 10) {
                    renderedMessages.append(contentsOf: messageGroup.compactMap(postbox.renderIntermediateMessage))
                }
            }
            var peers = SimpleDictionary<PeerId, Peer>()
            var notificationSettings: PeerNotificationSettings?
            var presence: PeerPresence?
            var isContact: Bool = false
            if let peer = postbox.peerTable.get(index.messageIndex.id.peerId) {
                peers[peer.id] = peer
                if let associatedPeerId = peer.associatedPeerId {
                    if let associatedPeer = postbox.peerTable.get(associatedPeerId) {
                        peers[associatedPeer.id] = associatedPeer
                    }
                    notificationSettings = postbox.peerNotificationSettingsTable.getEffective(associatedPeerId)
                    presence = postbox.peerPresenceTable.get(associatedPeerId)
                    isContact = postbox.contactsTable.isContact(peerId: associatedPeerId)
                } else {
                    notificationSettings = postbox.peerNotificationSettingsTable.getEffective(index.messageIndex.id.peerId)
                    presence = postbox.peerPresenceTable.get(index.messageIndex.id.peerId)
                    isContact = postbox.contactsTable.isContact(peerId: peer.id)
                }
            }
            
            return .MessageEntry(index: index, messages: renderedMessages, readState: postbox.readStateTable.getCombinedState(index.messageIndex.id.peerId), notificationSettings: notificationSettings, isRemovedFromTotalUnreadCount: false, embeddedInterfaceState: postbox.peerChatInterfaceStateTable.get(index.messageIndex.id.peerId), renderedPeer: RenderedPeer(peerId: index.messageIndex.id.peerId, peers: peers), presence: presence, tagSummaryInfo: [:], hasFailedMessages: postbox.messageHistoryFailedTable.contains(peerId: index.messageIndex.id.peerId), isContact: isContact)
        default:
            return nil
        }
    }
    
    func render(postbox: PostboxImpl) {
        for i in 0 ..< self.additionalItemEntries.count {
            if let updatedEntry = self.renderEntry(self.additionalItemEntries[i].entry, postbox: postbox) {
                self.additionalItemEntries[i].entry = updatedEntry
            }
        }
    }
}

public final class ChatListView {
    public let groupId: PeerGroupId
    public let additionalItemEntries: [ChatListAdditionalItemEntry]
    public let entries: [ChatListEntry]
    public let groupEntries: [ChatListGroupReferenceEntry]
    public let earlierIndex: ChatListIndex?
    public let laterIndex: ChatListIndex?
    
    init(_ mutableView: MutableChatListView) {
        self.groupId = mutableView.groupId
        
        var entries: [ChatListEntry] = []
        for entry in mutableView.sampledState.entries {
            switch entry {
            case let .MessageEntry(index, messages, combinedReadState, _, isRemovedFromTotalUnreadCount, embeddedState, peer, peerPresence, summaryInfo, hasFailed, isContact):
                entries.append(.MessageEntry(index: index, messages: messages, readState: combinedReadState, isRemovedFromTotalUnreadCount: isRemovedFromTotalUnreadCount, embeddedInterfaceState: embeddedState, renderedPeer: peer, presence: peerPresence, summaryInfo: summaryInfo, hasFailed: hasFailed, isContact: isContact))
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
        
        var additionalItemEntries: [ChatListAdditionalItemEntry] = []
        for entry in mutableView.additionalItemEntries {
            switch entry.entry {
            case let .MessageEntry(index, messages, combinedReadState, _, isExcludedFromUnreadCount, embeddedState, peer, peerPresence, summaryInfo, hasFailed, isContact):
                additionalItemEntries.append(ChatListAdditionalItemEntry(
                    entry: .MessageEntry(index: index, messages: messages, readState: combinedReadState, isRemovedFromTotalUnreadCount: isExcludedFromUnreadCount, embeddedInterfaceState: embeddedState, renderedPeer: peer, presence: peerPresence, summaryInfo: summaryInfo, hasFailed: hasFailed, isContact: isContact),
                    info: entry.info
                ))
            case .HoleEntry:
                assertionFailure()
            case .IntermediateMessageEntry:
                assertionFailure()
            }
        }
        
        self.additionalItemEntries = additionalItemEntries
    }
}
