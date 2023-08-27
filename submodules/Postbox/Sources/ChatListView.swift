import Foundation

public struct ChatListEntryMessageTagSummaryKey: Hashable {
    public var tag: MessageTags
    public var actionType: PendingMessageActionType
    
    public init(tag: MessageTags, actionType: PendingMessageActionType) {
        self.tag = tag
        self.actionType = actionType
    }
}

public struct ChatListEntryMessageTagSummaryComponent: Equatable {
    public let namespace: MessageId.Namespace
    
    public init(namespace: MessageId.Namespace) {
        self.namespace = namespace
    }
}

public struct ChatListEntryPendingMessageActionsSummaryComponent: Equatable {
    public let namespace: MessageId.Namespace
    
    public init(namespace: MessageId.Namespace) {
        self.namespace = namespace
    }
}

public struct ChatListEntrySummaryComponents: Equatable {
    public struct Component: Equatable {
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

public struct ChatListForumTopicData: Equatable {
    public var id: Int64
    public var info: StoredMessageHistoryThreadInfo
    
    public init(id: Int64, info: StoredMessageHistoryThreadInfo) {
        self.id = id
        self.info = info
    }
}

public enum ChatListEntry: Comparable {
    public struct MessageEntryData: Equatable {
        public var index: ChatListIndex
        public var messages: [Message]
        public var readState: ChatListViewReadState?
        public var isRemovedFromTotalUnreadCount: Bool
        public var embeddedInterfaceState: StoredPeerChatInterfaceState?
        public var renderedPeer: RenderedPeer
        public var presence: PeerPresence?
        public var summaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo]
        public var forumTopicData: ChatListForumTopicData?
        public var topForumTopics: [ChatListForumTopicData]
        public var hasFailed: Bool
        public var isContact: Bool
        public var autoremoveTimeout: Int32?
        public var storyStats: PeerStoryStats?
        
        public init(
            index: ChatListIndex,
            messages: [Message],
            readState: ChatListViewReadState?,
            isRemovedFromTotalUnreadCount: Bool,
            embeddedInterfaceState: StoredPeerChatInterfaceState?,
            renderedPeer: RenderedPeer,
            presence: PeerPresence?,
            summaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo],
            forumTopicData: ChatListForumTopicData?,
            topForumTopics: [ChatListForumTopicData],
            hasFailed: Bool,
            isContact: Bool,
            autoremoveTimeout: Int32?,
            storyStats: PeerStoryStats?
        ) {
            self.index = index
            self.messages = messages
            self.readState = readState
            self.isRemovedFromTotalUnreadCount = isRemovedFromTotalUnreadCount
            self.embeddedInterfaceState = embeddedInterfaceState
            self.renderedPeer = renderedPeer
            self.presence = presence
            self.summaryInfo = summaryInfo
            self.forumTopicData = forumTopicData
            self.topForumTopics = topForumTopics
            self.hasFailed = hasFailed
            self.isContact = isContact
            self.autoremoveTimeout = autoremoveTimeout
            self.storyStats = storyStats
        }
        
        public static func ==(lhs: MessageEntryData, rhs: MessageEntryData) -> Bool {
            if lhs.index != rhs.index {
                return false
            }
            if lhs.readState != rhs.readState {
                return false
            }
            if lhs.messages.count != rhs.messages.count {
                return false
            }
            for i in 0 ..< lhs.messages.count {
                if lhs.messages[i].stableVersion != rhs.messages[i].stableVersion {
                    return false
                }
                if lhs.messages[i].associatedStories != rhs.messages[i].associatedStories {
                    return false
                }
            }
            if lhs.isRemovedFromTotalUnreadCount != rhs.isRemovedFromTotalUnreadCount {
                return false
            }
            if let lhsEmbeddedState = lhs.embeddedInterfaceState, let rhsEmbeddedState = rhs.embeddedInterfaceState {
                if lhsEmbeddedState != rhsEmbeddedState {
                    return false
                }
            } else if (lhs.embeddedInterfaceState != nil) != (rhs.embeddedInterfaceState != nil) {
                return false
            }
            if lhs.renderedPeer != rhs.renderedPeer {
                return false
            }
            if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
                if !lhsPresence.isEqual(to: rhsPresence) {
                    return false
                }
            } else if (lhs.presence != nil) != (rhs.presence != nil) {
                return false
            }
            if lhs.summaryInfo != rhs.summaryInfo {
                return false
            }
            if lhs.forumTopicData != rhs.forumTopicData {
                return false
            }
            if lhs.topForumTopics != rhs.topForumTopics {
                return false
            }
            if lhs.hasFailed != rhs.hasFailed {
                return false
            }
            if lhs.isContact != rhs.isContact {
                return false
            }
            if lhs.autoremoveTimeout != rhs.autoremoveTimeout {
                return false
            }
            if lhs.storyStats != rhs.storyStats {
                return false
            }
            
            return true
        }
    }
    
    case MessageEntry(MessageEntryData)
    case HoleEntry(ChatListHole)
    
    public var index: ChatListIndex {
        switch self {
        case let .MessageEntry(entryData):
            return entryData.index
        case let .HoleEntry(hole):
            return ChatListIndex(pinningIndex: nil, messageIndex: hole.index)
        }
    }

    public static func ==(lhs: ChatListEntry, rhs: ChatListEntry) -> Bool {
        switch lhs {
        case let .MessageEntry(entryData):
            if case .MessageEntry(entryData) = rhs {
                return true
            } else {
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

public struct PeerStoryStats: Equatable {
    public var totalCount: Int
    public var unseenCount: Int
    public var hasUnseenCloseFriends: Bool
    
    public init(totalCount: Int, unseenCount: Int, hasUnseenCloseFriends: Bool) {
        self.totalCount = totalCount
        self.unseenCount = unseenCount
        self.hasUnseenCloseFriends = hasUnseenCloseFriends
    }
}

func fetchPeerStoryStats(postbox: PostboxImpl, peerId: PeerId) -> PeerStoryStats? {
    guard let topItems = postbox.storyTopItemsTable.get(peerId: peerId) else {
        return nil
    }
    if topItems.id == 0 {
        return nil
    }
    
    var maxSeenId: Int32 = 0
    if let state = postbox.storyPeerStatesTable.get(key: .peer(peerId)) {
        maxSeenId = state.maxSeenId
    }
    
    if topItems.isExact {
        let stats = postbox.storyItemsTable.getStats(peerId: peerId, maxSeenId: maxSeenId)
        return PeerStoryStats(totalCount: stats.total, unseenCount: stats.unseen, hasUnseenCloseFriends: stats.hasUnseenCloseFriends)
    } else {
        return PeerStoryStats(totalCount: 1, unseenCount: topItems.id > maxSeenId ? 1 : 0, hasUnseenCloseFriends: false)
    }
}

enum MutableChatListEntry: Equatable {
    struct MessageEntryData {
        var index: ChatListIndex
        var messages: [Message]
        var readState: ChatListViewReadState?
        var notificationSettings: PeerNotificationSettings?
        var isRemovedFromTotalUnreadCount: Bool
        var embeddedInterfaceState: StoredPeerChatInterfaceState?
        var renderedPeer: RenderedPeer
        var presence: PeerPresence?
        var tagSummaryInfo: [ChatListEntryMessageTagSummaryKey: ChatListMessageTagSummaryInfo]
        var forumTopicData: ChatListForumTopicData?
        var topForumTopics: [ChatListForumTopicData]
        var hasFailedMessages: Bool
        var isContact: Bool
        var autoremoveTimeout: Int32?
        var storyStats: PeerStoryStats?
        
        init(
            index: ChatListIndex,
            messages: [Message],
            readState: ChatListViewReadState?,
            notificationSettings: PeerNotificationSettings?,
            isRemovedFromTotalUnreadCount: Bool,
            embeddedInterfaceState: StoredPeerChatInterfaceState?,
            renderedPeer: RenderedPeer,
            presence: PeerPresence?,
            tagSummaryInfo: [ChatListEntryMessageTagSummaryKey : ChatListMessageTagSummaryInfo],
            forumTopicData: ChatListForumTopicData?,
            topForumTopics: [ChatListForumTopicData],
            hasFailedMessages: Bool,
            isContact: Bool,
            autoremoveTimeout: Int32?,
            storyStats: PeerStoryStats?
        ) {
            self.index = index
            self.messages = messages
            self.readState = readState
            self.notificationSettings = notificationSettings
            self.isRemovedFromTotalUnreadCount = isRemovedFromTotalUnreadCount
            self.embeddedInterfaceState = embeddedInterfaceState
            self.renderedPeer = renderedPeer
            self.presence = presence
            self.tagSummaryInfo = tagSummaryInfo
            self.forumTopicData = forumTopicData
            self.topForumTopics = topForumTopics
            self.hasFailedMessages = hasFailedMessages
            self.isContact = isContact
            self.autoremoveTimeout = autoremoveTimeout
            self.storyStats = storyStats
        }
    }
    
    case IntermediateMessageEntry(index: ChatListIndex, messageIndex: MessageIndex?)
    case MessageEntry(MessageEntryData)
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
        case let .MessageEntry(data):
            return data.index
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

func renderAssociatedMediaForPeers(postbox: PostboxImpl, peers: SimpleDictionary<PeerId, Peer>) -> [MediaId: Media] {
    var result: [MediaId: Media] = [:]
    
    for (_, peer) in peers {
        if let associatedMediaIds = peer.associatedMediaIds {
            for id in associatedMediaIds {
                if result[id] == nil {
                    if let media = postbox.messageHistoryTable.getMedia(id) {
                        result[id] = media
                    }
                }
            }
        }
    }
    
    return result
}

func renderAssociatedMediaForPeers(postbox: PostboxImpl, peers: [Peer]) -> [MediaId: Media] {
    var result: [MediaId: Media] = [:]
    
    for peer in peers {
        if let associatedMediaIds = peer.associatedMediaIds {
            for id in associatedMediaIds {
                if result[id] == nil {
                    if let media = postbox.messageHistoryTable.getMedia(id) {
                        result[id] = media
                    }
                }
            }
        }
    }
    
    return result
}

func renderAssociatedMediaForPeers(postbox: PostboxImpl, peers: [PeerId: Peer]) -> [MediaId: Media] {
    var result: [MediaId: Media] = [:]
    
    for (_, peer) in peers {
        if let associatedMediaIds = peer.associatedMediaIds {
            for id in associatedMediaIds {
                if result[id] == nil {
                    if let media = postbox.messageHistoryTable.getMedia(id) {
                        result[id] = media
                    }
                }
            }
        }
    }
    
    return result
}

public struct ChatListViewReadState: Equatable {
    public var state: CombinedPeerReadState
    public var isMuted: Bool
    
    public init(state: CombinedPeerReadState, isMuted: Bool) {
        self.state = state
        self.isMuted = isMuted
    }
}

final class MutableChatListView {
    let groupId: PeerGroupId
    let filterPredicate: ChatListFilterPredicate?
    private let aroundIndex: ChatListIndex
    private let summaryComponents: ChatListEntrySummaryComponents
    fileprivate var groupEntries: [ChatListGroupReferenceEntry]
    private var count: Int
    
    private let spaces: [ChatListViewSpace]
    fileprivate var state: ChatListViewState
    fileprivate var sampledState: ChatListViewSample
    
    private var additionalItemIds = Set<PeerId>()
    private var additionalItems: [AdditionalChatListItem] = []
    fileprivate var additionalItemEntries: [MutableChatListAdditionalItemEntry] = []
    
    private var currentHiddenPeerIds = Set<PeerId>()
    
    init(postbox: PostboxImpl, currentTransaction: Transaction, groupId: PeerGroupId, filterPredicate: ChatListFilterPredicate?, aroundIndex: ChatListIndex, count: Int, summaryComponents: ChatListEntrySummaryComponents) {
        self.groupId = groupId
        self.filterPredicate = filterPredicate
        self.aroundIndex = aroundIndex
        self.summaryComponents = summaryComponents
        
        self.currentHiddenPeerIds = postbox.hiddenChatIds
        
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
                                if let messageIndex = messageIndex, !postbox.isChatHidden(peerId: messageIndex.id.peerId) {
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
                            
                            let renderedPeer = RenderedPeer(peerId: peer.id, peers: peers, associatedMedia: renderAssociatedMediaForPeers(postbox: postbox, peers: peers))
                            
                            let isUnread: Bool
                            if postbox.seedConfiguration.peerSummaryIsThreadBased(peer) {
                                let hasUnmutedUnread = postbox.peerThreadsSummaryTable.get(peerId: peer.id)?.hasUnmutedUnread ?? false
                                isUnread = hasUnmutedUnread
                            } else {
                                isUnread = postbox.readStateTable.getCombinedState(peer.id)?.isUnread ?? false
                            }
                            
                            renderedPeers.append(ChatListGroupReferencePeer(peer: renderedPeer, isUnread: isUnread))
                            
                            if foundIndices.count == 1 && message == nil {
                                message = postbox.messageHistoryTable.getMessage(messageIndex).flatMap({ postbox.messageHistoryTable.renderMessage($0, peerTable: postbox.peerTable, threadIndexTable: postbox.messageHistoryThreadIndexTable, storyTable: postbox.storyTable) })
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
        
        self.state = ChatListViewState(postbox: postbox, currentTransaction: currentTransaction, spaces: self.spaces, anchorIndex: self.aroundIndex, summaryComponents: self.summaryComponents, halfLimit: self.count)
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
        
        let hiddenChatIds = postbox.hiddenChatIds
        var hasFilterChanges = false
        if hiddenChatIds != self.currentHiddenPeerIds {
            self.currentHiddenPeerIds = hiddenChatIds
            hasFilterChanges = true
        }
        
        if transaction.updatedGlobalNotificationSettings && self.filterPredicate != nil {
            self.state = ChatListViewState(postbox: postbox, currentTransaction: currentTransaction, spaces: self.spaces, anchorIndex: self.aroundIndex, summaryComponents: self.summaryComponents, halfLimit: self.count)
            self.sampledState = self.state.sample(postbox: postbox, currentTransaction: currentTransaction)
            hasChanges = true
        } else if hasFilterChanges {
            self.state = ChatListViewState(postbox: postbox, currentTransaction: currentTransaction, spaces: self.spaces, anchorIndex: self.aroundIndex, summaryComponents: self.summaryComponents, halfLimit: self.count)
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
            if hasFilterChanges {
                invalidatedGroups = true
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
                                
                                let isUnread: Bool
                                if let peer = groupEntries[i].renderedPeers[j].peer.peer, postbox.seedConfiguration.peerSummaryIsThreadBased(peer) {
                                    isUnread = postbox.peerThreadsSummaryTable.get(peerId: peer.id)?.hasUnmutedUnread ?? false
                                } else {
                                    isUnread = postbox.readStateTable.getCombinedState(groupEntries[i].renderedPeers[j].peer.peerId)?.isUnread ?? false
                                }
                                
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
            
            let renderedPeer = RenderedPeer(peerId: index.messageIndex.id.peerId, peers: peers, associatedMedia: renderAssociatedMediaForPeers(postbox: postbox, peers: peers))
            
            var forumTopicData: ChatListForumTopicData?
            if let message = renderedMessages.first, let threadId = message.threadId {
                if let info = postbox.messageHistoryThreadIndexTable.get(peerId: message.id.peerId, threadId: threadId) {
                    forumTopicData = ChatListForumTopicData(id: threadId, info: info)
                }
            }
            
            var topForumTopics: [ChatListForumTopicData] = []
            if let peer = renderedPeer.peer, postbox.seedConfiguration.peerSummaryIsThreadBased(peer) {
                for item in postbox.messageHistoryThreadIndexTable.fetch(peerId: peer.id, namespace: 0, start: .upperBound, end: .lowerBound, limit: 5) {
                    topForumTopics.append(ChatListForumTopicData(id: item.threadId, info: item.info))
                }
            }
            
            let readState: ChatListViewReadState?
            if let peer = postbox.peerTable.get(index.messageIndex.id.peerId), postbox.seedConfiguration.peerSummaryIsThreadBased(peer) {
                let summary = postbox.peerThreadsSummaryTable.get(peerId: index.messageIndex.id.peerId)
                var count: Int32 = 0
                var isMuted: Bool = false
                if let summary = summary {
                    count = summary.totalUnreadCount
                    if count > 0 {
                        isMuted = !summary.hasUnmutedUnread
                    }
                }
                readState = ChatListViewReadState(state: CombinedPeerReadState(states: [(0, .idBased(maxIncomingReadId: 1, maxOutgoingReadId: 0, maxKnownId: 0, count: count, markedUnread: false))]), isMuted: isMuted)
            } else {
                readState = postbox.readStateTable.getCombinedState(index.messageIndex.id.peerId).flatMap { state -> ChatListViewReadState in
                    return ChatListViewReadState(state: state, isMuted: false)
                }
            }
            
            var autoremoveTimeout: Int32?
            if let cachedData = postbox.cachedPeerDataTable.get(index.messageIndex.id.peerId) {
                autoremoveTimeout = postbox.seedConfiguration.decodeAutoremoveTimeout(cachedData)
            }
            
            let storyStats = fetchPeerStoryStats(postbox: postbox, peerId: index.messageIndex.id.peerId)
            
            return .MessageEntry(MutableChatListEntry.MessageEntryData(
                index: index,
                messages: renderedMessages,
                readState: readState,
                notificationSettings: notificationSettings,
                isRemovedFromTotalUnreadCount: false,
                embeddedInterfaceState: postbox.peerChatInterfaceStateTable.get(index.messageIndex.id.peerId),
                renderedPeer: renderedPeer,
                presence: presence,
                tagSummaryInfo: [:],
                forumTopicData: forumTopicData,
                topForumTopics: topForumTopics,
                hasFailedMessages: postbox.messageHistoryFailedTable.contains(peerId: index.messageIndex.id.peerId),
                isContact: isContact,
                autoremoveTimeout: autoremoveTimeout,
                storyStats: storyStats
            ))
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
            case let .MessageEntry(entryData):
                entries.append(.MessageEntry(ChatListEntry.MessageEntryData(
                    index: entryData.index,
                    messages: entryData.messages,
                    readState: entryData.readState,
                    isRemovedFromTotalUnreadCount: entryData.isRemovedFromTotalUnreadCount,
                    embeddedInterfaceState: entryData.embeddedInterfaceState,
                    renderedPeer: entryData.renderedPeer,
                    presence: entryData.presence,
                    summaryInfo: entryData.tagSummaryInfo,
                    forumTopicData: entryData.forumTopicData,
                    topForumTopics: entryData.topForumTopics,
                    hasFailed: entryData.hasFailedMessages,
                    isContact: entryData.isContact,
                    autoremoveTimeout: entryData.autoremoveTimeout,
                    storyStats: entryData.storyStats
                )))
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
            case let .MessageEntry(entryData):
                additionalItemEntries.append(ChatListAdditionalItemEntry(
                    entry: .MessageEntry(ChatListEntry.MessageEntryData(
                        index: entryData.index,
                        messages: entryData.messages,
                        readState: entryData.readState,
                        isRemovedFromTotalUnreadCount: entryData.isRemovedFromTotalUnreadCount,
                        embeddedInterfaceState: entryData.embeddedInterfaceState,
                        renderedPeer: entryData.renderedPeer,
                        presence: entryData.presence,
                        summaryInfo: entryData.tagSummaryInfo,
                        forumTopicData: entryData.forumTopicData,
                        topForumTopics: entryData.topForumTopics,
                        hasFailed: entryData.hasFailedMessages,
                        isContact: entryData.isContact,
                        autoremoveTimeout: entryData.autoremoveTimeout,
                        storyStats: entryData.storyStats
                    )),
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
