import Foundation
import Postbox
import SwiftSignalKit

private let hiddenChatSweepStartDelay: Double = 90.0
private let hiddenChatSweepBatchPeerCount = 500
private let hiddenChatSweepBatchPause: Double = 0.05

func supportHiddenChatSweepFolderPeerIds(transaction: Transaction) -> Set<PeerId> {
    var result = Set<PeerId>()
    for filter in _internal_currentChatListFilters(transaction: transaction) {
        if case let .filter(_, _, _, data) = filter {
            result.formUnion(data.includePeers.peers)
            result.formUnion(data.includePeers.pinnedPeers)
        }
    }
    return result
}

/// A one-to-one chat out of the list that still stores messages: an account reset hid it and put a hole over it. The
/// next reset leaves such chats alone (`supportAccountResetChat`), so their history is dropped as for a chat never seen.
func supportHiddenChatSweepClearsChat(transaction: Transaction, peerId: PeerId, accountPeerId: PeerId, folderPeerIds: Set<PeerId>) -> Bool {
    if peerId.namespace != Namespaces.Peer.CloudUser {
        return false
    }
    if transaction.getPeerChatListInclusion(peerId) != .notIncluded {
        return false
    }
    if transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) == nil {
        return false
    }
    let peerIdValue = peerId.id._internalGetInt64Value()
    return supportChatListCleanupRemovesChat(SupportChatListCleanupChatInfo(
        isOneToOne: true,
        isAccountPeer: peerId == accountPeerId,
        isServiceUser: peerIdValue == 777000 || peerIdValue == 333000,
        isNamedByFolder: folderPeerIds.contains(peerId),
        isPinned: false,
        hasStoredComposerState: transaction.getPeerChatInterfaceState(peerId)?.data != nil,
        hasUnsentMessages: transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Local) != nil,
        hasOpenHistoryView: transaction.hasOpenMessageHistoryView(peerId: peerId)
    ))
}

func supportHiddenChatSweepBatch(transaction: Transaction, peerIds: ArraySlice<PeerId>, accountPeerId: PeerId) -> Int {
    let folderPeerIds = supportHiddenChatSweepFolderPeerIds(transaction: transaction)
    var clearedCount = 0
    for peerId in peerIds {
        if supportHiddenChatSweepClearsChat(transaction: transaction, peerId: peerId, accountPeerId: accountPeerId, folderPeerIds: folderPeerIds) {
            transaction.removeHistoryAsUnseenPeer(peerId, namespace: Namespaces.Message.Cloud)
            clearedCount += 1
        }
    }
    return clearedCount
}

private final class SupportHiddenChatSweepContext {
    private let queue = Queue()
    private let postbox: Postbox
    private let accountPeerId: PeerId
    private let actionDisposable = MetaDisposable()

    private var peerIds: [PeerId] = []
    private var position = 0
    private var clearedCount = 0
    private var startTime: Double = 0.0

    init(postbox: Postbox, accountPeerId: PeerId) {
        self.postbox = postbox
        self.accountPeerId = accountPeerId
    }

    func start() {
        self.actionDisposable.set((Signal<Void, NoError>.single(Void())
        |> delay(hiddenChatSweepStartDelay, queue: self.queue)
        |> mapToSignal { [postbox = self.postbox] _ -> Signal<[PeerId], NoError> in
            return postbox.transaction { transaction -> [PeerId] in
                return transaction.chatListGetAllPeerIds().filter { $0.namespace == Namespaces.Peer.CloudUser }
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] peerIds in
            guard let self else {
                return
            }
            self.peerIds = peerIds
            self.startTime = CFAbsoluteTimeGetCurrent()
            self.sweepBatch()
        }))
    }

    func dispose() {
        self.actionDisposable.dispose()
    }

    private func sweepBatch() {
        if self.position >= self.peerIds.count {
            Logger.shared.log("SupportHiddenChatSweep", "cleared \(self.clearedCount) of \(self.peerIds.count) one-to-one chats in \(Int(CFAbsoluteTimeGetCurrent() - self.startTime)) s")
            return
        }
        let end = min(self.position + hiddenChatSweepBatchPeerCount, self.peerIds.count)
        let batch = self.peerIds[self.position ..< end]
        self.position = end
        let accountPeerId = self.accountPeerId
        self.actionDisposable.set((self.postbox.transaction { transaction -> Int in
            return supportHiddenChatSweepBatch(transaction: transaction, peerIds: batch, accountPeerId: accountPeerId)
        }
        |> deliverOn(self.queue)).start(next: { [weak self] clearedCount in
            guard let self else {
                return
            }
            self.clearedCount += clearedCount
            self.actionDisposable.set((Signal<Never, NoError>.complete()
            |> delay(hiddenChatSweepBatchPause, queue: self.queue)).start(completed: { [weak self] in
                self?.sweepBatch()
            }))
        }))
    }
}

func managedSupportHiddenChatSweep(postbox: Postbox, accountPeerId: PeerId) -> Signal<Never, NoError> {
    return Signal { _ in
        let context = SupportHiddenChatSweepContext(postbox: postbox, accountPeerId: accountPeerId)
        context.start()
        return ActionDisposable {
            context.dispose()
        }
    }
}
