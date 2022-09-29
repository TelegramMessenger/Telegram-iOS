import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public final class EngineMessageHistoryThreads {
    public final class Info: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case title
            case icon
        }
        
        public let title: String
        public let icon: Int64?
        
        public init(
            title: String,
            icon: Int64?
        ) {
            self.title = title
            self.icon = icon
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.title = try container.decode(String.self, forKey: .title)
            self.icon = try container.decodeIfPresent(Int64.self, forKey: .icon)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.title, forKey: .title)
            try container.encodeIfPresent(self.icon, forKey: .icon)
        }
        
        public static func ==(lhs: Info, rhs: Info) -> Bool {
            if lhs.title != rhs.title {
                return false
            }
            if lhs.icon != rhs.icon {
                return false
            }
            return true
        }
    }
}

func _internal_setChannelForumMode(account: Account, peerId: PeerId, isForum: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> mapToSignal { inputChannel -> Signal<Never, NoError> in
        guard let inputChannel = inputChannel else {
            return .complete()
        }
        return account.network.request(Api.functions.channels.toggleForum(channel: inputChannel, enabled: isForum ? .boolTrue : .boolFalse))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result = result else {
                return .complete()
            }
            account.stateManager.addUpdates(result)
            
            return .complete()
        }
    }
}

enum LoadMessageHistoryThreadsError {
    case generic
}

func _internal_loadMessageHistoryThreads(account: Account, peerId: PeerId) -> Signal<Never, LoadMessageHistoryThreadsError> {
    let signal: Signal<Never, LoadMessageHistoryThreadsError> = account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> castError(LoadMessageHistoryThreadsError.self)
    |> mapToSignal { inputChannel -> Signal<Never, LoadMessageHistoryThreadsError> in
        guard let inputChannel = inputChannel else {
            return .fail(.generic)
        }
        let signal: Signal<Never, LoadMessageHistoryThreadsError> = account.network.request(Api.functions.channels.getForumTopics(
            flags: 0,
            channel: inputChannel,
            q: nil,
            offsetDate: 0,
            offsetId: 0,
            offsetTopic: 0,
            limit: 100
        ))
        |> mapError { _ -> LoadMessageHistoryThreadsError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, LoadMessageHistoryThreadsError> in
            return account.postbox.transaction { transaction -> Void in
                switch result {
                case let .forumTopics(flags, count, topics, messages, chats, users, pts):
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: Api.User] = [:]
                    for chat in chats {
                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                            peers.append(groupOrChannel)
                        }
                    }
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        peerPresences[telegramUser.id] = user
                    }
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                        return updated
                    })
                    
                    updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                    
                    let _ = transaction.addMessages(messages.compactMap { message -> StoreMessage? in
                        return StoreMessage(apiMessage: message)
                    }, location: .Random)
                    
                    let _ = flags
                    let _ = count
                    let _ = topics
                    let _ = messages
                    let _ = chats
                    let _ = users
                    let _ = pts
                    
                    for topic in topics {
                        switch topic {
                        case let .forumTopic(_, id, _, title, iconEmojiId, _, _, _, _):
                            guard let info = CodableEntry(EngineMessageHistoryThreads.Info(title: title, icon: iconEmojiId)) else {
                                continue
                            }
                            transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: Int64(id), info: info)
                        }
                    }
                }
            }
            |> castError(LoadMessageHistoryThreadsError.self)
            |> ignoreValues
        }
        return signal
    }
    
    return signal
}

public final class ForumChannelTopics {
    private final class Impl {
        private let queue: Queue
        
        private let account: Account
        private let peerId: PeerId
        
        private let statePromise = Promise<State>()
        var state: Signal<State, NoError> {
            return self.statePromise.get()
        }
        
        private let loadMoreDisposable = MetaDisposable()
        private let createTopicDisposable = MetaDisposable()
        
        init(queue: Queue, account: Account, peerId: PeerId) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            
            let _ = _internal_loadMessageHistoryThreads(account: self.account, peerId: peerId).start()
            
            let viewKey: PostboxViewKey = .messageHistoryThreadIndex(id: self.peerId)
            self.statePromise.set(self.account.postbox.combinedView(keys: [viewKey])
            |> map { views -> State in
                guard let view = views.views[viewKey] as? MessageHistoryThreadIndexView else {
                    preconditionFailure()
                }
                return State(items: view.items.compactMap { item -> ForumChannelTopics.Item? in
                    guard let info = item.info.get(EngineMessageHistoryThreads.Info.self) else {
                        return nil
                    }
                    return ForumChannelTopics.Item(
                        id: item.id,
                        info: info,
                        index: item.index,
                        topMessage: item.topMessage.flatMap(EngineMessage.init)
                    )
                })
            })
        }
        
        deinit {
            assert(self.queue.isCurrent())
            
            self.loadMoreDisposable.dispose()
            self.createTopicDisposable.dispose()
        }
        
        func createTopic(title: String) {
            let peerId = self.peerId
            let account = self.account
            let signal: Signal<Int32?, NoError> = self.account.postbox.transaction { transaction -> (Api.InputChannel?, Int64?) in
                var fileId: Int64? = nil
                
                var filteredFiles: [TelegramMediaFile] = []
                for featuredEmojiPack in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks) {
                    guard let featuredEmojiPack = featuredEmojiPack.contents.get(FeaturedStickerPackItem.self) else {
                        continue
                    }
                    for item in featuredEmojiPack.topItems {
                        for attribute in item.file.attributes {
                            switch attribute {
                            case .CustomEmoji:
                                filteredFiles.append(item.file)
                            default:
                                break
                            }
                        }
                    }
                }
                fileId = filteredFiles.randomElement()?.fileId.id
                
                return (transaction.getPeer(peerId).flatMap(apiInputChannel), fileId)
            }
            |> mapToSignal { inputChannel, fileId -> Signal<Int32?, NoError> in
                guard let inputChannel = inputChannel else {
                    return .single(nil)
                }
                var flags: Int32 = 0
                if fileId != nil {
                    flags |= (1 << 3)
                }
                return account.network.request(Api.functions.channels.createForumTopic(
                    flags: flags,
                    channel: inputChannel,
                    title: title,
                    iconEmojiId: fileId,
                    randomId: Int64.random(in: Int64.min ..< Int64.max),
                    sendAs: nil
                ))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Int32?, NoError> in
                    guard let result = result else {
                        return .single(nil)
                    }
                    account.stateManager.addUpdates(result)
                    return .single(nil)
                }
            }
            
            self.createTopicDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                let _ = _internal_loadMessageHistoryThreads(account: strongSelf.account, peerId: strongSelf.peerId).start()
            }))
        }
    }
    
    public struct Item: Equatable {
        public var id: Int64
        public var info: EngineMessageHistoryThreads.Info
        public var index: MessageIndex
        public var topMessage: EngineMessage?
        
        init(
            id: Int64,
            info: EngineMessageHistoryThreads.Info,
            index: MessageIndex,
            topMessage: EngineMessage?
        ) {
            self.id = id
            self.info = info
            self.index = index
            self.topMessage = topMessage
        }
    }
    
    public struct State: Equatable {
        public var items: [Item]
        
        init(items: [Item]) {
            self.items = items
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public init(account: Account, peerId: PeerId) {
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId)
        })
    }
    
    public func createTopic(title: String) {
        self.impl.with { impl in
            impl.createTopic(title: title)
        }
    }
}
