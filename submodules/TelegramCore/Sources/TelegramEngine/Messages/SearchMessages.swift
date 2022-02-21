import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum SearchMessagesLocation: Equatable {
    case general(tags: MessageTags?, minDate: Int32?, maxDate: Int32?)
    case group(groupId: PeerGroupId, tags: MessageTags?, minDate: Int32?, maxDate: Int32?)
    case peer(peerId: PeerId, fromId: PeerId?, tags: MessageTags?, topMsgId: MessageId?, minDate: Int32?, maxDate: Int32?)
    case publicForwards(messageId: MessageId, datacenterId: Int?)
    case sentMedia(tags: MessageTags?)
}

private struct SearchMessagesPeerState: Equatable {
    let messages: [Message]
    let readStates: [PeerId: CombinedPeerReadState]
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

public struct SearchMessagesResult {
    public let messages: [Message]
    public let readStates: [PeerId: CombinedPeerReadState]
    public let totalCount: Int32
    public let completed: Bool
    
    public init(messages: [Message], readStates: [PeerId: CombinedPeerReadState], totalCount: Int32, completed: Bool) {
        self.messages = messages
        self.readStates = readStates
        self.totalCount = totalCount
        self.completed = completed
    }
}

public struct SearchMessagesState: Equatable {
    fileprivate let main: SearchMessagesPeerState
    fileprivate let additional: SearchMessagesPeerState?
}

private func mergedState(transaction: Transaction, state: SearchMessagesPeerState?, result: Api.messages.Messages?) -> SearchMessagesPeerState? {
    guard let result = result else {
        return state
    }
    let messages: [Api.Message]
    let chats: [Api.Chat]
    let users: [Api.User]
    let totalCount: Int32
    let nextRate: Int32?
    switch result {
        case let .channelMessages(_, _, count, _, apiMessages, apiChats, apiUsers):
            messages = apiMessages
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
    
    var renderedMessages: [Message] = []
    for message in messages {
        if let message = StoreMessage(apiMessage: message), let renderedMessage = locallyRenderedMessage(message: message, peers: peers) {
            renderedMessages.append(renderedMessage)
            peerIdsSet.insert(message.id.peerId)
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
        return SearchMessagesPeerState(messages: mergedMessages, readStates: readStates, totalCount: completed ? Int32(mergedMessages.count) : totalCount, completed: completed, nextRate: nextRate)
    } else {
        return SearchMessagesPeerState(messages: renderedMessages, readStates: readStates, totalCount: completed ? Int32(renderedMessages.count) : totalCount, completed: completed, nextRate: nextRate)
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
    
    return SearchMessagesResult(messages: messages, readStates: readStates, totalCount: state.main.totalCount + (state.additional?.totalCount ?? 0), completed: state.main.completed && (state.additional?.completed ?? true))
}

func _internal_searchMessages(account: Account, location: SearchMessagesLocation, query: String, state: SearchMessagesState?, limit: Int32 = 100) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
    let remoteSearchResult: Signal<(Api.messages.Messages?, Api.messages.Messages?), NoError>
    switch location {
        case let .peer(peerId, fromId, tags, topMsgId, minDate, maxDate):
            if peerId.namespace == Namespaces.Peer.SecretChat {
                return account.postbox.transaction { transaction -> (SearchMessagesResult, SearchMessagesState) in
                    var readStates: [PeerId: CombinedPeerReadState] = [:]
                    if let readState = transaction.getCombinedPeerReadState(peerId) {
                        readStates[peerId] = readState
                    }
                    let result = transaction.searchMessages(peerId: peerId, query: query, tags: tags)
                    return (SearchMessagesResult(messages: result, readStates: readStates, totalCount: Int32(result.count), completed: true), SearchMessagesState(main: SearchMessagesPeerState(messages: [], readStates: [:], totalCount: 0, completed: true, nextRate: nil), additional: nil))
                }
            }
            
            let filter: Api.MessagesFilter = tags.flatMap { messageFilterForTagMask($0) } ?? .inputMessagesFilterEmpty
            remoteSearchResult = account.postbox.transaction { transaction -> (peer: Peer, additionalPeer: Peer?, from: Peer?)? in
                guard let peer = transaction.getPeer(peerId) else {
                    return nil
                }
                var additionalPeer: Peer?
                if let _ = peer as? TelegramChannel, let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData, let migrationReference = cachedData.migrationReference {
                    additionalPeer = transaction.getPeer(migrationReference.maxMessageId.peerId)
                }
                if let fromId = fromId {
                    return (peer: peer, additionalPeer: additionalPeer, from: transaction.getPeer(fromId))
                }
                return (peer: peer, additionalPeer: additionalPeer, from: nil)
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
                if let _ = topMsgId {
                    flags |= (1 << 1)
                }
                let peerMessages: Signal<Api.messages.Messages?, NoError>
                if let completed = state?.main.completed, completed {
                    peerMessages = .single(nil)
                } else {
                    let lowerBound = state?.main.messages.last.flatMap({ $0.index })
                    let signal: Signal<Api.messages.Messages, MTRpcError>
                    if peer.id.namespace == Namespaces.Peer.CloudChannel && query.isEmpty && fromId == nil && tags == nil && minDate == nil && maxDate == nil {
                        signal = account.network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: lowerBound?.id.id ?? 0, offsetDate: 0, addOffset: 0, limit: limit, maxId: Int32.max - 1, minId: 0, hash: 0))
                    } else {
                        signal = account.network.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: query, fromId: fromInputPeer, topMsgId: topMsgId?.id, filter: filter, minDate: minDate ?? 0, maxDate: maxDate ?? (Int32.max - 1), offsetId: lowerBound?.id.id ?? 0, addOffset: 0, limit: limit, maxId: Int32.max - 1, minId: 0, hash: 0))
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
                        additionalPeerMessages = account.network.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: query, fromId: fromInputPeer, topMsgId: topMsgId?.id, filter: filter, minDate: minDate ?? 0, maxDate: maxDate ?? (Int32.max - 1), offsetId: lowerBound?.id.id ?? 0, addOffset: 0, limit: limit, maxId: Int32.max - 1, minId: 0, hash: 0))
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
        case let .general(tags, minDate, maxDate), let .group(_, tags, minDate, maxDate):
            var flags: Int32 = 0
            let folderId: Int32?
            if case let .group(groupId, _, _, _) = location {
                folderId = groupId.rawValue
                flags |= (1 << 0)
            } else {
                folderId = nil
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
        case let .publicForwards(messageId, datacenterId):
            remoteSearchResult = account.postbox.transaction { transaction -> (Api.InputChannel?, Int32, MessageIndex?, Api.InputPeer) in
                let sourcePeer = transaction.getPeer(messageId.peerId)
                let inputChannel = sourcePeer.flatMap { apiInputChannel($0) }
                
                var lowerBound: MessageIndex?
                if let state = state, let message = state.main.messages.last {
                    lowerBound = message.index
                }
                if let lowerBound = lowerBound, let peer = transaction.getPeer(lowerBound.id.peerId), let inputPeer = apiInputPeer(peer) {
                    return (inputChannel, state?.main.nextRate ?? 0, lowerBound, inputPeer)
                } else {
                    return (inputChannel, 0, lowerBound, .inputPeerEmpty)
                }
            }
            |> mapToSignal { (inputChannel, nextRate, lowerBound, inputPeer) in
                guard let inputChannel = inputChannel else {
                    return .complete()
                }
                
                let request = Api.functions.stats.getMessagePublicForwards(channel: inputChannel, msgId: messageId.id, offsetRate: nextRate, offsetPeer: inputPeer, offsetId: lowerBound?.id.id ?? 0, limit: limit)
                let signal: Signal<Api.messages.Messages, MTRpcError>
                if let datacenterId = datacenterId, account.network.datacenterId != datacenterId {
                    signal = account.network.download(datacenterId: datacenterId, isMedia: false, tag: nil)
                    |> castError(MTRpcError.self)
                    |> mapToSignal { worker in
                        return worker.request(request)
                    }
                } else {
                    signal = account.network.request(request, automaticFloodWait: false)
                }
                return signal
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
            var additional: SearchMessagesPeerState? = mergedState(transaction: transaction, state: state?.additional, result: additionalResult)
            
            if state?.additional == nil {
                switch location {
                    case let .general(tags, minDate, maxDate), let .group(_, tags, minDate, maxDate):
                        let secretMessages = transaction.searchMessages(peerId: nil, query: query, tags: tags)
                        var filteredMessages: [Message] = []
                        var readStates: [PeerId: CombinedPeerReadState] = [:]
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
                            }
                        }
                        additional = SearchMessagesPeerState(messages: filteredMessages, readStates: readStates, totalCount: Int32(filteredMessages.count), completed: true, nextRate: nil)
                    default:
                        break
                }
            }
            
            let updatedState = SearchMessagesState(main: mergedState(transaction: transaction, state: state?.main, result: result) ?? SearchMessagesPeerState(messages: [], readStates: [:], totalCount: 0, completed: true, nextRate: nil), additional: additional)
            return (mergedResult(updatedState), updatedState)
        }
    }
}

func _internal_downloadMessage(postbox: Postbox, network: Network, messageId: MessageId) -> Signal<Message?, NoError> {
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
                        case let .channelMessages(_, _, _, _, apiMessages, apiChats, apiUsers):
                            messages = apiMessages
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
                            if let message = StoreMessage(apiMessage: message), let renderedMessage = locallyRenderedMessage(message: message, peers: peers) {
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

func fetchRemoteMessage(postbox: Postbox, source: FetchMessageHistoryHoleSource, message: MessageReference) -> Signal<Message?, NoError> {
    guard case let .message(peer, id, _, _, _) = message.content else {
        return .single(nil)
    }
    let signal: Signal<Api.messages.Messages, MTRpcError>
    if id.namespace == Namespaces.Message.ScheduledCloud {
        signal = source.request(Api.functions.messages.getScheduledMessages(peer: peer.inputPeer, id: [id.id]))
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
            case let .channelMessages(_, _, _, _, apiMessages, apiChats, apiUsers):
                messages = apiMessages
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
            
            updatePeers(transaction: transaction, peers: Array(peers.values), update: { _, updated in
                return updated
            })
            
            var renderedMessages: [Message] = []
            for message in messages {
                if let message = StoreMessage(apiMessage: message, namespace: id.namespace), case let .Id(updatedId) = message.id {
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
                let primaryIndex = account.network.request(Api.functions.messages.getReplies(peer: inputPeer, msgId: makeThreadIdMessageId(peerId: peerId, threadId: threadId).id, offsetId: 0, offsetDate: timestamp, addOffset: -1, limit: 1, maxId: 0, minId: 0, hash: 0))
                |> map { result -> MessageIndex? in
                    let messages: [Api.Message]
                    switch result {
                        case let .messages(apiMessages, _, _):
                            messages = apiMessages
                        case let .channelMessages(_, _, _, _, apiMessages, _, _):
                            messages = apiMessages
                        case let .messagesSlice(_, _, _, _, apiMessages, _, _):
                            messages = apiMessages
                        case .messagesNotModified:
                            messages = []
                    }
                    for message in messages {
                        if let message = StoreMessage(apiMessage: message) {
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
                var secondaryIndex: Signal<MessageIndex?, NoError> = .single(nil)
                if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData, let migrationReference = cachedData.migrationReference, let secondaryPeer = transaction.getPeer(migrationReference.maxMessageId.peerId), let inputSecondaryPeer = apiInputPeer(secondaryPeer) {
                    secondaryIndex = account.network.request(Api.functions.messages.getHistory(peer: inputSecondaryPeer, offsetId: 0, offsetDate: timestamp, addOffset: -1, limit: 1, maxId: 0, minId: 0, hash: 0))
                    |> map { result -> MessageIndex? in
                        let messages: [Api.Message]
                        switch result {
                            case let .messages(apiMessages, _, _):
                                messages = apiMessages
                            case let .channelMessages(_, _, _, _, apiMessages, _, _):
                                messages = apiMessages
                            case let .messagesSlice(_, _, _, _, apiMessages, _, _):
                                messages = apiMessages
                            case .messagesNotModified:
                                messages = []
                        }
                        for message in messages {
                            if let message = StoreMessage(apiMessage: message) {
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
                        case let .channelMessages(_, _, _, _, apiMessages, _, _):
                            messages = apiMessages
                        case let .messagesSlice(_, _, _, _, apiMessages, _, _):
                            messages = apiMessages
                        case .messagesNotModified:
                            messages = []
                    }
                    for message in messages {
                        if let message = StoreMessage(apiMessage: message) {
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

func _internal_updatedRemotePeer(postbox: Postbox, network: Network, peer: PeerReference) -> Signal<Peer, UpdatedRemotePeerError> {
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
                guard let peer = TelegramUser.merge(transaction.getPeer(apiUser.peerId) as? TelegramUser, rhs: apiUser) else {
                    return nil
                }
                updatePeers(transaction: transaction, peers: [peer], update: { _, updated in
                    return updated
                })
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
            let chats: [Api.Chat]
            switch result {
                case let .chats(c):
                    chats = c
                case let .chatsSlice(_, c):
                    chats = c
            }
            if let updatedPeer = chats.first.flatMap(parseTelegramGroupOrChannel), updatedPeer.id == peer.id {
                return postbox.transaction { transaction -> Peer in
                    updatePeers(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                        return updated
                    })
                    return updatedPeer
                }
                |> mapError { _ -> UpdatedRemotePeerError in
                }
            } else {
                return .fail(.generic)
            }
        }
    } else if let inputChannel = peer.inputChannel {
        return network.request(Api.functions.channels.getChannels(id: [inputChannel]))
        |> mapError { _ -> UpdatedRemotePeerError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Peer, UpdatedRemotePeerError> in
            let chats: [Api.Chat]
            switch result {
                case let .chats(c):
                    chats = c
                case let .chatsSlice(_, c):
                    chats = c
            }
            if let updatedPeer = chats.first.flatMap(parseTelegramGroupOrChannel), updatedPeer.id == peer.id {
                return postbox.transaction { transaction -> Peer in
                    updatePeers(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                        return updated
                    })
                    return updatedPeer
                }
                |> mapError { _ -> UpdatedRemotePeerError in
                }
            } else {
                return .fail(.generic)
            }
        }
    } else {
        return .fail(.generic)
    }
}
