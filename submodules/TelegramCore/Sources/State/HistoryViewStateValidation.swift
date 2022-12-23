import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


private final class HistoryStateValidationBatch {
    private let disposable: Disposable
    let invalidatedState: HistoryState?
    
    var cancelledMessageIds = Set<MessageId>()
    
    init(disposable: Disposable, invalidatedState: HistoryState? = nil) {
        self.disposable = disposable
        self.invalidatedState = invalidatedState
    }
    
    deinit {
        self.disposable.dispose()
    }
}

private final class HistoryStateValidationContext {
    var batchReferences: [MessageId: HistoryStateValidationBatch] = [:]
    var batch: HistoryStateValidationBatch?
}

private enum HistoryState {
    case channel(PeerId, ChannelState)
    //case group(PeerGroupId, TelegramPeerGroupState)
    case scheduledMessages(PeerId)
    
    var hasInvalidationIndex: Bool {
        switch self {
            case let .channel(_, state):
                return state.invalidatedPts != nil
            /*case let .group(_, state):
                return state.invalidatedStateIndex != nil*/
            case .scheduledMessages:
                return false
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
            /*case let .group(_, state):
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
                }*/
            case .scheduledMessages:
                return false
        }
    }
    
    func matchesPeerId(_ peerId: PeerId) -> Bool {
        switch self {
            case let .channel(statePeerId, _):
                return statePeerId == peerId
            /*case .group:
                return true*/
            case let .scheduledMessages(statePeerId):
                return statePeerId == peerId
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
    
    private var previousPeerValidationTimestamps: [PeerId: Double] = [:]
    
    init(queue: Queue, postbox: Postbox, network: Network, accountPeerId: PeerId) {
        self.queue = queue
        self.postbox = postbox
        self.network = network
        self.accountPeerId = accountPeerId
    }
    
    func updateView(id: Int32, view: MessageHistoryView?, location: ChatLocationInput? = nil) {
        assert(self.queue.isCurrent())
        guard let view = view, view.tagMask == nil || view.tagMask == MessageTags.unseenPersonalMessage || view.tagMask == MessageTags.unseenReaction || view.tagMask == MessageTags.music || view.tagMask == MessageTags.pinned else {
            if self.contexts[id] != nil {
                self.contexts.removeValue(forKey: id)
            }
            return
        }
        
        var historyState: HistoryState?
        for entry in view.additionalData {
            if case let .peerChatState(peerId, chatState) = entry {
                if let chatState = chatState as? ChannelState {
                    historyState = .channel(peerId, chatState)
                }
                break
            }
        }
        
        if let location = location, let peerId = location.peerId, let threadId = location.threadId {
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
                if entry.message.id.peerId == peerId && entry.message.id.namespace == Namespaces.Message.Cloud {
                    addToRange(entry.message.id, &rangesToInvalidate)
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
                        
                        disposable.set((validateReplyThreadMessagesBatch(postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId, peerId: peerId, threadMessageId: makeThreadIdMessageId(peerId: peerId, threadId: threadId).id, tag: view.tagMask, messageIds: messages)
                        |> deliverOn(self.queue)).start(completed: { [weak self, weak batch] in
                            if let strongSelf = self, let context = strongSelf.contexts[id], let batch = batch {
                                var completedMessageIds: [MessageId] = []
                                for (messageId, messageBatch) in context.batchReferences {
                                    if messageBatch === batch {
                                        completedMessageIds.append(messageId)
                                    }
                                }
                                /*for messageId in completedMessageIds {
                                    context.batchReferences.removeValue(forKey: messageId)
                                }*/
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
        } else if let historyState = historyState, historyState.hasInvalidationIndex {
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
                if historyState.matchesPeerId(entry.message.id.peerId) && entry.message.id.namespace == Namespaces.Message.Cloud {
                    if let tag = view.tagMask {
                        if !entry.message.tags.contains(tag) {
                            continue
                        }
                    }
                    if !historyState.isMessageValid(entry.message) {
                        addToRange(entry.message.id, &rangesToInvalidate)
                    } else {
                        addRangeBreak(&rangesToInvalidate)
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
                        
                        disposable.set((validateChannelMessagesBatch(postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId, tag: view.tagMask, messageIds: messages, historyState: historyState)
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
        } else if view.namespaces.contains(Namespaces.Message.ScheduledCloud) {
            if let _ = self.contexts[id] {
            } else if let location = location, case let .peer(peerId, _) = location {
                let timestamp = self.network.context.globalTime()
                if let previousTimestamp = self.previousPeerValidationTimestamps[peerId], timestamp < previousTimestamp + 60  {
                } else {
                    self.previousPeerValidationTimestamps[peerId] = timestamp
                    
                    let context = HistoryStateValidationContext()
                    self.contexts[id] = context
            
                    let disposable = MetaDisposable()
                    let batch = HistoryStateValidationBatch(disposable: disposable)
                    context.batch = batch
                    
                    let messages: [Message] = view.entries.map { $0.message }.filter { $0.id.namespace == Namespaces.Message.ScheduledCloud }
                
                    disposable.set((validateScheduledMessagesBatch(postbox: self.postbox, network: self.network, accountPeerId: peerId, tag: nil, messages: messages, historyState: .scheduledMessages(peerId))
                    |> deliverOn(self.queue)).start(completed: { [weak self] in
                        if let strongSelf = self, let context = strongSelf.contexts[id] {
                            context.batch = nil
                        }
                    }))
                }
            }
        }
    }
}

private func hashForScheduledMessages(_ messages: [Message]) -> Int64 {
    var acc: UInt64 = 0
    
    let sorted = messages.sorted(by: { $0.timestamp > $1.timestamp })
    
    for message in sorted {
        combineInt64Hash(&acc, with: UInt64(message.id.id))

        var editTimestamp: Int32 = 0
        inner: for attribute in message.attributes {
            if let attribute = attribute as? EditedMessageAttribute {
                editTimestamp = attribute.date
                break inner
            }
        }
        combineInt64Hash(&acc, with: UInt64(editTimestamp))
        combineInt64Hash(&acc, with: UInt64(message.timestamp))
    }
    return finalizeInt64Hash(acc)
}

public func combineInt64Hash(_ acc: inout UInt64, with value: UInt64) {
    acc ^= (acc >> 21)
    acc ^= (acc << 35)
    acc ^= (acc >> 4)
    acc = acc &+ value
}

public func combineInt64Hash(_ acc: inout UInt64, with peerId: PeerId) {
    let value = UInt64(bitPattern: peerId.id._internalGetInt64Value())
    combineInt64Hash(&acc, with: value)
}

public func finalizeInt64Hash(_ acc: UInt64) -> Int64 {
    return Int64(bitPattern: acc)
}

private func hashForMessages(_ messages: [Message], withChannelIds: Bool) -> Int64 {
    var acc: UInt64 = 0
    
    let sorted = messages.sorted(by: { $0.index > $1.index })
    
    for message in sorted {
        if withChannelIds {
            combineInt64Hash(&acc, with: message.id.peerId)
        }

        combineInt64Hash(&acc, with: UInt64(message.id.id))

        var timestamp = message.timestamp
        inner: for attribute in message.attributes {
            if let attribute = attribute as? EditedMessageAttribute {
                timestamp = attribute.date
                break inner
            }
        }
        if message.tags.contains(.pinned) {
            combineInt64Hash(&acc, with: UInt64(1))
        }
        combineInt64Hash(&acc, with: UInt64(timestamp))
    }
    return finalizeInt64Hash(acc)
}

private func hashForMessages(_ messages: [StoreMessage], withChannelIds: Bool) -> Int64 {
    var acc: UInt64 = 0
    
    for message in messages {
        if case let .Id(id) = message.id {
            if withChannelIds {
                combineInt64Hash(&acc, with: id.peerId)
            }
            combineInt64Hash(&acc, with: UInt64(id.id))
            var timestamp = message.timestamp
            inner: for attribute in message.attributes {
                if let attribute = attribute as? EditedMessageAttribute {
                    timestamp = attribute.date
                    break inner
                }
            }
            combineInt64Hash(&acc, with: UInt64(timestamp))
        }
    }
    return finalizeInt64Hash(acc)
}

private enum ValidatedMessages {
    case notModified
    case messages([Api.Message], [Api.Chat], [Api.User], Int32?)
}

private func validateChannelMessagesBatch(postbox: Postbox, network: Network, accountPeerId: PeerId, tag: MessageTags?, messageIds: [MessageId], historyState: HistoryState) -> Signal<Void, NoError> {
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
                Logger.shared.log("HistoryValidation", "validate batch for \(peerId): \(previousMessages.map({ $0.id }))")
                if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                    let requestSignal: Signal<Api.messages.Messages, MTRpcError>
                    if let tag = tag {
                        if tag == MessageTags.unseenPersonalMessage {
                            requestSignal = network.request(Api.functions.messages.getUnreadMentions(flags: 0, peer: inputPeer, topMsgId: nil, offsetId: messageIds[messageIds.count - 1].id + 1, addOffset: 0, limit: Int32(messageIds.count), maxId: messageIds[messageIds.count - 1].id + 1, minId: messageIds[0].id - 1))
                        } else if tag == MessageTags.unseenReaction {
                            requestSignal = network.request(Api.functions.messages.getUnreadReactions(flags: 0, peer: inputPeer, topMsgId: nil, offsetId: messageIds[messageIds.count - 1].id + 1, addOffset: 0, limit: Int32(messageIds.count), maxId: messageIds[messageIds.count - 1].id + 1, minId: messageIds[0].id - 1))
                        } else if let filter = messageFilterForTagMask(tag) {
                            requestSignal = network.request(Api.functions.messages.search(flags: 0, peer: inputPeer, q: "", fromId: nil, topMsgId: nil, filter: filter, minDate: 0, maxDate: 0, offsetId: messageIds[messageIds.count - 1].id + 1, addOffset: 0, limit: Int32(messageIds.count), maxId: messageIds[messageIds.count - 1].id + 1, minId: messageIds[0].id - 1, hash: hash))
                        } else {
                            assertionFailure()
                            requestSignal = .complete()
                        }
                    } else {
                        requestSignal = network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: messageIds[messageIds.count - 1].id + 1, offsetDate: 0, addOffset: 0, limit: Int32(messageIds.count), maxId: messageIds[messageIds.count - 1].id + 1, minId: messageIds[0].id - 1, hash: hash))
                    }
                    
                    signal = requestSignal
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
                            case let .messagesSlice(_, _, _, _, messages: apiMessages, chats: apiChats, users: apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                            case let .channelMessages(_, pts, _, _, apiMessages, apiChats, apiUsers):
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
            default:
                signal = .complete()
        }
        
        return validateBatch(postbox: postbox, network: network, transaction: transaction, accountPeerId: accountPeerId, tag: tag, historyState: historyState, signal: signal, previous: previous, messageNamespace: Namespaces.Message.Cloud)
    } |> switchToLatest
}

private func validateReplyThreadMessagesBatch(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, threadMessageId: Int32, tag: MessageTags?, messageIds: [MessageId]) -> Signal<Void, NoError> {
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
        let hash = hashForMessages(previousMessages, withChannelIds: false)
        Logger.shared.log("HistoryValidation", "validate reply thread batch (tag: \(String(describing: tag?.rawValue)) for \(peerId): \(previousMessages.map({ $0.id }))")
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let requestSignal: Signal<Api.messages.Messages, MTRpcError>
            
            if let tag = tag {
                if let filter = messageFilterForTagMask(tag) {
                    var flags: Int32 = 0
                    flags |= (1 << 1)
                    
                    requestSignal = network.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: "", fromId: nil, topMsgId: threadMessageId, filter: filter, minDate: 0, maxDate: 0, offsetId: messageIds[messageIds.count - 1].id + 1, addOffset: 0, limit: Int32(messageIds.count), maxId: messageIds[messageIds.count - 1].id + 1, minId: messageIds[0].id - 1, hash: hash))
                } else {
                    return .complete()
                }
            } else {
                requestSignal = network.request(Api.functions.messages.getReplies(peer: inputPeer, msgId: threadMessageId, offsetId: messageIds[messageIds.count - 1].id, offsetDate: 0, addOffset: -1, limit: Int32(messageIds.count), maxId: messageIds[messageIds.count - 1].id + 1, minId: messageIds[0].id - 1, hash: hash))
            }
            
            signal = requestSignal
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
                    case let .messagesSlice(_, _, _, _, messages: apiMessages, chats: apiChats, users: apiUsers):
                        messages = apiMessages
                        chats = apiChats
                        users = apiUsers
                    case let .channelMessages(_, pts, _, _, apiMessages, apiChats, apiUsers):
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
        
        return validateReplyThreadBatch(postbox: postbox, network: network, transaction: transaction, accountPeerId: accountPeerId, peerId: peerId, threadId: makeMessageThreadId(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: threadMessageId)), signal: signal, previous: previous, messageNamespace: Namespaces.Message.Cloud)
    }
    |> switchToLatest
}

private func validateScheduledMessagesBatch(postbox: Postbox, network: Network, accountPeerId: PeerId, tag: MessageTags?, messages: [Message], historyState: HistoryState) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var signal: Signal<ValidatedMessages, MTRpcError>
        switch historyState {
            case let .scheduledMessages(peerId):
                if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                    let hash = hashForScheduledMessages(messages)
                    signal = network.request(Api.functions.messages.getScheduledHistory(peer: inputPeer, hash: hash))
                    |> map { result -> ValidatedMessages in
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
                            case let .channelMessages(_, _, _, _, apiMessages, apiChats, apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                            case .messagesNotModified:
                                return .notModified
                        }
                        return .messages(messages, chats, users, nil)
                    }
                } else {
                    signal = .complete()
                }
            default:
                signal = .complete()
        }
        var previous: [MessageId: Message] = [:]
        for message in messages {
            previous[message.id] = message
        }
        return validateBatch(postbox: postbox, network: network, transaction: transaction, accountPeerId: accountPeerId, tag: tag, historyState: historyState, signal: signal, previous: previous, messageNamespace: Namespaces.Message.ScheduledCloud)
    } |> switchToLatest
}

private func validateBatch(postbox: Postbox, network: Network, transaction: Transaction, accountPeerId: PeerId, tag: MessageTags?, historyState: HistoryState, signal: Signal<ValidatedMessages, MTRpcError>, previous: [MessageId: Message], messageNamespace: MessageId.Namespace) -> Signal<Void, NoError> {
    return signal
    |> map(Optional.init)
    |> `catch` { _ -> Signal<ValidatedMessages?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        guard let result = result else {
            return .complete()
        }
        switch result {
            case let .messages(messages, _, _, channelPts):
                var storeMessages: [StoreMessage] = []
                
                for message in messages {
                    if let storeMessage = StoreMessage(apiMessage: message, namespace: messageNamespace) {
                        var attributes = storeMessage.attributes
                        if let channelPts = channelPts {
                            attributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
                        }
                        storeMessages.append(storeMessage.withUpdatedAttributes(attributes))
                    }
                }
                
                var validMessageIds = Set<MessageId>()
                for message in storeMessages {
                    if case let .Id(id) = message.id {
                        validMessageIds.insert(id)
                    }
                }
                
                var maybeRemovedMessageIds: [MessageId] = []
                for id in previous.keys {
                    if !validMessageIds.contains(id) {
                        maybeRemovedMessageIds.append(id)
                    }
                }
                
                let actuallyRemovedMessagesSignal: Signal<Set<MessageId>, NoError>
                if maybeRemovedMessageIds.isEmpty {
                    actuallyRemovedMessagesSignal = .single(Set())
                } else {
                    switch historyState {
                        case let .channel(peerId, _):
                            actuallyRemovedMessagesSignal = postbox.transaction { transaction -> Signal<Set<MessageId>, NoError> in
                                if let inputChannel = transaction.getPeer(peerId).flatMap(apiInputChannel) {
                                    return network.request(Api.functions.channels.getMessages(channel: inputChannel, id: maybeRemovedMessageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                                    |> map { result -> Set<MessageId> in
                                        let apiMessages: [Api.Message]
                                        switch result {
                                            case let .channelMessages(_, _, _, _, messages, _, _):
                                                apiMessages = messages
                                            case let .messages(messages, _, _):
                                                apiMessages = messages
                                            case let .messagesSlice(_, _, _, _, messages, _, _):
                                                apiMessages = messages
                                            case .messagesNotModified:
                                                return Set()
                                        }
                                        var ids = Set<MessageId>()
                                        for message in apiMessages {
                                            if let parsedMessage = StoreMessage(apiMessage: message, namespace: messageNamespace), case let .Id(id) = parsedMessage.id {
                                                if let tag = tag {
                                                    if parsedMessage.tags.contains(tag) {
                                                        ids.insert(id)
                                                    }
                                                } else {
                                                    ids.insert(id)
                                                }
                                            }
                                        }
                                        return Set(maybeRemovedMessageIds).subtracting(ids)
                                    }
                                    |> `catch` { _ -> Signal<Set<MessageId>, NoError> in
                                        return .single(Set(maybeRemovedMessageIds))
                                    }
                                }
                                return .single(Set(maybeRemovedMessageIds))
                            } |> switchToLatest
                        default:
                            actuallyRemovedMessagesSignal = .single(Set(maybeRemovedMessageIds))
                    }
                }
                
                return actuallyRemovedMessagesSignal
                |> mapToSignal { removedMessageIds -> Signal<Void, NoError> in
                    return postbox.transaction { transaction -> Void in
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
                                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
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
                                            
                                            let updatedFlags = StoreMessageFlags(currentMessage.flags)
                                            
                                            return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: updatedFlags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                        }
                                    })
                                    
                                    if previous[id] == nil {
                                        print("\(id) missing")
                                    }
                                } else {
                                    let _ = transaction.addMessages([message], location: .Random)
                                }
                            }
                        }
                        
                        if let tag = tag {
                            for (_, previousMessage) in previous {
                                if !validMessageIds.contains(previousMessage.id) {
                                    transaction.updateMessage(previousMessage.id, update: { currentMessage in
                                        var updatedTags = currentMessage.tags
                                        updatedTags.remove(tag)
                                        var storeForwardInfo: StoreMessageForwardInfo?
                                        if let forwardInfo = currentMessage.forwardInfo {
                                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                                        }
                                        var attributes = currentMessage.attributes
                                        for i in (0 ..< attributes.count).reversed() {
                                            switch historyState {
                                                case .channel:
                                                    if let _ = attributes[i] as? ChannelMessageStateVersionAttribute {
                                                        attributes.remove(at: i)
                                                    }
                                                default:
                                                    break
                                            }
                                        }
                                        switch historyState {
                                            case let .channel(_, channelState):
                                                attributes.append(ChannelMessageStateVersionAttribute(pts: channelState.pts))
                                            default:
                                                break
                                        }
                                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                    })
                                }
                            }
                        }
                    
                        for id in removedMessageIds {
                            if !validMessageIds.contains(id) {
                                if let tag = tag {
                                    transaction.updateMessage(id, update: { currentMessage in
                                        var updatedTags = currentMessage.tags
                                        updatedTags.remove(tag)
                                        var storeForwardInfo: StoreMessageForwardInfo?
                                        if let forwardInfo = currentMessage.forwardInfo {
                                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                                        }
                                        var attributes = currentMessage.attributes
                                        for i in (0 ..< attributes.count).reversed() {
                                            switch historyState {
                                                case .channel:
                                                    if let _ = attributes[i] as? ChannelMessageStateVersionAttribute {
                                                        attributes.remove(at: i)
                                                    }
                                                default:
                                                    break
                                            }
                                        }
                                        switch historyState {
                                            case let .channel(_, channelState):
                                                attributes.append(ChannelMessageStateVersionAttribute(pts: channelState.pts))
                                            default:
                                                break
                                        }
                                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                    })
                                } else {
                                    _internal_deleteMessages(transaction: transaction, mediaBox: postbox.mediaBox, ids: [id])
                                    Logger.shared.log("HistoryValidation", "deleting message \(id) in \(id.peerId)")
                                }
                            }
                        }
                    }
                }
            case .notModified:
                return postbox.transaction { transaction -> Void in
                    for id in previous.keys {
                        transaction.updateMessage(id, update: { currentMessage in
                            var storeForwardInfo: StoreMessageForwardInfo?
                            if let forwardInfo = currentMessage.forwardInfo {
                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                            }
                            var attributes = currentMessage.attributes
                            for i in (0 ..< attributes.count).reversed() {
                                switch historyState {
                                    case .channel:
                                        if let _ = attributes[i] as? ChannelMessageStateVersionAttribute {
                                            attributes.remove(at: i)
                                        }
                                    default:
                                        break
                                }
                            }
                            switch historyState {
                                case let .channel(_, channelState):
                                    attributes.append(ChannelMessageStateVersionAttribute(pts: channelState.pts))
                                default:
                                    break
                            }
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                        })
                    }
                }
        }
    }
}

private func validateReplyThreadBatch(postbox: Postbox, network: Network, transaction: Transaction, accountPeerId: PeerId, peerId: PeerId, threadId: Int64, signal: Signal<ValidatedMessages, MTRpcError>, previous: [MessageId: Message], messageNamespace: MessageId.Namespace) -> Signal<Void, NoError> {
    return signal
    |> map(Optional.init)
    |> `catch` { _ -> Signal<ValidatedMessages?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        guard let result = result else {
            return .complete()
        }
        switch result {
        case let .messages(messages, _, _, channelPts):
            var storeMessages: [StoreMessage] = []
            
            for message in messages {
                if let storeMessage = StoreMessage(apiMessage: message, namespace: messageNamespace) {
                    var attributes = storeMessage.attributes
                    if let channelPts = channelPts {
                        attributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
                    }
                    storeMessages.append(storeMessage.withUpdatedAttributes(attributes))
                }
            }
            
            var validMessageIds = Set<MessageId>()
            for message in storeMessages {
                if case let .Id(id) = message.id {
                    validMessageIds.insert(id)
                }
            }
            
            var maybeRemovedMessageIds: [MessageId] = []
            for id in previous.keys {
                if !validMessageIds.contains(id) {
                    maybeRemovedMessageIds.append(id)
                }
            }
            
            let actuallyRemovedMessagesSignal: Signal<Set<MessageId>, NoError>
            if maybeRemovedMessageIds.isEmpty {
                actuallyRemovedMessagesSignal = .single(Set())
            } else {
                actuallyRemovedMessagesSignal = postbox.transaction { transaction -> Signal<Set<MessageId>, NoError> in
                    if let inputChannel = transaction.getPeer(peerId).flatMap(apiInputChannel) {
                        return network.request(Api.functions.channels.getMessages(channel: inputChannel, id: maybeRemovedMessageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                        |> map { result -> Set<MessageId> in
                            let apiMessages: [Api.Message]
                            switch result {
                                case let .channelMessages(_, _, _, _, messages, _, _):
                                    apiMessages = messages
                                case let .messages(messages, _, _):
                                    apiMessages = messages
                                case let .messagesSlice(_, _, _, _, messages, _, _):
                                    apiMessages = messages
                                case .messagesNotModified:
                                    return Set()
                            }
                            var ids = Set<MessageId>()
                            for message in apiMessages {
                                if let parsedMessage = StoreMessage(apiMessage: message, namespace: messageNamespace), case let .Id(id) = parsedMessage.id {
                                    ids.insert(id)
                                }
                            }
                            return Set(maybeRemovedMessageIds).subtracting(ids)
                        }
                        |> `catch` { _ -> Signal<Set<MessageId>, NoError> in
                            return .single(Set(maybeRemovedMessageIds))
                        }
                    }
                    return .single(Set(maybeRemovedMessageIds))
                }
                |> switchToLatest
            }
            
            return actuallyRemovedMessagesSignal
            |> mapToSignal { removedMessageIds -> Signal<Void, NoError> in
                return postbox.transaction { transaction -> Void in
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
                                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
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
                                        
                                        let updatedFlags = StoreMessageFlags(currentMessage.flags)
                                        
                                        return .update(StoreMessage(id: message.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: updatedFlags, tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                    }
                                })
                                
                                if previous[id] == nil {
                                    print("\(id) missing")
                                }
                            } else {
                                let _ = transaction.addMessages([message], location: .Random)
                            }
                        }
                    }
                
                    for id in removedMessageIds {
                        if !validMessageIds.contains(id) {
                            _internal_deleteMessages(transaction: transaction, mediaBox: postbox.mediaBox, ids: [id])
                            Logger.shared.log("HistoryValidation", "deleting thread message \(id) in \(id.peerId)")
                        }
                    }
                }
            }
        case .notModified:
            return .complete()
        }
    }
}
