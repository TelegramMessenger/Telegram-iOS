import SwiftSignalKit
import Postbox

public final class EngineTotalReadCounters {
    private let state: ChatListTotalUnreadState

    public init(state: ChatListTotalUnreadState) {
        self.state = state
    }

    public func count(for category: ChatListTotalUnreadStateCategory, in statsType: ChatListTotalUnreadStateStats, with tags: PeerSummaryCounterTags) -> Int32 {
        return self.state.count(for: category, in: statsType, with: tags)
    }
}

public struct EnginePeerReadCounters: Equatable {
    private let state: CombinedPeerReadState

    public init(state: CombinedPeerReadState) {
        self.state = state
    }

    public init() {
        self.state = CombinedPeerReadState(states: [])
    }

    public var count: Int32 {
        return self.state.count
    }

    public var markedUnread: Bool {
        return self.state.markedUnread
    }


    public var isUnread: Bool {
        return self.state.isUnread
    }

    public func isOutgoingMessageIndexRead(_ index: EngineMessage.Index) -> Bool {
        return self.state.isOutgoingMessageIndexRead(index)
    }

    public func isIncomingMessageIndexRead(_ index: EngineMessage.Index) -> Bool {
        return self.state.isIncomingMessageIndexRead(index)
    }
}

public extension EnginePeerReadCounters {
    init(incomingReadId: EngineMessage.Id.Id, outgoingReadId: EngineMessage.Id.Id, count: Int32, markedUnread: Bool) {
        self.init(state: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, .idBased(maxIncomingReadId: incomingReadId, maxOutgoingReadId: outgoingReadId, maxKnownId: max(incomingReadId, outgoingReadId), count: count, markedUnread: markedUnread))]))
    }
}

public extension TelegramEngine.EngineData.Item {
    enum Messages {
        public struct Message: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = Optional<EngineMessage>

            fileprivate var id: EngineMessage.Id

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

        public struct PeerUnreadCount: TelegramEngineDataItem, TelegramEngineMapKeyDataItem, PostboxViewDataItem {
            public typealias Result = Int

            fileprivate let id: EnginePeer.Id
            public var mapKey: EnginePeer.Id {
                return self.id
            }

            var key: PostboxViewKey {
                return .unreadCounts(items: [.peer(self.id)])
            }

            public init(id: EnginePeer.Id) {
                self.id = id
            }

            func extract(view: PostboxView) -> Int {
                guard let view = view as? UnreadMessageCountsView else {
                    preconditionFailure()
                }

                return Int(view.count(for: .peer(self.id)) ?? 0)
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
    }
}
