import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// The chat list: pinned chats, pinned saved-messages chats and forum topics, folders and chat filters.
extension UpdateInterpreter {
    mutating func applyDialogPinned(_ updateDialogPinnedData: Api.Update.Cons_updateDialogPinned) {
        let (flags, folderId, peer) = (updateDialogPinnedData.flags, updateDialogPinnedData.folderId, updateDialogPinnedData.peer)
        let groupId: PeerGroupId = folderId.flatMap(PeerGroupId.init(rawValue:)) ?? .root
        let item: PinnedItemId
        if let peerId = peer.peerId {
            item = .peer(peerId)
        } else {
            // G4: a folder (`dialogPeerFolder`) has no peer id and is never a pinned item here
            // (a getPinnedDialogs result skips `dialogFolder` too), so the update is skipped.
            // This `return` leaves only this update's method; the loop over the updates goes on.
            return
        }
        if (flags & (1 << 0)) != 0 {
            updatedState.addUpdatePinnedItemIds(groupId: groupId, operation: .pin(item))
        } else {
            updatedState.addUpdatePinnedItemIds(groupId: groupId, operation: .unpin(item))
        }
    }
    
    mutating func applyPinnedDialogs(_ updatePinnedDialogsData: Api.Update.Cons_updatePinnedDialogs) {
        let (folderId, order) = (updatePinnedDialogsData.folderId, updatePinnedDialogsData.order)
        let groupId: PeerGroupId = folderId.flatMap(PeerGroupId.init(rawValue:)) ?? .root
        if let order = order {
            // G4: a folder in the order is left out, as `updatePinnedSavedDialogs` does below.
            updatedState.addUpdatePinnedItemIds(groupId: groupId, operation: .reorder(order.compactMap {
                return $0.peerId.map(PinnedItemId.peer)
            }))
        } else {
            updatedState.addUpdatePinnedItemIds(groupId: groupId, operation: .sync)
        }
    }
    
    mutating func applySavedDialogPinned(_ updateSavedDialogPinnedData: Api.Update.Cons_updateSavedDialogPinned) {
        if case let .dialogPeer(dialogPeerData) = updateSavedDialogPinnedData.peer {
            let peer = dialogPeerData.peer
            if (updateSavedDialogPinnedData.flags & (1 << 0)) != 0 {
                updatedState.addUpdatePinnedSavedItemIds(operation: .pin(.peer(peer.peerId)))
            } else {
                updatedState.addUpdatePinnedSavedItemIds(operation: .unpin(.peer(peer.peerId)))
            }
        }
    }
    
    mutating func applyPinnedSavedDialogs(_ updatePinnedSavedDialogsData: Api.Update.Cons_updatePinnedSavedDialogs) {
        if let order = updatePinnedSavedDialogsData.order {
            updatedState.addUpdatePinnedSavedItemIds(operation: .reorder(order.compactMap {
                return $0.peerId.map(PinnedItemId.peer)
            }))
        } else {
            updatedState.addUpdatePinnedSavedItemIds(operation: .sync)
        }
    }
    
    mutating func applyPinnedForumTopic(_ updatePinnedForumTopicData: Api.Update.Cons_updatePinnedForumTopic) {
        let isPinned = (updatePinnedForumTopicData.flags & (1 << 0)) != 0
        updatedState.addUpdatePinnedTopic(peerId: updatePinnedForumTopicData.peer.peerId, threadId: Int64(updatePinnedForumTopicData.topicId), isPinned: isPinned)
    }
    
    mutating func applyFolderPeers(_ updateFolderPeersData: Api.Update.Cons_updateFolderPeers) {
        for folderPeer in updateFolderPeersData.folderPeers {
            switch folderPeer {
                case let .folderPeer(folderPeerData):
                    let (peer, folderId) = (folderPeerData.peer, folderPeerData.folderId)
                    updatedState.updatePeerChatInclusion(peerId: peer.peerId, groupId: PeerGroupId(rawValue: folderId), changedGroup: true)
            }
        }
    }
    
    mutating func applyDialogFilters() {
        updatedState.addSyncChatListFilters()
    }
    
    mutating func applyDialogFilterOrder(_ updateDialogFilterOrderData: Api.Update.Cons_updateDialogFilterOrder) {
        updatedState.addUpdateChatListFilterOrder(order: updateDialogFilterOrderData.order)
    }
    
    mutating func applyDialogFilter(_ updateDialogFilterData: Api.Update.Cons_updateDialogFilter) {
        updatedState.addUpdateChatListFilter(id: updateDialogFilterData.id, filter: updateDialogFilterData.filter)
    }
}
