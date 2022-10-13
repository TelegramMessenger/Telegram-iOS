import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public extension EngineMessageHistoryThread {
    final class Info: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case title
            case icon
            case iconColor
        }
        
        public let title: String
        public let icon: Int64?
        public let iconColor: Int32
        
        public init(
            title: String,
            icon: Int64?,
            iconColor: Int32
        ) {
            self.title = title
            self.icon = icon
            self.iconColor = iconColor
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.title = try container.decode(String.self, forKey: .title)
            self.icon = try container.decodeIfPresent(Int64.self, forKey: .icon)
            self.iconColor = try container.decodeIfPresent(Int32.self, forKey: .iconColor) ?? 0
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.title, forKey: .title)
            try container.encodeIfPresent(self.icon, forKey: .icon)
            try container.encode(self.iconColor, forKey: .iconColor)
        }
        
        public static func ==(lhs: Info, rhs: Info) -> Bool {
            if lhs.title != rhs.title {
                return false
            }
            if lhs.icon != rhs.icon {
                return false
            }
            if lhs.iconColor != rhs.iconColor {
                return false
            }
            return true
        }
    }
}

public struct MessageHistoryThreadData: Codable, Equatable {
    private enum CodingKeys: CodingKey {
        case creationDate
        case isOwnedByMe
        case author
        case info
        case incomingUnreadCount
        case maxIncomingReadId
        case maxKnownMessageId
        case maxOutgoingReadId
        case isClosed
        case notificationSettings
    }
    
    public var creationDate: Int32
    public var isOwnedByMe: Bool
    public var author: PeerId
    public var info: EngineMessageHistoryThread.Info
    public var incomingUnreadCount: Int32
    public var maxIncomingReadId: Int32
    public var maxKnownMessageId: Int32
    public var maxOutgoingReadId: Int32
    public var isClosed: Bool
    public var notificationSettings: TelegramPeerNotificationSettings
    
    public init(
        creationDate: Int32,
        isOwnedByMe: Bool,
        author: PeerId,
        info: EngineMessageHistoryThread.Info,
        incomingUnreadCount: Int32,
        maxIncomingReadId: Int32,
        maxKnownMessageId: Int32,
        maxOutgoingReadId: Int32,
        isClosed: Bool,
        notificationSettings: TelegramPeerNotificationSettings
    ) {
        self.creationDate = creationDate
        self.isOwnedByMe = isOwnedByMe
        self.author = author
        self.info = info
        self.incomingUnreadCount = incomingUnreadCount
        self.maxIncomingReadId = maxIncomingReadId
        self.maxKnownMessageId = maxKnownMessageId
        self.maxOutgoingReadId = maxOutgoingReadId
        self.isClosed = isClosed
        self.notificationSettings = notificationSettings
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.creationDate = try container.decode(Int32.self, forKey: .creationDate)
        self.isOwnedByMe = try container.decodeIfPresent(Bool.self, forKey: .isOwnedByMe) ?? false
        self.author = try container.decode(PeerId.self, forKey: .author)
        self.info = try container.decode(EngineMessageHistoryThread.Info.self, forKey: .info)
        self.incomingUnreadCount = try container.decode(Int32.self, forKey: .incomingUnreadCount)
        self.maxIncomingReadId = try container.decode(Int32.self, forKey: .maxIncomingReadId)
        self.maxKnownMessageId = try container.decode(Int32.self, forKey: .maxKnownMessageId)
        self.maxOutgoingReadId = try container.decode(Int32.self, forKey: .maxOutgoingReadId)
        self.isClosed = try container.decodeIfPresent(Bool.self, forKey: .isClosed) ?? false
        self.notificationSettings = try container.decode(TelegramPeerNotificationSettings.self, forKey: .notificationSettings)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.creationDate, forKey: .creationDate)
        try container.encode(self.isOwnedByMe, forKey: .isOwnedByMe)
        try container.encode(self.author, forKey: .author)
        try container.encode(self.info, forKey: .info)
        try container.encode(self.incomingUnreadCount, forKey: .incomingUnreadCount)
        try container.encode(self.maxIncomingReadId, forKey: .maxIncomingReadId)
        try container.encode(self.maxKnownMessageId, forKey: .maxKnownMessageId)
        try container.encode(self.maxOutgoingReadId, forKey: .maxOutgoingReadId)
        try container.encode(self.isClosed, forKey: .isClosed)
        try container.encode(self.notificationSettings, forKey: .notificationSettings)
    }
}

extension StoredMessageHistoryThreadInfo {
    init?(_ data: MessageHistoryThreadData) {
        guard let entry = CodableEntry(data) else {
            return nil
        }
        var mutedUntil: Int32?
        switch data.notificationSettings.muteState {
        case let .muted(until):
            mutedUntil = until
        case .unmuted, .default:
            break
        }
        self.init(data: entry, summary: Summary(
            totalUnreadCount: data.incomingUnreadCount,
            mutedUntil: mutedUntil
        ))
    }
}

struct StoreMessageHistoryThreadData {
    var data: MessageHistoryThreadData
    var topMessageId: Int32
    var unreadMentionCount: Int32
    var unreadReactionCount: Int32
}

public enum CreateForumChannelTopicError {
    case generic
}

func _internal_createForumChannelTopic(account: Account, peerId: PeerId, title: String, iconColor: Int32, iconFileId: Int64?) -> Signal<Int64, CreateForumChannelTopicError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> castError(CreateForumChannelTopicError.self)
    |> mapToSignal { inputChannel -> Signal<Int64, CreateForumChannelTopicError> in
        guard let inputChannel = inputChannel else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        if iconFileId != nil {
            flags |= (1 << 3)
        }
        flags |= (1 << 0)
        return account.network.request(Api.functions.channels.createForumTopic(
            flags: flags,
            channel: inputChannel,
            title: title,
            iconColor: iconColor,
            iconEmojiId: iconFileId,
            randomId: Int64.random(in: Int64.min ..< Int64.max),
            sendAs: nil
        ))
        |> mapError { _ -> CreateForumChannelTopicError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Int64, CreateForumChannelTopicError> in
            account.stateManager.addUpdates(result)
            
            var topicId: Int64?
            topicId = nil
            for update in result.allUpdates {
                switch update {
                case let .updateNewChannelMessage(message, _, _):
                    if let message = StoreMessage(apiMessage: message) {
                        if case let .Id(id) = message.id {
                            topicId = Int64(id.id)
                        }
                    }
                default:
                    break
                }
            }
            
            if let topicId = topicId {
                return resolveForumThreads(postbox: account.postbox, network: account.network, ids: [])
                |> castError(CreateForumChannelTopicError.self)
                |> map { _ -> Int64 in
                    return topicId
                }
            } else {
                return .fail(.generic)
            }
        }
    }
}

public enum EditForumChannelTopicError {
    case generic
}

func _internal_editForumChannelTopic(account: Account, peerId: PeerId, threadId: Int64, title: String, iconFileId: Int64?) -> Signal<Never, EditForumChannelTopicError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> castError(EditForumChannelTopicError.self)
    |> mapToSignal { inputChannel -> Signal<Never, EditForumChannelTopicError> in
        guard let inputChannel = inputChannel else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        flags |= (1 << 0)
        flags |= (1 << 1)
        
        return account.network.request(Api.functions.channels.editForumTopic(
            flags: flags,
            channel: inputChannel,
            topicId: Int32(clamping: threadId),
            title: title,
            iconEmojiId: iconFileId ?? 0,
            closed: nil
        ))
        |> mapError { _ -> EditForumChannelTopicError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, EditForumChannelTopicError> in
            account.stateManager.addUpdates(result)
            
            return account.postbox.transaction { transaction -> Void in
                if let initialData = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                    var data = initialData
                    
                    data.info = EngineMessageHistoryThread.Info(title: title, icon: iconFileId, iconColor: data.info.iconColor)
                    
                    if data != initialData {
                        if let entry = StoredMessageHistoryThreadInfo(data) {
                            transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: entry)
                        }
                    }
                }
            }
            |> castError(EditForumChannelTopicError.self)
            |> ignoreValues
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
                    
                    let _ = InternalAccountState.addMessages(transaction: transaction, messages: messages.compactMap { message -> StoreMessage? in
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
                        case let .forumTopic(flags, id, date, title, iconColor, iconEmojiId, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, fromId, notifySettings):
                            let data = MessageHistoryThreadData(
                                creationDate: date,
                                isOwnedByMe: (flags & (1 << 1)) != 0,
                                author: fromId.peerId,
                                info: EngineMessageHistoryThread.Info(
                                    title: title,
                                    icon: iconEmojiId == 0 ? nil : iconEmojiId,
                                    iconColor: iconColor
                                ),
                                incomingUnreadCount: unreadCount,
                                maxIncomingReadId: readInboxMaxId,
                                maxKnownMessageId: topMessage,
                                maxOutgoingReadId: readOutboxMaxId,
                                isClosed: (flags & (1 << 2)) != 0,
                                notificationSettings: TelegramPeerNotificationSettings(apiSettings: notifySettings)
                            )
                            guard let info = StoredMessageHistoryThreadInfo(data) else {
                                continue
                            }
                            transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: Int64(id), info: info)
                            
                            transaction.replaceMessageTagSummary(peerId: peerId, threadId: Int64(id), tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, maxId: topMessage)
                            transaction.replaceMessageTagSummary(peerId: peerId, threadId: Int64(id), tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, count: unreadReactionsCount, maxId: topMessage)
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
        private let updateDisposable = MetaDisposable()
        
        init(queue: Queue, account: Account, peerId: PeerId) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            
            let _ = _internal_loadMessageHistoryThreads(account: self.account, peerId: peerId).start()
            
            self.updateDisposable.set(account.viewTracker.polledChannel(peerId: peerId).start())
        }
        
        deinit {
            assert(self.queue.isCurrent())
            
            self.loadMoreDisposable.dispose()
            self.updateDisposable.dispose()
        }
    }
    
    public struct Item: Equatable {
        public var id: Int64
        public var info: EngineMessageHistoryThread.Info
        public var index: MessageIndex
        public var topMessage: EngineMessage?
        
        init(
            id: Int64,
            info: EngineMessageHistoryThread.Info,
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
}
