import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
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
        return Api.MessagesFilter.inputMessagesFilterPhotoVideo
    } else if tagMask == .photo {
        return Api.MessagesFilter.inputMessagesFilterPhotos
    } else if tagMask == .video {
        return Api.MessagesFilter.inputMessagesFilterVideo
    } else if tagMask == .file {
        return Api.MessagesFilter.inputMessagesFilterDocument
    } else if tagMask == .music {
        return Api.MessagesFilter.inputMessagesFilterMusic
    } else if tagMask == .webPage {
        return Api.MessagesFilter.inputMessagesFilterUrl
    } else if tagMask == .voiceOrInstantVideo {
        return Api.MessagesFilter.inputMessagesFilterRoundVoice
    } else if tagMask == .gif {
        return Api.MessagesFilter.inputMessagesFilterGif
    } else if tagMask == .pinned {
        return Api.MessagesFilter.inputMessagesFilterPinned
    } else if tagMask == .voice {
        return Api.MessagesFilter.inputMessagesFilterVoice
    } else if tagMask == .roundVideo {
        return Api.MessagesFilter.inputMessagesFilterRoundVideo
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
                    referencedReplyIds.add(sourceId: id, targetId: attribute.messageId)
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
                        signal = source.request(Api.functions.messages.getMessages(id: messageIds.targetIdsBySourceId.values.map({ Api.InputMessage.inputMessageReplyTo(id: $0.id) })))
                    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let inputChannel = apiInputChannel(peer) {
                            signal = source.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.targetIdsBySourceId.values.map({ Api.InputMessage.inputMessageReplyTo(id: $0.id) })))
                        }
                    }
                    if let signal = signal {
                        signals.append(signal
                        |> map { result in
                            switch result {
                                case let .messages(messages, chats, users):
                                    return (peer, messages, chats, users)
                                case let .messagesSlice(_, _, _, _, messages, chats, users):
                                    return (peer, messages, chats, users)
                                case let .channelMessages(_, _, _, _, messages, apiTopics, chats, users):
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
                        signal = source.request(Api.functions.messages.getMessages(id: messageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let inputChannel = apiInputChannel(peer) {
                            signal = source.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                        }
                    }
                    if let signal = signal {
                        signals.append(signal
                        |> map { result in
                            switch result {
                                case let .messages(messages, chats, users):
                                    return (peer, messages, chats, users)
                                case let .messagesSlice(_, _, _, _, messages, chats, users):
                                    return (peer, messages, chats, users)
                                case let .channelMessages(_, _, _, _, messages, apiTopics, chats, users):
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
                                        return f(transaction, parsedPeers, [])
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

func fetchMessageHistoryHole(accountPeerId: PeerId, source: FetchMessageHistoryHoleSource, postbox: Postbox, peerInput: FetchMessageHistoryHoleThreadInput, namespace: MessageId.Namespace, direction: MessageHistoryViewRelativeHoleDirection, space: MessageHistoryHoleOperationSpace, count rawCount: Int) -> Signal<FetchMessageHistoryHoleResult?, NoError> {
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
                        minId = 1
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
            
            return request
            |> retry(retryOnError: { error in
                if error.errorDescription == "CHANNEL_PRIVATE" {
                    switch peerInput {
                    case let .direct(_, threadId):
                        if threadId != nil {
                            return false
                        }
                    case .threadFromChannel:
                        return false
                    }
                }
                return true
            }, delayIncrement: 0.1, maxDelay: 2.0, maxRetries: 0, onQueue: .concurrentDefaultQueue())
            |> map { result -> Api.messages.Messages? in
                return result
            }
            |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<FetchMessageHistoryHoleResult?, NoError> in
                guard let result = result else {
                    return .single(nil)
                }
                return postbox.transaction { transaction -> Signal<FetchMessageHistoryHoleResult?, NoError> in
                    let messages: [Api.Message]
                    let chats: [Api.Chat]
                    let users: [Api.User]
                    var channelPts: Int32?
                    switch result {
                        case let .messages(messages: apiMessages, chats: apiChats, users: apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case let .messagesSlice(_, _, _, _, messages: apiMessages, chats: apiChats, users: apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case let .channelMessages(_, pts, _, _, apiMessages, apiTopics, apiChats, apiUsers):
                            messages = apiMessages
                            let _ = apiTopics
                            chats = apiChats
                            users = apiUsers
                            channelPts = pts
                        case .messagesNotModified:
                            messages = []
                            chats = []
                            users = []
                    }
                    
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                    
                    var storeMessages: [StoreMessage] = []
                    
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
                    
                    return withResolvedAssociatedMessages(postbox: postbox, source: source, accountPeerId: accountPeerId, parsedPeers: parsedPeers, storeMessages: storeMessages, resolveThreads: true, { transaction, additionalParsedPeers, additionalMessages -> FetchMessageHistoryHoleResult? in
                        let _ = transaction.addMessages(storeMessages, location: .Random)
                        let _ = transaction.addMessages(additionalMessages, location: .Random)
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
                        
                        print("fetchMessageHistoryHole for \(peerInput) space \(space) done")
                        
                        if ids.count == 0 || implicitelyFillHole {
                            filledRange = minMaxRange
                            strictFilledIndices = IndexSet()
                        } else {
                            let messageRange = ids.min()! ... ids.max()!
                            switch direction {
                            case let .aroundId(aroundId):
                                filledRange = min(aroundId.id, messageRange.lowerBound) ... max(aroundId.id, messageRange.upperBound)
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
                        
                        
                        switch peerInput {
                        case let .direct(peerId, threadId):
                            transaction.removeHole(peerId: peerId, threadId: threadId, namespace: namespace, space: space, range: filledRange)
                        case .threadFromChannel:
                            break
                        }
                        
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers.union(with: additionalParsedPeers))
                        
                        let result = FetchMessageHistoryHoleResult(
                            removedIndices: IndexSet(integersIn: Int(filledRange.lowerBound) ... Int(filledRange.upperBound)),
                            strictRemovedIndices: strictFilledIndices,
                            actualPeerId: storeMessages.first?.id.peerId,
                            actualThreadId: storeMessages.first?.threadId,
                            ids: fullIds
                        )
                        return result
                    })
                }
                |> switchToLatest
            }
        }
    }
}

func groupBoundaryPeer(_ peerId: PeerId, accountPeerId: PeerId) -> Api.Peer {
    switch peerId.namespace {
        case Namespaces.Peer.CloudUser:
            return Api.Peer.peerUser(userId: peerId.id._internalGetInt64Value())
        case Namespaces.Peer.CloudGroup:
            return Api.Peer.peerChat(chatId: peerId.id._internalGetInt64Value())
        case Namespaces.Peer.CloudChannel:
            return Api.Peer.peerChannel(channelId: peerId.id._internalGetInt64Value())
        default:
            return Api.Peer.peerUser(userId: accountPeerId.id._internalGetInt64Value())
    }
}

func fetchChatListHole(postbox: Postbox, network: Network, accountPeerId: PeerId, groupId: PeerGroupId, hole: ChatListHole) -> Signal<Never, NoError> {
    let location: FetchChatListLocation
    switch groupId {
        case .root:
            location = .general
        case .group:
            location = .group(groupId)
    }
    return fetchChatList(accountPeerId: accountPeerId, postbox: postbox, network: network, location: location, upperBound: hole.index, hash: 0, limit: 100)
    |> mapToSignal { fetchedChats -> Signal<Never, NoError> in
        guard let fetchedChats = fetchedChats else {
            return postbox.transaction { transaction -> Void in
                transaction.replaceChatListHole(groupId: groupId, index: hole.index, hole: nil)
            }
            |> ignoreValues
        }
        return withResolvedAssociatedMessages(postbox: postbox, source: .network(network), accountPeerId: accountPeerId, parsedPeers: fetchedChats.peers, storeMessages: fetchedChats.storeMessages, resolveThreads: false, { transaction, additionalPeers, additionalMessages -> Void in
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: fetchedChats.peers.union(with: additionalPeers))
            
            for (threadMessageId, data) in fetchedChats.threadInfos {
                if let entry = StoredMessageHistoryThreadInfo(data.data) {
                    transaction.setMessageHistoryThreadInfo(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, info: entry)
                }
                transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadMentionCount, maxId: data.topMessageId)
                transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadReactionCount, maxId: data.topMessageId)
            }
            
            transaction.updateCurrentPeerNotificationSettings(fetchedChats.notificationSettings)
            let _ = transaction.addMessages(fetchedChats.storeMessages, location: .UpperHistoryBlock)
            let _ = transaction.addMessages(additionalMessages, location: .Random)
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
                    transaction.setPeerChatState(peerId, state: current.withUpdatedPts(pts))
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
            
            for (groupId, summary) in fetchedChats.folderSummaries {
                transaction.resetPeerGroupSummary(groupId: groupId, namespace: Namespaces.Message.Cloud, summary: summary)
            }
        })
        |> ignoreValues
    }
}

func fetchCallListHole(network: Network, postbox: Postbox, accountPeerId: PeerId, holeIndex: MessageIndex, limit: Int32 = 100) -> Signal<Void, NoError> {
    let offset: Signal<(Int32, Int32, Api.InputPeer), NoError>
    offset = single((holeIndex.timestamp, min(holeIndex.id.id, Int32.max - 1) + 1, Api.InputPeer.inputPeerEmpty), NoError.self)
    return offset
    |> mapToSignal { (timestamp, id, peer) -> Signal<Void, NoError> in
        let searchResult = network.request(Api.functions.messages.search(flags: 0, peer: .inputPeerEmpty, q: "", fromId: nil, savedPeerId: nil, savedReaction: nil, topMsgId: nil, filter: .inputMessagesFilterPhoneCalls(flags: 0), minDate: 0, maxDate: holeIndex.timestamp, offsetId: 0, addOffset: 0, limit: limit, maxId: holeIndex.id.id, minId: 0, hash: 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<Void, NoError> in
            let messages: [Api.Message]
            let chats: [Api.Chat]
            let users: [Api.User]
            switch result {
                case let .messages(messages: apiMessages, chats: apiChats, users: apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let .messagesSlice(_, _, _, _, messages: apiMessages, chats: apiChats, users: apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let .channelMessages(_, _, _, _, apiMessages, apiTopics, apiChats, apiUsers):
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
