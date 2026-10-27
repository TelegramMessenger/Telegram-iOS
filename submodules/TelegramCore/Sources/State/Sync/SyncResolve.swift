import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

final class FetchedForumThreads {
    enum Item {
        case savedDialog(Api.SavedDialog)
        case forum(Api.ForumTopic)
    }
    
    let items: [Item]
    let totalCount: Int
    let orderByDate: Bool
    let pts: Int32?
    let messages: [Api.Message]
    let users: [Api.User]
    let chats: [Api.Chat]
    
    init(items: [Item], totalCount: Int, orderByDate: Bool, pts: Int32?, messages: [Api.Message], users: [Api.User], chats: [Api.Chat]) {
        self.items = items
        self.totalCount = totalCount
        self.orderByDate = orderByDate
        self.pts = pts
        self.messages = messages
        self.users = users
        self.chats = chats
    }
    
    convenience init(forumTopics: Api.messages.ForumTopics) {
        switch forumTopics {
        case let .forumTopics(forumTopicsData):
            let (flags, count, topics, messages, chats, users, pts) = (forumTopicsData.flags, forumTopicsData.count, forumTopicsData.topics, forumTopicsData.messages, forumTopicsData.chats, forumTopicsData.users, forumTopicsData.pts)
            let orderByDate = (flags & (1 << 0)) != 0
            self.init(items: topics.map(Item.forum), totalCount: Int(count), orderByDate: orderByDate, pts: pts, messages: messages, users: users, chats: chats)
        }
    }
    
    convenience init(savedDialogs: Api.messages.SavedDialogs) {
        switch savedDialogs {
        case let .savedDialogs(savedDialogsData):
            let (dialogs, messages, chats, users) = (savedDialogsData.dialogs, savedDialogsData.messages, savedDialogsData.chats, savedDialogsData.users)
            self.init(items: dialogs.map(Item.savedDialog), totalCount: Int(dialogs.count), orderByDate: false, pts: nil, messages: messages, users: users, chats: chats)
        case let .savedDialogsSlice(savedDialogsSliceData):
            let (count, dialogs, messages, chats, users) = (savedDialogsSliceData.count, savedDialogsSliceData.dialogs, savedDialogsSliceData.messages, savedDialogsSliceData.chats, savedDialogsSliceData.users)
            self.init(items: dialogs.map(Item.savedDialog), totalCount: Int(count), orderByDate: false, pts: nil, messages: messages, users: users, chats: chats)
        case .savedDialogsNotModified:
            self.init(items: [], totalCount: 0, orderByDate: false, pts: 0, messages: [], users: [], chats: [])
        }
    }
}

func resolveForumThreads(accountPeerId: PeerId, postbox: Postbox, source: FetchMessageHistoryHoleSource, state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    var forumThreadIds = Set<PeerAndBoundThreadId>()
    
    for operation in state.operations {
        switch operation {
        case let .AddMessages(messages, _):
            for message in messages {
                if let threadId = message.threadId {
                    if let channel = state.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info {
                        if channel.flags.contains(.isForum) || channel.flags.contains(.isMonoforum) {
                            forumThreadIds.insert(PeerAndBoundThreadId(peerId: message.id.peerId, threadId: threadId))
                        }
                    } else if let user = state.peers[message.id.peerId] as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasForum) {
                        forumThreadIds.insert(PeerAndBoundThreadId(peerId: message.id.peerId, threadId: threadId))
                    }
                }
            }
        default:
            break
        }
    }
    
    if forumThreadIds.isEmpty {
        return .single(state)
    } else {
        return postbox.transaction { transaction -> Signal<AccountMutableState, NoError> in
            var missingForumThreadIds: [PeerId: [Int64]] = [:]
            for threadId in forumThreadIds {
                if let _ = transaction.getMessageHistoryThreadInfo(peerId: threadId.peerId, threadId: threadId.threadId) {
                } else {
                    missingForumThreadIds[threadId.peerId, default: []].append(threadId.threadId)
                }
            }
            
            if missingForumThreadIds.isEmpty {
                return .single(state)
            } else {
                var signals: [Signal<(Peer, FetchedForumThreads)?, NoError>] = []
                for (peerId, threadIds) in missingForumThreadIds {
                    guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                        Logger.shared.log("State", "can't fetch thread infos \(threadIds) for peer \(peerId): can't create inputPeer")
                        continue
                    }
                    
                    if let peer = peer as? TelegramChannel, peer.flags.contains(.isMonoforum) {
                        let signal = source.request(Api.functions.messages.getSavedDialogsByID(flags: 1 << 1, parentPeer: inputPeer, ids: threadIds.compactMap { threadId in
                            let threadPeerId = PeerId(threadId)
                            if let threadPeer = state.peers[threadPeerId] {
                                return apiInputPeer(threadPeer)
                            } else if let threadPeer = transaction.getPeer(threadPeerId) {
                                return apiInputPeer(threadPeer)
                            } else {
                                return nil
                            }
                        }))
                        |> map { result -> (Peer, FetchedForumThreads)? in
                            let result = FetchedForumThreads(savedDialogs: result)
                            return (peer, result)
                        }
                        |> `catch` { _ -> Signal<(Peer, FetchedForumThreads)?, NoError> in
                            return .single(nil)
                        }
                        signals.append(signal)
                    } else {
                        let signal = source.request(Api.functions.messages.getForumTopicsByID(peer: inputPeer, topics: threadIds.map { Int32(clamping: $0) }))
                        |> map { result -> (Peer, FetchedForumThreads)? in
                            return (peer, FetchedForumThreads(forumTopics: result))
                        }
                        |> `catch` { _ -> Signal<(Peer, FetchedForumThreads)?, NoError> in
                            return .single(nil)
                        }
                        signals.append(signal)
                    }
                }
                
                return combineLatest(signals)
                |> map { results -> AccountMutableState in
                    var state = state
                    
                    var storeMessages: [StoreMessage] = []
                    
                    for maybeResult in results {
                        if let (peer, result) = maybeResult {
                            let peerIsForum = peer.isForum
                            let peerId = peer.id
                            
                            state.mergeChats(result.chats)
                            state.mergeUsers(result.users)
                            
                            for message in result.messages {
                                if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                                    storeMessages.append(message)
                                }
                            }
                            
                            for topic in result.items {
                                switch topic {
                                case let .forum(topic):
                                    switch topic {
                                    case let .forumTopic(forumTopicData):
                                        let (flags, id, date, peer, title, iconColor, iconEmojiId, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, unreadPollVoteCount, fromId, notifySettings, draft) = (forumTopicData.flags, forumTopicData.id, forumTopicData.date, forumTopicData.peer, forumTopicData.title, forumTopicData.iconColor, forumTopicData.iconEmojiId, forumTopicData.topMessage, forumTopicData.readInboxMaxId, forumTopicData.readOutboxMaxId, forumTopicData.unreadCount, forumTopicData.unreadMentionsCount, forumTopicData.unreadReactionsCount, forumTopicData.unreadPollVotesCount, forumTopicData.fromId, forumTopicData.notifySettings, forumTopicData.draft)
                                        let _ = peer
                                        let _ = draft

                                        state.operations.append(.ResetForumTopic(
                                            topicId: PeerAndBoundThreadId(peerId: peerId, threadId: Int64(id)),
                                            data: StoreMessageHistoryThreadData(
                                                data: MessageHistoryThreadData(
                                                    creationDate: date,
                                                    isOwnedByMe: (flags & (1 << 1)) != 0,
                                                    author: fromId.peerId,
                                                    info: EngineMessageHistoryThread.Info(
                                                        title: title,
                                                        icon: iconEmojiId == 0 ? nil : iconEmojiId,
                                                        iconColor: iconColor
                                                    ),
                                                    incomingUnreadCount: unreadCount,
                                                    isMarkedUnread: false,
                                                    maxIncomingReadId: readInboxMaxId,
                                                    maxKnownMessageId: topMessage,
                                                    maxOutgoingReadId: readOutboxMaxId,
                                                    isClosed: (flags & (1 << 2)) != 0,
                                                    isHidden: (flags & (1 << 6)) != 0,
                                                    notificationSettings: TelegramPeerNotificationSettings(apiSettings: notifySettings),
                                                    isMessageFeeRemoved: false
                                                ),
                                                topMessageId: topMessage,
                                                unreadMentionCount: unreadMentionsCount,
                                                unreadReactionCount: unreadReactionsCount,
                                                unreadPollVoteCount: unreadPollVoteCount
                                            ),
                                            pts: result.pts
                                        ))
                                    case .forumTopicDeleted:
                                        break
                                    }
                                case let .savedDialog(savedDialog):
                                    switch savedDialog {
                                    case let .monoForumDialog(monoForumDialogData):
                                        let (flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadReactionsCount, _) = (monoForumDialogData.flags, monoForumDialogData.peer, monoForumDialogData.topMessage, monoForumDialogData.readInboxMaxId, monoForumDialogData.readOutboxMaxId, monoForumDialogData.unreadCount, monoForumDialogData.unreadReactionsCount, monoForumDialogData.draft)
                                        state.operations.append(.ResetForumTopic(
                                            topicId: PeerAndBoundThreadId(peerId: peerId, threadId: peer.peerId.toInt64()),
                                            data: StoreMessageHistoryThreadData(
                                                data: MessageHistoryThreadData(
                                                    creationDate: 0,
                                                    isOwnedByMe: true,
                                                    author: accountPeerId,
                                                    info: EngineMessageHistoryThread.Info(
                                                        title: "",
                                                        icon: nil,
                                                        iconColor: 0
                                                    ),
                                                    incomingUnreadCount: unreadCount,
                                                    isMarkedUnread: (flags & (1 << 3)) != 0,
                                                    maxIncomingReadId: readInboxMaxId,
                                                    maxKnownMessageId: topMessage,
                                                    maxOutgoingReadId: readOutboxMaxId,
                                                    isClosed: false,
                                                    isHidden: false,
                                                    notificationSettings: TelegramPeerNotificationSettings.defaultSettings,
                                                    isMessageFeeRemoved: (flags & (1 << 4)) != 0
                                                ),
                                                topMessageId: topMessage,
                                                unreadMentionCount: 0,
                                                unreadReactionCount: unreadReactionsCount,
                                                unreadPollVoteCount: 0
                                            ),
                                            pts: result.pts
                                        ))
                                    case .savedDialog:
                                        break
                                    }
                                }
                            }
                        }
                    }
                    
                    state.addMessages(storeMessages, location: .Random)
                    
                    return state
                }
            }
        }
        |> switchToLatest
    }
}

func resolveForumThreads(accountPeerId: PeerId, postbox: Postbox, source: FetchMessageHistoryHoleSource, additionalPeers: AccumulatedPeers, ids: [PeerAndBoundThreadId]) -> Signal<Void, NoError> {
    let forumThreadIds = Set(ids)
    
    if forumThreadIds.isEmpty {
        return .single(Void())
    } else {
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            var missingForumThreadIds: [PeerId: [Int64]] = [:]
            for threadId in forumThreadIds {
                if !peerCanHaveForumThreads(transaction.getPeer(threadId.peerId) ?? additionalPeers.get(threadId.peerId)) {
                    continue
                }
                if let _ = transaction.getMessageHistoryThreadInfo(peerId: threadId.peerId, threadId: threadId.threadId) {
                } else {
                    missingForumThreadIds[threadId.peerId, default: []].append(threadId.threadId)
                }
            }
            
            if missingForumThreadIds.isEmpty {
                return .single(Void())
            } else {
                var signals: [Signal<(Peer, FetchedForumThreads)?, NoError>] = []
                for (peerId, threadIds) in missingForumThreadIds {
                    guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                        Logger.shared.log("State", "can't fetch thread infos \(threadIds) for peer \(peerId): can't create inputChannel")
                        continue
                    }
                    
                    if let peer = peer as? TelegramChannel, peer.flags.contains(.isMonoforum) {
                        let signal = source.request(Api.functions.messages.getSavedDialogsByID(flags: 1 << 1, parentPeer: inputPeer, ids: threadIds.compactMap { threadId in
                            let threadPeerId = PeerId(threadId)
                            if let threadPeer = additionalPeers.get(threadPeerId) {
                                return apiInputPeer(threadPeer)
                            } else if let threadPeer = transaction.getPeer(threadPeerId) {
                                return apiInputPeer(threadPeer)
                            } else {
                                return nil
                            }
                        }))
                        |> map { result -> (Peer, FetchedForumThreads)? in
                            let result = FetchedForumThreads(savedDialogs: result)
                            return (peer, result)
                        }
                        |> `catch` { _ -> Signal<(Peer, FetchedForumThreads)?, NoError> in
                            return .single(nil)
                        }
                        signals.append(signal)
                    } else {
                        let signal = source.request(Api.functions.messages.getForumTopicsByID(peer: inputPeer, topics: threadIds.map { Int32(clamping: $0) }))
                        |> map { result -> (Peer, FetchedForumThreads)? in
                            return (peer, FetchedForumThreads(forumTopics: result))
                        }
                        |> `catch` { _ -> Signal<(Peer, FetchedForumThreads)?, NoError> in
                            return .single(nil)
                        }
                        signals.append(signal)
                    }
                }
                
                return combineLatest(signals)
                |> mapToSignal { results -> Signal<Void, NoError> in
                    return postbox.transaction { transaction in
                        var chats: [Api.Chat] = []
                        var users: [Api.User] = []
                        var storeMessages: [StoreMessage] = []
                        
                        for maybeResult in results {
                            if let (peer, result) = maybeResult {
                                let peerIsForum = peer.isForum
                                let peerId = peer.id
                                
                                chats.append(contentsOf: result.chats)
                                users.append(contentsOf: result.users)
                                
                                for message in result.messages {
                                    if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                                        storeMessages.append(message)
                                    }
                                }
                                
                                for item in result.items {
                                    switch item {
                                    case let .forum(topic):
                                        storeFetchedForumTopic(transaction: transaction, peerId: peerId, topic: topic)
                                    case let .savedDialog(savedDialog):
                                        switch savedDialog {
                                        case let .monoForumDialog(monoForumDialogData):
                                            let (flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadReactionsCount, _) = (monoForumDialogData.flags, monoForumDialogData.peer, monoForumDialogData.topMessage, monoForumDialogData.readInboxMaxId, monoForumDialogData.readOutboxMaxId, monoForumDialogData.unreadCount, monoForumDialogData.unreadReactionsCount, monoForumDialogData.draft)
                                            let data = MessageHistoryThreadData(
                                                creationDate: 0,
                                                isOwnedByMe: true,
                                                author: accountPeerId,
                                                info: EngineMessageHistoryThread.Info(
                                                    title: "",
                                                    icon: nil,
                                                    iconColor: 0
                                                ),
                                                incomingUnreadCount: unreadCount,
                                                isMarkedUnread: (flags & (1 << 3)) != 0,
                                                maxIncomingReadId: readInboxMaxId,
                                                maxKnownMessageId: topMessage,
                                                maxOutgoingReadId: readOutboxMaxId,
                                                isClosed: false,
                                                isHidden: false,
                                                notificationSettings: TelegramPeerNotificationSettings.defaultSettings,
                                                isMessageFeeRemoved: (flags & (1 << 4)) != 0
                                            )
                                            if let entry = StoredMessageHistoryThreadInfo(data) {
                                                transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: peer.peerId.toInt64(), info: entry)
                                            }
                                            
                                            transaction.replaceMessageTagSummary(peerId: peerId, threadId: peer.peerId.toInt64(), tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: 0, maxId: topMessage)
                                            transaction.replaceMessageTagSummary(peerId: peerId, threadId: peer.peerId.toInt64(), tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, customTag: nil, count: unreadReactionsCount, maxId: topMessage)
                                            transaction.replaceMessageTagSummary(peerId: peerId, threadId: peer.peerId.toInt64(), tagMask: .unseenPollVote, namespace: Namespaces.Message.Cloud, customTag: nil, count: 0, maxId: topMessage)
                                        case .savedDialog:
                                            break
                                        }
                                    }
                                }
                            }
                        }
                        
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        
                        let _ = transaction.addMessages(storeMessages, location: .Random)
                    }
                }
            }
        }
        |> switchToLatest
    }
}

func resolveForumThreads(accountPeerId: PeerId, postbox: Postbox, source: FetchMessageHistoryHoleSource, fetchedChatList: FetchedChatList) -> Signal<FetchedChatList, NoError> {
    var forumThreadIds = Set<PeerAndBoundThreadId>()
    
    for message in fetchedChatList.storeMessages {
        if let threadId = message.threadId {
            // `get` also covers `users`, where the chat list's users (bots with topics among them) are.
            let peer = fetchedChatList.peers.get(message.id.peerId)
            if let channel = peer as? TelegramChannel, case .group = channel.info, (channel.flags.contains(.isForum) || channel.flags.contains(.isMonoforum)) {
                forumThreadIds.insert(PeerAndBoundThreadId(peerId: message.id.peerId, threadId: threadId))
            } else if let user = peer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasForum) {
                forumThreadIds.insert(PeerAndBoundThreadId(peerId: message.id.peerId, threadId: threadId))
            }
        }
    }
    
    if forumThreadIds.isEmpty {
        return .single(fetchedChatList)
    } else {
        return postbox.transaction { transaction -> Signal<FetchedChatList, NoError> in
            var missingForumThreadIds: [PeerId: [Int64]] = [:]
            for threadId in forumThreadIds {
                if let _ = transaction.getMessageHistoryThreadInfo(peerId: threadId.peerId, threadId: threadId.threadId) {
                } else {
                    missingForumThreadIds[threadId.peerId, default: []].append(threadId.threadId)
                }
            }
            
            if missingForumThreadIds.isEmpty {
                return .single(fetchedChatList)
            } else {
                var signals: [Signal<(Peer, FetchedForumThreads)?, NoError>] = []
                for (peerId, threadIds) in missingForumThreadIds {
                    guard let peer = fetchedChatList.peers.get(peerId), let inputPeer = apiInputPeer(peer) else {
                        Logger.shared.log("resolveForumThreads", "can't fetch thread infos \(threadIds) for peer \(peerId): can't create inputPeer")
                        continue
                    }
                    
                    if let peer = peer as? TelegramChannel, peer.flags.contains(.isMonoforum) {
                        let signal = source.request(Api.functions.messages.getSavedDialogsByID(flags: 1 << 1, parentPeer: inputPeer, ids: threadIds.compactMap { threadId in
                            let threadPeerId = PeerId(threadId)
                            if let threadPeer = fetchedChatList.peers.get(threadPeerId) {
                                return apiInputPeer(threadPeer)
                            } else if let threadPeer = transaction.getPeer(threadPeerId) {
                                return apiInputPeer(threadPeer)
                            } else {
                                return nil
                            }
                        }))
                        |> map { result -> (Peer, FetchedForumThreads)? in
                            let result = FetchedForumThreads(savedDialogs: result)
                            return (peer, result)
                        }
                        |> `catch` { _ -> Signal<(Peer, FetchedForumThreads)?, NoError> in
                            return .single(nil)
                        }
                        signals.append(signal)
                    } else {
                        let signal = source.request(Api.functions.messages.getForumTopicsByID(peer: inputPeer, topics: threadIds.map { Int32(clamping: $0) }))
                        |> map { result -> (Peer, FetchedForumThreads)? in
                            return (peer, FetchedForumThreads(forumTopics: result))
                        }
                        |> `catch` { _ -> Signal<(Peer, FetchedForumThreads)?, NoError> in
                            return .single(nil)
                        }
                        signals.append(signal)
                    }
                }
                
                return combineLatest(signals)
                |> map { results -> FetchedChatList in
                    var fetchedChatList = fetchedChatList
                    
                    for maybeResult in results {
                        if let (peer, result) = maybeResult {
                            let peerIsForum = peer.isForum
                            let peerId = peer.id
                            
                            fetchedChatList.peers = fetchedChatList.peers.union(with: AccumulatedPeers(chats: result.chats, users: result.users))
                            
                            for message in result.messages {
                                if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                                    fetchedChatList.storeMessages.append(message)
                                }
                            }
                            
                            for item in result.items {
                                switch item {
                                case let .forum(topic):
                                    switch topic {
                                    case let .forumTopic(forumTopicData):
                                        let (flags, id, date, peer, title, iconColor, iconEmojiId, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, unreadPollVoteCount, fromId, notifySettings, draft) = (forumTopicData.flags, forumTopicData.id, forumTopicData.date, forumTopicData.peer, forumTopicData.title, forumTopicData.iconColor, forumTopicData.iconEmojiId, forumTopicData.topMessage, forumTopicData.readInboxMaxId, forumTopicData.readOutboxMaxId, forumTopicData.unreadCount, forumTopicData.unreadMentionsCount, forumTopicData.unreadReactionsCount, forumTopicData.unreadPollVotesCount, forumTopicData.fromId, forumTopicData.notifySettings, forumTopicData.draft)
                                        let _ = peer
                                        let _ = draft

                                        fetchedChatList.threadInfos[PeerAndBoundThreadId(peerId: peerId, threadId: Int64(id))] = StoreMessageHistoryThreadData(
                                            data: MessageHistoryThreadData(
                                                creationDate: date,
                                                isOwnedByMe: (flags & (1 << 1)) != 0,
                                                author: fromId.peerId,
                                                info: EngineMessageHistoryThread.Info(
                                                    title: title,
                                                    icon: iconEmojiId == 0 ? nil : iconEmojiId,
                                                    iconColor: iconColor
                                                ),
                                                incomingUnreadCount: unreadCount,
                                                isMarkedUnread: false,
                                                maxIncomingReadId: readInboxMaxId,
                                                maxKnownMessageId: topMessage,
                                                maxOutgoingReadId: readOutboxMaxId,
                                                isClosed: (flags & (1 << 2)) != 0,
                                                isHidden: (flags & (1 << 6)) != 0,
                                                notificationSettings: TelegramPeerNotificationSettings(apiSettings: notifySettings),
                                                isMessageFeeRemoved: false
                                            ),
                                            topMessageId: topMessage,
                                            unreadMentionCount: unreadMentionsCount,
                                            unreadReactionCount: unreadReactionsCount,
                                            unreadPollVoteCount: unreadPollVoteCount
                                        )
                                    case .forumTopicDeleted:
                                        break
                                    }
                                case let .savedDialog(savedDialog):
                                    switch savedDialog {
                                    case let .monoForumDialog(monoForumDialogData):
                                        let (flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadReactionsCount, _) = (monoForumDialogData.flags, monoForumDialogData.peer, monoForumDialogData.topMessage, monoForumDialogData.readInboxMaxId, monoForumDialogData.readOutboxMaxId, monoForumDialogData.unreadCount, monoForumDialogData.unreadReactionsCount, monoForumDialogData.draft)

                                        fetchedChatList.threadInfos[PeerAndBoundThreadId(peerId: peerId, threadId: peer.peerId.toInt64())] = StoreMessageHistoryThreadData(
                                            data: MessageHistoryThreadData(
                                                creationDate: 0,
                                                isOwnedByMe: true,
                                                author: accountPeerId,
                                                info: EngineMessageHistoryThread.Info(
                                                    title: "",
                                                    icon: nil,
                                                    iconColor: 0
                                                ),
                                                incomingUnreadCount: unreadCount,
                                                isMarkedUnread: (flags & (1 << 3)) != 0,
                                                maxIncomingReadId: readInboxMaxId,
                                                maxKnownMessageId: topMessage,
                                                maxOutgoingReadId: readOutboxMaxId,
                                                isClosed: false,
                                                isHidden: false,
                                                notificationSettings: TelegramPeerNotificationSettings.defaultSettings,
                                                isMessageFeeRemoved: (flags & (1 << 4)) != 0
                                            ),
                                            topMessageId: topMessage,
                                            unreadMentionCount: 0,
                                            unreadReactionCount: unreadReactionsCount,
                                            unreadPollVoteCount: 0
                                        )
                                    case .savedDialog:
                                        break
                                    }
                                }
                            }
                        }
                    }
                    
                    return fetchedChatList
                }
            }
        }
        |> switchToLatest
    }
}

func resolveStories<T>(postbox: Postbox, source: FetchMessageHistoryHoleSource, accountPeerId: PeerId, storyIds: Set<StoryId>, additionalPeers: AccumulatedPeers, result: T) -> Signal<T, NoError> {
    return Signal { subscriber in
        let cancelled = Atomic<Bool>(value: false)
        let disposable = (postbox.transaction { transaction -> [PeerId: [Int32]] in
            guard !cancelled.with({ $0 }) else { return [:] }
            var buckets: [PeerId: [Int32]] = [:]
            for id in storyIds where id.id > 0 {
                if case let .item(item) = transaction.getStory(id: id)?.get(Stories.StoredItem.self), item.id == id.id { continue }
                if let existing = _internal_existingStoryItem(transaction: transaction, peerId: id.peerId, id: id.id), let entry = CodableEntry(Stories.StoredItem.item(existing)) {
                    transaction.setStory(id: id, value: entry)
                } else {
                    buckets[id.peerId, default: []].append(id.id)
                }
            }
            return buckets
        }
        |> mapToSignal { buckets -> Signal<T, NoError> in
            guard !cancelled.with({ $0 }) else { return .complete() }
            var signals: [Signal<Never, NoError>] = []
            for (peerId, unsortedIds) in buckets {
                let allIds = unsortedIds.sorted()
                var offset = 0
                while offset < allIds.count {
                    let length = min(100, allIds.count - offset)
                    let ids = Array(allIds[offset ..< offset + length])
                    signals.append(_internal_getStoriesById(accountPeerId: accountPeerId, postbox: postbox, source: source, peerId: peerId, peerReference: additionalPeers.get(peerId).flatMap(PeerReference.init), ids: ids, allowFloodWait: false)
                    |> mapToSignal { fetched -> Signal<Never, NoError> in
                        guard let fetched else { return .complete() }
                        let lease = fetched.lease
                        return postbox.transaction { transaction in
                            guard !cancelled.with({ $0 }) else { return }
                            let parsed: StoriesByIdResult
                            switch fetched.stories {
                            case let .stories(data):
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: data.chats, users: data.users))
                                parsed = _internal_parseStoriesById(transaction: transaction, peerId: peerId, ids: ids, stories: data.stories)
                            }
                            var snapshots: [Int32: StoryRefreshSnapshot] = [:]
                            for id in ids where parsed.missingIds.contains(id) || parsed.items.contains(where: { $0.id == id }) {
                                snapshots[id] = StoryRefreshSnapshot(transaction: transaction, peerId: peerId, id: id)
                            }
                            let accepted = lease.context.take(snapshots, for: lease.request)
                            if !accepted.isEmpty { _internal_invalidatePeerStoryPoll(postbox: postbox, peerId: peerId) }
                            for id in ids where accepted[id] != nil {
                                let storyId = StoryId(peerId: peerId, id: id)
                                let updated: CodableEntry
                                if let item = parsed.items.first(where: { $0.id == id }), let entry = CodableEntry(item) {
                                    updated = entry
                                } else if parsed.missingIds.contains(id) {
                                    updated = CodableEntry(data: Data())
                                } else {
                                    continue
                                }
                                if transaction.getStory(id: storyId) != updated { transaction.setStory(id: storyId, value: updated) }
                                if let previous = snapshots[id] {
                                    lease.context.advance(peerId: peerId, id: id, from: previous, to: StoryRefreshSnapshot(transaction: transaction, peerId: peerId, id: id))
                                }
                            }
                        }
                        |> ignoreValues
                    })
                    offset += length
                }
            }
            return combineLatest(signals)
            |> ignoreValues
            |> map { _ -> T in }
            |> then(.single(result))
        }).start(next: { subscriber.putNext($0) }, completed: { subscriber.putCompletion() })
        return ActionDisposable {
            _ = cancelled.swap(true)
            disposable.dispose()
        }
    }
}

func resolveAssociatedStories(postbox: Postbox, network: Network, accountPeerId: PeerId, state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    return postbox.transaction { transaction -> Signal<AccountMutableState, NoError> in
        var missingStoryIds = Set<StoryId>()
        
        for operation in state.operations {
            switch operation {
            case let .AddMessages(messages, _):
                for message in messages {
                    for media in message.media {
                        for id in media.storyIds {
                            if let existing = transaction.getStory(id: id), case .item = existing.get(Stories.StoredItem.self) {
                            } else if state.preCachedStories[id] != nil {
                            } else {
                                missingStoryIds.insert(id)
                            }
                        }
                    }
                }
            default:
                break
            }
        }
        
        if !missingStoryIds.isEmpty {
            return resolveStories(postbox: postbox, source: .network(network), accountPeerId: accountPeerId, storyIds: missingStoryIds, additionalPeers: AccumulatedPeers(peers: Array(state.insertedPeers.values)), result: state)
        } else {
            return .single(state)
        }
    }
    |> switchToLatest
}

func resolveAssociatedStories<T>(postbox: Postbox, source: FetchMessageHistoryHoleSource, accountPeerId: PeerId, messages: [StoreMessage], additionalPeers: AccumulatedPeers, result: T) -> Signal<T, NoError> {
    return postbox.transaction { transaction -> Signal<T, NoError> in
        var missingStoryIds = Set<StoryId>()
        
        for message in messages {
            for media in message.media {
                for id in media.storyIds {
                    if let existing = transaction.getStory(id: id), case .item = existing.get(Stories.StoredItem.self) {
                    } else {
                        missingStoryIds.insert(id)
                    }
                }
            }
        }
        
        if !missingStoryIds.isEmpty {
            return resolveStories(postbox: postbox, source: source, accountPeerId: accountPeerId, storyIds: missingStoryIds, additionalPeers: additionalPeers, result: result)
        } else {
            return .single(result)
        }
    }
    |> switchToLatest
}

func extractEmojiFileIds(message: StoreMessage, fileIds: inout Set<Int64>) {
    for attribute in message.attributes {
        if let attribute = attribute as? TextEntitiesMessageAttribute {
            for entity in attribute.entities {
                switch entity.type {
                case let .CustomEmoji(_, fileId):
                    fileIds.insert(fileId)
                default:
                    break
                }
            }
        } else if let attribute = attribute as? ReactionsMessageAttribute {
            for reaction in attribute.reactions {
                switch reaction.value {
                case let .custom(fileId):
                    fileIds.insert(fileId)
                default:
                    break
                }
            }
        } else if let attribute = attribute as? RichTextMessageAttribute {
            // A rich message's emoji are runs inside its page, not entities.
            fileIds.formUnion(attribute.instantPage.customEmojiFileIds)
            if let fullInstantPage = attribute.fullInstantPage {
                fileIds.formUnion(fullInstantPage.customEmojiFileIds)
            }
        }
    }
    for media in message.media {
        if let media = media as? TelegramMediaWebpage, case let .Loaded(content) = media.content {
            for attribute in content.attributes {
                if case let .aiTextStyle(aiTextStyle) = attribute {
                    fileIds.insert(aiTextStyle.emojiFileId)
                }
            }
        }
    }
}

private func messagesFromOperations(state: AccountMutableState) -> [StoreMessage] {
    var messages: [StoreMessage] = []
    for operation in state.operations {
        switch operation {
        case let .AddMessages(messagesValue, _):
            messages.append(contentsOf: messagesValue)
        case let .EditMessage(_, message):
            messages.append(message)
        case let .UpsertEphemeralReplacement(_, message):
            messages.append(message)
        default:
            break
        }
    }
    return messages
}

private func reactionsFromState(_ state: AccountMutableState) -> [MessageReaction.Reaction] {
    var result: [MessageReaction.Reaction] = []
    for operation in state.operations {
        if case let .UpdateMessageReactions(_, _, reactions, _) = operation {
            for reaction in ReactionsMessageAttribute(apiReactions: reactions).reactions {
                result.append(reaction.value)
            }
        }
    }
    return result
}

func resolveAssociatedMessages(accountPeerId: PeerId, postbox: Postbox, network: Network, state: AccountMutableState) -> Signal<AccountMutableState, NoError> {
    let missingReplyMessageIds = state.referencedReplyMessageIds.subtractingStoredIds(state.storedMessages)
    let missingGeneralMessageIds = state.referencedGeneralMessageIds.subtracting(state.storedMessages)
    
    if missingReplyMessageIds.isEmpty && missingGeneralMessageIds.isEmpty {
        return resolveUnknownEmojiFiles(postbox: postbox, source: .network(network), messages: messagesFromOperations(state: state), reactions: reactionsFromState(state), result: state)
        |> mapToSignal { state in
            return resolveForumThreads(accountPeerId: accountPeerId, postbox: postbox, source: .network(network), state: state)
        }
    } else {
        var signals: [Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>] = []
        for (peerId, messageIds) in messagesIdsGroupedByPeerId(missingReplyMessageIds) {
            if let peer = state.peers[peerId] {
                var signal: Signal<Api.messages.Messages, MTRpcError>?
                if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                    signal = network.request(Api.functions.messages.getMessages(id: messageIds.targetIdsBySourceId.values.map({ Api.InputMessage.inputMessageReplyTo(.init(id: $0.id)) })))
                } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                    if let inputChannel = apiInputChannel(peer) {
                        signal = network.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.targetIdsBySourceId.values.map({ Api.InputMessage.inputMessageReplyTo(.init(id: $0.id)) })))
                    }
                }
                if let signal = signal {
                    signals.append(signal |> map { result in
                        switch result {
                            case let .messages(messagesData):
                                let (messages, apiTopics, chats, users) = (messagesData.messages, messagesData.topics, messagesData.chats, messagesData.users)
                                let _ = apiTopics
                                return (messages, chats, users)
                            case let .messagesSlice(messagesSliceData):
                                let (messages, apiTopics, chats, users) = (messagesSliceData.messages, messagesSliceData.topics, messagesSliceData.chats, messagesSliceData.users)
                                let _ = apiTopics
                                return (messages, chats, users)
                            case let .channelMessages(channelMessagesData):
                                let (messages, apiTopics, chats, users) = (channelMessagesData.messages, channelMessagesData.topics, channelMessagesData.chats, channelMessagesData.users)
                                let _ = apiTopics
                                return (messages, chats, users)
                            case .messagesNotModified:
                                return ([], [], [])
                        }
                    } |> `catch` { _ in
                        return Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>.single(([], [], []))
                    })
                }
            }
        }
        for (peerId, messageIds) in messagesIdsGroupedByPeerId(missingGeneralMessageIds) {
            if let peer = state.peers[peerId] {
                var signal: Signal<Api.messages.Messages, MTRpcError>?
                if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                    signal = network.request(Api.functions.messages.getMessages(id: messageIds.map({ Api.InputMessage.inputMessageID(.init(id: $0.id)) })))
                } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                    if let inputChannel = apiInputChannel(peer) {
                        signal = network.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.map({ Api.InputMessage.inputMessageID(.init(id: $0.id)) })))
                    }
                }
                if let signal = signal {
                    signals.append(signal |> map { result in
                        switch result {
                            case let .messages(messagesData):
                                let (messages, chats, users) = (messagesData.messages, messagesData.chats, messagesData.users)
                                return (messages, chats, users)
                            case let .messagesSlice(messagesSliceData):
                                let (messages, chats, users) = (messagesSliceData.messages, messagesSliceData.chats, messagesSliceData.users)
                                return (messages, chats, users)
                            case let .channelMessages(channelMessagesData):
                                let (messages, apiTopics, chats, users) = (channelMessagesData.messages, channelMessagesData.topics, channelMessagesData.chats, channelMessagesData.users)
                                let _ = apiTopics
                                return (messages, chats, users)
                            case .messagesNotModified:
                                return ([], [], [])
                        }
                    } |> `catch` { _ in
                        return Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>.single(([], [], []))
                    })
                }
            }
        }
        
        let fetchMessages = combineLatest(signals)
        
        return fetchMessages
        |> map { results in
            var updatedState = state
            for (messages, chats, users) in results {
                if !chats.isEmpty {
                    updatedState.mergeChats(chats)
                }
                if !users.isEmpty {
                    updatedState.mergeUsers(users)
                }
                
                if !messages.isEmpty {
                    var storeMessages: [StoreMessage] = []
                    for message in messages {
                        var peerIsForum = false
                        if let peerId = message.peerId {
                            peerIsForum = updatedState.isPeerForum(peerId: peerId)
                        }
                        if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                            storeMessages.append(message)
                        }
                    }
                    updatedState.addMessages(storeMessages, location: .Random)
                }
            }
            return updatedState
        }
        |> mapToSignal { updatedState -> Signal<AccountMutableState, NoError> in
            return resolveUnknownEmojiFiles(postbox: postbox, source: .network(network), messages: messagesFromOperations(state: updatedState), reactions: reactionsFromState(updatedState), result: updatedState)
            |> mapToSignal { state in
                return resolveForumThreads(accountPeerId: accountPeerId, postbox: postbox, source: .network(network), state: state)
            }
        }
    }
}

func resolveMissingPeerChatInfos(accountPeerId: PeerId, network: Network, state: AccountMutableState) -> Signal<(AccountMutableState, Bool), NoError> {
    var missingPeers: [PeerId: Api.InputDialogPeer] = [:]
    var hadError = false
    
    for peerId in state.initialState.peerIdsRequiringLocalChatState {
        if state.peerChatInfos[peerId] == nil {
            if let peer = state.peers[peerId], let inputDialogPeer = apiInputDialogPeer(peer) {
                missingPeers[peerId] = inputDialogPeer
            } else {
                hadError = true
                Logger.shared.log("State", "can't fetch chat info for peer \(peerId): can't create inputDialogPeer")
            }
        }
    }
    
    if missingPeers.isEmpty {
        return .single((state, hadError))
    } else {
        Logger.shared.log("State", "will fetch chat info for \(missingPeers.count) peers")
        let signal = network.request(Api.functions.messages.getPeerDialogs(peers: Array(missingPeers.values)))
        |> map(Optional.init)
        
        return signal
        |> `catch` { _ -> Signal<Api.messages.PeerDialogs?, NoError> in
            return .single(nil)
        }
        |> map { result -> (AccountMutableState, Bool) in
            guard let result = result else {
                return (state, hadError)
            }
            
            var channelStates: [PeerId: ChannelState] = [:]
            
            var updatedState = state
            switch result {
                case let .peerDialogs(peerDialogsData):
                    let (dialogs, messages, chats, users) = (peerDialogsData.dialogs, peerDialogsData.messages, peerDialogsData.chats, peerDialogsData.users)
                    updatedState.mergeChats(chats)
                    updatedState.mergeUsers(users)
                    
                    var topMessageIds = Set<MessageId>()
                    
                    for dialog in dialogs {
                        switch dialog {
                            case let .dialog(dialogData):
                                let (peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, unreadPollVoteCount, notifySettings, pts, folderId, ttlPeriod) = (dialogData.peer, dialogData.topMessage, dialogData.readInboxMaxId, dialogData.readOutboxMaxId, dialogData.unreadCount, dialogData.unreadMentionsCount, dialogData.unreadReactionsCount, dialogData.unreadPollVotesCount, dialogData.notifySettings, dialogData.pts, dialogData.folderId, dialogData.ttlPeriod)
                                let peerId = peer.peerId
                                
                                updatedState.setNeedsHoleFromPreviousState(peerId: peerId, namespace: Namespaces.Message.Cloud)
                                
                                if topMessage != 0 {
                                    topMessageIds.insert(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: topMessage))
                                }
                                
                                var isExcludedFromChatList = false
                                for chat in chats {
                                    if chat.peerId == peerId {
                                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                            if let group = groupOrChannel as? TelegramGroup {
                                                if group.flags.contains(.deactivated) {
                                                    isExcludedFromChatList = true
                                                } else {
                                                    switch group.membership {
                                                    case .Member:
                                                        break
                                                    default:
                                                        isExcludedFromChatList = true
                                                    }
                                                }
                                            } else if let channel = groupOrChannel as? TelegramChannel {
                                                switch channel.participationStatus {
                                                case .member:
                                                    break
                                                default:
                                                    isExcludedFromChatList = true
                                                }
                                            }
                                        }
                                        break
                                    }
                                }
                                
                                if !isExcludedFromChatList {
                                    updatedState.updatePeerChatInclusion(peerId: peerId, groupId: PeerGroupId(rawValue: folderId ?? 0), changedGroup: false)
                                }
                            
                                updatedState.updateAutoremoveTimeout(peer: peer, value: ttlPeriod.flatMap(CachedPeerAutoremoveTimeout.Value.init(peerValue:)))
                                
                                let notificationSettings = TelegramPeerNotificationSettings(apiSettings: notifySettings)
                                updatedState.updateNotificationSettings(.peer(peerId: peer.peerId, threadId: nil), notificationSettings: notificationSettings)
                                
                                updatedState.resetReadState(peer.peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: readInboxMaxId, maxOutgoingReadId: readOutboxMaxId, maxKnownId: topMessage, count: unreadCount, markedUnread: nil)
                                updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                                updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenReaction, namespace: Namespaces.Message.Cloud, count: unreadReactionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                                updatedState.resetMessageTagSummary(peer.peerId, tag: .unseenPollVote, namespace: Namespaces.Message.Cloud, count: unreadPollVoteCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: topMessage))
                                updatedState.peerChatInfos[peer.peerId] = PeerChatInfo(notificationSettings: notificationSettings)
                                if let pts = pts {
                                    channelStates[peer.peerId] = ChannelState(pts: pts, invalidatedPts: pts, synchronizedUntilMessageId: nil)
                                }
                            case let .dialogCommunity(dialogCommunityData):
                                let peerId = peerIdFromApiCommunityId(dialogCommunityData.communityId)
                                let notificationSettings = TelegramPeerNotificationSettings(apiSettings: dialogCommunityData.notifySettings)
                                updatedState.updateNotificationSettings(.peer(peerId: peerId, threadId: nil), notificationSettings: notificationSettings)
                                updatedState.peerChatInfos[peerId] = PeerChatInfo(notificationSettings: notificationSettings)
                            case .dialogFolder:
                                assertionFailure()
                                break
                        }
                    }
                    
                    var storeMessages: [StoreMessage] = []
                    for message in messages {
                        var peerIsForum = false
                        if let peerId = message.peerId {
                            peerIsForum = updatedState.isPeerForum(peerId: peerId)
                        }
                        if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                            var updatedStoreMessage = storeMessage
                            if case let .Id(id) = storeMessage.id {
                                if let channelState = channelStates[id.peerId] {
                                    var updatedAttributes = storeMessage.attributes
                                    updatedAttributes.append(ChannelMessageStateVersionAttribute(pts: channelState.pts))
                                    updatedStoreMessage = updatedStoreMessage.withUpdatedAttributes(updatedAttributes)
                                }
                            }
                            storeMessages.append(updatedStoreMessage)
                        }
                    }
                
                    for message in storeMessages {
                        if case let .Id(id) = message.id {
                            updatedState.addMessages([message], location: topMessageIds.contains(id) ? .UpperHistoryBlock : .Random)
                        }
                    }
            }
            return (updatedState, hadError)
        }
    }
}

/// Stores a forum topic fetched from the server: its thread info and its unread mention, reaction and poll-vote
/// summaries. A deleted topic stores nothing.
func storeFetchedForumTopic(transaction: Transaction, peerId: PeerId, topic: Api.ForumTopic) {
    switch topic {
    case let .forumTopic(forumTopicData):
        let (flags, id, date, peer, title, iconColor, iconEmojiId, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, unreadPollVoteCount, fromId, notifySettings, draft) = (forumTopicData.flags, forumTopicData.id, forumTopicData.date, forumTopicData.peer, forumTopicData.title, forumTopicData.iconColor, forumTopicData.iconEmojiId, forumTopicData.topMessage, forumTopicData.readInboxMaxId, forumTopicData.readOutboxMaxId, forumTopicData.unreadCount, forumTopicData.unreadMentionsCount, forumTopicData.unreadReactionsCount, forumTopicData.unreadPollVotesCount, forumTopicData.fromId, forumTopicData.notifySettings, forumTopicData.draft)
        let _ = peer
        let _ = draft

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
            isMarkedUnread: false,
            maxIncomingReadId: readInboxMaxId,
            maxKnownMessageId: topMessage,
            maxOutgoingReadId: readOutboxMaxId,
            isClosed: (flags & (1 << 2)) != 0,
            isHidden: (flags & (1 << 6)) != 0,
            notificationSettings: TelegramPeerNotificationSettings(apiSettings: notifySettings),
            isMessageFeeRemoved: false
        )
        if let entry = StoredMessageHistoryThreadInfo(data) {
            transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: Int64(id), info: entry)
        }

        transaction.replaceMessageTagSummary(peerId: peerId, threadId: Int64(id), tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: unreadMentionsCount, maxId: topMessage)
        transaction.replaceMessageTagSummary(peerId: peerId, threadId: Int64(id), tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, customTag: nil, count: unreadReactionsCount, maxId: topMessage)
        transaction.replaceMessageTagSummary(peerId: peerId, threadId: Int64(id), tagMask: .unseenPollVote, namespace: Namespaces.Message.Cloud, customTag: nil, count: unreadPollVoteCount, maxId: topMessage)
    case .forumTopicDeleted:
        break
    }
}
