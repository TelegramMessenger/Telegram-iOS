import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


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
        let invalidateKey = PostboxViewKey.invalidatedMessageHistoryTagSummaries(tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud)
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
        let invalidateKey = PostboxViewKey.invalidatedMessageHistoryTagSummaries(tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud)
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
                                        case let .dialog(_, _, topMessage, _, _, _, unreadMentionsCount, _, _, _, _, _):
                                            apiTopMessage = topMessage
                                            apiUnreadMentionsCount = unreadMentionsCount
                                        
                                        case .dialogFolder:
                                            assertionFailure()
                                            return .complete()
                                    }
                                    
                                    return postbox.transaction { transaction -> Void in
                                        transaction.replaceMessageTagSummary(peerId: entry.key.peerId, tagMask: entry.key.tagMask, namespace: entry.key.namespace, count: apiUnreadMentionsCount, maxId: apiTopMessage)
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
                                        case let .dialog(_, _, topMessage, _, _, _, _, unreadReactionsCount, _, _, _, _):
                                            apiTopMessage = topMessage
                                            apiUnreadReactionsCount = unreadReactionsCount
                                        
                                        case .dialogFolder:
                                            assertionFailure()
                                            return .complete()
                                    }
                                    
                                    return postbox.transaction { transaction -> Void in
                                        transaction.replaceMessageTagSummary(peerId: entry.key.peerId, tagMask: entry.key.tagMask, namespace: entry.key.namespace, count: apiUnreadReactionsCount, maxId: apiTopMessage)
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
