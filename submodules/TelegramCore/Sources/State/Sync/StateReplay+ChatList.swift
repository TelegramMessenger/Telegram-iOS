import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// The chat list: chat inclusion, pinned chats and pinned saved chats, chat folders.
extension ReplayContext {
    func applyUpdatePeerChatInclusion(_ peerId: PeerId, _ groupId: PeerGroupId, _ changedGroup: Bool) {
        if shouldExcludePeerFromChatList(transaction: transaction, peerId: peerId) {
            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
        } else {
            let currentInclusion = transaction.getPeerChatListInclusion(peerId)
            var currentPinningIndex: UInt16?
            var currentMinTimestamp: Int32?
            switch currentInclusion {
                case let .ifHasMessagesOrOneOf(currentGroupId, pinningIndex, minTimestamp):
                    if currentGroupId == groupId {
                        currentPinningIndex = pinningIndex
                    }
                    currentMinTimestamp = minTimestamp
                default:
                    break
            }
            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: currentPinningIndex, minTimestamp: currentMinTimestamp))
        }
        if changedGroup {
            invalidateGroupStats.insert(Namespaces.PeerGroup.archive)
        }
    }
    
    func applyUpdatePinnedItemIds(_ groupId: PeerGroupId, _ pinnedOperation: AccountStateUpdatePinnedItemIdsOperation) {
        switch pinnedOperation {
            case let .pin(itemId):
                switch itemId {
                    case let .peer(peerId):
                        if transaction.getPeer(peerId) == nil || transaction.getPeerChatListInclusion(peerId) == .notIncluded {
                            addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
                        } else {
                            var currentItemIds = transaction.getPinnedItemIds(groupId: groupId)
                            if !currentItemIds.contains(.peer(peerId)) {
                                currentItemIds.insert(.peer(peerId), at: 0)
                                transaction.setPinnedItemIds(groupId: groupId, itemIds: currentItemIds)
                            }
                        }
                }
            case let .unpin(itemId):
                switch itemId {
                    case let .peer(peerId):
                        var currentItemIds = transaction.getPinnedItemIds(groupId: groupId)
                        if let index = currentItemIds.firstIndex(of: .peer(peerId)) {
                            currentItemIds.remove(at: index)
                            transaction.setPinnedItemIds(groupId: groupId, itemIds: currentItemIds)
                        } else {
                            addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
                        }
                }
            case let .reorder(itemIds):
                let currentItemIds = transaction.getPinnedItemIds(groupId: groupId)
                if Set(itemIds) == Set(currentItemIds) {
                    transaction.setPinnedItemIds(groupId: groupId, itemIds: itemIds)
                } else {
                    addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
                }
            case .sync:
                addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
        }
    }
    
    func applyUpdatePinnedSavedItemIds(_ pinnedOperation: AccountStateUpdatePinnedItemIdsOperation) {
        switch pinnedOperation {
        case let .pin(itemId):
            switch itemId {
            case let .peer(peerId):
                var currentItemIds = transaction.getPeerPinnedThreads(peerId: accountPeerId)
                if !currentItemIds.contains(peerId.toInt64()) {
                    currentItemIds.insert(peerId.toInt64(), at: 0)
                    transaction.setPeerPinnedThreads(peerId: accountPeerId, threadIds: currentItemIds)
                }
            }
        case let .unpin(itemId):
            switch itemId {
            case let .peer(peerId):
                var currentItemIds = transaction.getPeerPinnedThreads(peerId: accountPeerId)
                if let index = currentItemIds.firstIndex(of: peerId.toInt64()) {
                    currentItemIds.remove(at: index)
                    transaction.setPeerPinnedThreads(peerId: accountPeerId, threadIds: currentItemIds)
                } else {
                    addSynchronizePinnedSavedChatsOperation(transaction: transaction, accountPeerId: accountPeerId)
                }
            }
        case let .reorder(itemIds):
            let itemIds = itemIds.compactMap({
                switch $0 {
                case let .peer(peerId):
                    return peerId
                }
            })
            let currentItemIds = transaction.getPeerPinnedThreads(peerId: accountPeerId)
            if Set(itemIds) == Set(currentItemIds.map(PeerId.init)) {
                transaction.setPeerPinnedThreads(peerId: accountPeerId, threadIds: itemIds.map { $0.toInt64() })
            } else {
                addSynchronizePinnedSavedChatsOperation(transaction: transaction, accountPeerId: accountPeerId)
            }
        case .sync:
            addSynchronizePinnedSavedChatsOperation(transaction: transaction, accountPeerId: accountPeerId)
        }
    }
    
    func applySyncChatListFilters() {
        syncChatListFilters = true
    }
    
    func applyUpdateChatListFilterOrder(_ order: [Int32]) {
        if !syncChatListFilters {
            let _ = updateChatListFiltersState(transaction: transaction, { state in
                var state = state
                if Set(state.filters.map { $0.id }) == Set(order) {
                    var updatedFilters: [ChatListFilter] = []
                    for id in order {
                        if let filter = state.filters.first(where: { $0.id == id }) {
                            updatedFilters.append(filter)
                        } else {
                            assertionFailure()
                        }
                    }
                    state.filters = updatedFilters
                    state.remoteFilters = state.filters
                } else {
                    syncChatListFilters = true
                }
                return state
            })
        }
    }
    
    func applyUpdateChatListFilter(_ id: Int32, _ filter: Api.DialogFilter?) {
        if !syncChatListFilters {
            let _ = updateChatListFiltersState(transaction: transaction, { state in
                var state = state
                if let index = state.filters.firstIndex(where: { $0.id == id }) {
                    if let filter = filter {
                        state.filters[index] = ChatListFilter(apiFilter: filter).withLocalOnlyPeers(from: state.filters[index])
                    } else {
                        state.filters.remove(at: index)
                    }
                    state.remoteFilters = state.filters
                } else {
                    syncChatListFilters = true
                }
                return state
            })
        }
    }
}
