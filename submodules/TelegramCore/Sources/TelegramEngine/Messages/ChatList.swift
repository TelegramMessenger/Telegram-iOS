import Postbox

public final class EngineChatList {
    public enum Group {
        case root
        case archive
    }

    public final class Item {
        public typealias Index = ChatListIndex

        public let index: Index
        public let messages: [EngineMessage]
        public let readState: EngineReadState?
        public let isMuted: Bool
        public let draftText: String?
        public let renderedPeer: EngineRenderedPeer
        public let presence: EnginePeer.Presence?
        public let hasUnseenMentions: Bool
        public let hasFailed: Bool
        public let isContact: Bool

        public init(
            index: Index,
            messages: [EngineMessage],
            readState: EngineReadState?,
            isMuted: Bool,
            draftText: String?,
            renderedPeer: EngineRenderedPeer,
            presence: EnginePeer.Presence?,
            hasUnseenMentions: Bool,
            hasFailed: Bool,
            isContact: Bool
        ) {
            self.index = index
            self.messages = messages
            self.readState = readState
            self.isMuted = isMuted
            self.draftText = draftText
            self.renderedPeer = renderedPeer
            self.presence = presence
            self.hasUnseenMentions = hasUnseenMentions
            self.hasFailed = hasFailed
            self.isContact = isContact
        }
    }

    public final class GroupItem {
        public final class Item {
            public let peer: EngineRenderedPeer
            public let isUnread: Bool

            public init(peer: EngineRenderedPeer, isUnread: Bool) {
                self.peer = peer
                self.isUnread = isUnread
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
    }

    public let items: [Item]
    public let groupItems: [GroupItem]
    public let hasEarlier: Bool
    public let hasLater: Bool

    init(
        items: [Item],
        groupItems: [GroupItem],
        hasEarlier: Bool,
        hasLater: Bool
    ) {
        self.items = items
        self.groupItems = groupItems
        self.hasEarlier = hasEarlier
        self.hasLater = hasLater
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

extension EngineChatList.Item {
    convenience init?(_ entry: ChatListEntry) {
        switch entry {
        case let .MessageEntry(index, messages, readState, isRemovedFromTotalUnreadCount, embeddedInterfaceState, renderedPeer, presence, summaryInfo, hasFailed, isContact):
            self.init(
                index: index,
                messages: messages.map(EngineMessage.init),
                readState: readState.flatMap(EngineReadState.init),
                isMuted: isRemovedFromTotalUnreadCount,
                draftText: nil,
                renderedPeer: EngineRenderedPeer(renderedPeer),
                presence: presence.flatMap(EnginePeer.Presence.init),
                hasUnseenMentions: (summaryInfo.tagSummaryCount ?? 0) > (summaryInfo.actionsSummaryCount ?? 0),
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

extension EngineChatList {
    convenience init(_ view: ChatListView) {
        self.init(
            items: view.entries.compactMap(EngineChatList.Item.init),
            groupItems: view.groupEntries.map(EngineChatList.GroupItem.init),
            hasEarlier: view.earlierIndex != nil,
            hasLater: view.laterIndex != nil
        )
    }
}
