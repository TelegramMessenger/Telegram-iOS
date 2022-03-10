import Postbox

public final class EngineChatList {
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

    public final class Item {
        public typealias Index = ChatListIndex

        public let index: Index
        public let messages: [EngineMessage]
        public let readCounters: EnginePeerReadCounters?
        public let isMuted: Bool
        public let draftText: String?
        public let renderedPeer: EngineRenderedPeer
        public let presence: EnginePeer.Presence?
        public let hasUnseenMentions: Bool
        public let hasUnseenReactions: Bool
        public let hasFailed: Bool
        public let isContact: Bool

        public init(
            index: Index,
            messages: [EngineMessage],
            readCounters: EnginePeerReadCounters?,
            isMuted: Bool,
            draftText: String?,
            renderedPeer: EngineRenderedPeer,
            presence: EnginePeer.Presence?,
            hasUnseenMentions: Bool,
            hasUnseenReactions: Bool,
            hasFailed: Bool,
            isContact: Bool
        ) {
            self.index = index
            self.messages = messages
            self.readCounters = readCounters
            self.isMuted = isMuted
            self.draftText = draftText
            self.renderedPeer = renderedPeer
            self.presence = presence
            self.hasUnseenMentions = hasUnseenMentions
            self.hasUnseenReactions = hasUnseenReactions
            self.hasFailed = hasFailed
            self.isContact = isContact
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

    public final class AdditionalItem {
        public final class PromoInfo {
            public enum Content {
                case proxy
                case psa(type: String, message: String?)
            }

            public let content: Content

            public init(content: Content) {
                self.content = content
            }
        }

        public let item: Item
        public let promoInfo: PromoInfo

        public init(item: Item, promoInfo: PromoInfo) {
            self.item = item
            self.promoInfo = promoInfo
        }
    }

    public let items: [Item]
    public let groupItems: [GroupItem]
    public let additionalItems: [AdditionalItem]
    public let hasEarlier: Bool
    public let hasLater: Bool
    public let isLoading: Bool

    init(
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
            self = .earlier(than: than)
        case let .later(than):
            self = .later(than: than)
        }
    }

    func _asPosition() -> ChatListRelativePosition {
        switch self {
        case let .earlier(than):
            return .earlier(than: than)
        case let .later(than):
            return .later(than: than)
        }
    }
}

extension EngineChatList.Item {
    convenience init?(_ entry: ChatListEntry) {
        switch entry {
        case let .MessageEntry(index, messages, readState, isRemovedFromTotalUnreadCount, embeddedState, renderedPeer, presence, tagSummaryInfo, hasFailed, isContact):
            var draftText: String?
            if let embeddedState = embeddedState, let _ = embeddedState.overrideChatTimestamp {
                if let opaqueState = _internal_decodeStoredChatInterfaceState(state: embeddedState) {
                    if let text = opaqueState.synchronizeableInputState?.text {
                        draftText = text
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
            
            self.init(
                index: index,
                messages: messages.map(EngineMessage.init),
                readCounters: readState.flatMap(EnginePeerReadCounters.init),
                isMuted: isRemovedFromTotalUnreadCount,
                draftText: draftText,
                renderedPeer: EngineRenderedPeer(renderedPeer),
                presence: presence.flatMap(EnginePeer.Presence.init),
                hasUnseenMentions: hasUnseenMentions,
                hasUnseenReactions: hasUnseenReactions,
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
