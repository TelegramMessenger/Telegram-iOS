import Foundation
import Postbox
import SwiftSignalKit

struct SupportSwitchGroup {
    var topHole: MessageIndex?
    var pinnedRows: [ChatListIndex]
    var isListed: (ChatListIndex) -> Bool
    var walk: (_ after: ChatListIndex, _ downward: Bool, _ f: (ChatListIndex) -> Bool) -> Void
}

private func supportRowIsBelowHole(_ messageIndex: MessageIndex, topHole: MessageIndex?) -> Bool {
    guard let topHole else {
        return false
    }
    return messageIndex < topHole
}

func supportListSwitchTarget(current: ChatListIndex, downward: Bool, group: SupportSwitchGroup, isTarget: (PeerId) -> Bool) -> PeerId? {
    func isBelowHole(_ index: ChatListIndex) -> Bool {
        return index.pinningIndex == nil && supportRowIsBelowHole(index.messageIndex, topHole: group.topHole)
    }
    if isBelowHole(current) {
        return nil
    }
    var result: PeerId?
    group.walk(current, downward, { index in
        if isBelowHole(index) {
            return false
        }
        let peerId = index.messageIndex.id.peerId
        if isTarget(peerId) {
            result = peerId
            return false
        }
        return true
    })
    return result
}

// A folder shows its own pinned chats first, then every other chat by date across its groups:
// a chat pinned in the main list is an ordinary row there.
func supportFolderSwitchTarget(peerId: PeerId, current: ChatListIndex?, downward: Bool, pinnedPeerIds: [PeerId], namesAnyPeer: Bool, isNamed: (PeerId) -> Bool, groups: [SupportSwitchGroup], isTarget: (PeerId) -> Bool) -> PeerId? {
    let pinnedPosition = pinnedPeerIds.firstIndex(of: peerId)
    let start: MessageIndex
    if let pinnedPosition {
        let pinnedAfter = downward ? Array(pinnedPeerIds[(pinnedPosition + 1)...]) : Array(pinnedPeerIds[..<pinnedPosition].reversed())
        if let target = pinnedAfter.first(where: isTarget) {
            return target
        }
        if !downward {
            return nil
        }
        start = MessageIndex.absoluteUpperBound()
    } else {
        guard let current else {
            return nil
        }
        start = current.messageIndex
        if !isNamed(peerId), groups.contains(where: { supportRowIsBelowHole(start, topHole: $0.topHole) }) {
            return nil
        }
    }

    var best: MessageIndex?
    func consider(_ messageIndex: MessageIndex) {
        if let bestValue = best {
            best = downward ? max(bestValue, messageIndex) : min(bestValue, messageIndex)
        } else {
            best = messageIndex
        }
    }
    for group in groups {
        func accepts(_ index: ChatListIndex) -> Bool {
            let rowPeerId = index.messageIndex.id.peerId
            guard !pinnedPeerIds.contains(rowPeerId), isTarget(rowPeerId), group.isListed(index) else {
                return false
            }
            return !supportRowIsBelowHole(index.messageIndex, topHole: group.topHole) || isNamed(rowPeerId)
        }
        group.walk(ChatListIndex(pinningIndex: nil, messageIndex: start), downward, { index in
            if index.pinningIndex != nil {
                return false
            }
            if downward, !namesAnyPeer, supportRowIsBelowHole(index.messageIndex, topHole: group.topHole) {
                return false
            }
            if accepts(index) {
                consider(index.messageIndex)
                return false
            }
            return true
        })
        for index in group.pinnedRows {
            let isInDirection = downward ? index.messageIndex < start : index.messageIndex > start
            if isInDirection, accepts(index) {
                consider(index.messageIndex)
            }
        }
    }
    if let best {
        return best.id.peerId
    }
    if !downward, pinnedPosition == nil {
        return pinnedPeerIds.reversed().first(where: isTarget)
    }
    return nil
}

private func supportSwitchGroup(transaction: Transaction, groupId: PeerGroupId, predicate: ChatListFilterPredicate?) -> SupportSwitchGroup {
    var pinnedRows: [ChatListIndex] = []
    if predicate != nil {
        for item in transaction.getPinnedItemIds(groupId: groupId) {
            if case let .peer(pinnedPeerId) = item, let (rowGroupId, index) = transaction.getPeerChatListIndex(pinnedPeerId), rowGroupId == groupId {
                pinnedRows.append(index)
            }
        }
    }
    return SupportSwitchGroup(
        topHole: transaction.allChatListHoles(groupId: groupId).map(\.index).max(),
        pinnedRows: pinnedRows,
        isListed: predicate.flatMap { transaction.chatListFilterMatcher(groupId: groupId, predicate: $0) } ?? { _ in true },
        walk: { after, downward, f in
            transaction.enumerateChatListIndices(groupId: groupId, after: after, downward: downward, f)
        }
    )
}

private func supportSwitchTarget(transaction: Transaction, peerId: PeerId, chatListFilterId: Int32?, getFilterPredicate: (ChatListFilterData) -> ChatListFilterPredicate) -> PeerId? {
    let downward: Bool
    switch supportSettings(transaction: transaction).switchBehavior {
    case .none:
        return nil
    case .next:
        downward = true
    case .previous:
        downward = false
    }

    let isTarget: (PeerId) -> Bool = { targetPeerId in
        guard targetPeerId != peerId, transaction.getCombinedPeerReadState(targetPeerId)?.isUnread == true, let peer = transaction.getPeer(targetPeerId) else {
            return false
        }
        return !peer.isForumOrMonoForum
    }
    return supportChatListTarget(transaction: transaction, peerId: peerId, chatListFilterId: chatListFilterId, downward: downward, isTarget: isTarget, getFilterPredicate: getFilterPredicate)
}

private func supportChatListTarget(transaction: Transaction, peerId: PeerId, chatListFilterId: Int32?, downward: Bool, isTarget: (PeerId) -> Bool, getFilterPredicate: (ChatListFilterData) -> ChatListFilterPredicate) -> PeerId? {
    let chatListIndex = transaction.getPeerChatListIndex(peerId)

    var predicate: ChatListFilterPredicate?
    if let chatListFilterId {
        for filter in _internal_currentChatListFilters(transaction: transaction) {
            if case let .filter(id, _, _, data) = filter, id == chatListFilterId {
                predicate = getFilterPredicate(data)
            }
        }
    }
    if let predicate {
        let groups = ([PeerGroupId.root] + predicate.includeAdditionalPeerGroupIds).map { groupId in
            return supportSwitchGroup(transaction: transaction, groupId: groupId, predicate: predicate)
        }
        return supportFolderSwitchTarget(
            peerId: peerId,
            current: chatListIndex?.1,
            downward: downward,
            pinnedPeerIds: predicate.pinnedPeerIds,
            namesAnyPeer: !predicate.includePeerIds.isEmpty,
            isNamed: { namedPeerId in
                return transaction.getPeer(namedPeerId).flatMap(predicate.namesPeer) ?? false
            },
            groups: groups,
            isTarget: isTarget
        )
    }
    guard let (groupId, index) = chatListIndex else {
        return nil
    }
    return supportListSwitchTarget(current: index, downward: downward, group: supportSwitchGroup(transaction: transaction, groupId: groupId, predicate: nil), isTarget: isTarget)
}

func _internal_supportSwitchTarget(account: Account, peerId: PeerId, chatListFilterId: Int32?, getFilterPredicate: @escaping (ChatListFilterData) -> ChatListFilterPredicate) -> Signal<EnginePeer?, NoError> {
    return account.postbox.transaction { transaction -> EnginePeer? in
        let target = supportSwitchTarget(transaction: transaction, peerId: peerId, chatListFilterId: chatListFilterId, getFilterPredicate: getFilterPredicate)
        Logger.shared.log("SupportSwitch", "send in \(peerId.toInt64()) filter \(String(describing: chatListFilterId)): \(String(describing: target?.toInt64()))")
        return target.flatMap { transaction.getPeer($0) }.map { EnginePeer($0) }
    }
}

func supportChatListNeighbourIsTarget(targetPeerId: PeerId, currentPeerId: PeerId, peer: Peer?) -> Bool {
    guard targetPeerId != currentPeerId, let peer else {
        return false
    }
    return !peer.isForumOrMonoForum
}

func _internal_supportChatListNeighbour(account: Account, peerId: PeerId, chatListFilterId: Int32?, downward: Bool, getFilterPredicate: @escaping (ChatListFilterData) -> ChatListFilterPredicate) -> Signal<EnginePeer?, NoError> {
    return account.postbox.transaction { transaction -> EnginePeer? in
        let target = supportChatListTarget(transaction: transaction, peerId: peerId, chatListFilterId: chatListFilterId, downward: downward, isTarget: { targetPeerId in
            return supportChatListNeighbourIsTarget(targetPeerId: targetPeerId, currentPeerId: peerId, peer: transaction.getPeer(targetPeerId))
        }, getFilterPredicate: getFilterPredicate)
        return target.flatMap { transaction.getPeer($0) }.map { EnginePeer($0) }
    }
}

public enum SupportDoneResult {
    case switchTo(EnginePeer)
    case noUnreadChatLeft
    case stay
}

func supportDoneResult(behavior: SupportSwitchBehavior, target: EnginePeer?) -> SupportDoneResult {
    if let target {
        return .switchTo(target)
    }
    return behavior == .none ? .stay : .noUnreadChatLeft
}

func _internal_supportMarkDone(account: Account, peerId: PeerId, chatListFilterId: Int32?, getFilterPredicate: @escaping (ChatListFilterData) -> ChatListFilterPredicate) -> Signal<SupportDoneResult, NoError> {
    guard account.isSupportUser else {
        return .single(.stay)
    }
    return account.postbox.transaction { transaction -> SupportDoneResult in
        let target = supportSwitchTarget(transaction: transaction, peerId: peerId, chatListFilterId: chatListFilterId, getFilterPredicate: getFilterPredicate)
        Logger.shared.log("SupportSwitch", "done in \(peerId.toInt64()) filter \(String(describing: chatListFilterId)): \(String(describing: target?.toInt64()))")
        supportApplyReadOnSend(transaction: transaction, network: account.network, stateManager: account.stateManager, peerId: peerId, sends: [SupportSendReadInfo(isDeferred: false, threadId: nil, replyThreadId: nil)])
        return supportDoneResult(behavior: supportSettings(transaction: transaction).switchBehavior, target: target.flatMap { transaction.getPeer($0) }.map { EnginePeer($0) })
    }
}

func _internal_supportSendSwitchesChat(account: Account) -> Signal<Bool, NoError> {
    return account.postbox.transaction { transaction -> Bool in
        return supportSettings(transaction: transaction).switchBehavior != .none
    }
}

func _internal_supportSwitchTargetUpdates(account: Account, peerId: PeerId, chatListFilterId: Int32?, getFilterPredicate: @escaping (ChatListFilterData) -> ChatListFilterPredicate) -> Signal<PeerId?, NoError> {
    let postbox = account.postbox
    return postbox.combinedView(keys: [
        .preferences(keys: Set([PreferencesKeys.supportSettings])),
        .unreadCounts(items: [.total(nil), .totalInGroup(Namespaces.PeerGroup.archive)])
    ])
    |> mapToThrottled { _ -> Signal<PeerId?, NoError> in
        return postbox.transaction { transaction -> PeerId? in
            return supportSwitchTarget(transaction: transaction, peerId: peerId, chatListFilterId: chatListFilterId, getFilterPredicate: getFilterPredicate)
        }
        |> then(.complete() |> delay(1.0, queue: Queue.concurrentDefaultQueue()))
    }
    |> distinctUntilChanged
    |> afterNext { target in
        Logger.shared.log("SupportSwitch", "preload for \(peerId.toInt64()) filter \(String(describing: chatListFilterId)): \(String(describing: target?.toInt64()))")
    }
}
