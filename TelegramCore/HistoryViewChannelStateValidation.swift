import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

private final class HistoryStateValidationBatch {
    private let disposable: Disposable
    let invalidatedState: HistoryState
    
    var cancelledMessageIds = Set<MessageId>()
    
    init(disposable: Disposable, invalidatedState: HistoryState) {
        self.disposable = disposable
        self.invalidatedState = invalidatedState
    }
    
    deinit {
        disposable.dispose()
    }
}

private final class HistoryStateValidationContext {
    var batchReferences: [MessageId: HistoryStateValidationBatch] = [:]
}

private enum HistoryState {
    case channel(PeerId, ChannelState)
    case group(PeerGroupId, TelegramPeerGroupState)
    
    var hasInvalidationIndex: Bool {
        switch self {
            case let .channel(_, state):
                return state.invalidatedPts != nil
            case let .group(_, state):
                return state.invalidatedStateIndex != nil
        }
    }
    
    func isMessageValid(_ message: Message) -> Bool {
        switch self {
            case let .channel(_, state):
                if let invalidatedPts = state.invalidatedPts {
                    var messagePts: Int32?
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? ChannelMessageStateVersionAttribute {
                            messagePts = attribute.pts
                            break inner
                        }
                    }
                    var requiresValidation = false
                    if let messagePts = messagePts {
                        if messagePts < invalidatedPts {
                            requiresValidation = true
                        }
                    } else {
                        requiresValidation = true
                    }
                    
                    return !requiresValidation
                } else {
                    return true
                }
            case let .group(_, state):
                if let invalidatedStateIndex = state.invalidatedStateIndex {
                    var messageStateIndex: Int32?
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? PeerGroupMessageStateVersionAttribute {
                            messageStateIndex = attribute.stateIndex
                            break inner
                        }
                    }
                    var requiresValidation = false
                    if let messageStateIndex = messageStateIndex {
                        if messageStateIndex < invalidatedStateIndex {
                            requiresValidation = true
                        }
                    } else {
                        requiresValidation = true
                    }
                    return !requiresValidation
                } else {
                    return true
                }
        }
    }
    
    func matchesPeerId(_ peerId: PeerId) -> Bool {
        switch self {
            case let .channel(statePeerId, state):
                return statePeerId == peerId
            case .group:
                return true
        }
    }
}

private func slicedForValidationMessages(_ messages: [MessageId]) -> [[MessageId]] {
    let block = 64
    
    if messages.count <= block {
        return [messages]
    } else {
        var result: [[MessageId]] = []
        var offset = 0
        while offset < messages.count {
            result.append(Array(messages[offset ..< min(offset + block, messages.count)]))
            offset += block
        }
        return result
    }
}

final class HistoryViewStateValidationContexts {
    private let queue: Queue
    private let postbox: Postbox
    private let network: Network
    private let accountPeerId: PeerId
    
    private var contexts: [Int32: HistoryStateValidationContext] = [:]
    
    init(queue: Queue, postbox: Postbox, network: Network, accountPeerId: PeerId) {
        self.queue = queue
        self.postbox = postbox
        self.network = network
        self.accountPeerId = accountPeerId
    }
    
    func updateView(id: Int32, view: MessageHistoryView?) {
        assert(self.queue.isCurrent())
        if let view = view, view.tagMask == nil {
            var historyState: HistoryState?
            for entry in view.additionalData {
                if case let .peerChatState(peerId, chatState) = entry {
                    if let chatState = chatState as? ChannelState {
                        historyState = .channel(peerId, chatState)
                    }
                    break
                } else if case let .peerGroupState(groupId, groupState) = entry {
                    if let groupState = groupState as? TelegramPeerGroupState {
                        //historyState = .group(groupId, groupState)
                    }
                    break
                }
            }
            
            if let historyState = historyState, historyState.hasInvalidationIndex {
                var rangesToInvalidate: [[MessageId]] = []
                let addToRange: (MessageId, inout [[MessageId]]) -> Void = { id, ranges in
                    if ranges.isEmpty {
                        ranges = [[id]]
                    } else {
                        ranges[ranges.count - 1].append(id)
                    }
                }
                
                let addRangeBreak: (inout [[MessageId]]) -> Void = { ranges in
                    if ranges.last?.count != 0 {
                        ranges.append([])
                    }
                }
                
                for entry in view.entries {
                    switch entry {
                        case let .MessageEntry(message, _, _, _):
                            if historyState.matchesPeerId(message.id.peerId) && message.id.namespace == Namespaces.Message.Cloud {
                                if !historyState.isMessageValid(message) {
                                    addToRange(message.id, &rangesToInvalidate)
                                } else {
                                    addRangeBreak(&rangesToInvalidate)
                                }
                            }
                        case let .HoleEntry(hole, _):
                            if historyState.matchesPeerId(hole.maxIndex.id.peerId) {
                                if hole.maxIndex.id.namespace == Namespaces.Message.Cloud {
                                    addRangeBreak(&rangesToInvalidate)
                                }
                            }
                    }
                }
                
                if !rangesToInvalidate.isEmpty && rangesToInvalidate[rangesToInvalidate.count - 1].isEmpty {
                    rangesToInvalidate.removeLast()
                }
                
                var invalidatedMessageIds = Set<MessageId>()
                
                if !rangesToInvalidate.isEmpty {
                    let context: HistoryStateValidationContext
                    if let current = self.contexts[id] {
                        context = current
                    } else {
                        context = HistoryStateValidationContext()
                        self.contexts[id] = context
                    }
                    
                    var addedRanges: [[MessageId]] = []
                    for messages in rangesToInvalidate {
                        for id in messages {
                            invalidatedMessageIds.insert(id)
                            
                            if context.batchReferences[id] != nil {
                                addRangeBreak(&addedRanges)
                            } else {
                                addToRange(id, &addedRanges)
                            }
                        }
                        addRangeBreak(&addedRanges)
                    }
                    
                    if !addedRanges.isEmpty && addedRanges[addedRanges.count - 1].isEmpty {
                        addedRanges.removeLast()
                    }
                    
                    
                    for rangeMessages in addedRanges {
                        for messages in slicedForValidationMessages(rangeMessages) {
                            let disposable = MetaDisposable()
                            let batch = HistoryStateValidationBatch(disposable: disposable, invalidatedState: historyState)
                            for messageId in messages {
                                context.batchReferences[messageId] = batch
                            }
                            
                            disposable.set((validateBatch(postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId, messageIds: messages, historyState: historyState)
                                |> deliverOn(self.queue)).start(completed: { [weak self, weak batch] in
                                    if let strongSelf = self, let context = strongSelf.contexts[id], let batch = batch {
                                        var completedMessageIds: [MessageId] = []
                                        for (messageId, messageBatch) in context.batchReferences {
                                            if messageBatch === batch {
                                                completedMessageIds.append(messageId)
                                            }
                                        }
                                        for messageId in completedMessageIds {
                                            context.batchReferences.removeValue(forKey: messageId)
                                        }
                                    }
                                }))
                        }
                    }
                }
                
                if let context = self.contexts[id] {
                    var removeIds: [MessageId] = []
                    
                    for batchMessageId in context.batchReferences.keys {
                        if !invalidatedMessageIds.contains(batchMessageId) {
                            removeIds.append(batchMessageId)
                        }
                    }
                    
                    for messageId in removeIds {
                        context.batchReferences.removeValue(forKey: messageId)
                    }
                }
            }
        } else if self.contexts[id] != nil {
            self.contexts.removeValue(forKey: id)
        }
    }
}

private func hashForMessages(_ messages: [Message], withChannelIds: Bool) -> Int32 {
    var acc: UInt32 = 0
    
    let sorted = messages.sorted(by: { MessageIndex($0) > MessageIndex($1) })
    
    for message in sorted {
        if withChannelIds {
            acc = (acc &* 20261) &+ UInt32(message.id.peerId.id)
        }
        
        acc = (acc &* 20261) &+ UInt32(message.id.id)
        var timestamp = message.timestamp
        inner: for attribute in message.attributes {
            if let attribute = attribute as? EditedMessageAttribute {
                timestamp = attribute.date
                break inner
            }
        }
        acc = (acc &* 20261) &+ UInt32(timestamp)
    }
    return Int32(bitPattern: acc & UInt32(0x7FFFFFFF))
}

private func hashForMessages(_ messages: [StoreMessage], withChannelIds: Bool) -> Int32 {
    var acc: UInt32 = 0
    
    for message in messages {
        if case let .Id(id) = message.id {
            if withChannelIds {
                acc = (acc &* 20261) &+ UInt32(id.peerId.id)
            }
            acc = (acc &* 20261) &+ UInt32(id.id)
            var timestamp = message.timestamp
            inner: for attribute in message.attributes {
                if let attribute = attribute as? EditedMessageAttribute {
                    timestamp = attribute.date
                    break inner
                }
            }
            acc = (acc &* 20261) &+ UInt32(timestamp)
        }
    }
    return Int32(bitPattern: acc & UInt32(0x7FFFFFFF))
}

private enum ValidatedMessages {
    case notModified
    case messages([Api.Message], [Api.Chat], [Api.User], Int32?)
}

private func validateBatch(postbox: Postbox, network: Network, accountPeerId: PeerId, messageIds: [MessageId], historyState: HistoryState) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var previousMessages: [Message] = []
        var previous: [MessageId: Message] = [:]
        for messageId in messageIds {
            if let message = transaction.getMessage(messageId) {
                previousMessages.append(message)
                previous[message.id] = message
            }
        }
        
        var signal: Signal<ValidatedMessages, MTRpcError>
        switch historyState {
            case let .channel(peerId, _):
                let hash = hashForMessages(previousMessages, withChannelIds: false)
                if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                    signal = network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: messageIds[messageIds.count - 1].id + 1, offsetDate: 0, addOffset: 0, limit: Int32(messageIds.count), maxId: messageIds[messageIds.count - 1].id + 1, minId: messageIds[0].id - 1, hash: hash))
                    |> map { result -> ValidatedMessages in
                        let messages: [Api.Message]
                        let chats: [Api.Chat]
                        let users: [Api.User]
                        var channelPts: Int32?
                        
                        switch result {
                            case let .messages(messages: apiMessages, chats: apiChats, users: apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                            case let .messagesSlice(_, _, messages: apiMessages, chats: apiChats, users: apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                            case let .channelMessages(_, pts, _, apiMessages, apiChats, apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                                channelPts = pts
                            case .messagesNotModified:
                                return .notModified
                        }
                        return .messages(messages, chats, users, channelPts)
                    }
                } else {
                    return .complete()
                }
            case let .group(groupId, _):
                /*feed*/
                signal = .single(.notModified)
                /*let hash = hashForMessages(previousMessages, withChannelIds: true)
                let upperIndex = MessageIndex(previousMessages[previousMessages.count - 1])
                let minIndex = MessageIndex(previousMessages[0]).predecessor()
                
                let upperInputPeer: Api.Peer = groupBoundaryPeer(upperIndex.id.peerId, accountPeerId: accountPeerId)
                let lowerInputPeer: Api.Peer = groupBoundaryPeer(minIndex.id.peerId, accountPeerId: accountPeerId)
                
                var flags: Int32 = 0
                flags |= (1 << 0)
                
                let offsetPosition: Api.FeedPosition = .feedPosition(date: upperIndex.timestamp, peer: upperInputPeer, id: upperIndex.id.id)
                let addOffset: Int32 = -1
                let minPosition: Api.FeedPosition = .feedPosition(date: minIndex.timestamp, peer: lowerInputPeer, id: minIndex.id.id)
                
                flags |= (1 << 0)
                flags |= (1 << 2)
                
                signal = network.request(Api.functions.channels.getFeed(flags: flags, feedId: groupId.rawValue, offsetPosition: offsetPosition, addOffset: addOffset, limit: 200, maxPosition: nil, minPosition: minPosition, hash: hash))
            |> map { result -> ValidatedMessages in
                switch result {
                    case let .feedMessages(_, _, _, _, messages, chats, users):
                        return .messages(messages, chats, users, nil)
                    case .feedMessagesNotModified:
                        return .notModified
                }
            }*/
        }
        
        return signal
        |> map(Optional.init)
        |> `catch` { _ -> Signal<ValidatedMessages?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                if let result = result {
                    switch result {
                        case let .messages(messages, chats, users, channelPts):
                            var storeMessages: [StoreMessage] = []
                            
                            for message in messages {
                                if let storeMessage = StoreMessage(apiMessage: message) {
                                    var attributes = storeMessage.attributes
                                    
                                    if let channelPts = channelPts {
                                        attributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
                                    }
                                    
                                    switch historyState {
                                        case .channel:
                                            break
                                        case let .group(_, groupState):
                                            attributes.append(PeerGroupMessageStateVersionAttribute(stateIndex: groupState.stateIndex))
                                    }
                                    
                                    storeMessages.append(storeMessage.withUpdatedAttributes(attributes))
                                }
                            }
                            
                            if case .group = historyState {
                                let prevHash = hashForMessages(previousMessages, withChannelIds: true)
                                let updatedHash = hashForMessages(storeMessages, withChannelIds: true)
                                print("\(updatedHash) != \(prevHash)")
                            }
                            
                            var validMessageIds = Set<MessageId>()
                            for message in storeMessages {
                                if case let .Id(id) = message.id {
                                    validMessageIds.insert(id)
                                    let previousMessage = previous[id] ?? transaction.getMessage(id)
                                    
                                    if let previousMessage = previousMessage {
                                        var updatedTimestamp = message.timestamp
                                        inner: for attribute in message.attributes {
                                            if let attribute = attribute as? EditedMessageAttribute {
                                                updatedTimestamp = attribute.date
                                                break inner
                                            }
                                        }
                                        
                                        var timestamp = previousMessage.timestamp
                                        inner: for attribute in previousMessage.attributes {
                                            if let attribute = attribute as? EditedMessageAttribute {
                                                timestamp = attribute.date
                                                break inner
                                            }
                                        }
                                        
                                        transaction.updateMessage(id, update: { currentMessage in
                                            if updatedTimestamp != timestamp {
                                                var updatedLocalTags = message.localTags
                                                if currentMessage.localTags.contains(.OutgoingLiveLocation) {
                                                    updatedLocalTags.insert(.OutgoingLiveLocation)
                                                }
                                                return .update(message.withUpdatedLocalTags(updatedLocalTags))
                                            } else {
                                                var storeForwardInfo: StoreMessageForwardInfo?
                                                if let forwardInfo = currentMessage.forwardInfo {
                                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                                                }
                                                var attributes = currentMessage.attributes
                                                if let channelPts = channelPts {
                                                    for i in (0 ..< attributes.count).reversed() {
                                                        if let _ = attributes[i] as? ChannelMessageStateVersionAttribute {
                                                            attributes.remove(at: i)
                                                        }
                                                    }
                                                    attributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
                                                }
                                                
                                                switch historyState {
                                                    case .channel:
                                                        break
                                                    case let .group(_, groupState):
                                                        for i in (0 ..< attributes.count).reversed() {
                                                            if let _ = attributes[i] as? PeerGroupMessageStateVersionAttribute {
                                                                attributes.remove(at: i)
                                                            }
                                                        }
                                                        attributes.append(PeerGroupMessageStateVersionAttribute(stateIndex: groupState.stateIndex))
                                                }
                                                
                                                var updatedFlags = StoreMessageFlags(currentMessage.flags)
                                                if case .group = historyState {
                                                    updatedFlags.insert(.CanBeGroupedIntoFeed)
                                                }
                                                
                                                return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: updatedFlags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                            }
                                        })
                                        
                                        if previous[id] == nil {
                                            print("\(id) missing")
                                            if case let .group(groupId, _) = historyState {
                                                let _ = transaction.addMessagesToGroupFeedIndex(groupId: groupId, ids: [id])
                                            }
                                        }
                                    } else {
                                        let _ = transaction.addMessages([message], location: .Random)
                                    }
                                }
                            }
                            
                            for id in previous.keys {
                                if !validMessageIds.contains(id) {
                                    switch historyState {
                                        case .channel:
                                            deleteMessages(transaction: transaction, mediaBox: postbox.mediaBox, ids: [id])
                                        case let .group(groupId, _):
                                            transaction.removeMessagesFromGroupFeedIndex(groupId: groupId, ids: [id])
                                    }
                                }
                            }
                        case .notModified:
                            for id in previous.keys {
                                transaction.updateMessage(id, update: { currentMessage in
                                    var storeForwardInfo: StoreMessageForwardInfo?
                                    if let forwardInfo = currentMessage.forwardInfo {
                                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                                    }
                                    var attributes = currentMessage.attributes
                                    for i in (0 ..< attributes.count).reversed() {
                                        switch historyState {
                                            case .channel:
                                                if let _ = attributes[i] as? ChannelMessageStateVersionAttribute {
                                                    attributes.remove(at: i)
                                                }
                                            case .group:
                                                if let _ = attributes[i] as? PeerGroupMessageStateVersionAttribute {
                                                    attributes.remove(at: i)
                                                }
                                        }
                                    }
                                    switch historyState {
                                        case let .channel(_, channelState):
                                            attributes.append(ChannelMessageStateVersionAttribute(pts: channelState.pts))
                                        case let .group(_, groupState):
                                            attributes.append(PeerGroupMessageStateVersionAttribute(stateIndex: groupState.stateIndex))
                                    }
                                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                })
                            }
                    }
                }
            }
        }
    } |> switchToLatest
}
