import SwiftSignalKit
import Postbox

public final class EngineTotalReadCounters {
    fileprivate let state: ChatListTotalUnreadState

    public init(state: ChatListTotalUnreadState) {
        self.state = state
    }

    public func count(for category: ChatListTotalUnreadStateCategory, in statsType: ChatListTotalUnreadStateStats, with tags: PeerSummaryCounterTags) -> Int32 {
        return self.state.count(for: category, in: statsType, with: tags)
    }
}

public extension EngineTotalReadCounters {
    func _asCounters() -> ChatListTotalUnreadState {
        return self.state
    }
}

public struct EnginePeerReadCounters: Equatable {
    fileprivate var state: CombinedPeerReadState?
    public var isMuted: Bool

    public init(state: CombinedPeerReadState?, isMuted: Bool) {
        self.state = state
        self.isMuted = isMuted
    }
    
    public init(state: ChatListViewReadState?) {
        self.state = state?.state
        self.isMuted = state?.isMuted ?? false
    }

    public init() {
        self.state = CombinedPeerReadState(states: [])
        self.isMuted = false
    }

    public var count: Int32 {
        guard let state = self.state else {
            return 0
        }
        return state.count
    }

    public var markedUnread: Bool {
        guard let state = self.state else {
            return false
        }
        return state.markedUnread
    }

    public var isUnread: Bool {
        guard let state = self.state else {
            return false
        }
        return state.isUnread
    }
    
    public var hasEverRead: Bool {
        guard let state = self.state else {
            return false
        }
        for (_, state) in state.states {
            switch state {
            case let .idBased(maxIncomingReadId, _, _, _, _):
                if maxIncomingReadId != 0 {
                    return true
                }
            case .indexBased:
                return true
            }
        }
        return false
    }

    public func isOutgoingMessageIndexRead(_ index: EngineMessage.Index) -> Bool {
        guard let state = self.state else {
            return false
        }
        return state.isOutgoingMessageIndexRead(index)
    }

    public func isIncomingMessageIndexRead(_ index: EngineMessage.Index) -> Bool {
        guard let state = self.state else {
            return false
        }
        return state.isIncomingMessageIndexRead(index)
    }
}

public extension EnginePeerReadCounters {
    init(incomingReadId: EngineMessage.Id.Id, outgoingReadId: EngineMessage.Id.Id, count: Int32, markedUnread: Bool) {
        self.init(state: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, .idBased(maxIncomingReadId: incomingReadId, maxOutgoingReadId: outgoingReadId, maxKnownId: max(incomingReadId, outgoingReadId), count: count, markedUnread: markedUnread))]), isMuted: false)
    }
    
    func _asReadCounters() -> CombinedPeerReadState? {
        return self.state
    }
}

public extension TelegramEngine.EngineData.Item {
    enum Messages {
        public struct Message: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Optional<EngineMessage>

            fileprivate var id: EngineMessage.Id
            
            public var mapKey: EngineMessage.Id {
                return self.id
            }

            public init(id: EngineMessage.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .messages(Set([self.id]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessagesView else {
                    preconditionFailure()
                }
                guard let message = view.messages[self.id] else {
                    return nil
                }
                return EngineMessage(message)
            }
        }
        
        public struct MessageGroup: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [EngineMessage]

            fileprivate var id: EngineMessage.Id

            public init(id: EngineMessage.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .messageGroup(id: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessageGroupView else {
                    preconditionFailure()
                }
                return view.messages.map(EngineMessage.init)
            }
        }

        public struct Messages: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [EngineMessage.Id: EngineMessage]

            fileprivate var ids: Set<EngineMessage.Id>

            public init(ids: Set<EngineMessage.Id>) {
                self.ids = ids
            }

            var key: PostboxViewKey {
                return .messages(self.ids)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessagesView else {
                    preconditionFailure()
                }
                var result: [EngineMessage.Id: EngineMessage] = [:]
                for (id, message) in view.messages {
                    result[id] = EngineMessage(message)
                }
                return result
            }
        }
        
        public struct PeerReadCounters: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EnginePeerReadCounters

            fileprivate let id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            var key: PostboxViewKey {
                return .combinedReadState(peerId: self.id, handleThreads: true)
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? CombinedReadStateView else {
                    preconditionFailure()
                }

                return EnginePeerReadCounters(state: view.state, isMuted: false)
            }
        }

        public struct PeerUnreadCount: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Int

            fileprivate let id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            var key: PostboxViewKey {
                return .unreadCounts(items: [.peer(id: self.id, handleThreads: true)])
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? UnreadMessageCountsView else {
                    preconditionFailure()
                }

                return Int(view.count(for: .peer(id: self.id, handleThreads: true)) ?? 0)
            }
        }
        
        public struct PeerUnreadState: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public struct Result: Equatable {
                public var count: Int
                public var isMarkedUnread: Bool
                
                public init(count: Int, isMarkedUnread: Bool) {
                    self.count = count
                    self.isMarkedUnread = isMarkedUnread
                }
            }

            fileprivate let id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            var key: PostboxViewKey {
                return .unreadCounts(items: [.peer(id: self.id, handleThreads: true)])
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? UnreadMessageCountsView else {
                    preconditionFailure()
                }

                if let (value, isUnread) = view.countOrUnread(for: .peer(id: self.id, handleThreads: true)) {
                    return Result(count: Int(value), isMarkedUnread: isUnread)
                }
                return Result(count: 0, isMarkedUnread: false)
            }
        }

        public struct TotalReadCounters: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EngineTotalReadCounters

            public init() {
            }

            var key: PostboxViewKey {
                return .unreadCounts(items: [.total(nil)])
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? UnreadMessageCountsView else {
                    preconditionFailure()
                }
                guard let (_, total) = view.total() else {
                    return EngineTotalReadCounters(state: ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:]))
                }
                return EngineTotalReadCounters(state: total)
            }
        }
        
        public struct ChatListIndex: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EngineChatList.Item.Index?
            
            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }
            
            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .chatListIndex(id: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? ChatListIndexView else {
                    preconditionFailure()
                }
                return view.chatListIndex.flatMap(EngineChatList.Item.Index.chatList)
            }
        }
        
        public struct ChatListGroup: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EngineChatList.Group?
            
            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }
            
            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .chatListIndex(id: self.id)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? ChatListIndexView else {
                    preconditionFailure()
                }
                return view.inclusion.groupId.flatMap(EngineChatList.Group.init)
            }
        }
        
        public struct MessageCount: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public struct ItemKey: Hashable {
                public var peerId: EnginePeer.Id
                public var tag: MessageTags
                public var threadId: Int64?
            }
            
            public typealias Result = Int?
            
            fileprivate var peerId: EnginePeer.Id
            fileprivate var tag: MessageTags
            fileprivate var threadId: Int64?
            public var mapKey: ItemKey {
                return ItemKey(peerId: self.peerId, tag: self.tag, threadId: self.threadId)
            }
            
            public init(peerId: EnginePeer.Id, threadId: Int64?, tag: MessageTags) {
                self.peerId = peerId
                self.threadId = threadId
                self.tag = tag
            }

            var key: PostboxViewKey {
                return .historyTagSummaryView(tag: self.tag, peerId: self.peerId, threadId: self.threadId, namespace: Namespaces.Message.Cloud, customTag: nil)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessageHistoryTagSummaryView else {
                    preconditionFailure()
                }
                return view.count.flatMap(Int.init)
            }
        }
        
        public struct ReactionTagMessageCount: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public struct ItemKey: Hashable {
                public var peerId: EnginePeer.Id
                public var threadId: Int64?
                public var reaction: MessageReaction.Reaction
            }
            
            public typealias Result = Int?
            
            fileprivate var peerId: EnginePeer.Id
            fileprivate var threadId: Int64?
            fileprivate var reaction: MessageReaction.Reaction
            public var mapKey: ItemKey {
                return ItemKey(peerId: self.peerId, threadId: self.threadId, reaction: self.reaction)
            }
            
            public init(peerId: EnginePeer.Id, threadId: Int64?, reaction: MessageReaction.Reaction) {
                self.peerId = peerId
                self.threadId = threadId
                self.reaction = reaction
            }

            var key: PostboxViewKey {
                return .historyTagSummaryView(tag: [], peerId: self.peerId, threadId: self.threadId, namespace: Namespaces.Message.Cloud, customTag: ReactionsMessageAttribute.messageTag(reaction: self.reaction))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessageHistoryTagSummaryView else {
                    preconditionFailure()
                }
                return view.count.flatMap(Int.init)
            }
        }
        
        public struct TopMessage: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = EngineMessage?
            
            fileprivate var id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }
            
            public init(id: EnginePeer.Id) {
                self.id = id
            }

            var key: PostboxViewKey {
                return .topChatMessage(peerIds: [self.id])
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? TopChatMessageView else {
                    preconditionFailure()
                }
                guard let message = view.messages[self.id] else {
                    return nil
                }
                return EngineMessage(message)
            }
        }
        
        public struct SavedMessageTagStats: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [MessageReaction.Reaction: Int]
            
            fileprivate var peerId: EnginePeer.Id
            fileprivate var threadId: Int64?
            
            public init(peerId: EnginePeer.Id, threadId: Int64?) {
                self.peerId = peerId
                self.threadId = threadId
            }

            var key: PostboxViewKey {
                return .historyCustomTagSummariesView(peerId: self.peerId, threadId: self.threadId, namespace: Namespaces.Message.Cloud)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessageHistoryCustomTagSummariesView else {
                    preconditionFailure()
                }
                var result: [MessageReaction.Reaction: Int] = [:]
                for (key, value) in view.tags {
                    if let reaction = ReactionsMessageAttribute.reactionFromMessageTag(tag: key) {
                        result[reaction] = value
                    }
                }
                return result
            }
        }
        
        public struct ThreadInfo: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = MessageHistoryThreadData?
            
            fileprivate var peerId: EnginePeer.Id
            fileprivate var threadId: Int64
            
            public init(peerId: EnginePeer.Id, threadId: Int64) {
                self.peerId = peerId
                self.threadId = threadId
            }

            var key: PostboxViewKey {
                return .messageHistoryThreadInfo(peerId: self.peerId, threadId: self.threadId)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? MessageHistoryThreadInfoView else {
                    preconditionFailure()
                }
                return view.info?.data.get(MessageHistoryThreadData.self)
            }
        }
    }
}
