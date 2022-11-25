import Postbox

public final class EngineChatList: Equatable {
    public enum Group {
        case root
        case archive
    }

    public typealias MessageTagSummaryInfo = ChatListMessageTagSummaryInfo

    public enum PinnedItem {
        public typealias Id = PinnedItemId
    }

    public enum RelativePosition {
        case later(than: EngineChatList.Item.Index?)
        case earlier(than: EngineChatList.Item.Index?)
    }
    
    public struct Draft: Equatable {
        public var text: String
        public var entities: [MessageTextEntity]
        
        public init(text: String, entities: [MessageTextEntity]) {
            self.text = text
            self.entities = entities
        }
    }
    
    public struct ForumTopicData: Equatable {
        public var title: String
        public let iconFileId: Int64?
        public let iconColor: Int32
        public var maxOutgoingReadMessageId: EngineMessage.Id
        
        public init(title: String, iconFileId: Int64?, iconColor: Int32, maxOutgoingReadMessageId: EngineMessage.Id) {
            self.title = title
            self.iconFileId = iconFileId
            self.iconColor = iconColor
            self.maxOutgoingReadMessageId = maxOutgoingReadMessageId
        }
    }

    public final class Item: Equatable {
        public enum Id: Hashable {
            case chatList(EnginePeer.Id)
            case forum(Int64)
        }
        
        public enum PinnedIndex: Equatable, Comparable {
            case none
            case index(Int)
            
            public static func <(lhs: PinnedIndex, rhs: PinnedIndex) -> Bool {
                switch lhs {
                case .none:
                    switch rhs {
                    case .none:
                        return false
                    case .index:
                        return false
                    }
                case let .index(lhsValue):
                    switch rhs {
                    case .none:
                        return true
                    case let .index(rhsValue):
                        return lhsValue >= rhsValue
                    }
                }
            }
        }
        
        public enum Index: Equatable, Comparable {
            public typealias ChatList = ChatListIndex
            
            case chatList(ChatListIndex)
            case forum(pinnedIndex: PinnedIndex, timestamp: Int32, threadId: Int64, namespace: EngineMessage.Id.Namespace, id: EngineMessage.Id.Id)
            
            public static func <(lhs: Index, rhs: Index) -> Bool {
                switch lhs {
                case let .chatList(lhsIndex):
                    if case let .chatList(rhsIndex) = rhs {
                        return lhsIndex < rhsIndex
                    } else {
                        return true
                    }
                case let .forum(lhsPinnedIndex, lhsTimestamp, lhsThreadId, lhsNamespace, lhsId):
                    if case let .forum(rhsPinnedIndex, rhsTimestamp, rhsThreadId, rhsNamespace, rhsId) = rhs {
                        if lhsPinnedIndex != rhsPinnedIndex {
                            return lhsPinnedIndex < rhsPinnedIndex
                        }
                        if lhsTimestamp != rhsTimestamp {
                            return lhsTimestamp < rhsTimestamp
                        }
                        if lhsThreadId != rhsThreadId {
                            return lhsThreadId < rhsThreadId
                        }
                        if lhsNamespace != rhsNamespace {
                            return lhsNamespace < rhsNamespace
                        }
                        return lhsId < rhsId
                    } else {
                        return false
                    }
                }
            }
        }

        public let id: Id
        public let index: Index
        public let messages: [EngineMessage]
        public let readCounters: EnginePeerReadCounters?
        public let isMuted: Bool
        public let draft: Draft?
        public let threadData: MessageHistoryThreadData?
        public let renderedPeer: EngineRenderedPeer
        public let presence: EnginePeer.Presence?
        public let hasUnseenMentions: Bool
        public let hasUnseenReactions: Bool
        public let forumTopicData: ForumTopicData?
        public let hasFailed: Bool
        public let isContact: Bool

        public init(
            id: Id,
            index: Index,
            messages: [EngineMessage],
            readCounters: EnginePeerReadCounters?,
            isMuted: Bool,
            draft: Draft?,
            threadData: MessageHistoryThreadData?,
            renderedPeer: EngineRenderedPeer,
            presence: EnginePeer.Presence?,
            hasUnseenMentions: Bool,
            hasUnseenReactions: Bool,
            forumTopicData: ForumTopicData?,
            hasFailed: Bool,
            isContact: Bool
        ) {
            self.id = id
            self.index = index
            self.messages = messages
            self.readCounters = readCounters
            self.isMuted = isMuted
            self.draft = draft
            self.threadData = threadData
            self.renderedPeer = renderedPeer
            self.presence = presence
            self.hasUnseenMentions = hasUnseenMentions
            self.hasUnseenReactions = hasUnseenReactions
            self.forumTopicData = forumTopicData
            self.hasFailed = hasFailed
            self.isContact = isContact
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.index != rhs.index {
                return false
            }
            if lhs.messages != rhs.messages {
                return false
            }
            if lhs.readCounters != rhs.readCounters {
                return false
            }
            if lhs.isMuted != rhs.isMuted {
                return false
            }
            if lhs.draft != rhs.draft {
                return false
            }
            if lhs.threadData != rhs.threadData {
                return false
            }
            if lhs.renderedPeer != rhs.renderedPeer {
                return false
            }
            if lhs.presence != rhs.presence {
                return false
            }
            if lhs.hasUnseenMentions != rhs.hasUnseenMentions {
                return false
            }
            if lhs.hasUnseenReactions != rhs.hasUnseenReactions {
                return false
            }
            if lhs.forumTopicData != rhs.forumTopicData {
                return false
            }
            if lhs.hasFailed != rhs.hasFailed {
                return false
            }
            if lhs.isContact != rhs.isContact {
                return false
            }
            return true
        }
    }

    public final class GroupItem: Equatable {
        public final class Item: Equatable {
            public let peer: EngineRenderedPeer
            public let isUnread: Bool

            public init(peer: EngineRenderedPeer, isUnread: Bool) {
                self.peer = peer
                self.isUnread = isUnread
            }

            public static func ==(lhs: Item, rhs: Item) -> Bool {
                if lhs.peer != rhs.peer {
                    return false
                }
                if lhs.isUnread != rhs.isUnread {
                    return false
                }
                return true
            }
        }

        public let id: Group
        public let topMessage: EngineMessage?
        public let items: [Item]
        public let unreadCount: Int

        public init(
            id: Group,
            topMessage: EngineMessage?,
            items: [Item],
            unreadCount: Int
        ) {
            self.id = id
            self.topMessage = topMessage
            self.items = items
            self.unreadCount = unreadCount
        }

        public static func ==(lhs: GroupItem, rhs: GroupItem) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.topMessage?.index != rhs.topMessage?.index {
                return false
            }
            if lhs.topMessage?.stableVersion != rhs.topMessage?.stableVersion {
                return false
            }
            if lhs.items != rhs.items {
                return false
            }
            if lhs.unreadCount != rhs.unreadCount {
                return false
            }
            return true
        }
    }

    public final class AdditionalItem: Equatable {
        public final class PromoInfo: Equatable {
            public enum Content: Equatable {
                case proxy
                case psa(type: String, message: String?)
            }

            public let content: Content

            public init(content: Content) {
                self.content = content
            }
            
            public static func ==(lhs: PromoInfo, rhs: PromoInfo) -> Bool {
                if lhs.content != rhs.content {
                    return false
                }
                
                return true
            }
        }

        public let item: Item
        public let promoInfo: PromoInfo

        public init(item: Item, promoInfo: PromoInfo) {
            self.item = item
            self.promoInfo = promoInfo
        }
        
        public static func ==(lhs: AdditionalItem, rhs: AdditionalItem) -> Bool {
            if lhs.item != rhs.item {
                return false
            }
            if lhs.promoInfo != rhs.promoInfo {
                return false
            }
            
            return true
        }
    }

    public let items: [Item]
    public let groupItems: [GroupItem]
    public let additionalItems: [AdditionalItem]
    public let hasEarlier: Bool
    public let hasLater: Bool
    public let isLoading: Bool

    public init(
        items: [Item],
        groupItems: [GroupItem],
        additionalItems: [AdditionalItem],
        hasEarlier: Bool,
        hasLater: Bool,
        isLoading: Bool
    ) {
        self.items = items
        self.groupItems = groupItems
        self.additionalItems = additionalItems
        self.hasEarlier = hasEarlier
        self.hasLater = hasLater
        self.isLoading = isLoading
    }
    
    public static func ==(lhs: EngineChatList, rhs: EngineChatList) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.groupItems != rhs.groupItems {
            return false
        }
        if lhs.additionalItems != rhs.additionalItems {
            return false
        }
        if lhs.hasEarlier != rhs.hasEarlier {
            return false
        }
        if lhs.hasLater != rhs.hasLater {
            return false
        }
        if lhs.isLoading != rhs.isLoading {
            return false
        }
        
        return true
    }
}

public extension EngineChatList.Group {
    init(_ group: PeerGroupId) {
        switch group {
        case .root:
            self = .root
        case let .group(value):
            assert(value == Namespaces.PeerGroup.archive.rawValue)
            self = .archive
        }
    }

    func _asGroup() -> PeerGroupId {
        switch self {
        case .root:
            return .root
        case .archive:
            return Namespaces.PeerGroup.archive
        }
    }
}

public extension EngineChatList.RelativePosition {
    init(_ position: ChatListRelativePosition) {
        switch position {
        case let .earlier(than):
            self = .earlier(than: than.flatMap(EngineChatList.Item.Index.chatList))
        case let .later(than):
            self = .later(than: than.flatMap(EngineChatList.Item.Index.chatList))
        }
    }

    func _asPosition() -> ChatListRelativePosition? {
        switch self {
        case let .earlier(than):
            guard case let .chatList(than) = than else {
                return nil
            }
            return .earlier(than: than)
        case let .later(than):
            guard case let .chatList(than) = than else {
                return nil
            }
            return .later(than: than)
        }
    }
}

extension EngineChatList.Item {
    convenience init?(_ entry: ChatListEntry) {
        switch entry {
        case let .MessageEntry(index, messages, readState, isRemovedFromTotalUnreadCount, embeddedState, renderedPeer, presence, tagSummaryInfo, forumTopicData, hasFailed, isContact):
            var draft: EngineChatList.Draft?
            if let embeddedState = embeddedState, let _ = embeddedState.overrideChatTimestamp {
                if let opaqueState = _internal_decodeStoredChatInterfaceState(state: embeddedState) {
                    if let text = opaqueState.synchronizeableInputState?.text {
                        draft = EngineChatList.Draft(text: text, entities: opaqueState.synchronizeableInputState?.entities ?? [])
                    }
                }
            }
            
            var hasUnseenMentions = false
            if let info = tagSummaryInfo[ChatListEntryMessageTagSummaryKey(
                tag: .unseenPersonalMessage,
                actionType: PendingMessageActionType.consumeUnseenPersonalMessage
            )] {
                hasUnseenMentions = (info.tagSummaryCount ?? 0) > (info.actionsSummaryCount ?? 0)
            }
            
            var hasUnseenReactions = false
            if let info = tagSummaryInfo[ChatListEntryMessageTagSummaryKey(
                tag: .unseenReaction,
                actionType: PendingMessageActionType.readReaction
            )] {
                hasUnseenReactions = (info.tagSummaryCount ?? 0) != 0// > (info.actionsSummaryCount ?? 0)
            }
            
            var forumTopicDataValue: EngineChatList.ForumTopicData?
            if let forumTopicData = forumTopicData?.data.get(MessageHistoryThreadData.self) {
                forumTopicDataValue = EngineChatList.ForumTopicData(title: forumTopicData.info.title, iconFileId: forumTopicData.info.icon, iconColor: forumTopicData.info.iconColor, maxOutgoingReadMessageId: MessageId(peerId: index.messageIndex.id.peerId, namespace: Namespaces.Message.Cloud, id: forumTopicData.maxOutgoingReadId))
            }
            
            let readCounters = readState.flatMap(EnginePeerReadCounters.init)

            self.init(
                id: .chatList(index.messageIndex.id.peerId),
                index: .chatList(index),
                messages: messages.map(EngineMessage.init),
                readCounters: readCounters,
                isMuted: isRemovedFromTotalUnreadCount,
                draft: draft,
                threadData: nil,
                renderedPeer: EngineRenderedPeer(renderedPeer),
                presence: presence.flatMap(EnginePeer.Presence.init),
                hasUnseenMentions: hasUnseenMentions,
                hasUnseenReactions: hasUnseenReactions,
                forumTopicData: forumTopicDataValue,
                hasFailed: hasFailed,
                isContact: isContact
            )
        case .HoleEntry:
            return nil
        }
    }
}

extension EngineChatList.GroupItem {
    convenience init(_ entry: ChatListGroupReferenceEntry) {
        self.init(
            id: EngineChatList.Group(entry.groupId),
            topMessage: entry.message.flatMap(EngineMessage.init),
            items: entry.renderedPeers.map { peer in
                return EngineChatList.GroupItem.Item(
                    peer: EngineRenderedPeer(peer.peer),
                    isUnread: peer.isUnread
                )
            },
            unreadCount: Int(entry.unreadState.count(countingCategory: .chats, mutedCategory: .all))
        )
    }
}

extension EngineChatList.AdditionalItem.PromoInfo {
    convenience init(_ item: PromoChatListItem) {
        let content: EngineChatList.AdditionalItem.PromoInfo.Content
        switch item.kind {
        case .proxy:
            content = .proxy
        case let .psa(type, message):
            content = .psa(type: type, message: message)
        }

        self.init(content: content)
    }
}

extension EngineChatList.AdditionalItem {
    convenience init?(_ entry: ChatListAdditionalItemEntry) {
        guard let item = EngineChatList.Item(entry.entry) else {
            return nil
        }
        guard let promoInfo = (entry.info as? PromoChatListItem).flatMap(EngineChatList.AdditionalItem.PromoInfo.init) else {
            return nil
        }
        self.init(item: item, promoInfo: promoInfo)
    }
}

public extension EngineChatList {
    convenience init(_ view: ChatListView) {
        var isLoading = false

        var items: [EngineChatList.Item] = []
        loop: for entry in view.entries {
            switch entry {
            case .MessageEntry:
                if let item = EngineChatList.Item(entry) {
                    items.append(item)
                }
            case .HoleEntry:
                isLoading = true
                break loop
            }
        }

        self.init(
            items: items,
            groupItems: view.groupEntries.map(EngineChatList.GroupItem.init),
            additionalItems: view.additionalItemEntries.compactMap(EngineChatList.AdditionalItem.init),
            hasEarlier: view.earlierIndex != nil,
            hasLater: view.laterIndex != nil,
            isLoading: isLoading
        )
    }
}
