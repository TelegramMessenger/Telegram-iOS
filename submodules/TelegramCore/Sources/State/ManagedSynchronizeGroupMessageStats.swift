import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi


private final class ManagedSynchronizeGroupMessageStatsState {
    private var synchronizeDisposables: [PeerGroupAndNamespace: Disposable] = [:]
    
    func clearDisposables() -> [Disposable] {
        let disposables = Array(self.synchronizeDisposables.values)
        self.synchronizeDisposables.removeAll()
        return disposables
    }
    
    func update(operations: Set<PeerGroupAndNamespace>) -> (removed: [Disposable], added: [(PeerGroupAndNamespace, MetaDisposable)]) {
        var removed: [Disposable] = []
        var added: [(PeerGroupAndNamespace, MetaDisposable)] = []
        
        for (groupAndNamespace, disposable) in self.synchronizeDisposables {
            if !operations.contains(groupAndNamespace) {
                removed.append(disposable)
                self.synchronizeDisposables.removeValue(forKey: groupAndNamespace)
            }
        }
        
        for groupAndNamespace in operations {
            if self.synchronizeDisposables[groupAndNamespace] == nil {
                let disposable = MetaDisposable()
                self.synchronizeDisposables[groupAndNamespace] = disposable
                added.append((groupAndNamespace, disposable))
            }
        }
        
        return (removed, added)
    }
}

func managedSynchronizeGroupMessageStats(network: Network, postbox: Postbox, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let state = Atomic(value: ManagedSynchronizeGroupMessageStatsState())
        
        let disposable = postbox.combinedView(keys: [.synchronizeGroupMessageStats]).start(next: { views in
            let (removed, added) = state.with { state -> (removed: [Disposable], added: [(PeerGroupAndNamespace, MetaDisposable)]) in
                let view = views.views[.synchronizeGroupMessageStats] as? SynchronizeGroupMessageStatsView
                return state.update(operations: view?.groupsAndNamespaces ?? Set())
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (groupAndNamespace, disposable) in added {
                let synchronizeOperation = synchronizeGroupMessageStats(postbox: postbox, network: network, groupId: groupAndNamespace.groupId, namespace: groupAndNamespace.namespace)
                disposable.set(synchronizeOperation.start())
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
            for disposable in state.with({ state -> [Disposable] in
                state.clearDisposables()
            }) {
                disposable.dispose()
            }
        }
    }
}

private func synchronizeGroupMessageStats(postbox: Postbox, network: Network, groupId: PeerGroupId, namespace: MessageId.Namespace) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        if namespace != Namespaces.Message.Cloud || groupId == .root {
            transaction.confirmSynchronizedPeerGroupMessageStats(groupId: groupId, namespace: namespace)
            return .complete()
        }
        
        if !transaction.doesChatListGroupContainHoles(groupId: groupId) {
            transaction.recalculateChatListGroupStats(groupId: groupId)
            return .complete()
        }
    
        return network.request(Api.functions.messages.getPeerDialogs(peers: [.inputDialogPeerFolder(folderId: groupId.rawValue)]))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.PeerDialogs?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction in
                if let result = result {
                    switch result {
                    case let .peerDialogs(dialogs, _, _, _, _):
                        for dialog in dialogs {
                            switch dialog {
                                case let .dialogFolder(_, _, _, _, unreadMutedPeersCount, _, unreadMutedMessagesCount, _):
                                    transaction.resetPeerGroupSummary(groupId: groupId, namespace: namespace, summary: PeerGroupUnreadCountersSummary(all: PeerGroupUnreadCounters(messageCount: unreadMutedMessagesCount, chatCount: unreadMutedPeersCount)))
                                case .dialog:
                                    assertionFailure()
                                    break
                            }
                        }
                    }
                }
                transaction.confirmSynchronizedPeerGroupMessageStats(groupId: groupId, namespace: namespace)
            }
        }
    }
    |> switchToLatest
}
