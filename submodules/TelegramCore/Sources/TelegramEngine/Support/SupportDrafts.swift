import Foundation
import Postbox
import SwiftSignalKit

func isSupportAccount(transaction: Transaction, accountPeerId: PeerId) -> Bool {
    guard let user = transaction.getPeer(accountPeerId) as? TelegramUser else {
        return false
    }
    return isSupportAccountPhone(user.phone)
}

// On a support account the main thread's cloud draft belongs to occupation, so composer text stays local.
func supportKeepsDraftLocal(isSupportAccount: Bool, threadId: Int64?) -> Bool {
    return isSupportAccount && threadId == nil
}

func supportKeepsDraftLocal(transaction: Transaction, accountPeerId: PeerId, threadId: Int64?) -> Bool {
    if threadId != nil {
        return false
    }
    return isSupportAccount(transaction: transaction, accountPeerId: accountPeerId)
}

func isSupportOccupationDraftText(_ text: String) -> Bool {
    let parts = text.split(separator: ";", omittingEmptySubsequences: false)
    guard parts.count == 3, parts[0].hasPrefix("t:"), parts[1].hasPrefix("u:"), parts[2].hasPrefix("n:") else {
        return false
    }
    let till = parts[0].dropFirst(2)
    let tag = parts[1].dropFirst(2)
    let name = parts[2].dropFirst(2)
    let isDigits: (Substring) -> Bool = { value in
        return !value.isEmpty && value.allSatisfy({ ("0" ... "9").contains($0) })
    }
    return isDigits(till) && isDigits(tag) && !name.contains(":")
}

enum SupportStoredDraftSweep: Equatable {
    case keep
    case dropOverride
    case clearOccupationText
}

func supportStoredDraftSweep(hasOverride: Bool, inputState: SynchronizeableChatInputState?) -> SupportStoredDraftSweep {
    if let inputState, inputState.replySubject == nil, case let .textEntities(text, _) = inputState.content, isSupportOccupationDraftText(text) {
        return .clearOccupationText
    }
    return hasOverride ? .dropOverride : .keep
}

struct SupportDraftSweepState: Codable, Equatable {
    var version: Int32
}

private let draftSweepBatchCount = 50
private let draftSweepBatchPause: Double = 0.05

private func supportSweepStoredDraft(transaction: Transaction, peerId: PeerId) -> Bool {
    guard let stored = transaction.getPeerChatInterfaceState(peerId) else {
        return false
    }
    let internalState = stored.data.flatMap { try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: $0) }
    var data = stored.data
    var associatedMessageIds = stored.associatedMessageIds
    switch supportStoredDraftSweep(hasOverride: stored.overrideChatTimestamp != nil, inputState: internalState?.synchronizeableInputState) {
    case .keep:
        return false
    case .dropOverride:
        break
    case .clearOccupationText:
        guard let internalState, let updatedData = try? AdaptedPostboxEncoder().encode(InternalChatInterfaceState(
            synchronizeableInputState: nil,
            historyScrollMessageIndex: internalState.historyScrollMessageIndex,
            mediaDraftState: internalState.mediaDraftState,
            opaqueData: internalState.opaqueData
        )) else {
            return false
        }
        data = updatedData
        associatedMessageIds = []
    }
    transaction.setPeerChatInterfaceState(peerId, state: StoredPeerChatInterfaceState(
        overrideChatTimestamp: nil,
        historyScrollMessageIndex: stored.historyScrollMessageIndex,
        associatedMessageIds: associatedMessageIds,
        data: data
    ))
    return true
}

private func supportDraftSweepBatch(transaction: Transaction, groupId: PeerGroupId, position: (index: ChatListIndex, isChat: Bool)?) -> (next: (index: ChatListIndex, isChat: Bool)?, updatedCount: Int) {
    let entries = transaction.chatListStoredEntries(groupId: groupId, earlierThan: position, count: draftSweepBatchCount)
    var next: (index: ChatListIndex, isChat: Bool)?
    var updatedCount = 0
    for entry in entries {
        switch entry {
        case let .hole(hole):
            next = (ChatListIndex(pinningIndex: nil, messageIndex: hole.index), false)
        case let .chat(index):
            next = (index, true)
            if supportSweepStoredDraft(transaction: transaction, peerId: index.messageIndex.id.peerId) {
                updatedCount += 1
            }
        }
    }
    return (next, updatedCount)
}

// Once per account: claim strings stored by older builds leave the composer, and stored drafts stop lifting rows. Nothing is sent.
func managedSupportDraftSweep(postbox: Postbox) -> Signal<Never, NoError> {
    let groupIds: [PeerGroupId] = [.root, Namespaces.PeerGroup.archive]
    let startTime = CFAbsoluteTimeGetCurrent()

    let sweep = supportSequentialBatches(initial: SupportChatListSweepCursor(groupIndex: 0, position: nil, count: 0), pause: draftSweepBatchPause, queue: Queue.concurrentDefaultQueue(), batch: { cursor in
        return postbox.transaction { transaction -> SupportChatListSweepCursor? in
            if cursor.groupIndex >= groupIds.count {
                transaction.updatePreferencesEntry(key: PreferencesKeys.supportDraftSweep, { _ in
                    return PreferencesEntry(SupportDraftSweepState(version: 1))
                })
                Logger.shared.log("SupportDraftSweep", "updated \(cursor.count) stored drafts in \(Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)) ms")
                return nil
            }
            let result = supportDraftSweepBatch(transaction: transaction, groupId: groupIds[cursor.groupIndex], position: cursor.position)
            if let next = result.next {
                return SupportChatListSweepCursor(groupIndex: cursor.groupIndex, position: next, count: cursor.count + result.updatedCount)
            }
            return SupportChatListSweepCursor(groupIndex: cursor.groupIndex + 1, position: nil, count: cursor.count + result.updatedCount)
        }
    })

    return postbox.transaction { transaction -> Bool in
        return transaction.getPreferencesEntry(key: PreferencesKeys.supportDraftSweep)?.get(SupportDraftSweepState.self) != nil
    }
    |> mapToSignal { isDone -> Signal<Never, NoError> in
        if isDone {
            return .complete()
        }
        return sweep
    }
}
