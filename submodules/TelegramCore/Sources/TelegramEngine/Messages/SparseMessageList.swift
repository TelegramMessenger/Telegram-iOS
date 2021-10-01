import SwiftSignalKit
import Postbox
import TelegramApi

public final class SparseMessageList {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let peerId: PeerId
        private let messageTag: MessageTags

        private struct TopSection: Equatable {
            var messages: [Message]

            static func ==(lhs: TopSection, rhs: TopSection) -> Bool {
                if lhs.messages.count != rhs.messages.count {
                    return false
                }
                for i in 0 ..< lhs.messages.count {
                    if lhs.messages[i].id != rhs.messages[i].id {
                        return false
                    }
                    if lhs.messages[i].stableVersion != rhs.messages[i].stableVersion {
                        return false
                    }
                }
                return true
            }
        }

        private struct ItemIndices: Equatable {
            var ids: [MessageId]
            var timestamps: [Int32]
        }

        private var topSectionItemRequestCount: Int = 100
        private var topSection: TopSection?
        private var topItemsDisposable: Disposable?

        private var messageIndices: ItemIndices?
        private var messageIndicesDisposable: Disposable?

        private var loadingPlaceholders: [MessageId: Disposable] = [:]
        private var loadedPlaceholders: [MessageId: Message] = [:]

        let statePromise = Promise<SparseMessageList.State>()

        init(queue: Queue, account: Account, peerId: PeerId, messageTag: MessageTags) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.messageTag = messageTag

            self.resetTopSection()
            self.messageIndicesDisposable = (self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<ItemIndices, NoError> in
                guard let inputPeer = inputPeer else {
                    return .single(ItemIndices(ids: [], timestamps: []))
                }
                return self.account.network.request(Api.functions.messages.getSearchResultsRawMessages(peer: inputPeer, filter: .inputMessagesFilterPhotoVideo, offsetId: 0, offsetDate: 0))
                |> map { result -> ItemIndices in
                    switch result {
                    case let .searchResultsRawMessages(msgIds, msgDates):
                        return ItemIndices(ids: msgIds.map { id in
                            return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)
                        }, timestamps: msgDates)
                    }
                }
                |> `catch` { _ -> Signal<ItemIndices, NoError> in
                    return .single(ItemIndices(ids: [], timestamps: []))
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] indices in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.messageIndices = indices
                if strongSelf.topSection != nil {
                    strongSelf.updateState()
                }
            })
        }

        deinit {
            self.topItemsDisposable?.dispose()
            self.messageIndicesDisposable?.dispose()
        }

        private func resetTopSection() {
            self.topItemsDisposable = (self.account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId), anchor: .upperBound, count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tagMask: self.messageTag, appendMessagesFromTheSameGroup: false, namespaces: .not(Set(Namespaces.Message.allScheduled)), orderStatistics: [])
            |> deliverOn(self.queue)).start(next: { [weak self] view, updateType, _ in
                guard let strongSelf = self else {
                    return
                }
                switch updateType {
                case .FillHole:
                    strongSelf.resetTopSection()
                default:
                    strongSelf.updateTopSection(view: view)
                }
            })
        }

        func loadMoreFromTopSection() {
            self.topSectionItemRequestCount += 100
            self.resetTopSection()
        }

        func loadPlaceholders(ids: [MessageId]) {
            var loadGlobalIds: [MessageId] = []
            var loadChannelIds: [PeerId: [MessageId]] = [:]
            for id in ids {
                if self.loadingPlaceholders[id] != nil {
                    continue
                }
                self.loadingPlaceholders[id] = MetaDisposable()
                if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
                    loadGlobalIds.append(id)
                } else if id.peerId.namespace == Namespaces.Peer.CloudChannel {
                    if loadChannelIds[id.peerId] == nil {
                        loadChannelIds[id.peerId] = []
                    }
                    loadChannelIds[id.peerId]!.append(id)
                }
            }

            var loadSignals: [Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError>] = []
            let account = self.account

            if !loadGlobalIds.isEmpty {
                loadSignals.append(self.account.postbox.transaction { transaction -> [Api.InputMessage] in
                    var result: [Api.InputMessage] = []
                    for id in loadGlobalIds {
                        let inputMessage: Api.InputMessage = .inputMessageID(id: id.id)
                        result.append(inputMessage)
                    }
                    return result
                }
                |> mapToSignal { inputMessages -> Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError> in
                    return account.network.request(Api.functions.messages.getMessages(id: inputMessages))
                    |> map { result -> (messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) in
                        switch result {
                        case let .messages(messages, chats, users):
                            return (messages, chats, users)
                        case let .messagesSlice(_, _, _, _, messages, chats, users):
                            return (messages, chats, users)
                        case let .channelMessages(_, _, _, _, messages, chats, users):
                            return (messages, chats, users)
                        case .messagesNotModified:
                            return ([], [], [])
                        }
                    }
                    |> `catch` { _ -> Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError> in
                        return .single(([], [], []))
                    }
                })
            }

            if !loadChannelIds.isEmpty {
                for (channelId, ids) in loadChannelIds {
                    loadSignals.append(self.account.postbox.transaction { transaction -> Api.InputChannel? in
                        return transaction.getPeer(channelId).flatMap(apiInputChannel)
                    }
                    |> mapToSignal { inputChannel -> Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError> in
                        guard let inputChannel = inputChannel else {
                            return .single(([], [], []))
                        }

                        return account.network.request(Api.functions.channels.getMessages(channel: inputChannel, id: ids.map { Api.InputMessage.inputMessageID(id: $0.id) }))
                        |> map { result -> (messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) in
                            switch result {
                            case let .messages(messages, chats, users):
                                return (messages, chats, users)
                            case let .messagesSlice(_, _, _, _, messages, chats, users):
                                return (messages, chats, users)
                            case let .channelMessages(_, _, _, _, messages, chats, users):
                                return (messages, chats, users)
                            case .messagesNotModified:
                                return ([], [], [])
                            }
                        }
                        |> `catch` { _ -> Signal<(messages: [Api.Message], chats: [Api.Chat], users: [Api.User]), NoError> in
                            return .single(([], [], []))
                        }
                    })
                }
            }

            let _ = (combineLatest(queue: self.queue, loadSignals)
            |> mapToSignal { messageLists -> Signal<[Message], NoError> in
                return account.postbox.transaction { transaction -> [Message] in
                    var parsedMessages: [StoreMessage] = []
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: PeerPresence] = [:]

                    for (messages, chats, users) in messageLists {
                        for chat in chats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(groupOrChannel)
                            }
                        }
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            if let presence = TelegramUserPresence(apiUser: user) {
                                peerPresences[telegramUser.id] = presence
                            }
                        }

                        for message in messages {
                            if let parsedMessage = StoreMessage(apiMessage: message) {
                                parsedMessages.append(parsedMessage)
                            }
                        }
                    }

                    let _ = transaction.addMessages(parsedMessages, location: .Random)

                    var result: [Message] = []
                    for parsedMessage in parsedMessages {
                        switch parsedMessage.id {
                        case let .Id(id):
                            if let message = transaction.getMessage(id) {
                                result.append(message)
                            }
                        case .Partial:
                            break
                        }
                    }

                    return result
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] messages in
                guard let strongSelf = self else {
                    return
                }
                for message in messages {
                    strongSelf.loadedPlaceholders[message.id] = message
                }

                strongSelf.updateState()
            })
        }

        private func updateTopSection(view: MessageHistoryView) {
            var topSection: TopSection?

            if view.isLoading {
                topSection = nil
            } else {
                topSection = TopSection(messages: view.entries.map { entry in
                    return entry.message
                })
            }

            if self.topSection != topSection {
                self.topSection = topSection
            }
            self.updateState()
        }

        private func updateState() {
            var items: [SparseMessageList.State.Item] = []
            var minMessageId: MessageId?
            if let topSection = self.topSection {
                for i in 0 ..< topSection.messages.count {
                    let message = topSection.messages[i]
                    items.append(SparseMessageList.State.Item(index: items.count, content: .message(message)))
                    if let minMessageIdValue = minMessageId {
                        if message.id < minMessageIdValue {
                            minMessageId = message.id
                        }
                    } else {
                        minMessageId = message.id
                    }
                }
            }

            var totalCount = items.count
            if let minMessageId = minMessageId, let messageIndices = self.messageIndices {
                for i in 0 ..< messageIndices.ids.count {
                    if messageIndices.ids[i] < minMessageId {
                        if let message = self.loadedPlaceholders[messageIndices.ids[i]] {
                            items.append(SparseMessageList.State.Item(index: items.count, content: .message(message)))
                        } else {
                            items.append(SparseMessageList.State.Item(index: items.count, content: .placeholder(id: messageIndices.ids[i], timestamp: messageIndices.timestamps[i])))
                        }
                        totalCount += 1
                    }
                }
            }

            self.statePromise.set(.single(SparseMessageList.State(
                items: items,
                totalCount: items.count,
                isLoading: self.topSection == nil
            )))
        }
    }

    private let queue: Queue
    private let impl: QueueLocalObject<Impl>

    public struct State {
        public final class Item {
            public enum Content {
                case message(Message)
                case placeholder(id: MessageId, timestamp: Int32)
            }

            public let index: Int
            public let content: Content

            init(index: Int, content: Content) {
                self.index = index
                self.content = content
            }
        }

        public var items: [Item]
        public var totalCount: Int
        public var isLoading: Bool
    }

    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()

            self.impl.with { impl in
                disposable.set(impl.statePromise.get().start(next: subscriber.putNext))
            }

            return disposable
        }
    }

    init(account: Account, peerId: PeerId, messageTag: MessageTags) {
        self.queue = .mainQueue()
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, messageTag: messageTag)
        })
    }

    public func loadMoreFromTopSection() {
        self.impl.with { impl in
            impl.loadMoreFromTopSection()
        }
    }

    public func loadPlaceholders(ids: [MessageId]) {
        self.impl.with { impl in
            impl.loadPlaceholders(ids: ids)
        }
    }
}
