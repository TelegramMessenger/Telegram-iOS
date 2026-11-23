import Foundation
import Postbox
import SwiftSignalKit

private let cleanupStartDelay: Double = 30.0
private let cleanupStillFillingRetryDelay: Double = 60.0
private let cleanupBatchEntryCount = 50
private let cleanupBatchPause: Double = 0.05
private let cleanupVacuumMinRemovedChatCount = 10000

struct SupportChatListCleanupChatInfo {
    var isOneToOne: Bool
    var isAccountPeer: Bool
    var isServiceUser: Bool
    var isNamedByFolder: Bool
    var isPinned: Bool
    var hasStoredComposerState: Bool
    var hasUnsentMessages: Bool
    var hasOpenHistoryView: Bool
}

func supportChatListCleanupRemovesChat(_ chat: SupportChatListCleanupChatInfo) -> Bool {
    return chat.isOneToOne && !chat.isAccountPeer && !chat.isServiceUser && !chat.isNamedByFolder && !chat.isPinned && !chat.hasStoredComposerState && !chat.hasUnsentMessages && !chat.hasOpenHistoryView
}

func supportChatListCleanupRuns(cutoffAtLaunch: Int32?, cutoff: Int32?) -> Bool {
    guard let cutoff, cutoff == cutoffAtLaunch else {
        return false
    }
    return cutoff > 0
}

func supportChatListCleanupRunsVacuum(removedChatCount: Int, databaseSize: Int64, freeSpace: Int64) -> Bool {
    return removedChatCount >= cleanupVacuumMinRemovedChatCount && freeSpace >= databaseSize * 2
}

private enum SupportChatListCleanupBoundary {
    case stillFilling
    case nothingPastCutoff
    case position(ChatListIndex, isChat: Bool)
}

private func supportChatListCleanupSeekPosition(cutoff: Int32) -> (index: ChatListIndex, isChat: Bool) {
    return (ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: 0), timestamp: cutoff + 1)), true)
}

private func supportChatListCleanupCanHoldHole(transaction: Transaction, index: ChatListIndex) -> Bool {
    let messageIndex = index.messageIndex
    if messageIndex.id.namespace != Namespaces.Message.Cloud || messageIndex.id.id <= 1 {
        return false
    }
    return transaction.getPeerChatInterfaceState(messageIndex.id.peerId)?.overrideChatTimestamp == nil
}

private func supportChatListCleanupPlaceBoundary(transaction: Transaction, groupId: PeerGroupId, cutoff: Int32) -> SupportChatListCleanupBoundary {
    let holes = transaction.allChatListHoles(groupId: groupId)
    if holes.contains(where: { $0.index.timestamp > cutoff }) {
        return .stillFilling
    }

    var boundary: (index: ChatListIndex, isChat: Bool, hole: ChatListHole)?
    var position = supportChatListCleanupSeekPosition(cutoff: cutoff)
    search: while true {
        let entries = transaction.chatListStoredEntries(groupId: groupId, earlierThan: position, count: cleanupBatchEntryCount)
        if entries.isEmpty {
            break
        }
        for entry in entries {
            switch entry {
            case let .hole(hole):
                boundary = (ChatListIndex(pinningIndex: nil, messageIndex: hole.index), false, hole)
                break search
            case let .chat(index):
                position = (index, true)
                if supportChatListCleanupCanHoldHole(transaction: transaction, index: index) {
                    boundary = (index, true, ChatListHole(index: index.messageIndex))
                    break search
                }
            }
        }
    }
    guard let boundary else {
        return .nothingPastCutoff
    }

    for hole in holes where hole.index != boundary.hole.index {
        transaction.replaceChatListHole(groupId: groupId, index: hole.index, hole: nil)
    }
    transaction.addChatListHole(groupId: groupId, hole: boundary.hole)
    return .position(boundary.index, isChat: boundary.isChat)
}

private func supportChatListCleanupRemoveBatch(transaction: Transaction, groupId: PeerGroupId, accountPeerId: PeerId, folderPeerIds: Set<PeerId>, position: (index: ChatListIndex, isChat: Bool)) -> (next: (index: ChatListIndex, isChat: Bool)?, removedCount: Int) {
    let entries = transaction.chatListStoredEntries(groupId: groupId, earlierThan: position, count: cleanupBatchEntryCount)
    var next: (index: ChatListIndex, isChat: Bool)?
    var removedCount = 0
    for entry in entries {
        switch entry {
        case let .hole(hole):
            next = (ChatListIndex(pinningIndex: nil, messageIndex: hole.index), false)
        case let .chat(index):
            next = (index, true)
            let peerId = index.messageIndex.id.peerId
            let peerIdValue = peerId.id._internalGetInt64Value()
            let isOneToOne = peerId.namespace == Namespaces.Peer.CloudUser
            let chat = SupportChatListCleanupChatInfo(
                isOneToOne: isOneToOne,
                isAccountPeer: peerId == accountPeerId,
                isServiceUser: isOneToOne && (peerIdValue == 777000 || peerIdValue == 333000),
                isNamedByFolder: folderPeerIds.contains(peerId),
                isPinned: index.pinningIndex != nil,
                hasStoredComposerState: transaction.getPeerChatInterfaceState(peerId)?.data != nil,
                hasUnsentMessages: transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Local) != nil,
                hasOpenHistoryView: transaction.hasOpenMessageHistoryView(peerId: peerId)
            )
            if supportChatListCleanupRemovesChat(chat) {
                transaction.removeHistoryAsUnseenPeer(peerId, namespace: Namespaces.Message.Cloud)
                removedCount += 1
            }
        }
    }
    return (next, removedCount)
}

private final class SupportChatListCleanupContext {
    private let queue = Queue()
    private let postbox: Postbox
    private let accountPeerId: PeerId
    private let supportContext: SupportContext
    private let loadTillDisposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()

    private var loadTillAtLaunch: Int32?
    private var loadTill: Int32?
    private var cutoff: Int32?
    private var groupIds: [PeerGroupId] = [.root, Namespaces.PeerGroup.archive]
    private var folderPeerIds = Set<PeerId>()
    private var removedChatCount = 0
    private let startTime = CFAbsoluteTimeGetCurrent()

    init(postbox: Postbox, accountPeerId: PeerId, supportContext: SupportContext) {
        self.postbox = postbox
        self.accountPeerId = accountPeerId
        self.supportContext = supportContext
    }

    func start() {
        self.loadTillDisposable.set((self.supportContext.chatListLoadTill
        |> deliverOn(self.queue)).start(next: { [weak self] loadTill in
            guard let self else {
                return
            }
            if self.loadTillAtLaunch == nil {
                self.loadTillAtLaunch = loadTill
            }
            self.loadTill = loadTill
        }))
        self.after(cleanupStartDelay) { [weak self] in
            guard let self else {
                return
            }
            guard supportChatListCleanupRuns(cutoffAtLaunch: self.loadTillAtLaunch, cutoff: self.loadTill) else {
                Logger.shared.log("SupportChatListCleanup", "not running, cutoff \(String(describing: self.loadTill)), at launch \(String(describing: self.loadTillAtLaunch))")
                return
            }
            self.cutoff = self.loadTill
            self.placeBoundary()
        }
    }

    func dispose() {
        self.loadTillDisposable.dispose()
        self.actionDisposable.dispose()
    }

    private func after(_ seconds: Double, _ f: @escaping () -> Void) {
        self.actionDisposable.set((Signal<Never, NoError>.complete()
        |> delay(seconds, queue: self.queue)).start(completed: f))
    }

    private var loadTillChanged: Bool {
        return self.loadTill != self.cutoff
    }

    private func placeBoundary() {
        guard let cutoff = self.cutoff, let groupId = self.groupIds.first else {
            self.finish()
            return
        }
        if self.loadTillChanged {
            self.finish()
            return
        }
        self.actionDisposable.set((self.postbox.transaction { transaction -> (SupportChatListCleanupBoundary, Set<PeerId>) in
            var folderPeerIds = Set<PeerId>()
            for filter in _internal_currentChatListFilters(transaction: transaction) {
                if case let .filter(_, _, _, data) = filter {
                    folderPeerIds.formUnion(data.includePeers.peers)
                    folderPeerIds.formUnion(data.includePeers.pinnedPeers)
                }
            }
            return (supportChatListCleanupPlaceBoundary(transaction: transaction, groupId: groupId, cutoff: cutoff), folderPeerIds)
        }
        |> deliverOn(self.queue)).start(next: { [weak self] boundary, folderPeerIds in
            guard let self else {
                return
            }
            self.folderPeerIds = folderPeerIds
            switch boundary {
            case .stillFilling:
                self.after(cleanupStillFillingRetryDelay) { [weak self] in
                    self?.placeBoundary()
                }
            case .nothingPastCutoff:
                self.nextGroup()
            case let .position(index, isChat):
                self.removeBatch(groupId: groupId, position: (index, isChat))
            }
        }))
    }

    private func nextGroup() {
        self.groupIds.removeFirst()
        self.placeBoundary()
    }

    private func removeBatch(groupId: PeerGroupId, position: (index: ChatListIndex, isChat: Bool)) {
        if self.loadTillChanged {
            self.finish()
            return
        }
        let accountPeerId = self.accountPeerId
        let folderPeerIds = self.folderPeerIds
        self.actionDisposable.set((self.postbox.transaction { transaction -> (next: (index: ChatListIndex, isChat: Bool)?, removedCount: Int) in
            return supportChatListCleanupRemoveBatch(transaction: transaction, groupId: groupId, accountPeerId: accountPeerId, folderPeerIds: folderPeerIds, position: position)
        }
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            guard let self else {
                return
            }
            self.removedChatCount += result.removedCount
            if let next = result.next {
                self.after(cleanupBatchPause) { [weak self] in
                    self?.removeBatch(groupId: groupId, position: next)
                }
            } else {
                self.nextGroup()
            }
        }))
    }

    private func finish() {
        Logger.shared.log("SupportChatListCleanup", "removed \(self.removedChatCount) chats in \(Int(CFAbsoluteTimeGetCurrent() - self.startTime)) s, load till changed: \(self.loadTillChanged)")

        let databasePath = self.postbox.mediaBox.basePath + "/../db/db_sqlite"
        let databaseSize = (try? FileManager.default.attributesOfItem(atPath: databasePath)[.size] as? Int64) ?? 0
        let freeSpace = (try? FileManager.default.attributesOfFileSystem(forPath: self.postbox.mediaBox.basePath)[.systemFreeSize] as? Int64) ?? 0
        if self.loadTillChanged || !supportChatListCleanupRunsVacuum(removedChatCount: self.removedChatCount, databaseSize: databaseSize, freeSpace: freeSpace) {
            return
        }
        let vacuumStartTime = CFAbsoluteTimeGetCurrent()
        self.actionDisposable.set((self.postbox.optimizeStorage(usingTempFile: true)
        |> deliverOn(self.queue)).start(completed: {
            let updatedSize = (try? FileManager.default.attributesOfItem(atPath: databasePath)[.size] as? Int64) ?? 0
            Logger.shared.log("SupportChatListCleanup", "vacuum took \(Int((CFAbsoluteTimeGetCurrent() - vacuumStartTime) * 1000.0)) ms, \(databaseSize) to \(updatedSize) bytes")
        }))
    }
}

func managedSupportChatListCleanup(postbox: Postbox, accountPeerId: PeerId, supportContext: SupportContext) -> Signal<Never, NoError> {
    return Signal { _ in
        let context = SupportChatListCleanupContext(postbox: postbox, accountPeerId: accountPeerId, supportContext: supportContext)
        context.start()
        return ActionDisposable {
            context.dispose()
        }
    }
}
