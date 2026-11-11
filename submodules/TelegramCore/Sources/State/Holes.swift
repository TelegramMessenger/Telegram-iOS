import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

struct AccumulatedPeers {
    var peers: [PeerId: Peer] = [:]
    var users: [PeerId: Api.User] = [:]
    var chats: [PeerId: Api.Chat] = [:]
    
    var allIds: Set<PeerId> {
        var result = Set<PeerId>()
        for (id, _) in self.peers {
            result.insert(id)
        }
        for (id, _) in self.users {
            result.insert(id)
        }
        return result
    }
    
    init() {
    }
    
    init(transaction: Transaction, chats: [Api.Chat], users: [Api.User]) {
        for chat in chats {
            if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                self.peers[groupOrChannel.id] = groupOrChannel
            }
        }
        for user in users {
            self.users[user.peerId] = user
        }
        for chat in chats {
            self.chats[chat.peerId] = chat
        }
    }
    
    init(chats: [Api.Chat], users: [Api.User]) {
        for chat in chats {
            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                self.peers[groupOrChannel.id] = groupOrChannel
            }
        }
        for user in users {
            self.users[user.peerId] = user
        }
        for chat in chats {
            self.chats[chat.peerId] = chat
        }
    }
    
    init(users: [Api.User]) {
        for user in users {
            self.users[user.peerId] = user
        }
    }
    
    init(peers: [Peer]) {
        for peer in peers {
            self.peers[peer.id] = peer
        }
    }
    
    func union(with other: AccumulatedPeers) -> AccumulatedPeers {
        var result = self
        
        for (id, peer) in other.peers {
            result.peers[id] = peer
        }
        for (id, user) in other.users {
            result.users[id] = user
        }
        for (id, chat) in other.chats {
            result.chats[id] = chat
        }
        
        return result
    }
    
    func get(_ id: PeerId) -> Peer? {
        if let peer = self.peers[id] {
            return peer
        } else if let user = self.users[id] {
            return TelegramUser(user: user)
        } else {
            return nil
        }
    }
}

func messageFilterForTagMask(_ tagMask: MessageTags) -> Api.MessagesFilter? {
    if tagMask == .photoOrVideo {
        return .inputMessagesFilterPhotoVideo
    } else if tagMask == .photo {
        return .inputMessagesFilterPhotos
    } else if tagMask == .video {
        return .inputMessagesFilterVideo
    } else if tagMask == .file {
        return .inputMessagesFilterDocument
    } else if tagMask == .music {
        return .inputMessagesFilterMusic
    } else if tagMask == .webPage {
        return .inputMessagesFilterUrl
    } else if tagMask == .voiceOrInstantVideo {
        return .inputMessagesFilterRoundVoice
    } else if tagMask == .gif {
        return .inputMessagesFilterGif
    } else if tagMask == .pinned {
        return .inputMessagesFilterPinned
    } else if tagMask == .voice {
        return .inputMessagesFilterVoice
    } else if tagMask == .roundVideo {
        return .inputMessagesFilterRoundVideo
    } else if tagMask == .polls {
        return .inputMessagesFilterPoll
    } else {
        return nil
    }
}

enum FetchMessageHistoryHoleSource {
    case network(Network)
    case download(Download)
    
    func request<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), automaticFloodWait: Bool = true) -> Signal<T, MTRpcError> {
        switch self {
        case let .network(network):
            return network.request(data, automaticFloodWait: automaticFloodWait)
        case let .download(download):
            return download.request(data, automaticFloodWait: automaticFloodWait)
        }
    }
}

func resolveUnknownEmojiFiles<T>(postbox: Postbox, source: FetchMessageHistoryHoleSource, messages: [StoreMessage], reactions: [MessageReaction.Reaction], result: T) -> Signal<T, NoError> {
    var fileIds = Set<Int64>()
    
    for message in messages {
        extractEmojiFileIds(message: message, fileIds: &fileIds)
    }
    
    for reaction in reactions {
        if case let .custom(fileId) = reaction {
            fileIds.insert(fileId)
        }
    }
    
    if fileIds.isEmpty {
        return .single(result)
    } else {
        return postbox.transaction { transaction -> Set<Int64> in
            return transaction.filterStoredMediaIds(namespace: Namespaces.Media.CloudFile, ids: fileIds)
        }
        |> mapToSignal { unknownIds -> Signal<T, NoError> in
            if unknownIds.isEmpty {
                return .single(result)
            } else {
                var signals: [Signal<[Api.Document]?, NoError>] = []
                var remainingIds = Array(unknownIds)
                while !remainingIds.isEmpty {
                    let partIdCount = min(100, remainingIds.count)
                    let partIds = remainingIds.prefix(partIdCount)
                    remainingIds.removeFirst(partIdCount)
                    signals.append(source.request(Api.functions.messages.getCustomEmojiDocuments(documentId: Array(partIds)))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<[Api.Document]?, NoError> in
                        return .single(nil)
                    })
                }
                
                return combineLatest(signals)
                |> mapToSignal { documentSets -> Signal<T, NoError> in
                    return postbox.transaction { transaction -> T in
                        for documentSet in documentSets {
                            if let documentSet = documentSet {
                                for document in documentSet {
                                    if let file = telegramMediaFileFromApiDocument(document, altDocuments: []) {
                                        transaction.storeMediaIfNotPresent(media: file)
                                    }
                                }
                            }
                        }
                        
                        return result
                    }
                }
            }
        }
    }
}

func withResolvedAssociatedMessages<T>(postbox: Postbox, source: FetchMessageHistoryHoleSource, accountPeerId: PeerId, parsedPeers: AccumulatedPeers, storeMessages: [StoreMessage], resolveThreads: Bool, _ f: @escaping (Transaction, AccumulatedPeers, [StoreMessage]) -> T) -> Signal<T, NoError> {
    return postbox.transaction { transaction -> Signal<T, NoError> in
        var storedIds = Set<MessageId>()
        var referencedReplyIds = ReferencedReplyMessageIds()
        var referencedGeneralIds = Set<MessageId>()
        var threadIds = Set<PeerAndBoundThreadId>()
        for message in storeMessages {
            guard case let .Id(id) = message.id else {
                continue
            }
            storedIds.insert(id)
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyMessageAttribute {
                    if id.namespace != Namespaces.Message.EphemeralLocal && attribute.messageId.namespace != Namespaces.Message.EphemeralLocal {
                        referencedReplyIds.add(sourceId: id, targetId: attribute.messageId)
                    }
                } else {
                    referencedGeneralIds.formUnion(attribute.associatedMessageIds)
                }
            }
            if let threadId = message.threadId {
                threadIds.insert(PeerAndBoundThreadId(peerId: id.peerId, threadId: threadId))
            }
        }
        
        let allPossiblyStoredReferencedIds = referencedGeneralIds.union(referencedReplyIds.targetIdsBySourceId.keys)
        
        let allStoredReferencedIds = transaction.filterStoredMessageIds(allPossiblyStoredReferencedIds).union(storedIds)
        
        referencedReplyIds = referencedReplyIds.subtractingStoredIds(allStoredReferencedIds)
        referencedGeneralIds.subtract(allStoredReferencedIds)
        
        if referencedReplyIds.isEmpty && referencedGeneralIds.isEmpty {
            return resolveUnknownEmojiFiles(postbox: postbox, source: source, messages: storeMessages, reactions: [], result: Void())
            |> mapToSignal { _ -> Signal<T, NoError> in
                return resolveAssociatedStories(postbox: postbox, source: source, accountPeerId: accountPeerId, messages: storeMessages, additionalPeers: parsedPeers, result: Void())
                |> mapToSignal { _ -> Signal<T, NoError> in
                    if resolveThreads && !threadIds.isEmpty {
                        return resolveForumThreads(accountPeerId: accountPeerId, postbox: postbox, source: source, additionalPeers: parsedPeers, ids: Array(threadIds))
                        |> mapToSignal { _ -> Signal<T, NoError> in
                            return postbox.transaction { transaction -> T in
                                return f(transaction, parsedPeers, [])
                            }
                        }
                    } else {
                        return postbox.transaction { transaction -> T in
                            return f(transaction, parsedPeers, [])
                        }
                    }
                }
            }
        } else {
            var signals: [Signal<(Peer, [Api.Message], [Api.Chat], [Api.User]), NoError>] = []
            for (peerId, messageIds) in messagesIdsGroupedByPeerId(referencedReplyIds) {
                if let peer = transaction.getPeer(peerId) ?? parsedPeers.get(peerId) {
                    var signal: Signal<Api.messages.Messages, MTRpcError>?
                    if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                        signal = source.request(Api.functions.messages.getMessages(id: messageIds.targetIdsBySourceId.values.map({ Api.InputMessage.inputMessageReplyTo(.init(id: $0.id)) })))
                    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let inputChannel = apiInputChannel(peer) {
                            signal = source.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.targetIdsBySourceId.values.map({ Api.InputMessage.inputMessageReplyTo(.init(id: $0.id)) })))
                        }
                    }
                    if let signal = signal {
                        signals.append(signal
                        |> map { result in
                            switch result {
                                case let .messages(messagesData):
                                    let (messages, _, chats, users) = (messagesData.messages, messagesData.topics, messagesData.chats, messagesData.users)
                                    return (peer, messages, chats, users)
                                case let .messagesSlice(messagesSliceData):
                                    let (messages, chats, users) = (messagesSliceData.messages, messagesSliceData.chats, messagesSliceData.users)
                                    return (peer, messages, chats, users)
                                case let .channelMessages(channelMessagesData):
                                    let (messages, apiTopics, chats, users) = (channelMessagesData.messages, channelMessagesData.topics, channelMessagesData.chats, channelMessagesData.users)
                                    let _ = apiTopics
                                    return (peer, messages, chats, users)
                                case .messagesNotModified:
                                    return (peer, [], [], [])
                            }
                        }
                        |> `catch` { _ in
                            return Signal<(Peer, [Api.Message], [Api.Chat], [Api.User]), NoError>.single((peer, [], [], []))
                        })
                    }
                }
            }
            for (peerId, messageIds) in messagesIdsGroupedByPeerId(referencedGeneralIds) {
                if let peer = transaction.getPeer(peerId) ?? parsedPeers.get(peerId) {
                    var signal: Signal<Api.messages.Messages, MTRpcError>?
                    if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                        signal = source.request(Api.functions.messages.getMessages(id: messageIds.map({ Api.InputMessage.inputMessageID(.init(id: $0.id)) })))
                    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let inputChannel = apiInputChannel(peer) {
                            signal = source.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.map({ Api.InputMessage.inputMessageID(.init(id: $0.id)) })))
                        }
                    }
                    if let signal = signal {
                        signals.append(signal
                        |> map { result in
                            switch result {
                                case let .messages(messagesData):
                                    let (messages, _, chats, users) = (messagesData.messages, messagesData.topics, messagesData.chats, messagesData.users)
                                    return (peer, messages, chats, users)
                                case let .messagesSlice(messagesSliceData):
                                    let (messages, chats, users) = (messagesSliceData.messages, messagesSliceData.chats, messagesSliceData.users)
                                    return (peer, messages, chats, users)
                                case let .channelMessages(channelMessagesData):
                                    let (messages, apiTopics, chats, users) = (channelMessagesData.messages, channelMessagesData.topics, channelMessagesData.chats, channelMessagesData.users)
                                    let _ = apiTopics
                                    return (peer, messages, chats, users)
                                case .messagesNotModified:
                                    return (peer, [], [], [])
                            }
                        }
                        |> `catch` { _ in
                            return Signal<(Peer, [Api.Message], [Api.Chat], [Api.User]), NoError>.single((peer, [], [], []))
                        })
                    }
                }
            }
            
            let fetchMessages = combineLatest(signals)
            
            return fetchMessages
            |> mapToSignal { results -> Signal<T, NoError> in
                return postbox.transaction { transaction -> Signal<T, NoError> in
                    var additionalPeers = AccumulatedPeers()
                    
                    var additionalMessages: [StoreMessage] = []
                    for (peer, messages, chats, users) in results {
                        if !messages.isEmpty {
                            for message in messages {
                                if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peer.isForumOrMonoForum) {
                                    additionalMessages.append(message)
                                }
                            }
                        }
                        additionalPeers = additionalPeers.union(with: AccumulatedPeers(transaction: transaction, chats: chats, users: users))
                    }
                    
                    let combinedMessages = storeMessages + additionalMessages
                    return resolveUnknownEmojiFiles(postbox: postbox, source: source, messages: combinedMessages, reactions: [], result: Void())
                    |> mapToSignal { _ -> Signal<T, NoError> in
                        let additionalPeers = parsedPeers.union(with: additionalPeers)
                        return resolveAssociatedStories(postbox: postbox, source: source, accountPeerId: accountPeerId, messages: storeMessages + additionalMessages, additionalPeers: additionalPeers, result: Void())
                        |> mapToSignal { _ -> Signal<T, NoError> in
                            var threadIds = Set<PeerAndBoundThreadId>()
                            for message in combinedMessages {
                                if case let .Id(id) = message.id, let threadId = message.threadId {
                                    threadIds.insert(PeerAndBoundThreadId(peerId: id.peerId, threadId: threadId))
                                }
                            }
                            
                            if resolveThreads && !threadIds.isEmpty {
                                return resolveForumThreads(accountPeerId: accountPeerId, postbox: postbox, source: source, additionalPeers: additionalPeers, ids: Array(threadIds))
                                |> mapToSignal { _ -> Signal<T, NoError> in
                                    return postbox.transaction { transaction -> T in
                                        // The reply targets fetched above are stored with the rest: dropping them
                                        // here left a forum message's reply header waiting for good.
                                        return f(transaction, additionalPeers, additionalMessages)
                                    }
                                }
                            } else {
                                return postbox.transaction { transaction -> T in
                                    return f(transaction, additionalPeers, additionalMessages)
                                }
                            }
                        }
                    }
                }
                |> switchToLatest
            }
        }
    }
    |> switchToLatest
}

enum FetchMessageHistoryHoleThreadInput: CustomStringConvertible {
    case direct(peerId: PeerId, threadId: Int64?)
    case threadFromChannel(channelMessageId: MessageId)
    
    var description: String {
        switch self {
        case let .direct(peerId, threadId):
            return "direct(\(peerId), \(String(describing: threadId))"
        case let .threadFromChannel(channelMessageId):
            return "threadFromChannel(peerId: \(channelMessageId.peerId), postId: \(channelMessageId.id)"
        }
    }
    
    func requestThreadId(accountPeerId: PeerId, peer: Peer) -> Int64? {
        switch self {
        case let .direct(peerId, threadId):
            if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                return nil
            }
            if let threadId = threadId, peerId != accountPeerId {
                return threadId
            } else {
                return nil
            }
        case let .threadFromChannel(channelMessageId):
            return Int64(channelMessageId.id)
        }
    }
    
    func requestSubPeerId(accountPeerId: PeerId, peer: Peer) -> PeerId? {
        switch self {
        case let .direct(peerId, threadId):
            if let threadId, peerId == accountPeerId {
                return PeerId(threadId)
            } else if let threadId, let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                return PeerId(threadId)
            } else {
                return nil
            }
        case .threadFromChannel:
            return nil
        }
    }
}

struct FetchMessageHistoryHoleResult: Equatable {
    var removedIndices: IndexSet
    var strictRemovedIndices: IndexSet
    var actualPeerId: PeerId?
    var actualThreadId: Int64?
    var ids: [MessageId]
}

/// `pendingReferences`: where a fill that stores before resolving registers the reply targets and stories it is
/// fetching, so the views it feeds draw them as skeletons. Fills nobody is looking at pass nil.
func fetchMessageHistoryHole(accountPeerId: PeerId, source: FetchMessageHistoryHoleSource, postbox: Postbox, peerInput: FetchMessageHistoryHoleThreadInput, namespace: MessageId.Namespace, direction: MessageHistoryViewRelativeHoleDirection, space: MessageHistoryHoleOperationSpace, count rawCount: Int, pendingReferences: PendingMessageReferences? = nil) -> Signal<FetchMessageHistoryHoleResult?, NoError> {
    let count = min(100, rawCount)
    
    return postbox.stateView()
    |> mapToSignal { view -> Signal<AuthorizedAccountState, NoError> in
        if let state = view.state as? AuthorizedAccountState {
            return .single(state)
        } else {
            return .complete()
        }
    }
    |> take(1)
    |> mapToSignal { _ -> Signal<FetchMessageHistoryHoleResult?, NoError> in
        return postbox.transaction { transaction -> (Peer?, Int64, Peer?) in
            switch peerInput {
            case let .direct(peerId, _):
                let peer = transaction.getPeer(peerId)
                var subPeerId: PeerId?
                if let peer {
                    subPeerId = peerInput.requestSubPeerId(accountPeerId: accountPeerId, peer: peer)
                }
                return (peer, 0, subPeerId.flatMap(transaction.getPeer))
            case let .threadFromChannel(channelMessageId):
                return (transaction.getPeer(channelMessageId.peerId), 0, nil)
            }
        }
        |> mapToSignal { (peer, hash, subPeer) -> Signal<FetchMessageHistoryHoleResult?, NoError> in
            guard let peer = peer else {
                return .single(FetchMessageHistoryHoleResult(removedIndices: IndexSet(), strictRemovedIndices: IndexSet(), actualPeerId: nil, actualThreadId: nil, ids: []))
            }
            guard let inputPeer = forceApiInputPeer(peer) else {
                return .single(FetchMessageHistoryHoleResult(removedIndices: IndexSet(), strictRemovedIndices: IndexSet(), actualPeerId: nil, actualThreadId: nil, ids: []))
            }
            
            print("fetchMessageHistoryHole for \(peerInput) direction \(direction) space \(space)")
            Logger.shared.log("fetchMessageHistoryHole", "fetch for \(peerInput) direction \(direction) space \(space)")
            let request: Signal<Api.messages.Messages, MTRpcError>
            var implicitelyFillHole = false
            let minMaxRange: ClosedRange<MessageId.Id>
            
            switch space {
            case .everywhere:
                if let requestThreadId = peerInput.requestThreadId(accountPeerId: accountPeerId, peer: peer) {
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = count
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                    case let .range(start, end):
                        if start.id <= end.id {
                            offsetId = start.id <= 1 ? 1 : (start.id - 1)
                            addOffset = Int32(-selectedLimit)
                            maxId = end.id
                            minId = start.id - 1
                            
                            let rangeStartId = start.id
                            let rangeEndId = min(end.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        } else {
                            offsetId = start.id == Int32.max ? start.id : (start.id + 1)
                            addOffset = 0
                            maxId = start.id == Int32.max ? start.id : (start.id + 1)
                            minId = end.id
                            
                            let rangeStartId = end.id
                            let rangeEndId = min(start.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        }
                    case let .aroundId(id):
                        offsetId = id.id
                        addOffset = Int32(-selectedLimit / 2)
                        maxId = Int32.max
                        minId = 1
                        
                        minMaxRange = 1 ... (Int32.max - 1)
                    }
                    
                    request = source.request(Api.functions.messages.getReplies(peer: inputPeer, msgId: Int32(clamping: requestThreadId), offsetId: offsetId, offsetDate: 0, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId, hash: hash))
                } else if let subPeerId = peerInput.requestSubPeerId(accountPeerId: accountPeerId, peer: peer) {
                    guard let subPeer, subPeer.id == subPeerId, let inputSubPeer = apiInputPeer(subPeer) else {
                        Logger.shared.log("fetchMessageHistoryHole", "subPeer not available")
                        return .never()
                    }
                    
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = count
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                    case let .range(start, end):
                        if start.id <= end.id {
                            offsetId = start.id <= 1 ? 1 : (start.id - 1)
                            addOffset = Int32(-selectedLimit)
                            maxId = end.id
                            minId = start.id - 1
                            
                            let rangeStartId = start.id
                            let rangeEndId = min(end.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        } else {
                            offsetId = start.id == Int32.max ? start.id : (start.id + 1)
                            addOffset = 0
                            maxId = start.id == Int32.max ? start.id : (start.id + 1)
                            minId = end.id
                            
                            let rangeStartId = end.id
                            let rangeEndId = min(start.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        }
                    case let .aroundId(id):
                        offsetId = id.id
                        addOffset = Int32(-selectedLimit / 2)
                        maxId = Int32.max
                        minId = 1
                        
                        minMaxRange = 1 ... (Int32.max - 1)
                    }
                    
                    var getSavedHistoryFlags: Int32 = 0
                    var parentPeer: Api.InputPeer?
                    if peer.id != accountPeerId {
                        getSavedHistoryFlags |= 1 << 0
                        parentPeer = inputPeer
                    }
                    
                    request = source.request(Api.functions.messages.getSavedHistory(flags: getSavedHistoryFlags, parentPeer: parentPeer, peer: inputSubPeer, offsetId: offsetId, offsetDate: 0, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId, hash: hash))
                } else {
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = count
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                    case let .range(start, end):
                        if start.id <= end.id {
                            offsetId = start.id <= 1 ? 1 : (start.id - 1)
                            addOffset = Int32(-selectedLimit)
                            // max_id is exclusive and the range closed below includes its end: a hole of one id
                            // (`1 ... 1` under a top message of 2, which the account reset leaves) asked with max_id
                            // 1 got nothing and was closed without its message.
                            maxId = end.id == Int32.max ? end.id : (end.id + 1)
                            minId = start.id - 1
                            
                            let rangeStartId = start.id
                            let rangeEndId = min(end.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        } else {
                            offsetId = start.id == Int32.max ? start.id : (start.id + 1)
                            addOffset = 0
                            maxId = start.id == Int32.max ? start.id : (start.id + 1)
                            // min_id is exclusive, so a downward range's own end is not asked for, though an empty
                            // answer closes it with the rest (`minMaxRange`). No caller loses a message to that: views
                            // ask down to 1, which min_id 0 includes (`MessageHistoryViewState`), and SparseMessageList
                            // passes the id below the range it wants as `end`. The upward arm adds one to its end
                            // instead (above); changing this one means changing SparseMessageList with it.
                            minId = end.id == 1 ? 0 : end.id
                            
                            let rangeStartId = end.id
                            let rangeEndId = min(start.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        }
                    case let .aroundId(id):
                        offsetId = id.id
                        addOffset = Int32(-selectedLimit / 2)
                        maxId = Int32.max
                        // min_id is exclusive and the fill closes over its anchor: min_id 1 left message 1 out of a
                        // fill anchored at it, which was then never loaded. 0 is no bound.
                        minId = 0
                        minMaxRange = 1 ... Int32.max - 1
                    }

                    request = source.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: offsetId, offsetDate: 0, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId, hash: 0))
                }
            case let .tag(tag):
                assert(tag.containsSingleElement)
                if tag == .unseenPersonalMessage {
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = count
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                    case let .range(start, end):
                        if start.id <= end.id {
                            offsetId = start.id <= 1 ? 1 : (start.id - 1)
                            addOffset = Int32(-selectedLimit)
                            maxId = end.id
                            minId = start.id - 1
                            
                            let rangeStartId = start.id
                            let rangeEndId = min(end.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        } else {
                            offsetId = start.id == Int32.max ? start.id : (start.id + 1)
                            addOffset = 0
                            maxId = start.id == Int32.max ? start.id : (start.id + 1)
                            minId = end.id
                            
                            let rangeStartId = end.id
                            let rangeEndId = min(start.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        }
                    case let .aroundId(id):
                        offsetId = id.id
                        addOffset = Int32(-selectedLimit / 2)
                        maxId = Int32.max
                        minId = 1
                        
                        minMaxRange = 1 ... Int32.max - 1
                    }
                    
                    var flags: Int32 = 0
                    var topMsgId: Int32?
                    if let threadId = peerInput.requestThreadId(accountPeerId: accountPeerId, peer: peer) {
                        flags |= (1 << 1)
                        topMsgId = Int32(clamping: threadId)
                    }
                    
                    request = source.request(Api.functions.messages.getUnreadMentions(flags: flags, peer: inputPeer, topMsgId: topMsgId, offsetId: offsetId, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId))
                } else if tag == .unseenReaction {
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = count
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                    case let .range(start, end):
                        if start.id <= end.id {
                            offsetId = start.id <= 1 ? 1 : (start.id - 1)
                            addOffset = Int32(-selectedLimit)
                            maxId = end.id
                            minId = start.id - 1
                            
                            let rangeStartId = start.id
                            let rangeEndId = min(end.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        } else {
                            offsetId = start.id == Int32.max ? start.id : (start.id + 1)
                            addOffset = 0
                            maxId = start.id == Int32.max ? start.id : (start.id + 1)
                            minId = end.id
                            
                            let rangeStartId = end.id
                            let rangeEndId = min(start.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        }
                    case let .aroundId(id):
                        offsetId = id.id
                        addOffset = Int32(-selectedLimit / 2)
                        maxId = Int32.max
                        minId = 1
                        
                        minMaxRange = 1 ... Int32.max - 1
                    }
                    
                    var flags: Int32 = 0
                    var topMsgId: Int32?
                    if let threadId = peerInput.requestThreadId(accountPeerId: accountPeerId, peer: peer) {
                        flags |= (1 << 0)
                        topMsgId = Int32(clamping: threadId)
                    }
                    var savedPeerId: Api.InputPeer?
                    if let subPeerId = peerInput.requestSubPeerId(accountPeerId: accountPeerId, peer: peer), let subPeer = subPeer, subPeer.id == subPeerId {
                        flags |= (1 << 1)
                        if let inputPeer = apiInputPeer(subPeer) {
                            flags |= 1 << 2
                            savedPeerId = inputPeer
                        }
                    }
                    
                    request = source.request(Api.functions.messages.getUnreadReactions(flags: flags, peer: inputPeer, topMsgId: topMsgId, savedPeerId: savedPeerId, offsetId: offsetId, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId))
                } else if tag == .unseenPollVote {
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = count
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                    case let .range(start, end):
                        if start.id <= end.id {
                            offsetId = start.id <= 1 ? 1 : (start.id - 1)
                            addOffset = Int32(-selectedLimit)
                            maxId = end.id
                            minId = start.id - 1
                            
                            let rangeStartId = start.id
                            let rangeEndId = min(end.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        } else {
                            offsetId = start.id == Int32.max ? start.id : (start.id + 1)
                            addOffset = 0
                            maxId = start.id == Int32.max ? start.id : (start.id + 1)
                            minId = end.id
                            
                            let rangeStartId = end.id
                            let rangeEndId = min(start.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        }
                    case let .aroundId(id):
                        offsetId = id.id
                        addOffset = Int32(-selectedLimit / 2)
                        maxId = Int32.max
                        minId = 1
                        
                        minMaxRange = 1 ... Int32.max - 1
                    }
                    
                    var flags: Int32 = 0
                    var topMsgId: Int32?
                    if let threadId = peerInput.requestThreadId(accountPeerId: accountPeerId, peer: peer) {
                        flags |= (1 << 0)
                        topMsgId = Int32(clamping: threadId)
                    }
                    var savedPeerId: Api.InputPeer?
                    if let subPeerId = peerInput.requestSubPeerId(accountPeerId: accountPeerId, peer: peer), let subPeer = subPeer, subPeer.id == subPeerId {
                        flags |= (1 << 1)
                        if let inputPeer = apiInputPeer(subPeer) {
                            flags |= 1 << 2
                            savedPeerId = inputPeer
                        }
                    }
                    let _ = savedPeerId
                    
                    request = source.request(Api.functions.messages.getUnreadPollVotes(flags: flags, peer: inputPeer, topMsgId: topMsgId, offsetId: offsetId, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId))
                } else if tag == .liveLocation {
                    let selectedLimit = count
                    
                    switch direction {
                    case .aroundId, .range:
                        implicitelyFillHole = true
                    }
                    minMaxRange = 1 ... (Int32.max - 1)
                    request = source.request(Api.functions.messages.getRecentLocations(peer: inputPeer, limit: Int32(selectedLimit), hash: 0))
                } else if let filter = messageFilterForTagMask(tag) {
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = count
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                    case let .range(start, end):
                        if start.id <= end.id {
                            offsetId = start.id <= 1 ? 1 : (start.id - 1)
                            addOffset = Int32(-selectedLimit)
                            maxId = end.id
                            minId = start.id - 1
                            
                            let rangeStartId = start.id
                            let rangeEndId = min(end.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        } else {
                            offsetId = start.id == Int32.max ? start.id : (start.id + 1)
                            addOffset = 0
                            maxId = start.id == Int32.max ? start.id : (start.id + 1)
                            minId = end.id
                            
                            let rangeStartId = end.id
                            let rangeEndId = min(start.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        }
                    case let .aroundId(id):
                        offsetId = id.id
                        addOffset = Int32(-selectedLimit / 2)
                        maxId = Int32.max
                        minId = 1
                        
                        minMaxRange = 1 ... (Int32.max - 1)
                    }
                    
                    var flags: Int32 = 0
                    var topMsgId: Int32?
                    if let threadId = peerInput.requestThreadId(accountPeerId: accountPeerId, peer: peer) {
                        flags |= (1 << 1)
                        topMsgId = Int32(clamping: threadId)
                    }
                    
                    var savedPeerId: Api.InputPeer?
                    if let subPeerId = peerInput.requestSubPeerId(accountPeerId: accountPeerId, peer: peer), let subPeer = subPeer, subPeer.id == subPeerId {
                        if let inputPeer = apiInputPeer(subPeer) {
                            flags |= 1 << 2
                            savedPeerId = inputPeer
                        }
                    }
                    
                    request = source.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: "", fromId: nil, savedPeerId: savedPeerId, savedReaction: nil, topMsgId: topMsgId, filter: filter, minDate: 0, maxDate: 0, offsetId: offsetId, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId, hash: 0))
                } else {
                    assertionFailure()
                    minMaxRange = 1 ... 1
                    request = .never()
                }
            case let .customTag(customTag, regularTag):
                if let reaction = ReactionsMessageAttribute.reactionFromMessageTag(tag: customTag) {
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = count
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                    case let .range(start, end):
                        if start.id <= end.id {
                            offsetId = start.id <= 1 ? 1 : (start.id - 1)
                            addOffset = Int32(-selectedLimit)
                            maxId = end.id
                            minId = start.id - 1
                            
                            let rangeStartId = start.id
                            let rangeEndId = min(end.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        } else {
                            offsetId = start.id == Int32.max ? start.id : (start.id + 1)
                            addOffset = 0
                            maxId = start.id == Int32.max ? start.id : (start.id + 1)
                            minId = end.id
                            
                            let rangeStartId = end.id
                            let rangeEndId = min(start.id, Int32.max - 1)
                            if rangeStartId <= rangeEndId {
                                minMaxRange = rangeStartId ... rangeEndId
                            } else {
                                minMaxRange = rangeStartId ... rangeStartId
                                assertionFailure()
                            }
                        }
                    case let .aroundId(id):
                        offsetId = id.id
                        addOffset = Int32(-selectedLimit / 2)
                        maxId = Int32.max
                        minId = 1
                        
                        minMaxRange = 1 ... (Int32.max - 1)
                    }
                    
                    var flags: Int32 = 0
                    var topMsgId: Int32?
                    if let threadId = peerInput.requestThreadId(accountPeerId: accountPeerId, peer: peer) {
                        flags |= (1 << 1)
                        topMsgId = Int32(clamping: threadId)
                    }
                    
                    var savedPeerId: Api.InputPeer?
                    if let subPeerId = peerInput.requestSubPeerId(accountPeerId: accountPeerId, peer: peer), let subPeer = subPeer, subPeer.id == subPeerId {
                        if let inputPeer = apiInputPeer(subPeer) {
                            flags |= 1 << 2
                            savedPeerId = inputPeer
                        }
                    }
                    
                    var mappedFilter: Api.MessagesFilter = .inputMessagesFilterEmpty
                    if let regularTag {
                        if let filter = messageFilterForTagMask(regularTag) {
                            mappedFilter = filter
                        } else {
                            Logger.shared.log("fetchMessageHistoryHole", "fetch for \(peerInput) direction \(direction) space \(space): unknown filter for tag \(regularTag.rawValue)")
                            assertionFailure()
                            return .never()
                        }
                    }
                    
                    flags |= 1 << 3
                    
                    request = source.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: "", fromId: nil, savedPeerId: savedPeerId, savedReaction: [reaction.apiReaction], topMsgId: topMsgId, filter: mappedFilter, minDate: 0, maxDate: 0, offsetId: offsetId, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId, hash: 0))
                } else {
                    assertionFailure()
                    minMaxRange = 1 ... 1
                    return .never()
                }
            }
            
            // When the attempt that was answered went out, on the record's clock: an edit the replay received since
            // then can postdate the answer, which then stores the edit in place of its message
            // (`fetchedMessagesWithRecentEdits`). Every retry sends the request again, and resets it.
            let requestSentAt = Atomic<Double>(value: FetchedAnswerAge.now())
            let timedRequest: Signal<Api.messages.Messages, MTRpcError> = deferred {
                let _ = requestSentAt.swap(FetchedAnswerAge.now())
                return request
            }
            // A transient error (a 5xx, a flood wait the engine handed back) is retried until the request
            // succeeds, with a growing delay, and never given up; a definite answer (a 4xx, CHANNEL_PRIVATE)
            // closes nothing and is logged (HistoryFillRequestRetry.swift, owner decision D4, audit Q15).
            return historyFillRequestRetryingTransientErrors(timedRequest, describe: {
                return "fetch for \(peerInput) direction \(direction) space \(space)"
            })
            |> mapToSignal { result -> Signal<FetchMessageHistoryHoleResult?, NoError> in
                guard let result = result else {
                    return .single(nil)
                }
                // When the answer arrived, on the record's clock: an answer that has grown older than the record
                // of recent deletions keeps one by the time it would be stored is not stored (FetchedAnswerAge).
                let answeredAt = FetchedAnswerAge.now()
                let sentAt = requestSentAt.with { $0 }
                return postbox.transaction { transaction -> Signal<FetchMessageHistoryHoleResult?, NoError> in
                    let messages: [Api.Message]
                    let chats: [Api.Chat]
                    let users: [Api.User]
                    var channelPts: Int32?
                    var serverCount: Int32?
                    var serverOffsetIdOffset: Int32?
                    var serverInexact = false
                    var responseTopics: [Api.ForumTopic] = []
                    switch result {
                        case let .messages(messagesData):
                            let (apiMessages, apiTopics, apiChats, apiUsers) = (messagesData.messages, messagesData.topics, messagesData.chats, messagesData.users)
                            messages = apiMessages
                            responseTopics = apiTopics
                            chats = apiChats
                            users = apiUsers
                            serverCount = Int32(clamping: apiMessages.count)
                        case let .messagesSlice(messagesSliceData):
                            let (apiMessages, apiChats, apiUsers) = (messagesSliceData.messages, messagesSliceData.chats, messagesSliceData.users)
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                            serverCount = messagesSliceData.count
                            serverOffsetIdOffset = messagesSliceData.offsetIdOffset
                            serverInexact = (messagesSliceData.flags & (1 << 1)) != 0
                        case let .channelMessages(channelMessagesData):
                            let (pts, apiMessages, apiTopics, apiChats, apiUsers) = (channelMessagesData.pts, channelMessagesData.messages, channelMessagesData.topics, channelMessagesData.chats, channelMessagesData.users)
                            messages = apiMessages
                            responseTopics = apiTopics
                            chats = apiChats
                            users = apiUsers
                            channelPts = pts
                            serverCount = channelMessagesData.count
                            serverOffsetIdOffset = channelMessagesData.offsetIdOffset
                            serverInexact = (channelMessagesData.flags & (1 << 1)) != 0
                        case .messagesNotModified:
                            messages = []
                            chats = []
                            users = []
                    }
                    
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)

                    var storeMessages: [StoreMessage] = []

                    if peerInput.requestThreadId(accountPeerId: accountPeerId, peer: peer) != nil {
                        let messageIds = messages.compactMap { $0.id()?.id }
                        Logger.shared.log("ReplyThreadOpen", "thread fill answered input=\(peerInput) ids=\(messageIds.count) min=\(String(describing: messageIds.min())) max=\(String(describing: messageIds.max())) pts=\(String(describing: channelPts)) count=\(String(describing: serverCount)) offsetIdOffset=\(String(describing: serverOffsetIdOffset))")
                    }

                    for message in messages {
                        if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peer.isForumOrMonoForum, namespace: namespace) {
                            if let channelPts = channelPts {
                                var attributes = storeMessage.attributes
                                attributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
                                storeMessages.append(storeMessage.withUpdatedAttributes(attributes))
                            } else {
                                storeMessages.append(storeMessage)
                            }
                        }
                    }
                    
                    // What the answer fills is decided from the answer alone (none of this reads the
                    // transaction), so the stored messages it covers can be read before anything is written.
                    var filledRange: ClosedRange<MessageId.Id>
                    var strictFilledIndices: IndexSet
                    let ids = storeMessages.compactMap { message -> MessageId.Id? in
                        switch message.id {
                        case let .Id(id):
                            switch space {
                            case let .tag(tag):
                                if !message.tags.contains(tag) {
                                    return nil
                                } else {
                                    return id.id
                                }
                            case let .customTag(customTag, regularTag):
                                if let regularTag {
                                    if !message.tags.contains(regularTag) {
                                        return nil
                                    }
                                }
                                if !postbox.seedConfiguration.customTagsFromAttributes(message.attributes).contains(customTag) {
                                    return nil
                                }
                                return id.id
                            case .everywhere:
                                return id.id
                            }
                        case .Partial:
                            return nil
                        }
                    }
                    let fullIds = storeMessages.compactMap { message -> MessageId? in
                        switch message.id {
                        case let .Id(id):
                            switch space {
                            case let .tag(tag):
                                if !message.tags.contains(tag) {
                                    return nil
                                } else {
                                    return id
                                }
                            case let .customTag(customTag, regularTag):
                                if let regularTag {
                                    if !message.tags.contains(regularTag) {
                                        return nil
                                    }
                                }
                                if !postbox.seedConfiguration.customTagsFromAttributes(message.attributes).contains(customTag) {
                                    return nil
                                }
                                return id
                            case .everywhere:
                                return id
                            }
                        case .Partial:
                            return nil
                        }
                    }
                    
                    if ids.count == 0 || implicitelyFillHole {
                        filledRange = minMaxRange
                        strictFilledIndices = IndexSet()
                    } else {
                        let messageRange = ids.min()! ... ids.max()!
                        switch direction {
                        case let .aroundId(aroundId):
                            // The server's position facts behind aroundHoleFillRange were measured for
                            // messages.getHistory on a channel (no thread, the everywhere space, the Cloud
                            // namespace); every other request shape keeps the fetched span until traced.
                            var inferredRange: ClosedRange<MessageId.Id>?
                            if case let .direct(_, directThreadId) = peerInput, directThreadId == nil, case .everywhere = space, namespace == Namespaces.Message.Cloud {
                                inferredRange = aroundHoleFillRange(anchorId: aroundId.id, ids: ids, totalCount: serverCount, offsetIdOffset: serverOffsetIdOffset, inexact: serverInexact)
                            }
                            filledRange = inferredRange ?? (min(aroundId.id, messageRange.lowerBound) ... max(aroundId.id, messageRange.upperBound))
                            strictFilledIndices = IndexSet(integersIn: Int(min(aroundId.id, messageRange.lowerBound)) ... Int(max(aroundId.id, messageRange.upperBound)))
                            var shouldFillAround = false
                            if peerInput.requestThreadId(accountPeerId: accountPeerId, peer: peer) != nil || peerInput.requestSubPeerId(accountPeerId: accountPeerId, peer: peer) != nil {
                                shouldFillAround = true
                            }
                            if case .customTag = space {
                                shouldFillAround = true
                            }
                            
                            if shouldFillAround {
                                if ids.count <= count / 2 - 1 {
                                    filledRange = minMaxRange
                                }
                            }
                        case let .range(start, end):
                            if start.id <= end.id {
                                let minBound = start.id
                                let maxBound = messageRange.upperBound
                                filledRange = min(minBound, maxBound) ... max(minBound, maxBound)
                                
                                var maxStrictIndex = max(minBound, maxBound)
                                maxStrictIndex = min(maxStrictIndex, messageRange.upperBound)
                                strictFilledIndices = IndexSet(integersIn: Int(min(minBound, maxBound)) ... Int(maxStrictIndex))
                            } else {
                                let minBound = messageRange.lowerBound
                                let maxBound = start.id
                                filledRange = min(minBound, maxBound) ... max(minBound, maxBound)
                                
                                var maxStrictIndex = max(minBound, maxBound)
                                maxStrictIndex = min(maxStrictIndex, messageRange.upperBound)
                                strictFilledIndices = IndexSet(integersIn: Int(min(minBound, maxBound)) ... Int(maxStrictIndex))
                            }
                        }
                    }
                    
                    // Stored messages of a private chat or a basic group that the answer leaves out of
                    // `filledRange` are confirmed before anything is written (HistoryFillReconciliation.swift).
                    // Nil for every other fill and for a fill that left nothing out: those proceed as before.
                    let reconciliation = historyFillReconciliation(transaction: transaction, peer: peer, peerInput: peerInput, namespace: namespace, space: space, direction: direction, filledRange: filledRange, storeMessages: storeMessages)
                    let closedRange = reconciliation?.plan.closedRange ?? filledRange
                    let closedStrictFilledIndices: IndexSet
                    if closedRange == filledRange {
                        closedStrictFilledIndices = strictFilledIndices
                    } else {
                        closedStrictFilledIndices = strictFilledIndices.intersection(IndexSet(integersIn: Int(closedRange.lowerBound) ... Int(closedRange.upperBound)))
                    }
                    
                    /// Stores the fetched messages, applies the confirmation of the stored messages the answer
                    /// left out, closes the hole and reports what was filled. `peers` is what `store` built
                    /// from the answer's and the confirmation's peers.
                    let storeAndCloseHole: (Transaction, StoredMessageConfirmation?, AccumulatedPeers) -> FetchMessageHistoryHoleResult? = { transaction, confirmation, peers in
                        // An answer older than the record of recent deletions keeps one (its confirmation, or a
                        // forum's thread resolution, retried for longer) may predate a deletion the record has
                        // already forgotten: the fill stores none of it, closes nothing and reports nothing, so its
                        // caller asks again (FetchedAnswerAge, HistoryFillReconciliation.swift). Its confirmation is
                        // applied all the same, as the account reset and the chat-list fill apply theirs: it touches
                        // only messages still at the version they were read at, so it is safe at any age, and the
                        // next attempt does not confirm again what it settled.
                        if FetchedAnswerAge.isTooOldToStore(answeredAt: answeredAt) {
                            var confirmationNote = ""
                            if let confirmation = confirmation, let reconciliation = reconciliation {
                                let deletedIds = applyStoredMessageConfirmation(transaction: transaction, accountPeerId: accountPeerId, mediaBox: postbox.mediaBox, confirmation: confirmation, versions: reconciliation.versions)
                                confirmationNote = ", applying only its confirmation (\(deletedIds.count) deleted)"
                            }
                            Logger.shared.log("fetchMessageHistoryHole", "fetch for \(peerInput) space \(space): the answer is \(Int(FetchedAnswerAge.now() - answeredAt)) s old, older than the record of recent deletions keeps one; storing none of it\(confirmationNote)")
                            return nil
                        }
                        // No fill stores an answer message deleted in the last few minutes: its request, and a
                        // confirmation, were in flight meanwhile, so the answer can predate the deletion (owner
                        // decision D2, HistoryFillReconciliation.swift), and none older than an edit the replay
                        // received since the request went out: that edit is stored in its place (owner decision
                        // 2026-10-25). A fill that waited for a confirmation also leaves alone what was written again
                        // meanwhile; every other fill stores the rest of its answer.
                        let answerNotDeleted = fetchedMessagesWithoutRecentDeletions(transaction: transaction, messages: storeMessages, logTag: "fetchMessageHistoryHole", logPrefix: "fetch for \(peerInput) space \(space)")
                        let answerCurrent = fetchedMessagesWithRecentEdits(transaction: transaction, messages: answerNotDeleted, since: sentAt, logTag: "fetchMessageHistoryHole", logPrefix: "fetch for \(peerInput) space \(space)")
                        let answerToStore: [StoreMessage]
                        if confirmation != nil, let reconciliation = reconciliation {
                            answerToStore = historyFillAnswerToStore(transaction: transaction, storeMessages: answerCurrent, answerVersions: reconciliation.answerVersions)
                        } else {
                            answerToStore = answerCurrent
                        }
                        let _ = transaction.addMessages(answerToStore, location: .Random)
                        
                        // A candidate the server answered as gone but written again while the confirmation was in
                        // flight is left stored: the newer write wins (`applyStoredMessageConfirmation`). It is not
                        // confirmed either, so the hole is opened again over it alone, and the next fill that reaches
                        // it asks again; closing over it would show a message the server says is gone for good.
                        var reopenedIds: [MessageId] = []
                        if let confirmation = confirmation, let reconciliation = reconciliation {
                            applyStoredMessageConfirmation(transaction: transaction, accountPeerId: accountPeerId, mediaBox: postbox.mediaBox, confirmation: confirmation, versions: reconciliation.versions)
                            reopenedIds = transaction.filterStoredMessageIds(confirmation.missing).filter { closedRange.contains($0.id) }.sorted()
                        }

                        switch peerInput {
                        case let .direct(peerId, threadId):
                            transaction.removeHole(peerId: peerId, threadId: threadId, namespace: namespace, space: space, range: closedRange)
                            // What a partial close leaves of the filled range holds candidates not yet confirmed.
                            // It is a hole afterwards, also where it was none: an earlier fill may have closed part
                            // of it over messages the server has since deleted (one held across a cleared history,
                            // truth seed 361), and only a fill that reaches them again confirms them.
                            if confirmation != nil {
                                if filledRange.lowerBound < closedRange.lowerBound {
                                    transaction.addHole(peerId: peerId, threadId: threadId, namespace: namespace, space: space, range: filledRange.lowerBound ... (closedRange.lowerBound - 1))
                                }
                                if closedRange.upperBound < filledRange.upperBound {
                                    transaction.addHole(peerId: peerId, threadId: threadId, namespace: namespace, space: space, range: (closedRange.upperBound + 1) ... filledRange.upperBound)
                                }
                            }
                            for id in reopenedIds {
                                transaction.addHole(peerId: peerId, threadId: threadId, namespace: namespace, space: space, range: id.id ... id.id)
                            }
                            if !reopenedIds.isEmpty {
                                Logger.shared.log("fetchMessageHistoryHole", "fetch for \(peerInput) space \(space): \(reopenedIds) answered as gone but written again meanwhile; left stored under a hole")
                            }
                        case .threadFromChannel:
                            break
                        }
                        
                        // A fill that reached the top of a channel's history knows that history is
                        // contiguous up to its newest id: the poll's next too-long answer seeds its gap
                        // hole from this value, and a stale one re-covered a range the fill had closed
                        // (measured 2026-10-13). Only an existing state is advanced; a state is never
                        // made up here, because its pts is the poll's to set.
                        if case let .direct(peerId, threadId) = peerInput, threadId == nil, case .everywhere = space, namespace == Namespaces.Message.Cloud, peerId.namespace == Namespaces.Peer.CloudChannel, filledRange.upperBound == Int32.max - 1, let maxId = ids.max() {
                            if let current = transaction.getPeerChatState(peerId) as? ChannelState, (current.synchronizedUntilMessageId ?? 0) < maxId {
                                transaction.setPeerChatState(peerId, state: current.withUpdatedSynchronizedUntilMessageId(maxId))
                            }
                        }
                        
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: peers)

                        var removedIndices = IndexSet(integersIn: Int(closedRange.lowerBound) ... Int(closedRange.upperBound))
                        var strictRemovedIndices = closedStrictFilledIndices
                        for id in reopenedIds {
                            removedIndices.remove(Int(id.id))
                            strictRemovedIndices.remove(Int(id.id))
                        }
                        return FetchMessageHistoryHoleResult(
                            removedIndices: removedIndices,
                            strictRemovedIndices: strictRemovedIndices,
                            actualPeerId: storeMessages.first?.id.peerId,
                            actualThreadId: storeMessages.first?.threadId,
                            ids: fullIds
                        )
                    }
                    
                    /// What the stored messages reference that is not stored: reply targets (other than a forum
                    /// message's own topic root, which never draws as a header) and stories, in their media or in a
                    /// reply header (`replyStoryIds`, which the associated-message resolution does not fetch), and
                    /// the messages referencing any of them (`sourceIds`), which draw them as loading and are redrawn
                    /// when the follow-up ends.
                    struct MissingReferences {
                        var sourceIds = Set<MessageId>()
                        var replyStoryIds = Set<StoryId>()
                        /// Rich messages with a custom emoji whose file is not stored. Their previews (chat list,
                        /// reply headers) read the files from the stored media (`RichTextMessageAttribute
                        /// .associatedMediaIds`) and draw such an emoji as its alt text, so they are redrawn too when
                        /// the follow-up, which fetches the files, ends. Nothing draws as loading for them.
                        var emojiSourceIds = Set<MessageId>()
                    }
                    let missingReferences: (Transaction) -> MissingReferences = { transaction in
                        var storedIds = Set<MessageId>()
                        for message in storeMessages {
                            if case let .Id(id) = message.id {
                                storedIds.insert(id)
                            }
                        }
                        var targetsBySource: [MessageId: [MessageId]] = [:]
                        var storiesBySource: [MessageId: [StoryId]] = [:]
                        var candidateTargets = Set<MessageId>()
                        var mediaStoryIds = Set<StoryId>()
                        var attributeStoryIds = Set<StoryId>()
                        var emojiFileIdsBySource: [MessageId: [Int64]] = [:]
                        for message in storeMessages {
                            guard case let .Id(id) = message.id else {
                                continue
                            }
                            for attribute in message.attributes {
                                if let attribute = attribute as? RichTextMessageAttribute {
                                    let fileIds = attribute.associatedMediaIds.map(\.id)
                                    if !fileIds.isEmpty {
                                        emojiFileIdsBySource[id, default: []].append(contentsOf: fileIds)
                                    }
                                }
                                let targets = pendingReplyTargets(replyTargets: attribute.associatedMessageIds, messageThreadId: message.threadId, peerIsForum: peer.isForumOrMonoForum).filter { !storedIds.contains($0) }
                                if !targets.isEmpty {
                                    targetsBySource[id, default: []].append(contentsOf: targets)
                                    candidateTargets.formUnion(targets)
                                }
                                if !attribute.associatedStoryIds.isEmpty {
                                    storiesBySource[id, default: []].append(contentsOf: attribute.associatedStoryIds)
                                    attributeStoryIds.formUnion(attribute.associatedStoryIds)
                                }
                            }
                            for media in message.media where !media.storyIds.isEmpty {
                                storiesBySource[id, default: []].append(contentsOf: media.storyIds)
                                mediaStoryIds.formUnion(media.storyIds)
                            }
                        }
                        let missingTargets = candidateTargets.subtracting(transaction.filterStoredMessageIds(candidateTargets))
                        var missingStories = Set<StoryId>()
                        for id in mediaStoryIds.union(attributeStoryIds) where transaction.getStory(id: id) == nil {
                            missingStories.insert(id)
                        }
                        
                        var result = MissingReferences()
                        result.replyStoryIds = missingStories.subtracting(mediaStoryIds)
                        for (id, targets) in targetsBySource where targets.contains(where: { missingTargets.contains($0) }) {
                            result.sourceIds.insert(id)
                        }
                        for (id, stories) in storiesBySource where stories.contains(where: { missingStories.contains($0) }) {
                            result.sourceIds.insert(id)
                        }
                        if !emojiFileIdsBySource.isEmpty {
                            let missingEmojiFileIds = transaction.filterStoredMediaIds(namespace: Namespaces.Media.CloudFile, ids: Set(emojiFileIdsBySource.values.joined()))
                            for (id, fileIds) in emojiFileIdsBySource where fileIds.contains(where: { missingEmojiFileIds.contains($0) }) {
                                result.emojiSourceIds.insert(id)
                            }
                        }
                        return result
                    }
                    
                    /// Stores what the follow-up fetched (reply targets and their peers). A reply target deleted
                    /// while the fill ran stays deleted (owner decision D2, HistoryFillReconciliation.swift); one
                    /// edited since `since`, when its requests went out, is stored as its edit.
                    let storeReferencedData: (Transaction, AccumulatedPeers, [StoreMessage], Double) -> Void = { transaction, additionalParsedPeers, fetchedAdditionalMessages, since in
                        let additionalMessages = fetchedMessagesWithRecentEdits(transaction: transaction, messages: fetchedMessagesWithoutRecentDeletions(transaction: transaction, messages: fetchedAdditionalMessages, logTag: "fetchMessageHistoryHole", logPrefix: "fetch for \(peerInput) space \(space), follow-up"), since: since, logTag: "fetchMessageHistoryHole", logPrefix: "fetch for \(peerInput) space \(space), follow-up")
                        let _ = transaction.addMessages(additionalMessages, location: .Random)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: additionalParsedPeers)
                    }
                    
                    /// Redraws the messages that referenced something missing, found or not: each is rewritten from
                    /// its current row, which loses nothing written since and always counts as an update (a view
                    /// watches its own chat only, and a skeleton drawn meanwhile must end).
                    let redrawMessages: (Transaction, Set<MessageId>) -> Void = { transaction, ids in
                        for id in ids {
                            transaction.updateMessage(id, update: { current in
                                return .update(storeMessageRewritingCurrent(current))
                            })
                        }
                    }
                    
                    // Topic headers read a message's thread info while drawing: a forum fill holding a message of a
                    // topic whose info is not stored resolves before it stores. The answer's own topics count; they
                    // are stored with the messages, since a topic's info does not survive a commit without one of
                    // its messages (MessageThreadIndexTable.replay). Only channels are forums or monoforums, and only
                    // private chats and basic groups confirm (`reconciliation`), so no fill does both.
                    var storesFirst = true
                    var answerTopics: [Int64: Api.ForumTopic] = [:]
                    if peer.isForumOrMonoForum {
                        for topic in responseTopics {
                            if case let .forumTopic(forumTopicData) = topic {
                                answerTopics[Int64(forumTopicData.id)] = topic
                            }
                        }
                        var fetchedThreadIds = Set<Int64>()
                        var storedThreadIds = Set<Int64>()
                        for message in storeMessages {
                            guard case let .Id(id) = message.id, let threadId = message.threadId else {
                                continue
                            }
                            fetchedThreadIds.insert(threadId)
                            if transaction.getMessageHistoryThreadInfo(peerId: id.peerId, threadId: threadId) != nil {
                                storedThreadIds.insert(threadId)
                            }
                        }
                        storesFirst = forumFillStoresFirst(fetchedThreadIds: fetchedThreadIds, storedThreadIds: storedThreadIds, answerThreadIds: Set(answerTopics.keys))
                        Logger.shared.log("ReplyThreadOpen", "forum fill responseTopics=\(answerTopics.count) threads=\(fetchedThreadIds.count) unknownThreads=\(fetchedThreadIds.subtracting(storedThreadIds).count) storesFirst=\(storesFirst)")
                    }

                    /// Stores what was fetched (applying `confirmation`, if any), then what it references.
                    let store: (StoredMessageConfirmation?) -> Signal<FetchMessageHistoryHoleResult?, NoError> = { confirmation in
                        // The confirmation answered after the fill's own request: where both carry a peer,
                        // its copy is the newer one and wins, except that a min copy never replaces a full
                        // copy (owner decision D3, AccumulatedPeersFullCopies.swift). Every write of the
                        // fill's peers uses this one set, the follow-up's later transactions included, so the
                        // older copy is never written over the newer one.
                        let peers = confirmation.map { parsedPeers.unionKeepingFullCopies(with: $0.peers) } ?? parsedPeers
                        if !storesFirst {
                            return withResolvedAssociatedMessages(postbox: postbox, source: source, accountPeerId: accountPeerId, parsedPeers: peers, storeMessages: storeMessages, resolveThreads: true, { transaction, additionalParsedPeers, additionalMessages -> FetchMessageHistoryHoleResult? in
                                // Nil when the answer was too old to store: what it references is not stored either.
                                guard let result = storeAndCloseHole(transaction, confirmation, peers) else {
                                    return nil
                                }
                                // Its requests went out after the fill's own, so `sentAt` is earlier than them, which
                                // is safe (`fetchedMessagesWithRecentEdits`).
                                storeReferencedData(transaction, additionalParsedPeers, additionalMessages, sentAt)
                                return result
                            })
                        }
                        /// The follow-up: fetches what the stored messages reference and stores it. Its answers are
                        /// stored only while none can be older than the record of recent deletions keeps one, timed
                        /// from its start (FetchedAnswerAge); otherwise it stores nothing and starts again, so it
                        /// neither gives up nor stores an answer that can predate a forgotten deletion.
                        func referencedDataFollowUp() -> Signal<Void, NoError> {
                            let followUpStartedAt = FetchedAnswerAge.now()
                            return withResolvedAssociatedMessages(postbox: postbox, source: source, accountPeerId: accountPeerId, parsedPeers: peers, storeMessages: storeMessages, resolveThreads: peer.isForumOrMonoForum, { transaction, additionalParsedPeers, additionalMessages -> Bool in
                                if FetchedAnswerAge.isTooOldToStore(answeredAt: followUpStartedAt) {
                                    return false
                                }
                                storeReferencedData(transaction, additionalParsedPeers, additionalMessages, followUpStartedAt)
                                return true
                            })
                            |> mapToSignal { stored -> Signal<Void, NoError> in
                                if stored {
                                    return .single(Void())
                                }
                                Logger.shared.log("fetchMessageHistoryHole", "fetch for \(peerInput) space \(space): the follow-up's answers are older than the record of recent deletions keeps one; storing none of them and fetching them again")
                                return referencedDataFollowUp()
                            }
                        }
                        // The view loads after one round trip; what the messages reference follows, registered
                        // meanwhile so the view draws it as loading.
                        return postbox.transaction { transaction -> FetchMessageHistoryHoleResult? in
                            // Nil when the answer was too old to store (only its confirmation was applied): none of
                            // it was stored to follow up on.
                            guard let result = storeAndCloseHole(transaction, confirmation, peers) else {
                                return nil
                            }
                            var storedAnswerTopics = 0
                            for (threadId, topic) in answerTopics where transaction.getMessageHistoryThreadInfo(peerId: peer.id, threadId: threadId) == nil {
                                storeFetchedForumTopic(transaction: transaction, peerId: peer.id, topic: topic)
                                storedAnswerTopics += 1
                            }
                            let missing = missingReferences(transaction)
                            let registration = pendingReferences?.register(sourceIds: missing.sourceIds)
                            if !missing.sourceIds.isEmpty || !missing.emojiSourceIds.isEmpty || storedAnswerTopics != 0 {
                                Logger.shared.log("ReplyThreadOpen", "fill stored answerTopics=\(storedAnswerTopics) waiting messages=\(missing.sourceIds.count) replyStories=\(missing.replyStoryIds.count) emojiWaiting=\(missing.emojiSourceIds.count) registered=\(registration != nil)")
                            }
                            // The rich messages waiting for emoji files are redrawn with the rest but not registered:
                            // they draw alt text meanwhile, not a skeleton.
                            let redrawnIds = missing.sourceIds.union(missing.emojiSourceIds)

                            // Started here, not after this transaction's result is delivered: a fill disposed in
                            // between (ReplyThreadHistory disposes one as soon as the thread's hole changes, which
                            // this transaction just did) must still fetch what its messages reference and release
                            // what it registered.
                            let replyStories: Signal<Void, NoError>
                            if missing.replyStoryIds.isEmpty {
                                replyStories = .single(Void())
                            } else {
                                replyStories = resolveStories(postbox: postbox, source: source, accountPeerId: accountPeerId, storyIds: missing.replyStoryIds, additionalPeers: peers, result: Void())
                            }
                            let _ = (combineLatest(replyStories, referencedDataFollowUp())
                            |> take(1)
                            |> mapToSignal { _ -> Signal<Void, NoError> in
                                return postbox.transaction { transaction -> Void in
                                    if let registration {
                                        pendingReferences?.release(registration)
                                    }
                                    redrawMessages(transaction, redrawnIds)
                                }
                            }).startStandalone()

                            return result
                        }
                    }
                    
                    guard let confirming = reconciliation else {
                        return store(nil)
                    }
                    Logger.shared.log("fetchMessageHistoryHole", "fetch for \(peerInput) space \(space): confirming \(confirming.plan.batch.count) stored message(s) left out, closing \(confirming.plan.closedRange) of \(filledRange)")
                    // Nothing is stored and no hole closes until the confirmation answers (it retries every
                    // error); a fill disposed meanwhile (its view went away) writes nothing. It goes through
                    // the fill's own source, so a preload fill (ChatHistoryPreloadManager, `.download`)
                    // confirms through its download session.
                    return confirmStoredMessages(accountPeerId: accountPeerId, postbox: postbox, source: source, ids: confirming.plan.batch, knownPeers: parsedPeers)
                    |> take(1)
                    |> mapToSignal { confirmation -> Signal<FetchMessageHistoryHoleResult?, NoError> in
                        return store(confirmation)
                    }
                }
                |> switchToLatest
            }
        }
    }
}

func groupBoundaryPeer(_ peerId: PeerId, accountPeerId: PeerId) -> Api.Peer {
    switch peerId.namespace {
        case Namespaces.Peer.CloudUser:
            return Api.Peer.peerUser(.init(userId: peerId.id._internalGetInt64Value()))
        case Namespaces.Peer.CloudGroup:
            return Api.Peer.peerChat(.init(chatId: peerId.id._internalGetInt64Value()))
        case Namespaces.Peer.CloudChannel:
            return Api.Peer.peerChannel(.init(channelId: peerId.id._internalGetInt64Value()))
        default:
            return Api.Peer.peerUser(.init(userId: accountPeerId.id._internalGetInt64Value()))
    }
}

/// Fills `hole` of `groupId`'s chat list from one fetched page. Answers older than the record of recent deletions
/// keeps one (`FetchedAnswerAge`) write nothing, and the fill starts again after `FetchedAnswerAge.staleRestartDelay`
/// for its place in the row (`staleRestarts`, which callers leave at 0). It never gives up.
///
/// Stored messages above a dialog's top message are left as they are (spec section 3 point 3, as amended
/// 2026-10-24): the fill moves no pts while updates keep being applied around it, so a message that arrived while
/// the page was in flight would never be delivered again if the fill deleted it. Only the account reset deletes a
/// ghost tail.
func fetchChatListHole(postbox: Postbox, network: Network, accountPeerId: PeerId, groupId: PeerGroupId, hole: ChatListHole, staleRestarts: Int = 0) -> Signal<Never, NoError> {
    let location: FetchChatListLocation
    switch groupId {
        case .root:
            location = .general
        case .group:
            location = .group(groupId)
    }
    return deferred { () -> Signal<(fetchedChats: FetchedChatList?, fetchStartedAt: Double), NoError> in
        let fetchStartedAt = FetchedAnswerAge.now()
        return fetchChatList(accountPeerId: accountPeerId, postbox: postbox, network: network, location: location, upperBound: hole.index, hash: 0, limit: 100)
        |> map { fetchedChats -> (fetchedChats: FetchedChatList?, fetchStartedAt: Double) in
            return (fetchedChats: fetchedChats, fetchStartedAt: fetchStartedAt)
        }
    }
    |> mapToSignal { answer -> Signal<Never, NoError> in
        // When the page's first request was sent (`FetchedAnswerAge.now()`): no answer the fill writes is older.
        let fetchStartedAt = answer.fetchStartedAt
        guard let fetchedChats = answer.fetchedChats else {
            return postbox.transaction { transaction -> Void in
                transaction.replaceChatListHole(groupId: groupId, index: hole.index, hole: nil)
            }
            |> ignoreValues
        }
        return withResolvedAssociatedMessages(postbox: postbox, source: .network(network), accountPeerId: accountPeerId, parsedPeers: fetchedChats.peers, storeMessages: fetchedChats.storeMessages, resolveThreads: false, { transaction, additionalPeers, additionalMessages -> Bool in
            // Answers older than the record of recent deletions keeps one may predate a deletion it has already
            // forgotten (FetchedAnswerAge): they write nothing, the hole stays, and the fill starts again below.
            if FetchedAnswerAge.isTooOldToStore(answeredAt: fetchStartedAt) {
                Logger.shared.log("State", "chat list hole fill: the answers are \(Int(FetchedAnswerAge.now() - fetchStartedAt)) s old, older than the record of recent deletions keeps one; writing nothing, fetching the page again")
                return false
            }
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: fetchedChats.peers.union(with: additionalPeers))
            _internal_applyFetchedChatInputStates(transaction: transaction, accountPeerId: accountPeerId, inputStates: fetchedChats.inputStates)

            for (threadMessageId, data) in fetchedChats.threadInfos {
                if let entry = StoredMessageHistoryThreadInfo(data.data) {
                    transaction.setMessageHistoryThreadInfo(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, info: entry)
                }
                transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadMentionCount, maxId: data.topMessageId)
                transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadReactionCount, maxId: data.topMessageId)
                transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, tagMask: .unseenPollVote, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadPollVoteCount, maxId: data.topMessageId)
            }
            
            transaction.updateCurrentPeerNotificationSettings(fetchedChats.notificationSettings)
            // A top message or reply target deleted while the answers were in flight is not stored again (owner
            // decision D2): its chat's holes stay as they are, from that top message up, so the chat's next history
            // fill asks the server what is there now, and its chat-list entry keeps the newest message still
            // stored, as after a deletion that lands once the top message is stored. One edited while the answers
            // were in flight is stored as its edit (owner decision 2026-10-25).
            let topMessages = fetchedMessagesWithRecentEdits(transaction: transaction, messages: fetchedMessagesWithoutRecentDeletions(transaction: transaction, messages: fetchedChats.storeMessages, logTag: "State", logPrefix: "chat list hole fill, top messages"), since: fetchStartedAt, logTag: "State", logPrefix: "chat list hole fill, top messages")
            let _ = transaction.addMessages(topMessages, location: .UpperHistoryBlock)
            let _ = transaction.addMessages(fetchedMessagesWithRecentEdits(transaction: transaction, messages: fetchedMessagesWithoutRecentDeletions(transaction: transaction, messages: additionalMessages, logTag: "State", logPrefix: "chat list hole fill, reply targets"), since: fetchStartedAt, logTag: "State", logPrefix: "chat list hole fill, reply targets"), location: .Random)
            // The stored messages above a private chat's or basic group's top stay (this fill moves no pts, so one may
            // have arrived while the page was in flight; owner, 2026-10-24), but under a hole, which the top's
            // `.UpperHistoryBlock` store just removed: the chat's next history fill asks the server about them and
            // deletes only those it no longer has (owner, 2026-10-25). After an account reset, a chat beyond its
            // first page is where a message deleted during the gap waits. A channel's revalidation covers its own.
            var lowestAboveTop: [PeerId: MessageId.Id] = [:]
            for id in storedCloudMessagesAboveTopMessages(transaction: transaction, fetchedChats: fetchedChats) where id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
                lowestAboveTop[id.peerId] = min(lowestAboveTop[id.peerId] ?? id.id, id.id)
            }
            for (peerId, lowestId) in lowestAboveTop where lowestId < Int32.max - 1 {
                transaction.addHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: lowestId ... (Int32.max - 1))
            }
            if !lowestAboveTop.isEmpty {
                Logger.shared.log("State", "chat list hole fill: stored messages above the top of \(lowestAboveTop.keys.sorted()) left under a hole for their next history fill")
            }
            transaction.resetIncomingReadStates(fetchedChats.readStates)
            
            for (peerId, autoremoveValue) in fetchedChats.ttlPeriods {
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    if peerId.namespace == Namespaces.Peer.CloudUser {
                        let current = (current as? CachedUserData) ?? CachedUserData()
                        return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                        let current = (current as? CachedChannelData) ?? CachedChannelData()
                        return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                    } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                        let current = (current as? CachedGroupData) ?? CachedGroupData()
                        return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                    } else {
                        return current
                    }
                })
            }
            for (peerId, value) in fetchedChats.viewForumAsMessages {
                if value {
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        if peerId.namespace == Namespaces.Peer.CloudChannel {
                            let current = (current as? CachedChannelData) ?? CachedChannelData()
                            return current.withUpdatedViewForumAsMessages(.known(value))
                        } else {
                            return current
                        }
                    })
                }
            }
            
            transaction.replaceChatListHole(groupId: groupId, index: hole.index, hole: fetchedChats.lowerNonPinnedIndex.flatMap(ChatListHole.init))
            
            for peerId in fetchedChats.chatPeerIds {
                if let peer = transaction.getPeer(peerId) {
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: transaction.getPeerChatListIndex(peerId)?.1.pinningIndex, minTimestamp: minTimestampForPeerInclusion(peer)))
                } else {
                    assertionFailure()
                }
            }
            
            for (peerId, peerGroupId) in fetchedChats.peerGroupIds {
                if let peer = transaction.getPeer(peerId) {
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: peerGroupId, pinningIndex: nil, minTimestamp: minTimestampForPeerInclusion(peer)))
                } else {
                    assertionFailure()
                }
            }
            
            for (peerId, pts) in fetchedChats.channelStates {
                if let current = transaction.getPeerChatState(peerId) as? ChannelState {
                    // A page that moves a channel's pts also raises its invalidatedPts, so the messages stored
                    // before it are revalidated (HistoryViewStateValidation), as after channelDifferenceTooLong.
                    // It never lowers it: an older page's lower pts would stop the revalidation of what the higher
                    // one marks. A channel whose pts did not move is left alone.
                    if current.pts != pts {
                        transaction.setPeerChatState(peerId, state: current.withUpdatedPts(pts).withUpdatedInvalidatedPts(max(current.invalidatedPts ?? pts, pts)))
                    }
                } else {
                    transaction.setPeerChatState(peerId, state: ChannelState(pts: pts, invalidatedPts: nil, synchronizedUntilMessageId: nil))
                }
            }
            
            if let replacePinnedItemIds = fetchedChats.pinnedItemIds {
                transaction.setPinnedItemIds(groupId: groupId, itemIds: replacePinnedItemIds.map(PinnedItemId.peer))
            }
            
            for (peerId, summary) in fetchedChats.mentionTagSummaries {
                transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: summary.count, maxId: summary.range.maxId)
            }
            for (peerId, summary) in fetchedChats.reactionTagSummaries {
                transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, customTag: nil, count: summary.count, maxId: summary.range.maxId)
            }
            for (peerId, summary) in fetchedChats.pollVoteTagSummaries {
                transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenPollVote, namespace: Namespaces.Message.Cloud, customTag: nil, count: summary.count, maxId: summary.range.maxId)
            }
            
            for (groupId, summary) in fetchedChats.folderSummaries {
                transaction.resetPeerGroupSummary(groupId: groupId, namespace: Namespaces.Message.Cloud, summary: summary)
            }
            return true
        })
        |> mapToSignal { written -> Signal<Never, NoError> in
            if written {
                return .complete()
            }
            let restarts = staleRestarts + 1
            let restartDelay = FetchedAnswerAge.staleRestartDelay(restarts)
            Logger.shared.log("State", "chat list hole fill: restart \(restarts) in a row after answers too old to store, waiting \(restartDelay) s first")
            let restart = fetchChatListHole(postbox: postbox, network: network, accountPeerId: accountPeerId, groupId: groupId, hole: hole, staleRestarts: restarts)
            if restartDelay > 0.0 {
                // Inside this fill's subscription, so whoever holds it (the chat-list hole manager) still cancels the
                // wait.
                return restart |> delay(restartDelay, queue: Queue.concurrentDefaultQueue())
            }
            return restart
        }
    }
}

func fetchCallListHole(network: Network, postbox: Postbox, accountPeerId: PeerId, holeIndex: MessageIndex, limit: Int32 = 100) -> Signal<Void, NoError> {
    let offset: Signal<(Int32, Int32, Api.InputPeer), NoError>
    offset = single((holeIndex.timestamp, min(holeIndex.id.id, Int32.max - 1) + 1, Api.InputPeer.inputPeerEmpty), NoError.self)
    return offset
    |> mapToSignal { (timestamp, id, peer) -> Signal<Void, NoError> in
        let searchResult = network.request(Api.functions.messages.search(flags: 0, peer: .inputPeerEmpty, q: "", fromId: nil, savedPeerId: nil, savedReaction: nil, topMsgId: nil, filter: .inputMessagesFilterPhoneCalls(.init(flags: 0)), minDate: 0, maxDate: holeIndex.timestamp, offsetId: 0, addOffset: 0, limit: limit, maxId: holeIndex.id.id, minId: 0, hash: 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            let messages: [Api.Message]
            let chats: [Api.Chat]
            let users: [Api.User]
            switch result {
                case let .messages(messagesData):
                    let (apiMessages, _, apiChats, apiUsers) = (messagesData.messages, messagesData.topics, messagesData.chats, messagesData.users)
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let .messagesSlice(messagesSliceData):
                    let (apiMessages, apiChats, apiUsers) = (messagesSliceData.messages, messagesSliceData.chats, messagesSliceData.users)
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let .channelMessages(channelMessagesData):
                    let (apiMessages, apiTopics, apiChats, apiUsers) = (channelMessagesData.messages, channelMessagesData.topics, channelMessagesData.chats, channelMessagesData.users)
                    messages = apiMessages
                    let _ = apiTopics
                    chats = apiChats
                    users = apiUsers
                case .messagesNotModified:
                    messages = []
                    chats = []
                    users = []
            }
            return postbox.transaction { transaction -> Void in
                var storeMessages: [StoreMessage] = []
                var topIndex: MessageIndex?
                
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                
                for message in messages {
                    var peerIsForum = false
                    if let peerId = message.peerId, let peer = parsedPeers.get(peerId), peer.isForumOrMonoForum {
                        peerIsForum = true
                    }
                    if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
                        storeMessages.append(storeMessage)
                        if let index = storeMessage.index, topIndex == nil || index < topIndex! {
                            topIndex = index
                        }
                    }
                }
                
                var updatedIndex: MessageIndex?
                if let topIndex = topIndex {
                    updatedIndex = topIndex.globalPredecessor()
                }
                
                transaction.replaceGlobalMessageTagsHole(globalTags: [.Calls, .MissedCalls], index: holeIndex, with: updatedIndex, messages: storeMessages)
                
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
            }
        }
        return searchResult
    }
}

/// A message as it now stands, to write back unchanged: a rewrite always counts as an update, so views redraw it.
private func storeMessageRewritingCurrent(_ message: Message) -> StoreMessage {
    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: message.attributes, media: message.media)
}
