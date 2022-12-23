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

struct PeerThreadCombinedState: Equatable, Codable {
    var validIndexBoundary: StoredPeerThreadCombinedState.Index?
    
    init(validIndexBoundary: StoredPeerThreadCombinedState.Index?) {
        self.validIndexBoundary = validIndexBoundary
    }
}

extension StoredPeerThreadCombinedState {
    init?(_ state: PeerThreadCombinedState) {
        guard let entry = CodableEntry(state) else {
            return nil
        }
        self.init(data: entry, validIndexBoundary: state.validIndexBoundary)
    }
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
                return account.postbox.transaction { transaction -> Void in
                    transaction.removeHole(peerId: peerId, threadId: topicId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                }
                |> castError(CreateForumChannelTopicError.self)
                |> mapToSignal { _ -> Signal<Int64, CreateForumChannelTopicError> in
                    return resolveForumThreads(postbox: account.postbox, network: account.network, ids: [MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: topicId))])
                    |> castError(CreateForumChannelTopicError.self)
                    |> map { _ -> Int64 in
                        return topicId
                    }
                }
            } else {
                return .fail(.generic)
            }
        }
    }
}

func _internal_fetchForumChannelTopic(account: Account, peerId: PeerId, threadId: Int64) -> Signal<EngineMessageHistoryThread.Info?, NoError> {
    return account.postbox.transaction { transaction -> (info: EngineMessageHistoryThread.Info?, inputChannel: Api.InputChannel?) in
        if let data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
            return (data.info, nil)
        } else {
            return (nil, transaction.getPeer(peerId).flatMap(apiInputChannel))
        }
    }
    |> mapToSignal { info, _ -> Signal<EngineMessageHistoryThread.Info?, NoError> in
        if let info = info {
            return .single(info)
        } else {
            return resolveForumThreads(postbox: account.postbox, network: account.network, ids: [MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))])
            |> mapToSignal { _ -> Signal<EngineMessageHistoryThread.Info?, NoError> in
                return account.postbox.transaction { transaction -> EngineMessageHistoryThread.Info?  in
                    if let data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                        return data.info
                    } else {
                        return nil
                    }
                }
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

func _internal_setForumChannelTopicClosed(account: Account, id: EnginePeer.Id, threadId: Int64, isClosed: Bool) -> Signal<Never, EditForumChannelTopicError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(id).flatMap(apiInputChannel)
    }
    |> castError(EditForumChannelTopicError.self)
    |> mapToSignal { inputChannel -> Signal<Never, EditForumChannelTopicError> in
        guard let inputChannel = inputChannel else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        flags |= (1 << 2)
        
        return account.network.request(Api.functions.channels.editForumTopic(
            flags: flags,
            channel: inputChannel,
            topicId: Int32(clamping: threadId),
            title: nil,
            iconEmojiId: nil,
            closed: isClosed ? .boolTrue : .boolFalse
        ))
        |> mapError { _ -> EditForumChannelTopicError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, EditForumChannelTopicError> in
            account.stateManager.addUpdates(result)
            
            return account.postbox.transaction { transaction -> Void in
                if let initialData = transaction.getMessageHistoryThreadInfo(peerId: id, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                    var data = initialData
                    
                    data.isClosed = isClosed
                    
                    if data != initialData {
                        if let entry = StoredMessageHistoryThreadInfo(data) {
                            transaction.setMessageHistoryThreadInfo(peerId: id, threadId: threadId, info: entry)
                        }
                    }
                }
            }
            |> castError(EditForumChannelTopicError.self)
            |> ignoreValues
        }
    }
}

public enum SetForumChannelTopicPinnedError {
    case generic
}

func _internal_setForumChannelTopicPinned(account: Account, id: EnginePeer.Id, threadId: Int64, isPinned: Bool) -> Signal<Never, SetForumChannelTopicPinnedError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        guard let inputChannel = transaction.getPeer(id).flatMap(apiInputChannel) else {
            return nil
        }
        
        if isPinned {
            transaction.setPeerPinnedThreads(peerId: id, threadIds: [threadId])
        } else {
            if transaction.getPeerPinnedThreads(peerId: id).contains(threadId) {
                transaction.setPeerPinnedThreads(peerId: id, threadIds: [])
            }
        }
        
        return inputChannel
    }
    |> castError(SetForumChannelTopicPinnedError.self)
    |> mapToSignal { inputChannel -> Signal<Never, SetForumChannelTopicPinnedError> in
        guard let inputChannel = inputChannel else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        flags |= (1 << 2)
        
        return account.network.request(Api.functions.channels.updatePinnedForumTopic(
            channel: inputChannel,
            topicId: Int32(clamping: threadId),
            pinned: isPinned ? .boolTrue : .boolFalse
        ))
        |> mapError { _ -> SetForumChannelTopicPinnedError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, SetForumChannelTopicPinnedError> in
            account.stateManager.addUpdates(result)
            
            return .complete()
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

struct LoadMessageHistoryThreadsResult {
    struct Item {
        var threadId: Int64
        var data: MessageHistoryThreadData
        var topMessage: Int32
        var unreadMentionsCount: Int32
        var unreadReactionsCount: Int32
        var index: StoredPeerThreadCombinedState.Index?
        
        init(
            threadId: Int64,
            data: MessageHistoryThreadData,
            topMessage: Int32,
            unreadMentionsCount: Int32,
            unreadReactionsCount: Int32,
            index: StoredPeerThreadCombinedState.Index
        ) {
            self.threadId = threadId
            self.data = data
            self.topMessage = topMessage
            self.unreadMentionsCount = unreadMentionsCount
            self.unreadReactionsCount = unreadReactionsCount
            self.index = index
        }
    }
    
    var peerId: PeerId
    var items: [Item]
    var pinnedThreadIds: [Int64]?
    var combinedState: PeerThreadCombinedState
    var messages: [StoreMessage]
    var users: [Api.User]
    var chats: [Api.Chat]
    
    init(
        peerId: PeerId,
        items: [Item],
        messages: [StoreMessage],
        pinnedThreadIds: [Int64]?,
        combinedState: PeerThreadCombinedState,
        users: [Api.User],
        chats: [Api.Chat]
    ) {
        self.peerId = peerId
        self.items = items
        self.messages = messages
        self.pinnedThreadIds = pinnedThreadIds
        self.combinedState = combinedState
        self.users = users
        self.chats = chats
    }
}

enum LoadMessageHistoryThreadsError {
    case generic
}

func _internal_requestMessageHistoryThreads(accountPeerId: PeerId, postbox: Postbox, network: Network, peerId: PeerId, offsetIndex: StoredPeerThreadCombinedState.Index?, limit: Int) -> Signal<LoadMessageHistoryThreadsResult, LoadMessageHistoryThreadsError> {
    let signal: Signal<LoadMessageHistoryThreadsResult, LoadMessageHistoryThreadsError> = postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> castError(LoadMessageHistoryThreadsError.self)
    |> mapToSignal { inputChannel -> Signal<LoadMessageHistoryThreadsResult, LoadMessageHistoryThreadsError> in
        guard let inputChannel = inputChannel else {
            return .fail(.generic)
        }
        let flags: Int32 = 0
        var offsetDate: Int32 = 0
        var offsetId: Int32 = 0
        var offsetTopic: Int32 = 0
        if let offsetIndex = offsetIndex {
            offsetDate = offsetIndex.timestamp
            offsetId = offsetIndex.messageId
            offsetTopic = Int32(clamping: offsetIndex.threadId)
        }
        let signal: Signal<LoadMessageHistoryThreadsResult, LoadMessageHistoryThreadsError> = network.request(Api.functions.channels.getForumTopics(
            flags: flags,
            channel: inputChannel,
            q: nil,
            offsetDate: offsetDate,
            offsetId: offsetId,
            offsetTopic: offsetTopic,
            limit: Int32(limit)
        ))
        |> mapError { _ -> LoadMessageHistoryThreadsError in
            return .generic
        }
        |> mapToSignal { result -> Signal<LoadMessageHistoryThreadsResult, LoadMessageHistoryThreadsError> in
            switch result {
            case let .forumTopics(_, _, topics, messages, chats, users, pts):
                var items: [LoadMessageHistoryThreadsResult.Item] = []
                var pinnedId: Int64?
                
                let addedMessages = messages.compactMap { message -> StoreMessage? in
                    return StoreMessage(apiMessage: message)
                }
                
                let _ = pts
                var minIndex: StoredPeerThreadCombinedState.Index?
                
                for topic in topics {
                    switch topic {
                    case let .forumTopic(flags, id, date, title, iconColor, iconEmojiId, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, fromId, notifySettings, draft):
                        let _ = draft
                        
                        if (flags & (1 << 3)) != 0 {
                            pinnedId = Int64(id)
                        }
                        
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
                        
                        var topTimestamp = date
                        for message in addedMessages {
                            if message.id.peerId == peerId && message.threadId == Int64(id) {
                                topTimestamp = max(topTimestamp, message.timestamp)
                            }
                        }
                        
                        let topicIndex = StoredPeerThreadCombinedState.Index(timestamp: topTimestamp, threadId: Int64(id), messageId: topMessage)
                        if let minIndexValue = minIndex {
                            if topicIndex < minIndexValue {
                                minIndex = topicIndex
                            }
                        } else {
                            minIndex = topicIndex
                        }
                        
                        items.append(LoadMessageHistoryThreadsResult.Item(
                            threadId: Int64(id),
                            data: data,
                            topMessage: topMessage,
                            unreadMentionsCount: unreadMentionsCount,
                            unreadReactionsCount: unreadReactionsCount,
                            index: topicIndex
                        ))
                    case .forumTopicDeleted:
                        break
                    }
                }
                
                var pinnedThreadIds: [Int64]?
                if offsetIndex == nil {
                    if let pinnedId = pinnedId {
                        pinnedThreadIds = [pinnedId]
                    } else {
                        pinnedThreadIds = []
                    }
                }
                
                var nextIndex: StoredPeerThreadCombinedState.Index
                if topics.count != 0 {
                    nextIndex = minIndex ?? StoredPeerThreadCombinedState.Index(timestamp: 0, threadId: 0, messageId: 1)
                } else {
                    nextIndex = StoredPeerThreadCombinedState.Index(timestamp: 0, threadId: 0, messageId: 1)
                }
                if let offsetIndex = offsetIndex, nextIndex == offsetIndex {
                    nextIndex = StoredPeerThreadCombinedState.Index(timestamp: 0, threadId: 0, messageId: 1)
                }
                
                let combinedState = PeerThreadCombinedState(validIndexBoundary: nextIndex)
                
                return .single(LoadMessageHistoryThreadsResult(
                    peerId: peerId,
                    items: items,
                    messages: addedMessages,
                    pinnedThreadIds: pinnedThreadIds,
                    combinedState: combinedState,
                    users: users,
                    chats: chats
                ))
            }
        }
        return signal
    }
    
    return signal
}

func applyLoadMessageHistoryThreadsResults(accountPeerId: PeerId, transaction: Transaction, results: [LoadMessageHistoryThreadsResult]) {
    for result in results {
        var peers: [Peer] = []
        var peerPresences: [PeerId: Api.User] = [:]
        for chat in result.chats {
            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                peers.append(groupOrChannel)
            }
        }
        for user in result.users {
            let telegramUser = TelegramUser(user: user)
            peers.append(telegramUser)
            peerPresences[telegramUser.id] = user
        }
        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
            return updated
        })
        
        updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
        
        let _ = InternalAccountState.addMessages(transaction: transaction, messages: result.messages, location: .Random)
        
        for item in result.items {
            guard let info = StoredMessageHistoryThreadInfo(item.data) else {
                continue
            }
            transaction.setMessageHistoryThreadInfo(peerId: result.peerId, threadId: item.threadId, info: info)
            
            transaction.replaceMessageTagSummary(peerId: result.peerId, threadId: item.threadId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: item.unreadMentionsCount, maxId: item.topMessage)
            transaction.replaceMessageTagSummary(peerId: result.peerId, threadId: item.threadId, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, count: item.unreadReactionsCount, maxId: item.topMessage)
            
            if item.topMessage != 0 {
                transaction.removeHole(peerId: result.peerId, threadId: item.threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: item.topMessage ... (Int32.max - 1))
            }
            
            for message in result.messages {
                if message.id.peerId == result.peerId && message.threadId == item.threadId {
                    if case let .Id(messageId) = message.id {
                        for media in message.media {
                            if let action = media as? TelegramMediaAction {
                                if case .topicCreated = action.action {
                                    transaction.removeHole(peerId: messageId.peerId, threadId: item.threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... messageId.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if let pinnedThreadIds = result.pinnedThreadIds {
            transaction.setPeerPinnedThreads(peerId: result.peerId, threadIds: pinnedThreadIds)
        }
        
        if let entry = StoredPeerThreadCombinedState(result.combinedState) {
            transaction.setPeerThreadCombinedState(peerId: result.peerId, state: entry)
        }
    }
}

public extension EngineMessageHistoryThread {
    struct NotificationException: Equatable {
        public var threadId: Int64
        public var info: EngineMessageHistoryThread.Info
        public var notificationSettings: EnginePeer.NotificationSettings
        
        public init(
            threadId: Int64,
            info: EngineMessageHistoryThread.Info,
            notificationSettings: EnginePeer.NotificationSettings
        ) {
            self.threadId = threadId
            self.info = info
            self.notificationSettings = notificationSettings
        }
    }
}

func _internal_forumChannelTopicNotificationExceptions(account: Account, id: EnginePeer.Id) -> Signal<[EngineMessageHistoryThread.NotificationException], NoError> {
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(id)
    }
    |> mapToSignal { peer -> Signal<[EngineMessageHistoryThread.NotificationException], NoError> in
        guard let inputPeer = peer.flatMap(apiInputPeer), let inputChannel = peer.flatMap(apiInputChannel) else {
            return .single([])
        }
        
        return account.network.request(Api.functions.account.getNotifyExceptions(flags: 1 << 0, peer: Api.InputNotifyPeer.inputNotifyPeer(peer: inputPeer)))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> map { result -> [(threadId: Int64, notificationSettings: EnginePeer.NotificationSettings)] in
            guard let result = result else {
                return []
            }
            
            var list: [(threadId: Int64, notificationSettings: EnginePeer.NotificationSettings)] = []
            for update in result.allUpdates {
                switch update {
                case let .updateNotifySettings(peer, notifySettings):
                    switch peer {
                    case let .notifyForumTopic(_, topMsgId):
                        list.append((Int64(topMsgId), EnginePeer.NotificationSettings(TelegramPeerNotificationSettings(apiSettings: notifySettings))))
                    default:
                        break
                    }
                default:
                    break
                }
            }
            return list
        }
        |> mapToSignal { list -> Signal<[EngineMessageHistoryThread.NotificationException], NoError> in
            return account.network.request(Api.functions.channels.getForumTopicsByID(channel: inputChannel, topics: list.map { Int32(clamping: $0.threadId) }))
            |> map { result -> [EngineMessageHistoryThread.NotificationException] in
                var infoMapping: [Int64: EngineMessageHistoryThread.Info] = [:]
                
                switch result {
                case let .forumTopics(_, _, topics, _, _, _, _):
                    for topic in topics {
                        switch topic {
                        case let .forumTopic(_, id, _, title, iconColor, iconEmojiId, _, _, _, _, _, _, _, _, _):
                            infoMapping[Int64(id)] = EngineMessageHistoryThread.Info(title: title, icon: iconEmojiId, iconColor: iconColor)
                        case .forumTopicDeleted:
                            break
                        }
                    }
                }
                
                return list.compactMap { item -> EngineMessageHistoryThread.NotificationException? in
                    if let info = infoMapping[item.threadId] {
                        return EngineMessageHistoryThread.NotificationException(threadId: item.threadId, info: info, notificationSettings: item.notificationSettings)
                    } else {
                        return nil
                    }
                }
            }
            |> `catch` { _ -> Signal<[EngineMessageHistoryThread.NotificationException], NoError> in
                return .single([])
            }
        }
    }
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
            
            //let _ = _internal_loadMessageHistoryThreads(account: self.account, peerId: peerId, offsetIndex: nil, limit: 100).start()
            
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
