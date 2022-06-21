import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi


func _internal_sendScheduledMessageNowInteractively(postbox: Postbox, messageId: MessageId) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.setPendingMessageAction(type: .sendScheduledMessageImmediately, id: messageId, action: SendScheduledMessageImmediatelyAction())
    }
    |> ignoreValues
}

private final class ManagedApplyPendingScheduledMessagesActionsHelper {
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
        
        if let action = transaction.getPendingMessageAction(type: type, id: id) as? SendScheduledMessageImmediatelyAction {
            result = PendingMessageActionsEntry(id: id, action: action)
        }
        
        return f(transaction, result)
    }
    |> switchToLatest
}

func managedApplyPendingScheduledMessagesActions(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic<ManagedApplyPendingScheduledMessagesActionsHelper>(value: ManagedApplyPendingScheduledMessagesActionsHelper())
        
        let actionsKey = PostboxViewKey.pendingMessageActions(type: .sendScheduledMessageImmediately)
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
                let signal = withTakenAction(postbox: postbox, type: .sendScheduledMessageImmediately, id: entry.id, { transaction, entry -> Signal<Never, NoError> in
                    if let entry = entry {
                        if let _ = entry.action as? SendScheduledMessageImmediatelyAction {
                            return sendScheduledMessageNow(postbox: postbox, network: network, stateManager: stateManager, messageId: entry.id)
                            |> `catch` { _ -> Signal<Never, NoError> in
                                return .complete()
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(
                    postbox.transaction { transaction -> Void in
                        var resourceIds: [MediaResourceId] = []
                        transaction.deleteMessages([entry.id], forEachMedia: { media in
                            addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
                        })
                        if !resourceIds.isEmpty {
                            let _ = postbox.mediaBox.removeCachedResources(Set(resourceIds)).start()
                        }
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

private enum SendScheduledMessageNowError {
    case generic
}

private func sendScheduledMessageNow(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId) -> Signal<Never, SendScheduledMessageNowError> {
    return postbox.transaction { transaction -> Peer? in
        guard let peer = transaction.getPeer(messageId.peerId) else {
            return nil
        }
        return peer
    }
    |> castError(SendScheduledMessageNowError.self)
    |> mapToSignal { peer -> Signal<Never, SendScheduledMessageNowError> in
        guard let peer = peer else {
            return .fail(.generic)
        }
        guard let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        return network.request(Api.functions.messages.sendScheduledMessages(peer: inputPeer, id: [messageId.id]))
        |> mapError { _ -> SendScheduledMessageNowError in
            return .generic
        }
        |> mapToSignal { updates -> Signal<Never, SendScheduledMessageNowError> in
            stateManager.addUpdates(updates)
            return .complete()
        }
    }
}
