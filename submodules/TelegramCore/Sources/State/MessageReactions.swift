import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public func updateMessageReactionsInteractively(postbox: Postbox, messageId: MessageId, reaction: String?) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.setPendingMessageAction(type: .updateReaction, id: messageId, action: UpdateMessageReactionsAction())
        transaction.updateMessage(messageId, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var attributes = currentMessage.attributes
            loop: for j in 0 ..< attributes.count {
                if let _ = attributes[j] as? PendingReactionsMessageAttribute {
                    attributes.remove(at: j)
                    break loop
                }
            }
            attributes.append(PendingReactionsMessageAttribute(value: reaction))
            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
    }
    |> ignoreValues
}

private enum RequestUpdateMessageReactionError {
    case generic
}

private func requestUpdateMessageReaction(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId) -> Signal<Never, RequestUpdateMessageReactionError> {
    return .complete()
    /*return postbox.transaction { transaction -> (Peer, String?)? in
        guard let peer = transaction.getPeer(messageId.peerId) else {
            return nil
        }
        guard let message = transaction.getMessage(messageId) else {
            return nil
        }
        var value: String?
        for attribute in message.attributes {
            if let attribute = attribute as? PendingReactionsMessageAttribute {
                value = attribute.value
                break
            }
        }
        return (peer, value)
    }
    |> castError(RequestUpdateMessageReactionError.self)
    |> mapToSignal { peerAndValue in
        guard let (peer, value) = peerAndValue else {
            return .fail(.generic)
        }
        guard let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        if messageId.namespace != Namespaces.Message.Cloud {
            return .fail(.generic)
        }
        return network.request(Api.functions.messages.sendReaction(flags: value == nil ? 0 : 1, peer: inputPeer, msgId: messageId.id, reaction: value))
        |> mapError { _ -> RequestUpdateMessageReactionError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, RequestUpdateMessageReactionError> in
            return postbox.transaction { transaction -> Void in
                transaction.setPendingMessageAction(type: .updateReaction, id: messageId, action: UpdateMessageReactionsAction())
                transaction.updateMessage(messageId, update: { currentMessage in
                    var storeForwardInfo: StoreMessageForwardInfo?
                    if let forwardInfo = currentMessage.forwardInfo {
                        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                    }
                    let reactions = mergedMessageReactions(attributes: currentMessage.attributes)
                    var attributes = currentMessage.attributes
                    for j in (0 ..< attributes.count).reversed() {
                        if attributes[j] is PendingReactionsMessageAttribute || attributes[j] is ReactionsMessageAttribute {
                            attributes.remove(at: j)
                        }
                    }
                    if let reactions = reactions {
                        attributes.append(reactions)
                    }
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
                stateManager.addUpdates(result)
            }
            |> castError(RequestUpdateMessageReactionError.self)
            |> ignoreValues
        }
    }*/
}

private final class ManagedApplyPendingMessageReactionsActionsHelper {
    var operationDisposables: [MessageId: Disposable] = [:]
    
    func update(entries: [PendingMessageActionsEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PendingMessageActionsEntry, MetaDisposable)] = []
        
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
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenAction(postbox: Postbox, type: PendingMessageActionType, id: MessageId, _ f: @escaping (Transaction, PendingMessageActionsEntry?) -> Signal<Never, NoError>) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        var result: PendingMessageActionsEntry?
        
        if let action = transaction.getPendingMessageAction(type: type, id: id) as? UpdateMessageReactionsAction {
            result = PendingMessageActionsEntry(id: id, action: action)
        }
        
        return f(transaction, result)
    }
    |> switchToLatest
}

func managedApplyPendingMessageReactionsActions(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedApplyPendingMessageReactionsActionsHelper>(value: ManagedApplyPendingMessageReactionsActionsHelper())
        
        let actionsKey = PostboxViewKey.pendingMessageActions(type: .updateReaction)
        let disposable = postbox.combinedView(keys: [actionsKey]).start(next: { view in
            var entries: [PendingMessageActionsEntry] = []
            if let v = view.views[actionsKey] as? PendingMessageActionsView {
                entries = v.entries
            }
            
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PendingMessageActionsEntry, MetaDisposable)]) in
                return helper.update(entries: entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenAction(postbox: postbox, type: .updateReaction, id: entry.id, { transaction, entry -> Signal<Never, NoError> in
                    if let entry = entry {
                        if let _ = entry.action as? UpdateMessageReactionsAction {
                            return synchronizeMessageReactions(transaction: transaction, postbox: postbox, network: network, stateManager: stateManager, id: entry.id)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(
                    postbox.transaction { transaction -> Void in
                    transaction.setPendingMessageAction(type: .updateReaction, id: entry.id, action: nil)
                    }
                    |> ignoreValues
                )
                
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

private func synchronizeMessageReactions(transaction: Transaction, postbox: Postbox, network: Network, stateManager: AccountStateManager, id: MessageId) -> Signal<Never, NoError> {
    return requestUpdateMessageReaction(postbox: postbox, network: network, stateManager: stateManager, messageId: id)
    |> `catch` { _ -> Signal<Never, NoError> in
        return postbox.transaction { transaction -> Void in
            transaction.setPendingMessageAction(type: .updateReaction, id: id, action: nil)
            transaction.updateMessage(id, update: { currentMessage in
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                var attributes = currentMessage.attributes
                loop: for j in 0 ..< attributes.count {
                    if let _ = attributes[j] as? PendingReactionsMessageAttribute {
                        attributes.remove(at: j)
                        break loop
                    }
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
        }
        |> ignoreValues
    }
}
