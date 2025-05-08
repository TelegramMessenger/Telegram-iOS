import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit
import CryptoUtils

private struct Md5Hash: Hashable {
    public let data: Data
    
    public init(data: Data) {
        precondition(data.count == 16)
        self.data = data
    }
}

private func md5Hash(_ data: Data) -> Md5Hash {
    let hashData = data.withUnsafeBytes { bytes -> Data in
        return CryptoMD5(bytes.baseAddress!, Int32(bytes.count))
    }
    return Md5Hash(data: hashData)
}

func md5StringHash(_ string: String) -> UInt64 {
    guard let data = string.data(using: .utf8) else {
        return 0
    }
    let hash = md5Hash(data).data
    
    return hash.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> UInt64 in
        let bytes = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
        var result: UInt64 = 0
        for i in 0 ... 7 {
            result += UInt64(bitPattern: Int64(bytes[i])) << (56 - 8 * i)
        }
        return result
    }
}

private final class ManagedConsumePersonalMessagesActionsHelper {
    var operationDisposables: [MessageId: Disposable] = [:]
    var validateDisposables: [InvalidatedMessageHistoryTagsSummaryEntry: Disposable] = [:]
    
    func update(entries: [PendingMessageActionsEntry], invalidateEntries: Set<InvalidatedMessageHistoryTagsSummaryEntry>) -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)], beginValidateOperations: [(InvalidatedMessageHistoryTagsSummaryEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PendingMessageActionsEntry, MetaDisposable)] = []
        var beginValidateOperations: [(InvalidatedMessageHistoryTagsSummaryEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validIds = Set<MessageId>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.id.peerId) {
                hasRunningOperationForPeerId.insert(entry.id.peerId)
                validIds.insert(entry.id)
                
                if self.operationDisposables[entry.id] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.id] = disposable
                }
            }
        }
        
        var removeMergedIds: [MessageId] = []
        for (id, disposable) in self.operationDisposables {
            if !validIds.contains(id) {
                removeMergedIds.append(id)
                disposeOperations.append(disposable)
            }
        }
        
        for id in removeMergedIds {
            self.operationDisposables.removeValue(forKey: id)
        }
        
        var validInvalidateEntries = Set<InvalidatedMessageHistoryTagsSummaryEntry>()
        
        for entry in invalidateEntries {
            if !hasRunningOperationForPeerId.contains(entry.key.peerId) {
                validInvalidateEntries.insert(entry)
                if self.validateDisposables[entry] == nil {
                    let disposable = MetaDisposable()
                    beginValidateOperations.append((entry, disposable))
                    self.validateDisposables[entry] = disposable
                }
            }
        }
        
        var removeValidateEntries: [InvalidatedMessageHistoryTagsSummaryEntry] = []
        for (entry, disposable) in self.validateDisposables {
            if !validInvalidateEntries.contains(entry) {
                removeValidateEntries.append(entry)
                disposeOperations.append(disposable)
            }
        }
        
        for entry in removeValidateEntries {
            self.validateDisposables.removeValue(forKey: entry)
        }
        
        return (disposeOperations, beginOperations, beginValidateOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenAction<T: PendingMessageActionData>(postbox: Postbox, type: PendingMessageActionType, actionType: T.Type, id: MessageId, _ f: @escaping (Transaction, PendingMessageActionsEntry?) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var result: PendingMessageActionsEntry?
        
        if let action = transaction.getPendingMessageAction(type: type, id: id) as? T {
            result = PendingMessageActionsEntry(id: id, action: action)
        }
        
        return f(transaction, result)
    } |> switchToLatest
}

func managedConsumePersonalMessagesActions(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedConsumePersonalMessagesActionsHelper>(value: ManagedConsumePersonalMessagesActionsHelper())
        
        let actionsKey = PostboxViewKey.pendingMessageActions(type: .consumeUnseenPersonalMessage)
        let invalidateKey = PostboxViewKey.invalidatedMessageHistoryTagSummaries(peerId: nil, threadId: nil, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud)
        let disposable = postbox.combinedView(keys: [actionsKey, invalidateKey]).start(next: { view in
            var entries: [PendingMessageActionsEntry] = []
            var invalidateEntries = Set<InvalidatedMessageHistoryTagsSummaryEntry>()
            if let v = view.views[actionsKey] as? PendingMessageActionsView {
                entries = v.entries
            }
            if let v = view.views[invalidateKey] as? InvalidatedMessageHistoryTagSummariesView {
                invalidateEntries = v.entries
            }
            
            let (disposeOperations, beginOperations, beginValidateOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)], beginValidateOperations: [(InvalidatedMessageHistoryTagsSummaryEntry, MetaDisposable)]) in
                return helper.update(entries: entries, invalidateEntries: invalidateEntries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenAction(postbox: postbox, type: .consumeUnseenPersonalMessage, actionType: ConsumePersonalMessageAction.self, id: entry.id, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let _ = entry.action as? ConsumePersonalMessageAction {
                            return synchronizeConsumeMessageContents(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, id: entry.id)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: entry.id, action: nil)
                })
                
                disposable.set(signal.start())
            }
            
            for (entry, disposable) in beginValidateOperations {
                let signal = synchronizeUnseenPersonalMentionsTag(postbox: postbox, network: network, entry: entry)
                |> then(postbox.transaction { transaction -> Void in
                    transaction.removeInvalidatedMessageHistoryTagsSummaryEntry(entry)
                })
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

func managedReadReactionActions(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedConsumePersonalMessagesActionsHelper>(value: ManagedConsumePersonalMessagesActionsHelper())
        
        let actionsKey = PostboxViewKey.pendingMessageActions(type: .readReaction)
        let invalidateKey = PostboxViewKey.invalidatedMessageHistoryTagSummaries(peerId: nil, threadId: nil, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud)
        let disposable = postbox.combinedView(keys: [actionsKey, invalidateKey]).start(next: { view in
            var entries: [PendingMessageActionsEntry] = []
            var invalidateEntries = Set<InvalidatedMessageHistoryTagsSummaryEntry>()
            if let v = view.views[actionsKey] as? PendingMessageActionsView {
                entries = v.entries
            }
            if let v = view.views[invalidateKey] as? InvalidatedMessageHistoryTagSummariesView {
                invalidateEntries = v.entries
            }
            
            let (disposeOperations, beginOperations, beginValidateOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)], beginValidateOperations: [(InvalidatedMessageHistoryTagsSummaryEntry, MetaDisposable)]) in
                return helper.update(entries: entries, invalidateEntries: invalidateEntries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenAction(postbox: postbox, type: .readReaction, actionType: ReadReactionAction.self, id: entry.id, { transaction, entry -> Signal<Void, NoError> in
                    if let entry = entry {
                        if let _ = entry.action as? ReadReactionAction {
                            return synchronizeReadMessageReactions(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, id: entry.id)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .readReaction, id: entry.id, action: nil)
                })
                
                disposable.set(signal.start())
            }
            
            for (entry, disposable) in beginValidateOperations {
                let signal = synchronizeUnseenReactionsTag(postbox: postbox, network: network, entry: entry)
                |> then(postbox.transaction { transaction -> Void in
                    transaction.removeInvalidatedMessageHistoryTagsSummaryEntry(entry)
                })
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

private func synchronizeConsumeMessageContents(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Void, NoError> {
    if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
        return network.request(Api.functions.messages.readMessageContents(id: [id.id]))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Void, NoError> in
                if let result = result {
                    switch result {
                        case let .affectedMessages(pts, ptsCount):
                            stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                    }
                }
                return postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: nil)
                    transaction.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                        }
                        var attributes = currentMessage.attributes
                        loop: for j in 0 ..< attributes.count {
                            if let attribute = attributes[j] as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed {
                                attributes[j] = ConsumablePersonalMentionMessageAttribute(consumed: true, pending: false)
                                break loop
                            }
                        }
                        var updatedTags = currentMessage.tags
                        updatedTags.remove(.unseenPersonalMessage)
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                    })
                }
            }
    } else if id.peerId.namespace == Namespaces.Peer.CloudChannel {
        if let peer = transaction.getPeer(id.peerId), let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.readMessageContents(channel: inputChannel, id: [id.id]))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                } |> mapToSignal { result -> Signal<Void, NoError> in
                    return postbox.transaction { transaction -> Void in
                        transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: nil)
                        transaction.updateMessage(id, update: { currentMessage in
                            var storeForwardInfo: StoreMessageForwardInfo?
                            if let forwardInfo = currentMessage.forwardInfo {
                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                            }
                            var attributes = currentMessage.attributes
                            loop: for j in 0 ..< attributes.count {
                                if let attribute = attributes[j] as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed {
                                    attributes[j] = ConsumablePersonalMentionMessageAttribute(consumed: true, pending: false)
                                    break loop
                                }
                            }
                            var updatedTags = currentMessage.tags
                            updatedTags.remove(.unseenPersonalMessage)
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                        })
                    }
                }
        } else {
            return .complete()
        }
    } else {
        return .complete()
    }
}

private func synchronizeReadMessageReactions(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Void, NoError> {
    if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
        return network.request(Api.functions.messages.readMessageContents(id: [id.id]))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Void, NoError> in
            if let result = result {
                switch result {
                    case let .affectedMessages(pts, ptsCount):
                        stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                }
            }
            return postbox.transaction { transaction -> Void in
                transaction.setPendingMessageAction(type: .readReaction, id: id, action: nil)
                transaction.updateMessage(id, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    var attributes = currentMessage.attributes
                    loop: for j in 0 ..< attributes.count {
                        if let attribute = attributes[j] as? ReactionsMessageAttribute, attribute.hasUnseen {
                            attributes[j] = attribute.withAllSeen()
                            break loop
                        }
                    }
                    var updatedTags = currentMessage.tags
                    updatedTags.remove(.unseenReaction)
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
            }
        }
    } else if id.peerId.namespace == Namespaces.Peer.CloudChannel {
        if let peer = transaction.getPeer(id.peerId), let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.readMessageContents(channel: inputChannel, id: [id.id]))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { result -> Signal<Void, NoError> in
                return postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .readReaction, id: id, action: nil)
                    transaction.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                        }
                        var attributes = currentMessage.attributes
                        loop: for j in 0 ..< attributes.count {
                            if let attribute = attributes[j] as? ReactionsMessageAttribute, attribute.hasUnseen {
                                attributes[j] = attribute.withAllSeen()
                                break loop
                            }
                        }
                        var updatedTags = currentMessage.tags
                        updatedTags.remove(.unseenReaction)
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                    })
                }
            }
        } else {
            return .complete()
        }
    } else {
        return .complete()
    }
}

private func synchronizeUnseenPersonalMentionsTag(postbox: Postbox, network: Network, entry: InvalidatedMessageHistoryTagsSummaryEntry) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(entry.key.peerId), let inputPeer = apiInputPeer(peer) {
            return network.request(Api.functions.messages.getPeerDialogs(peers: [.inputDialogPeer(peer: inputPeer)]))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.PeerDialogs?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if let result = result {
                        switch result {
                            case let .peerDialogs(dialogs, _, _, _, _):
                                if let dialog = dialogs.filter({ $0.peerId == entry.key.peerId }).first {
                                    let apiTopMessage: Int32
                                    let apiUnreadMentionsCount: Int32
                                    switch dialog {
                                        case let .dialog(_, _, topMessage, _, _, _, unreadMentionsCount, _, _, _, _, _, _):
                                            apiTopMessage = topMessage
                                            apiUnreadMentionsCount = unreadMentionsCount
                                        
                                        case .dialogFolder:
                                            assertionFailure()
                                            return .complete()
                                    }
                                    
                                    return postbox.transaction { transaction -> Void in
                                        transaction.replaceMessageTagSummary(peerId: entry.key.peerId, threadId: nil, tagMask: entry.key.tagMask, namespace: entry.key.namespace, customTag: nil, count: apiUnreadMentionsCount, maxId: apiTopMessage)
                                    }
                                } else {
                                    return .complete()
                                }
                        }
                    } else {
                        return .complete()
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

private func synchronizeUnseenReactionsTag(postbox: Postbox, network: Network, entry: InvalidatedMessageHistoryTagsSummaryEntry) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(entry.key.peerId), let inputPeer = apiInputPeer(peer) {
            return network.request(Api.functions.messages.getPeerDialogs(peers: [.inputDialogPeer(peer: inputPeer)]))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.PeerDialogs?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if let result = result {
                        switch result {
                            case let .peerDialogs(dialogs, _, _, _, _):
                                if let dialog = dialogs.filter({ $0.peerId == entry.key.peerId }).first {
                                    let apiTopMessage: Int32
                                    let apiUnreadReactionsCount: Int32
                                    switch dialog {
                                        case let .dialog(_, _, topMessage, _, _, _, _, unreadReactionsCount, _, _, _, _, _):
                                            apiTopMessage = topMessage
                                            apiUnreadReactionsCount = unreadReactionsCount
                                        
                                        case .dialogFolder:
                                            assertionFailure()
                                            return .complete()
                                    }
                                    
                                    return postbox.transaction { transaction -> Void in
                                        transaction.replaceMessageTagSummary(peerId: entry.key.peerId, threadId: nil, tagMask: entry.key.tagMask, namespace: entry.key.namespace, customTag: nil, count: apiUnreadReactionsCount, maxId: apiTopMessage)
                                    }
                                } else {
                                    return .complete()
                                }
                        }
                    } else {
                        return .complete()
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

func managedSynchronizeMessageHistoryTagSummaries(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, threadId: Int64?) -> Signal<Void, NoError> {
    let accountPeerId = stateManager.accountPeerId
    
    return Signal { _ in
        let helper = Atomic<ManagedConsumePersonalMessagesActionsHelper>(value: ManagedConsumePersonalMessagesActionsHelper())
        
        let invalidateKey = PostboxViewKey.invalidatedMessageHistoryTagSummaries(peerId: peerId, threadId: threadId, tagMask: MessageTags(rawValue: 0), namespace: Namespaces.Message.Cloud)
        let disposable = postbox.combinedView(keys: [invalidateKey]).start(next: { view in
            var invalidateEntries = Set<InvalidatedMessageHistoryTagsSummaryEntry>()
            if let v = view.views[invalidateKey] as? InvalidatedMessageHistoryTagSummariesView {
                invalidateEntries = v.entries
            }
            if invalidateEntries.contains(where: { $0.key.customTag != nil }) {
                invalidateEntries = invalidateEntries.filter({ $0.key.customTag == nil })
                invalidateEntries.insert(InvalidatedMessageHistoryTagsSummaryEntry(key: InvalidatedMessageHistoryTagsSummaryKey(peerId: peerId, namespace: Namespaces.Message.Cloud, tagMask: [], threadId: threadId, customTag: MemoryBuffer()), version: 0))
            }
            
            let (disposeOperations, _, beginValidateOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)], beginValidateOperations: [(InvalidatedMessageHistoryTagsSummaryEntry, MetaDisposable)]) in
                return helper.update(entries: [], invalidateEntries: invalidateEntries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginValidateOperations {
                if entry.key.customTag != nil {
                    if peerId == stateManager.accountPeerId {
                        let signal = synchronizeSavedMessageTags(postbox: postbox, network: network, peerId: peerId, threadId: entry.key.threadId, force: false)
                        |> map { _ -> Void in
                        }
                        |> then(postbox.transaction { transaction -> Void in
                            transaction.removeInvalidatedMessageHistoryTagsSummaryEntriesWithCustomTags(peerId: peerId, threadId: entry.key.threadId, namespace: Namespaces.Message.Cloud, tagMask: [])
                        })
                        disposable.set(signal.start())
                    } else {
                        assertionFailure()
                        let signal = postbox.transaction { transaction -> Void in
                            transaction.removeInvalidatedMessageHistoryTagsSummaryEntriesWithCustomTags(peerId: peerId, threadId: entry.key.threadId, namespace: Namespaces.Message.Cloud, tagMask: [])
                        }
                        disposable.set(signal.start())
                    }
                } else {
                    let signal = synchronizeMessageHistoryTagSummary(accountPeerId: accountPeerId, postbox: postbox, network: network, entry: entry)
                    |> then(postbox.transaction { transaction -> Void in
                        transaction.removeInvalidatedMessageHistoryTagsSummaryEntry(entry)
                    })
                    disposable.set(signal.start())
                }
            }
        })
        
        return ActionDisposable {
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

private func synchronizeMessageHistoryTagSummary(accountPeerId: PeerId, postbox: Postbox, network: Network, entry: InvalidatedMessageHistoryTagsSummaryEntry) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if let threadId = entry.key.threadId {
            if let peer = transaction.getPeer(entry.key.peerId) as? TelegramChannel, peer.flags.contains(.isForum), !peer.flags.contains(.isMonoforum), let inputPeer = apiInputPeer(peer) {
                return network.request(Api.functions.messages.getReplies(peer: inputPeer, msgId: Int32(clamping: threadId), offsetId: 0, offsetDate: 0, addOffset: 0, limit: 1, maxId: 0, minId: 0, hash: 0))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    guard let result = result else {
                        return .complete()
                    }
                    return postbox.transaction { transaction -> Void in
                        switch result {
                        case let .channelMessages(_, _, count, _, messages, _, _, _):
                            let topId: Int32 = messages.first?.id(namespace: Namespaces.Message.Cloud)?.id ?? 1
                            transaction.replaceMessageTagSummary(peerId: entry.key.peerId, threadId: threadId, tagMask: entry.key.tagMask, namespace: entry.key.namespace, customTag: nil, count: count, maxId: topId)
                        default:
                            break
                        }
                    }
                }
            } else {
                return .complete()
            }
        } else {
            if entry.key.peerId != accountPeerId {
                return .single(Void())
            }
            
            if let peer = transaction.getPeer(entry.key.peerId), let inputPeer = apiInputPeer(peer) {
                return network.request(Api.functions.messages.search(flags: 0, peer: inputPeer, q: "", fromId: nil, savedPeerId: nil, savedReaction: nil, topMsgId: nil, filter: .inputMessagesFilterEmpty, minDate: 0, maxDate: 0, offsetId: 0, addOffset: 0, limit: 1, maxId: 0, minId: 0, hash: 0))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return postbox.transaction { transaction -> Void in
                        if let result {
                            let apiMessages: [Api.Message]
                            let apiCount: Int32
                            switch result {
                            case let .channelMessages(_, _, count, _, messages, _, _, _):
                                apiMessages = messages
                                apiCount = count
                            case let .messages(messages, _, _):
                                apiMessages = messages
                                apiCount = Int32(messages.count)
                            case let .messagesNotModified(count):
                                apiMessages = []
                                apiCount = count
                            case let .messagesSlice(_, count, _, _, messages, _, _):
                                apiMessages = messages
                                apiCount = count
                            }
                            
                            let topMessageId = apiMessages.first?.id(namespace: Namespaces.Message.Cloud)?.id ?? 1
                            transaction.replaceMessageTagSummary(peerId: entry.key.peerId, threadId: nil, tagMask: entry.key.tagMask, namespace: entry.key.namespace, customTag: nil, count: apiCount, maxId: topMessageId)
                        }
                    }
                }
            } else {
                return .complete()
            }
        }
    }
    |> switchToLatest
}

func synchronizeSavedMessageTags(postbox: Postbox, network: Network, peerId: PeerId, threadId: Int64?, force: Bool) -> Signal<Never, NoError> {
    let key: PostboxViewKey = .pendingMessageActions(type: .updateReaction)
    let waitForApplySignal: Signal<Never, NoError> = postbox.combinedView(keys: [key])
    |> map { views -> Bool in
        guard let view = views.views[key] as? PendingMessageActionsView else {
            return false
        }
        
        for entry in view.entries {
            if entry.id.peerId == peerId {
                return false
            }
        }
        
        return true
    }
    |> filter { $0 }
    |> take(1)
    |> ignoreValues
    
    let updateSignal: Signal<Never, NoError> = (postbox.transaction { transaction -> (Bool, Peer?, Int64) in
        struct HashableTag {
            var titleId: UInt64?
            var count: Int
            var id: UInt64
            
            init(titleId: UInt64?, count: Int, id: UInt64) {
                self.titleId = titleId
                self.count = count
                self.id = id
            }
        }
        
        let savedTags = _internal_savedMessageTags(transaction: transaction)
        
        var hashableTags: [HashableTag] = []
        for tag in transaction.getMessageTagSummaryCustomTags(peerId: peerId, threadId: threadId, tagMask: [], namespace: Namespaces.Message.Cloud) {
            if let summary = transaction.getMessageTagSummary(peerId: peerId, threadId: threadId, tagMask: [], namespace: Namespaces.Message.Cloud, customTag: tag), summary.count > 0 {
                guard let reaction = ReactionsMessageAttribute.reactionFromMessageTag(tag: tag) else {
                    continue
                }
                
                var tagTitle: String?
                if threadId == nil, let savedTags {
                    if let value = savedTags.tags.first(where: { $0.reaction == reaction }) {
                        tagTitle = value.title
                    }
                }
                
                let reactionId: UInt64
                switch reaction {
                case let .custom(id):
                    reactionId = UInt64(bitPattern: id)
                case let .builtin(string):
                    reactionId = md5StringHash(string)
                case .stars:
                    reactionId = md5StringHash("star")
                }
                
                var titleId: UInt64?
                if let tagTitle {
                    titleId = md5StringHash(tagTitle)
                }
                
                hashableTags.append(HashableTag(
                    titleId: titleId,
                    count: Int(summary.count),
                    id: reactionId
                ))
            }
        }
        
        hashableTags.sort(by: { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.id < rhs.id
        })
        
        var hashIds: [UInt64] = []
        for tag in hashableTags {
            hashIds.append(tag.id)
            if let titleId = tag.titleId {
                hashIds.append(titleId)
            }
            hashIds.append(UInt64(tag.count))
        }
        
        var hashAcc: UInt64 = 0
        for id in hashIds {
            combineInt64Hash(&hashAcc, with: id)
        }
        
        return (
            transaction.getPreferencesEntry(key: PreferencesKeys.didCacheSavedMessageTags(threadId: threadId)) != nil,
            threadId.flatMap { transaction.getPeer(PeerId($0)) },
            Int64(bitPattern: hashAcc)
        )
    }
    |> mapToSignal { alreadyCached, subPeer, currentHash -> Signal<Never, NoError> in
        if alreadyCached && !force {
            return .complete()
        }
        
        let inputSubPeer = subPeer.flatMap(apiInputPeer)
        if threadId != nil && inputSubPeer == nil {
            return .complete()
        }
        
        var flags: Int32 = 0
        if inputSubPeer != nil {
            flags |= 1 << 0
        }
        
        return network.request(Api.functions.messages.getSavedReactionTags(flags: flags, peer: inputSubPeer, hash: currentHash))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.SavedReactionTags?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result = result else {
                return .complete()
            }
            
            switch result {
            case .savedReactionTagsNotModified:
                return postbox.transaction { transaction -> Void in
                    transaction.setPreferencesEntry(key: PreferencesKeys.didCacheSavedMessageTags(threadId: threadId), value: PreferencesEntry(data: Data()))
                }
                |> ignoreValues
            case let .savedReactionTags(tags, _):
                var customFileIds: [Int64] = []
                var parsedTags: [SavedMessageTags.Tag] = []
                for tag in tags {
                    switch tag {
                    case let .savedReactionTag(_, reaction, title, count):
                        guard let reaction = MessageReaction.Reaction(apiReaction: reaction) else {
                            continue
                        }
                        parsedTags.append(SavedMessageTags.Tag(
                            reaction: reaction,
                            title: title,
                            count: Int(count)
                        ))
                        
                        if case let .custom(fileId) = reaction {
                            customFileIds.append(fileId)
                        }
                    }
                }
                
                return postbox.transaction { transaction -> Void in
                    if threadId == nil {
                        _internal_setSavedMessageTags(transaction: transaction, savedMessageTags: SavedMessageTags(
                            hash: 0,
                            tags: parsedTags
                        ))
                    }
                    
                    let previousTags = transaction.getMessageTagSummaryCustomTags(peerId: peerId, threadId: threadId, tagMask: [], namespace: Namespaces.Message.Cloud)
                    
                    let topMessageId = transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud)?.id ?? 1
                    
                    var validTags: [MemoryBuffer] = []
                    for tag in parsedTags {
                        let customTag = ReactionsMessageAttribute.messageTag(reaction: tag.reaction)
                        validTags.append(customTag)
                        transaction.replaceMessageTagSummary(peerId: peerId, threadId: threadId, tagMask: [], namespace: Namespaces.Message.Cloud, customTag: customTag, count: Int32(tag.count), maxId: topMessageId)
                    }
                    for tag in previousTags {
                        if !validTags.contains(tag) {
                            transaction.replaceMessageTagSummary(peerId: peerId, threadId: threadId, tagMask: [], namespace: Namespaces.Message.Cloud, customTag: tag, count: 0, maxId: topMessageId)
                        }
                    }
                    
                    transaction.setPreferencesEntry(key: PreferencesKeys.didCacheSavedMessageTags(threadId: threadId), value: PreferencesEntry(data: Data()))
                }
                |> ignoreValues
            }
        }
    })
    
    return waitForApplySignal |> then(updateSignal |> delay(1.0, queue: .concurrentDefaultQueue()))
}
