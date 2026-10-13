import Foundation
import Postbox
import SwiftSignalKit

private final class WalletTransferStoreMessageAction: StoreOrUpdateMessageAction {
    let id: MessageId

    init(id: MessageId) {
        self.id = id
    }

    func addOrUpdate(messages: [StoreMessage], transaction: Transaction) {
        guard let pending = transaction.getPendingMessageAction(type: .walletTransfer, id: self.id) as? PendingWalletTransferMessageAttribute,
              messages.contains(where: { walletTransferMessageMatches($0, peerId: self.id.peerId, pending: pending) }) else {
            return
        }
        reconcileStoredWalletTransferMessage(transaction: transaction, id: self.id, pending: pending)
    }
}

private func managedPendingWalletTransferMessage(postbox: Postbox, id: MessageId, pending: PendingWalletTransferMessageAttribute) -> Disposable {
    let disposables = DisposableSet()
    disposables.add(postbox.installStoreOrUpdateMessageAction(peerId: id.peerId, action: WalletTransferStoreMessageAction(id: id)))
    disposables.add(postbox.transaction { transaction in
        guard let current = transaction.getPendingMessageAction(type: .walletTransfer, id: id) as? PendingWalletTransferMessageAttribute else {
            return
        }
        if current.expiresAt <= Int32(clamping: Int64(Date().timeIntervalSince1970)) {
            removePendingWalletTransferMessage(transaction: transaction, id: id)
        } else {
            reconcileStoredWalletTransferMessage(transaction: transaction, id: id, pending: current)
        }
    }.start())

    let remaining = max(0.0, Double(pending.expiresAt) - Date().timeIntervalSince1970)
    disposables.add((Signal<Void, NoError>.single(Void())
    |> delay(remaining, queue: Queue.concurrentDefaultQueue())
    |> mapToSignal { _ in
        return postbox.transaction { transaction in
            if let current = transaction.getPendingMessageAction(type: .walletTransfer, id: id) as? PendingWalletTransferMessageAttribute,
               current.expiresAt <= Int32(clamping: Int64(Date().timeIntervalSince1970)) {
                removePendingWalletTransferMessage(transaction: transaction, id: id)
            }
        }
    }).start())

    return disposables
}

private final class PendingWalletTransferMessagesHelper {
    var operations: [MessageId: (PendingWalletTransferMessageAttribute, MetaDisposable)] = [:]

    func update(_ entries: [PendingMessageActionsEntry]) -> (dispose: [Disposable], start: [(MessageId, PendingWalletTransferMessageAttribute, MetaDisposable)]) {
        var dispose: [Disposable] = []
        var start: [(MessageId, PendingWalletTransferMessageAttribute, MetaDisposable)] = []
        let validIds = Set(entries.map(\.id))
        for id in Array(self.operations.keys) where !validIds.contains(id) {
            if let previous = self.operations.removeValue(forKey: id) {
                dispose.append(previous.1)
            }
        }
        for entry in entries {
            guard let pending = entry.action as? PendingWalletTransferMessageAttribute else {
                continue
            }
            if let previous = self.operations[entry.id] {
                if previous.0.isEqual(to: pending) {
                    continue
                }
                dispose.append(previous.1)
            }
            let disposable = MetaDisposable()
            self.operations[entry.id] = (pending, disposable)
            start.append((entry.id, pending, disposable))
        }
        return (dispose, start)
    }
}

func managedPendingWalletTransferMessages(postbox: Postbox) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic(value: PendingWalletTransferMessagesHelper())
        let key = PostboxViewKey.pendingMessageActions(type: .walletTransfer)
        let disposable = postbox.combinedView(keys: [key]).start(next: { views in
            guard let view = views.views[key] as? PendingMessageActionsView else {
                return
            }
            let changes = helper.with { $0.update(view.entries) }
            for disposable in changes.dispose {
                disposable.dispose()
            }
            for (id, pending, disposable) in changes.start {
                disposable.set(managedPendingWalletTransferMessage(postbox: postbox, id: id, pending: pending))
            }
        })
        return ActionDisposable {
            disposable.dispose()
            for disposable in helper.with({ $0.update([]).dispose }) {
                disposable.dispose()
            }
        }
    }
}
