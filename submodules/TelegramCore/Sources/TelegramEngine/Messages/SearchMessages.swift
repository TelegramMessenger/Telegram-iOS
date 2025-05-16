import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum SearchMessagesLocation: Equatable {
    case general(scope: TelegramSearchPeersScope, tags: MessageTags?, minDate: Int32?, maxDate: Int32?)
    case group(groupId: PeerGroupId, tags: MessageTags?, minDate: Int32?, maxDate: Int32?)
    case peer(peerId: PeerId, fromId: PeerId?, tags: MessageTags?, reactions: [MessageReaction.Reaction]?, threadId: Int64?, minDate: Int32?, maxDate: Int32?)
    case sentMedia(tags: MessageTags?)
}

private struct SearchMessagesPeerState: Equatable {
    let messages: [Message]
    let readStates: [PeerId: CombinedPeerReadState]
    let threadInfo: [MessageId: MessageHistoryThreadData]
    let totalCount: Int32
    let completed: Bool
    let nextRate: Int32?
    
    static func ==(lhs: SearchMessagesPeerState, rhs: SearchMessagesPeerState) -> Bool {
        if lhs.totalCount != rhs.totalCount {
            return false
        }
        if lhs.completed != rhs.completed {
            return false
        }
        if lhs.messages.count != rhs.messages.count {
            return false
        }
        for i in 0 ..< lhs.messages.count {
            if lhs.messages[i].id != rhs.messages[i].id {
                return false
            }
        }
        if lhs.nextRate != rhs.nextRate {
            return false
        }
        return true
    }
}

public struct SearchMessagesResult: Equatable {
    public let messages: [Message]
    public let threadInfo: [MessageId: MessageHistoryThreadData]
    public let readStates: [PeerId: CombinedPeerReadState]
    public let totalCount: Int32
    public let completed: Bool
    
    public init(messages: [Message], readStates: [PeerId: CombinedPeerReadState], threadInfo:[MessageId : MessageHistoryThreadData], totalCount: Int32, completed: Bool) {
        self.messages = messages
        self.threadInfo = threadInfo
        self.readStates = readStates
        self.totalCount = totalCount
        self.completed = completed
    }
    
    public static func ==(lhs: SearchMessagesResult, rhs: SearchMessagesResult) -> Bool {
        if lhs.messages.count != rhs.messages.count {
            return false
        }
        for i in 0 ..< lhs.messages.count {
            if lhs.messages[i].index != rhs.messages[i].index {
                return false
            }
            if lhs.messages[i].stableVersion != rhs.messages[i].stableVersion {
                return false
            }
        }
        return true
    }
}

public struct SearchMessagesState: Equatable {
    fileprivate let main: SearchMessagesPeerState
    fileprivate let additional: SearchMessagesPeerState?
}

private func mergedState(transaction: Transaction, seedConfiguration: SeedConfiguration, accountPeerId: PeerId, state: SearchMessagesPeerState?, result: Api.messages.Messages?) -> SearchMessagesPeerState? {
    guard let result = result else {
        return state
    }
    let messages: [Api.Message]
    let chats: [Api.Chat]
    let users: [Api.User]
    let totalCount: Int32
    let nextRate: Int32?
    switch result {
        case let .channelMessages(_, _, count, _, apiMessages, apiTopics, apiChats, apiUsers):
            messages = apiMessages
            let _ = apiTopics
            chats = apiChats
            users = apiUsers
            totalCount = count
            nextRate = nil
        case let .messages(apiMessages, apiChats, apiUsers):
            messages = apiMessages
            chats = apiChats
            users = apiUsers
            totalCount = Int32(messages.count)
            nextRate = nil
        case let .messagesSlice(_, count, apiNextRate, _, apiMessages, apiChats, apiUsers):
            messages = apiMessages
            chats = apiChats
            users = apiUsers
            totalCount = count
            nextRate = apiNextRate
        case .messagesNotModified:
            messages = []
            chats = []
            users = []
            totalCount = 0
            nextRate = nil
    }
    
    var peers: [PeerId: Peer] = [:]
    
    for user in users {
        if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
            peers[user.id] = user
        }
    }
    
    for chat in chats {
        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
            peers[groupOrChannel.id] = groupOrChannel
        }
    }
    
    var peerIdsSet: Set<PeerId> = Set()
    var readStates: [PeerId: CombinedPeerReadState] = [:]
    var threadInfo: [MessageId : MessageHistoryThreadData] = [:]
    if let state = state {
        threadInfo = state.threadInfo
    }
    
    var renderedMessages: [Message] = []
    for message in messages {
        var peerIsForum = false
        if let peerId = message.peerId, let peer = peers[peerId], peer.isForumOrMonoForum {
            peerIsForum = true
        }
        if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
            var associatedThreadInfo: Message.AssociatedThreadInfo?
            if let threadId = message.threadId, let threadInfo = transaction.getMessageHistoryThreadInfo(peerId: message.id.peerId, threadId: threadId) {
                associatedThreadInfo = seedConfiguration.decodeMessageThreadInfo(threadInfo.data)
            }
            if let renderedMessage = locallyRenderedMessage(message: message, peers: peers, associatedThreadInfo: associatedThreadInfo) {
                let peerId = renderedMessage.id.peerId
                renderedMessages.append(renderedMessage)
                peerIdsSet.insert(peerId)
                for attribute in renderedMessage.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute {
                        if let threadMessageId = attribute.threadMessageId {
                            let threadId = Int64(threadMessageId.id)
                            if let data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                                threadInfo[renderedMessage.id] = data
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    for peerId in peerIdsSet {
        if let readState = transaction.getCombinedPeerReadState(peerId) {
            readStates[peerId] = readState
        }
    }
    
    renderedMessages.sort(by: { lhs, rhs in
        return lhs.index > rhs.index
    })
        
    let completed = renderedMessages.isEmpty || renderedMessages.count == totalCount
    if let previous = state {
        var currentIds = Set<MessageId>()
        var mergedMessages: [Message] = []
        for message in previous.messages {
            if currentIds.contains(message.id) {
                continue
            }
            currentIds.insert(message.id)
            mergedMessages.append(message)
        }
        for message in renderedMessages {
            if currentIds.contains(message.id) {
                continue
            }
            currentIds.insert(message.id)
            mergedMessages.append(message)
        }
        mergedMessages.sort(by: { lhs, rhs in
            return lhs.index > rhs.index
        })
        return SearchMessagesPeerState(messages: mergedMessages, readStates: readStates, threadInfo: threadInfo, totalCount: completed ? Int32(mergedMessages.count) : totalCount, completed: completed, nextRate: nextRate)
    } else {
        return SearchMessagesPeerState(messages: renderedMessages, readStates: readStates, threadInfo: threadInfo, totalCount: completed ? Int32(renderedMessages.count) : totalCount, completed: completed, nextRate: nextRate)
    }
}

private func mergedResult(_ state: SearchMessagesState) -> SearchMessagesResult {
    var messages: [Message] = state.main.messages
    if let additional = state.additional {
        if state.main.completed {
            messages.append(contentsOf: additional.messages)
        } else if let lastMessage = state.main.messages.last {
            let earliestIndex = lastMessage.index
            messages.append(contentsOf: additional.messages.filter({ $0.index > earliestIndex }))
        }
    }
    messages.sort(by: { lhs, rhs in
        return lhs.index > rhs.index
    })
    
    var readStates: [PeerId: CombinedPeerReadState] = [:]
    for message in messages {
        let readState = state.main.readStates[message.id.peerId] ?? state.additional?.readStates[message.id.peerId]
        if let readState = readState {
            readStates[message.id.peerId] = readState
        }
    }
    
    var threadInfo: [MessageId: MessageHistoryThreadData] = [:]
    for message in messages {
        let data = state.main.threadInfo[message.id] ?? state.additional?.threadInfo[message.id]
        if let data = data {
            threadInfo[message.id] = data
        }
    }
    
    return SearchMessagesResult(messages: messages, readStates: readStates, threadInfo: threadInfo, totalCount: state.main.totalCount + (state.additional?.totalCount ?? 0), completed: state.main.completed && (state.additional?.completed ?? true))
}

func _internal_getSearchMessageCount(account: Account, location: SearchMessagesLocation, query: String) -> Signal<Int?, NoError> {
    guard case let .peer(peerId, fromId, _, _, threadId, _, _) = location else {
        return .single(nil)
    }
    return account.postbox.transaction { transaction -> (Api.InputPeer?, Api.InputPeer?, Api.InputPeer?) in
        var chatPeer = transaction.getPeer(peerId)
        var fromPeer: Api.InputPeer?
        var savedPeer: Api.InputPeer?
        if let fromId {
            if let value = transaction.getPeer(fromId).flatMap(apiInputPeer) {
                fromPeer = value
            } else {
                chatPeer = nil
            }
        }
        
        if let threadId, let channel = chatPeer as? TelegramChannel, channel.isMonoForum {
            savedPeer = transaction.getPeer(PeerId(threadId)).flatMap(apiInputPeer)
        }
        
        return (chatPeer.flatMap(apiInputPeer), fromPeer, savedPeer)
    }
    |> mapToSignal { inputPeer, fromPeer, savedPeer -> Signal<Int?, NoError> in
        guard let inputPeer else {
            return .single(nil)
        }
        
        var flags: Int32 = 0
        
        if let _ = fromPeer {
            flags |= (1 << 0)
        }
        
        var topMsgId: Int32?
        var savedPeerId: Api.InputPeer?
        if let savedPeer {
            flags |= (1 << 2)
            savedPeerId = savedPeer
        } else if let threadId {
            flags |= (1 << 1)
            topMsgId = Int32(clamping: threadId)
        }
        
        return account.network.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: query, fromId: fromPeer, savedPeerId: savedPeerId, savedReaction: nil, topMsgId: topMsgId, filter: .inputMessagesFilterEmpty, minDate: 0, maxDate: 0, offsetId: 0, addOffset: 0, limit: 1, maxId: 0, minId: 0, hash: 0))
        |> map { result -> Int? in
            switch result {
            case let .channelMessages(_, _, count, _, _, _, _, _):
                return Int(count)
            case let .messages(messages, _, _):
                return messages.count
            case let .messagesNotModified(count):
                return Int(count)
            case let .messagesSlice(_, count, _, _, _, _, _):
                return Int(count)
            }
        }
        |> `catch` { _ -> Signal<Int?, NoError> in
            return .single(nil)
        }
    }
}

func _internal_searchMessages(account: Account, location: SearchMessagesLocation, query: String, state: SearchMessagesState?, centerId: MessageId?, limit: Int32 = 100) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
    if case let .peer(peerId, fromId, tags, reactions, threadId, minDate, maxDate) = location, fromId == nil, tags == nil, peerId == account.peerId, let reactions, let reaction = reactions.first, (minDate == nil || minDate == 0), (maxDate == nil || maxDate == 0) {
        return account.postbox.transaction { transaction -> (SearchMessagesResult, SearchMessagesState) in
            let messages = transaction.getMessagesWithCustomTag(peerId: peerId, namespace: Namespaces.Message.Cloud, threadId: threadId, customTag: ReactionsMessageAttribute.messageTag(reaction: reaction), from: MessageIndex.upperBound(peerId: peerId, namespace: Namespaces.Message.Cloud), includeFrom: false, to: MessageIndex.lowerBound(peerId: peerId, namespace: Namespaces.Message.Cloud), limit: 500)
            
            return (
                SearchMessagesResult(
                    messages: messages,
                    readStates: [:],
                    threadInfo: [:],
                    totalCount: Int32(messages.count),
                    completed: true
                ),
                SearchMessagesState(
                    main: SearchMessagesPeerState(
                        messages: messages,
                        readStates: [:],
                        threadInfo: [:],
                        totalCount: Int32(messages.count),
                        completed: true,
                        nextRate: nil
                    ),
                    additional: nil
                )
            )
        }
    }
    
    let remoteSearchResult: Signal<(Api.messages.Messages?, Api.messages.Messages?), NoError>
    switch location {
        case let .peer(peerId, fromId, tags, reactions, threadId, minDate, maxDate):
            if peerId.namespace == Namespaces.Peer.SecretChat {
                return account.postbox.transaction { transaction -> (SearchMessagesResult, SearchMessagesState) in
                    var readStates: [PeerId: CombinedPeerReadState] = [:]
                    var threadInfo: [MessageId: MessageHistoryThreadData] = [:]
                    if let readState = transaction.getCombinedPeerReadState(peerId) {
                        readStates[peerId] = readState
                    }
                    let result = transaction.searchMessages(peerId: peerId, query: query, tags: tags)
                    
                    for message in result {
                        for attribute in message.attributes {
                            if let attribute = attribute as? ReplyMessageAttribute {
                                if let threadMessageId = attribute.threadMessageId {
                                    let threadId = Int64(threadMessageId.id)
                                    if let data = transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                                        threadInfo[message.id] = data
                                        break
                                    }
                                }
                            }
                        }
                    }
                    
                    return (SearchMessagesResult(messages: result, readStates: readStates, threadInfo: threadInfo, totalCount: Int32(result.count), completed: true), SearchMessagesState(main: SearchMessagesPeerState(messages: [], readStates: [:], threadInfo: [:], totalCount: 0, completed: true, nextRate: nil), additional: nil))
                }
            }
            
            let filter: Api.MessagesFilter = tags.flatMap { messageFilterForTagMask($0) } ?? .inputMessagesFilterEmpty
            remoteSearchResult = account.postbox.transaction { transaction -> (peer: Peer, additionalPeer: Peer?, from: Peer?, subPeer: Peer?)? in
                guard let peer = transaction.getPeer(peerId) else {
                    return nil
                }
                var additionalPeer: Peer?
                if let _ = peer as? TelegramChannel, let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData, let migrationReference = cachedData.migrationReference {
                    additionalPeer = transaction.getPeer(migrationReference.maxMessageId.peerId)
                }
                var subPeer: Peer?
                if peerId == account.peerId || peer.isMonoForum, let threadId {
                    subPeer = transaction.getPeer(PeerId(threadId))
                }
                
                return (peer: peer, additionalPeer: additionalPeer, from: fromId.flatMap(transaction.getPeer), subPeer: subPeer)
            }
            |> mapToSignal { values -> Signal<(Api.messages.Messages?, Api.messages.Messages?), NoError> in
                guard let values = values else {
                    return .single((nil, nil))
                }
                let peer = values.peer
                guard let inputPeer = apiInputPeer(peer) else {
                    return .single((nil, nil))
                }
                var fromInputPeer: Api.InputPeer? = nil
                var flags: Int32 = 0
                if let from = values.from {
                    fromInputPeer = apiInputPeer(from)
                    if let _ = fromInputPeer {
                        flags |= (1 << 0)
                    }
                }
                var inputSavedPeer: Api.InputPeer? = nil
                if let subPeer = values.subPeer {
                    if let inputPeer = apiInputPeer(subPeer) {
                        inputSavedPeer = inputPeer
                        flags |= (1 << 2)
                    }
                }
                var topMsgId: Int32?
                if peerId == account.peerId || inputSavedPeer != nil {
                } else if let threadId = threadId {
                    flags |= (1 << 1)
                    topMsgId = Int32(clamping: threadId)
                }
                
                let peerMessages: Signal<Api.messages.Messages?, NoError>
                if let completed = state?.main.completed, completed {
                    peerMessages = .single(nil)
                } else {
                    let lowerBound = state?.main.messages.last.flatMap({ $0.index })
                    let signal: Signal<Api.messages.Messages, MTRpcError>
                    if peer.id.namespace == Namespaces.Peer.CloudChannel && query.isEmpty && fromId == nil && tags == nil && minDate == nil && maxDate == nil && threadId == nil {
                        signal = account.network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: lowerBound?.id.id ?? 0, offsetDate: 0, addOffset: 0, limit: limit, maxId: Int32.max - 1, minId: 0, hash: 0))
                    } else {
                        var savedReactions: [Api.Reaction]?
                        if let reactions = reactions {
                            savedReactions = reactions.map {
                                $0.apiReaction
                            }
                        }
                        
                        if savedReactions != nil {
                            flags |= 1 << 3
                        }
                        
                        signal = account.network.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: query, fromId: fromInputPeer, savedPeerId: inputSavedPeer, savedReaction: savedReactions, topMsgId: topMsgId, filter: filter, minDate: minDate ?? 0, maxDate: maxDate ?? (Int32.max - 1), offsetId: lowerBound?.id.id ?? 0, addOffset: 0, limit: limit, maxId: Int32.max - 1, minId: 0, hash: 0))
                    }
                    peerMessages = signal
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                        return .single(nil)
                    }
                }
                let additionalPeerMessages: Signal<Api.messages.Messages?, NoError>
                if let inputPeer = values.additionalPeer.flatMap(apiInputPeer) {
                    let mainCompleted = state?.main.completed ?? false
                    let hasAdditional = state?.additional != nil
                    if let completed = state?.additional?.completed, completed {
                        additionalPeerMessages = .single(nil)
                    } else if mainCompleted || !hasAdditional {
                        let lowerBound = state?.additional?.messages.last.flatMap({ $0.index })
                        
                        var savedReactions: [Api.Reaction]?
                        if let reactions = reactions {
                            savedReactions = reactions.map {
                                $0.apiReaction
                            }
                        }
                        
                        if savedReactions != nil {
                            flags |= 1 << 3
                        }
                        
                        additionalPeerMessages = account.network.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: query, fromId: fromInputPeer, savedPeerId: inputSavedPeer, savedReaction: savedReactions, topMsgId: topMsgId, filter: filter, minDate: minDate ?? 0, maxDate: maxDate ?? (Int32.max - 1), offsetId: lowerBound?.id.id ?? 0, addOffset: 0, limit: limit, maxId: Int32.max - 1, minId: 0, hash: 0))
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                            return .single(nil)
                        }
                    } else {
                        additionalPeerMessages = .single(nil)
                    }
                } else {
                    additionalPeerMessages = .single(nil)
                }
                return combineLatest(peerMessages, additionalPeerMessages)
            }
        case let .general(_, tags, minDate, maxDate), let .group(_, tags, minDate, maxDate):
            var flags: Int32 = 0
            let folderId: Int32?
            if case let .group(groupId, _, _, _) = location {
                folderId = groupId.rawValue
                flags |= (1 << 0)
            } else {
                folderId = nil
            }
        
            if case let .general(scope, _, _, _) = location {
                switch scope {
                case .everywhere:
                    break
                case .channels:
                    flags |= (1 << 1)
                case .groups:
                    flags |= (1 << 2)
                case .privateChats:
                    flags |= (1 << 3)
                }
            }
        
            let filter: Api.MessagesFilter = tags.flatMap { messageFilterForTagMask($0) } ?? .inputMessagesFilterEmpty
            remoteSearchResult = account.postbox.transaction { transaction -> (Int32, MessageIndex?, Api.InputPeer) in
                var lowerBound: MessageIndex?
                if let state = state, let message = state.main.messages.last {
                    lowerBound = message.index
                }
                if let lowerBound = lowerBound, let peer = transaction.getPeer(lowerBound.id.peerId), let inputPeer = apiInputPeer(peer) {
                    return (state?.main.nextRate ?? 0, lowerBound, inputPeer)
                } else {
                    return (0, lowerBound, .inputPeerEmpty)
                }
            }
            |> mapToSignal { (nextRate, lowerBound, inputPeer) in
                return account.network.request(Api.functions.messages.searchGlobal(flags: flags, folderId: folderId, q: query, filter: filter, minDate: minDate ?? 0, maxDate: maxDate ?? (Int32.max - 1), offsetRate: nextRate, offsetPeer: inputPeer, offsetId: lowerBound?.id.id ?? 0, limit: limit), automaticFloodWait: false)
                |> map { result -> (Api.messages.Messages?, Api.messages.Messages?) in
                    return (result, nil)
                }
                |> `catch` { _ -> Signal<(Api.messages.Messages?, Api.messages.Messages?), NoError> in
                    return .single((nil, nil))
                }
            }
        case let .sentMedia(tags):
            let filter: Api.MessagesFilter = tags.flatMap { messageFilterForTagMask($0) } ?? .inputMessagesFilterEmpty
        
            let peerMessages: Signal<Api.messages.Messages?, NoError>
            if let completed = state?.main.completed, completed {
                peerMessages = .single(nil)
            } else {
                peerMessages = account.network.request(Api.functions.messages.searchSentMedia(q: query, filter: filter, limit: limit))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                    return .single(nil)
                }
            }
            remoteSearchResult = combineLatest(peerMessages, .single(nil))
    }
    
    return remoteSearchResult
    |> mapToSignal { result, additionalResult -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> in
        return account.postbox.transaction { transaction -> (SearchMessagesResult, SearchMessagesState) in
            var additional: SearchMessagesPeerState? = mergedState(transaction: transaction, seedConfiguration: account.postbox.seedConfiguration, accountPeerId: account.peerId, state: state?.additional, result: additionalResult)
            
            if state?.additional == nil {
                switch location {
                    case let .general(_, tags, minDate, maxDate), let .group(_, tags, minDate, maxDate):
                        let secretMessages: [Message]
                        if case let .general(scope, _, _, _) = location, case .channels = scope {
                            secretMessages = []
                        } else {
                            secretMessages = transaction.searchMessages(peerId: nil, query: query, tags: tags)
                        }
                        
                        var filteredMessages: [Message] = []
                        var readStates: [PeerId: CombinedPeerReadState] = [:]
                        var threadInfo:[MessageId : MessageHistoryThreadData] = [:]
                        for message in secretMessages {
                            var match = true
                            if let minDate = minDate, message.timestamp < minDate {
                                match = false
                            }
                            if let maxDate = maxDate, message.timestamp > maxDate {
                                match = false
                            }
                            if match {
                                filteredMessages.append(message)
                                if let readState = transaction.getCombinedPeerReadState(message.id.peerId) {
                                    readStates[message.id.peerId] = readState
                                }
                                for attribute in message.attributes {
                                    if let attribute = attribute as? ReplyMessageAttribute {
                                        if let threadMessageId = attribute.threadMessageId {
                                            let threadId = Int64(threadMessageId.id)
                                            if let data = transaction.getMessageHistoryThreadInfo(peerId: message.id.peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self) {
                                                threadInfo[message.id] = data
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        additional = SearchMessagesPeerState(messages: filteredMessages, readStates: readStates, threadInfo: threadInfo, totalCount: Int32(filteredMessages.count), completed: true, nextRate: nil)
                    default:
                        break
                }
            }
            
            let updatedState = SearchMessagesState(main: mergedState(transaction: transaction, seedConfiguration: account.postbox.seedConfiguration, accountPeerId: account.peerId, state: state?.main, result: result) ?? SearchMessagesPeerState(messages: [], readStates: [:], threadInfo: [:], totalCount: 0, completed: true, nextRate: nil), additional: additional)
            return (mergedResult(updatedState), updatedState)
        }
    }
}

func _internal_searchHashtagPosts(account: Account, hashtag: String, state: SearchMessagesState?, limit: Int32 = 100) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
    let remoteSearchResult = account.postbox.transaction { transaction -> (Int32, MessageIndex?, Api.InputPeer) in
        var lowerBound: MessageIndex?
        var peer: Peer?
        if let state = state, let message = state.main.messages.last {
            lowerBound = message.index
            peer = message.peers[message.id.peerId]
        }
        if let lowerBound = lowerBound, let peer, let inputPeer = apiInputPeer(peer) {
            return (state?.main.nextRate ?? 0, lowerBound, inputPeer)
        } else {
            return (0, lowerBound, .inputPeerEmpty)
        }
    }
    |> mapToSignal { (nextRate, lowerBound, inputPeer) in
        return account.network.request(Api.functions.channels.searchPosts(hashtag: hashtag, offsetRate: nextRate, offsetPeer: inputPeer, offsetId: lowerBound?.id.id ?? 0, limit: limit), automaticFloodWait: false)
        |> map { result -> (Api.messages.Messages?, Api.messages.Messages?) in
            return (result, nil)
        }
        |> `catch` { _ -> Signal<(Api.messages.Messages?, Api.messages.Messages?), NoError> in
            return .single((nil, nil))
        }
    }
    return remoteSearchResult
    |> mapToSignal { result, additionalResult -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> in
        return account.postbox.transaction { transaction -> (SearchMessagesResult, SearchMessagesState) in
            let updatedState = SearchMessagesState(main: mergedState(transaction: transaction, seedConfiguration: account.postbox.seedConfiguration, accountPeerId: account.peerId, state: state?.main, result: result) ?? SearchMessagesPeerState(messages: [], readStates: [:], threadInfo: [:], totalCount: 0, completed: true, nextRate: nil), additional: nil)
            return (mergedResult(updatedState), updatedState)
        }
    }
}

func _internal_downloadMessage(accountPeerId: PeerId, postbox: Postbox, network: Network, messageId: MessageId) -> Signal<Message?, NoError> {
    return postbox.transaction { transaction -> Message? in
        return transaction.getMessage(messageId)
    } |> mapToSignal { message in
        if let _ = message {
            return .single(message)
        } else {
            return postbox.loadedPeerWithId(messageId.peerId)
            |> mapToSignal { peer -> Signal<Message?, NoError> in
                let signal: Signal<Api.messages.Messages, MTRpcError>
                if messageId.peerId.namespace == Namespaces.Peer.CloudChannel {
                    if let channel = apiInputChannel(peer) {
                        signal = network.request(Api.functions.channels.getMessages(channel: channel, id: [Api.InputMessage.inputMessageID(id: messageId.id)]))
                    } else {
                        signal = .complete()
                    }
                } else {
                    signal = network.request(Api.functions.messages.getMessages(id: [Api.InputMessage.inputMessageID(id: messageId.id)]))
                }
                
                return signal
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Message?, NoError> in
                    guard let result = result else {
                        return .single(nil)
                    }
                    let messages: [Api.Message]
                    let chats: [Api.Chat]
                    let users: [Api.User]
                    switch result {
                        case let .channelMessages(_, _, _, _, apiMessages, apiTopics, apiChats, apiUsers):
                            messages = apiMessages
                            let _ = apiTopics
                            chats = apiChats
                            users = apiUsers
                        case let .messages(apiMessages, apiChats, apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case let .messagesSlice(_, _, _, _, apiMessages, apiChats, apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case .messagesNotModified:
                            messages = []
                            chats = []
                            users = []
                    }
                    
                    let postboxSignal = postbox.transaction { transaction -> Message? in
                        var peers: [PeerId: Peer] = [:]
                        
                        for user in users {
                            if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                peers[user.id] = user
                            }
                        }
                        
                        for chat in chats {
                            if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                                peers[groupOrChannel.id] = groupOrChannel
                            }
                        }
                        
                        var renderedMessages: [Message] = []
                        for message in messages {
                            if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peer.isForumOrMonoForum), let renderedMessage = locallyRenderedMessage(message: message, peers: peers) {
                                renderedMessages.append(renderedMessage)
                            }
                        }
                        
                        return renderedMessages.first
                    }
                    
                    return postboxSignal
                }
            }
            |> `catch` { _ -> Signal<Message?, NoError> in
            }
        }
    }
}

func fetchRemoteMessage(accountPeerId: PeerId, postbox: Postbox, source: FetchMessageHistoryHoleSource, message: MessageReference) -> Signal<Message?, NoError> {
    guard case let .message(peer, _, id, _, _, _, threadId) = message.content else {
        return .single(nil)
    }
    let signal: Signal<Api.messages.Messages, MTRpcError>
    if id.namespace == Namespaces.Message.ScheduledCloud {
        signal = source.request(Api.functions.messages.getScheduledMessages(peer: peer.inputPeer, id: [id.id]))
    } else if id.namespace == Namespaces.Message.QuickReplyCloud {
        if let threadId {
            signal = source.request(Api.functions.messages.getQuickReplyMessages(flags: 1 << 0, shortcutId: Int32(clamping: threadId), id: [id.id], hash: 0))
        } else {
            signal = .never()
        }
    } else if id.peerId.namespace == Namespaces.Peer.CloudChannel {
        if let channel = peer.inputChannel {
            signal = source.request(Api.functions.channels.getMessages(channel: channel, id: [Api.InputMessage.inputMessageID(id: id.id)]))
        } else {
            signal = .fail(MTRpcError(errorCode: 400, errorDescription: "Peer Not Found"))
        }
    } else if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
        signal = source.request(Api.functions.messages.getMessages(id: [Api.InputMessage.inputMessageID(id: id.id)]))
    } else {
        signal = .fail(MTRpcError(errorCode: 400, errorDescription: "Invalid Peer"))
    }
    
    return signal
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Message?, NoError> in
        guard let result = result else {
            return .single(nil)
        }
        let messages: [Api.Message]
        let chats: [Api.Chat]
        let users: [Api.User]
        switch result {
            case let .channelMessages(_, _, _, _, apiMessages, apiTopics, apiChats, apiUsers):
                messages = apiMessages
                let _ = apiTopics
                chats = apiChats
                users = apiUsers
            case let .messages(apiMessages, apiChats, apiUsers):
                messages = apiMessages
                chats = apiChats
                users = apiUsers
            case let .messagesSlice(_, _, _, _, apiMessages, apiChats, apiUsers):
                messages = apiMessages
                chats = apiChats
                users = apiUsers
            case .messagesNotModified:
                messages = []
                chats = []
                users = []
        }
        
        return postbox.transaction { transaction -> Message? in
            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
            
            var renderedMessages: [Message] = []
            for message in messages {
                var peerIsForum = false
                if let peerId = message.peerId, let peer = transaction.getPeer(peerId) ?? parsedPeers.get(peerId), peer.isForumOrMonoForum {
                    peerIsForum = true
                }
                if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum, namespace: id.namespace), case let .Id(updatedId) = message.id {
                    var addedExisting = false
                    if transaction.getMessage(updatedId) != nil {
                        transaction.updateMessage(updatedId, update: { _ in
                            return .update(message)
                        })
                        if let updatedMessage = transaction.getMessage(updatedId) {
                            renderedMessages.append(updatedMessage)
                            addedExisting = true
                        }
                    }
                    
                    var peers: [PeerId: Peer] = [:]
                    for id in parsedPeers.allIds {
                        if let peer = transaction.getPeer(id) {
                            peers[peer.id] = peer
                        }
                    }
                    if !addedExisting, let renderedMessage = locallyRenderedMessage(message: message, peers: peers) {
                        renderedMessages.append(renderedMessage)
                    }
                }
            }
            
            return renderedMessages.first
        }
    }
    |> `catch` { _ -> Signal<Message?, NoError> in
    }
}

func _internal_searchMessageIdByTimestamp(account: Account, peerId: PeerId, threadId: Int64?, timestamp: Int32) -> Signal<MessageId?, NoError> {
    return account.postbox.transaction { transaction -> Signal<MessageId?, NoError> in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            return .single(transaction.findClosestMessageIdByTimestamp(peerId: peerId, timestamp: timestamp))
        } else if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            if let threadId = threadId {
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    let primaryIndex = account.network.request(Api.functions.messages.getReplies(peer: inputPeer, msgId: Int32(clamping: threadId), offsetId: 0, offsetDate: timestamp, addOffset: -1, limit: 1, maxId: 0, minId: 0, hash: 0))
                    |> map { result -> MessageIndex? in
                        let messages: [Api.Message]
                        switch result {
                        case let .messages(apiMessages, _, _):
                            messages = apiMessages
                        case let .channelMessages(_, _, _, _, apiMessages, _, _, _):
                            messages = apiMessages
                        case let .messagesSlice(_, _, _, _, apiMessages, _, _):
                            messages = apiMessages
                        case .messagesNotModified:
                            messages = []
                        }
                        for message in messages {
                            if let message = StoreMessage(apiMessage: message, accountPeerId: account.peerId, peerIsForum: peer.isForumOrMonoForum) {
                                return message.index
                            }
                        }
                        return nil
                    }
                    |> `catch` { _ -> Signal<MessageIndex?, NoError> in
                        return .single(nil)
                    }
                    return primaryIndex
                    |> map { primaryIndex -> MessageId? in
                        return primaryIndex?.id
                    }
                } else if peerId == account.peerId {
                    guard let subPeer = transaction.getPeer(PeerId(threadId)), let inputSubPeer = apiInputPeer(subPeer) else {
                        return .single(nil)
                    }
                    var getSavedHistoryFlags: Int32 = 0
                    var parentPeer: Api.InputPeer?
                    if peer.id != account.peerId {
                        getSavedHistoryFlags |= 1 << 0
                        parentPeer = inputPeer
                    }
                    let primaryIndex = account.network.request(Api.functions.messages.getSavedHistory(flags: getSavedHistoryFlags, parentPeer: parentPeer, peer: inputSubPeer, offsetId: 0, offsetDate: timestamp, addOffset: -1, limit: 1, maxId: 0, minId: 0, hash: 0))
                    |> map { result -> MessageIndex? in
                        let messages: [Api.Message]
                        switch result {
                        case let .messages(apiMessages, _, _):
                            messages = apiMessages
                        case let .channelMessages(_, _, _, _, apiMessages, _, _, _):
                            messages = apiMessages
                        case let .messagesSlice(_, _, _, _, apiMessages, _, _):
                            messages = apiMessages
                        case .messagesNotModified:
                            messages = []
                        }
                        for message in messages {
                            if let message = StoreMessage(apiMessage: message, accountPeerId: account.peerId, peerIsForum: peer.isForumOrMonoForum) {
                                return message.index
                            }
                        }
                        return nil
                    }
                    |> `catch` { _ -> Signal<MessageIndex?, NoError> in
                        return .single(nil)
                    }
                    return primaryIndex
                    |> map { primaryIndex -> MessageId? in
                        return primaryIndex?.id
                    }
                } else {
                    return .single(nil)
                }
            } else {
                var secondaryIndex: Signal<MessageIndex?, NoError> = .single(nil)
                if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData, let migrationReference = cachedData.migrationReference, let secondaryPeer = transaction.getPeer(migrationReference.maxMessageId.peerId), let inputSecondaryPeer = apiInputPeer(secondaryPeer) {
                    secondaryIndex = account.network.request(Api.functions.messages.getHistory(peer: inputSecondaryPeer, offsetId: 0, offsetDate: timestamp, addOffset: -1, limit: 1, maxId: 0, minId: 0, hash: 0))
                    |> map { result -> MessageIndex? in
                        let messages: [Api.Message]
                        switch result {
                            case let .messages(apiMessages, _, _):
                                messages = apiMessages
                            case let .channelMessages(_, _, _, _, apiMessages, _, _, _):
                                messages = apiMessages
                            case let .messagesSlice(_, _, _, _, apiMessages, _, _):
                                messages = apiMessages
                            case .messagesNotModified:
                                messages = []
                        }
                        for message in messages {
                            if let message = StoreMessage(apiMessage: message, accountPeerId: account.peerId, peerIsForum: secondaryPeer.isForumOrMonoForum) {
                                return message.index
                            }
                        }
                        return nil
                    }
                    |> `catch` { _ -> Signal<MessageIndex?, NoError> in
                        return .single(nil)
                    }
                }
                let primaryIndex = account.network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: 0, offsetDate: timestamp, addOffset: -1, limit: 1, maxId: 0, minId: 0, hash: 0))
                |> map { result -> MessageIndex? in
                    let messages: [Api.Message]
                    switch result {
                        case let .messages(apiMessages, _, _):
                            messages = apiMessages
                        case let .channelMessages(_, _, _, _, apiMessages, _, _, _):
                            messages = apiMessages
                        case let .messagesSlice(_, _, _, _, apiMessages, _, _):
                            messages = apiMessages
                        case .messagesNotModified:
                            messages = []
                    }
                    for message in messages {
                        if let message = StoreMessage(apiMessage: message, accountPeerId: account.peerId, peerIsForum: peer.isForumOrMonoForum) {
                            return message.index
                        }
                    }
                    return nil
                }
                |> `catch` { _ -> Signal<MessageIndex?, NoError> in
                    return .single(nil)
                }
                return combineLatest(primaryIndex, secondaryIndex)
                |> map { primaryIndex, secondaryIndex -> MessageId? in
                    if let primaryIndex = primaryIndex, let secondaryIndex = secondaryIndex {
                        if abs(primaryIndex.timestamp - timestamp) < abs(secondaryIndex.timestamp - timestamp) {
                            return primaryIndex.id
                        } else {
                            return secondaryIndex.id
                        }
                    } else if let primaryIndex = primaryIndex {
                        return primaryIndex.id
                    } else if let secondaryIndex = secondaryIndex {
                        return secondaryIndex.id
                    } else {
                        return nil
                    }
                }
            }
        } else {
            return .single(nil)
        }
    } |> switchToLatest
}

public enum UpdatedRemotePeerError {
    case generic
}

func _internal_updatedRemotePeer(accountPeerId: PeerId, postbox: Postbox, network: Network, peer: PeerReference) -> Signal<Peer, UpdatedRemotePeerError> {
    if let inputUser = peer.inputUser {
        return network.request(Api.functions.users.getUsers(id: [inputUser]))
        |> mapError { _ -> UpdatedRemotePeerError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Peer, UpdatedRemotePeerError> in
            guard let apiUser = result.first else {
                return .fail(.generic)
            }
            return postbox.transaction { transaction -> Peer? in
                let parsedPeers = AccumulatedPeers(users: [apiUser])
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                
                let peer = transaction.getPeer(apiUser.peerId)
                return peer
            }
            |> castError(UpdatedRemotePeerError.self)
            |> mapToSignal { peer -> Signal<Peer, UpdatedRemotePeerError> in
                if let peer = peer {
                    return .single(peer)
                } else {
                    return .fail(.generic)
                }
            }
        }
    } else if case let .group(id) = peer {
        return network.request(Api.functions.messages.getChats(id: [id]))
        |> mapError { _ -> UpdatedRemotePeerError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Peer, UpdatedRemotePeerError> in
            return postbox.transaction { transaction -> Signal<Peer, UpdatedRemotePeerError> in
                let chats: [Api.Chat]
                switch result {
                case let .chats(c):
                    chats = c
                case let .chatsSlice(_, c):
                    chats = c
                }
                
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
                
                if let firstId = chats.first?.peerId, let updatedPeer = parsedPeers.get(firstId), updatedPeer.id == peer.id {
                    return postbox.transaction { transaction -> Peer in
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        return updatedPeer
                    }
                    |> mapError { _ -> UpdatedRemotePeerError in
                    }
                } else {
                    return .fail(.generic)
                }
            }
            |> castError(UpdatedRemotePeerError.self)
            |> switchToLatest
        }
    } else if let inputChannel = peer.inputChannel {
        return network.request(Api.functions.channels.getChannels(id: [inputChannel]))
        |> mapError { _ -> UpdatedRemotePeerError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Peer, UpdatedRemotePeerError> in
            return postbox.transaction { transaction -> Signal<Peer, UpdatedRemotePeerError> in
                let chats: [Api.Chat]
                switch result {
                case let .chats(c):
                    chats = c
                case let .chatsSlice(_, c):
                    chats = c
                }
                
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
                
                if let firstId = chats.first?.peerId, let updatedPeer = parsedPeers.get(firstId), updatedPeer.id == peer.id {
                    return postbox.transaction { transaction -> Peer in
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        return updatedPeer
                    }
                    |> mapError { _ -> UpdatedRemotePeerError in
                    }
                } else {
                    return .fail(.generic)
                }
            }
            |> castError(UpdatedRemotePeerError.self)
            |> switchToLatest
        }
    } else {
        return .fail(.generic)
    }
}
