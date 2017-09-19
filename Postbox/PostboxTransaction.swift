import Foundation

final class PostboxTransaction {
    let currentUpdatedState: PostboxCoding?
    let currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]]
    let peerIdsWithFilledHoles: [PeerId: [MessageIndex: HoleFillDirection]]
    let removedHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]]
    let chatListOperations: [ChatListOperation]
    let currentUpdatedPeers: [PeerId: Peer]
    let currentUpdatedPeerNotificationSettings: [PeerId: PeerNotificationSettings]
    let currentUpdatedCachedPeerData: [PeerId: CachedPeerData]
    let currentUpdatedPeerPresences: [PeerId: PeerPresence]
    let currentUpdatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?]
    let currentUpdatedTotalUnreadCount: Int32?
    let peerIdsWithUpdatedUnreadCounts: Set<PeerId>
    let currentPeerMergedOperationLogOperations: [PeerMergedOperationLogOperation]
    let currentTimestampBasedMessageAttributesOperations: [TimestampBasedMessageAttributesOperation]
    let currentPreferencesOperations: [PreferencesOperation]
    let currentOrderedItemListOperations: [Int32: [OrderedItemListOperation]]
    let currentItemCollectionItemsOperations: [ItemCollectionId: [ItemCollectionItemsOperation]]
    let currentItemCollectionInfosOperations: [ItemCollectionInfosOperation]
    let currentUpdatedPeerChatStates: Set<PeerId>
    let updatedAccessChallengeData: PostboxAccessChallengeData?
    let currentGlobalTagsOperations: [GlobalMessageHistoryTagsOperation]
    let currentPendingMessageActionsOperations: [PendingMessageActionsOperation]
    let currentUpdatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32]
    let currentUpdatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary]
    let currentInvalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation]
    let currentUpdatedPendingPeerNotificationSettings: Set<PeerId>
    
    let unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation]
    let updatedSynchronizePeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]
    let updatedMedia: [MediaId: Media?]
    let replaceRemoteContactCount: Int32?
    let replaceContactPeerIds: Set<PeerId>?
    let currentUpdatedMasterClientId: Int64?
    
    var isEmpty: Bool {
        if currentUpdatedState != nil {
            return false
        }
        if !currentOperationsByPeerId.isEmpty {
            return false
        }
        if !peerIdsWithFilledHoles.isEmpty {
            return false
        }
        if !removedHolesByPeerId.isEmpty {
            return false
        }
        if !chatListOperations.isEmpty {
            return false
        }
        if !currentUpdatedPeers.isEmpty {
            return false
        }
        if !currentUpdatedPeerNotificationSettings.isEmpty {
            return false
        }
        if !currentUpdatedCachedPeerData.isEmpty {
            return false
        }
        if !currentUpdatedPeerPresences.isEmpty {
            return false
        }
        if !currentUpdatedPeerChatListEmbeddedStates.isEmpty {
            return false
        }
        if !unsentMessageOperations.isEmpty {
            return false
        }
        if !updatedSynchronizePeerReadStateOperations.isEmpty {
            return false
        }
        if !updatedMedia.isEmpty {
            return false
        }
        if replaceRemoteContactCount != nil {
            return false
        }
        if let replaceContactPeerIds = replaceContactPeerIds, !replaceContactPeerIds.isEmpty {
            return false
        }
        if currentUpdatedMasterClientId != nil {
            return false
        }
        if currentUpdatedTotalUnreadCount != nil {
            return false
        }
        if !peerIdsWithUpdatedUnreadCounts.isEmpty {
            return false
        }
        if !currentPeerMergedOperationLogOperations.isEmpty {
            return false
        }
        if !currentTimestampBasedMessageAttributesOperations.isEmpty {
            return false
        }
        if !currentPreferencesOperations.isEmpty {
            return false
        }
        if !currentOrderedItemListOperations.isEmpty {
            return false
        }
        if !currentItemCollectionItemsOperations.isEmpty {
            return false
        }
        if !currentItemCollectionInfosOperations.isEmpty {
            return false
        }
        if !currentUpdatedPeerChatStates.isEmpty {
            return false
        }
        if self.updatedAccessChallengeData != nil {
            return false
        }
        if !self.currentGlobalTagsOperations.isEmpty {
            return false
        }
        if !self.currentPendingMessageActionsOperations.isEmpty {
            return false
        }
        if !self.currentUpdatedMessageActionsSummaries.isEmpty {
            return false
        }
        if !self.currentUpdatedMessageTagSummaries.isEmpty {
            return false
        }
        if !self.currentInvalidateMessageTagSummaries.isEmpty {
            return false
        }
        if !self.currentUpdatedPendingPeerNotificationSettings.isEmpty {
            return false
        }
        return true
    }
    
    init(currentUpdatedState: PostboxCoding?, currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]], peerIdsWithFilledHoles: [PeerId: [MessageIndex: HoleFillDirection]], removedHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]], chatListOperations: [ChatListOperation], currentUpdatedPeers: [PeerId: Peer], currentUpdatedPeerNotificationSettings: [PeerId: PeerNotificationSettings], currentUpdatedCachedPeerData: [PeerId: CachedPeerData], currentUpdatedPeerPresences: [PeerId: PeerPresence], currentUpdatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?], currentUpdatedTotalUnreadCount: Int32?, peerIdsWithUpdatedUnreadCounts: Set<PeerId>, currentPeerMergedOperationLogOperations: [PeerMergedOperationLogOperation], currentTimestampBasedMessageAttributesOperations: [TimestampBasedMessageAttributesOperation], unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation], updatedSynchronizePeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?], currentPreferencesOperations: [PreferencesOperation], currentOrderedItemListOperations: [Int32: [OrderedItemListOperation]], currentItemCollectionItemsOperations: [ItemCollectionId: [ItemCollectionItemsOperation]], currentItemCollectionInfosOperations: [ItemCollectionInfosOperation], currentUpdatedPeerChatStates: Set<PeerId>, updatedAccessChallengeData: PostboxAccessChallengeData?, currentGlobalTagsOperations: [GlobalMessageHistoryTagsOperation], updatedMedia: [MediaId: Media?], replaceRemoteContactCount: Int32?, replaceContactPeerIds: Set<PeerId>?, currentPendingMessageActionsOperations: [PendingMessageActionsOperation], currentUpdatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32], currentUpdatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], currentInvalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation], currentUpdatedPendingPeerNotificationSettings: Set<PeerId>, currentUpdatedMasterClientId: Int64?) {
        self.currentUpdatedState = currentUpdatedState
        self.currentOperationsByPeerId = currentOperationsByPeerId
        self.peerIdsWithFilledHoles = peerIdsWithFilledHoles
        self.removedHolesByPeerId = removedHolesByPeerId
        self.chatListOperations = chatListOperations
        self.currentUpdatedPeers = currentUpdatedPeers
        self.currentUpdatedPeerNotificationSettings = currentUpdatedPeerNotificationSettings;
        self.currentUpdatedCachedPeerData = currentUpdatedCachedPeerData
        self.currentUpdatedPeerPresences = currentUpdatedPeerPresences
        self.currentUpdatedPeerChatListEmbeddedStates = currentUpdatedPeerChatListEmbeddedStates
        self.currentUpdatedTotalUnreadCount = currentUpdatedTotalUnreadCount
        self.peerIdsWithUpdatedUnreadCounts = peerIdsWithUpdatedUnreadCounts
        self.currentPeerMergedOperationLogOperations = currentPeerMergedOperationLogOperations
        self.currentTimestampBasedMessageAttributesOperations = currentTimestampBasedMessageAttributesOperations
        self.unsentMessageOperations = unsentMessageOperations
        self.updatedSynchronizePeerReadStateOperations = updatedSynchronizePeerReadStateOperations
        self.currentPreferencesOperations = currentPreferencesOperations
        self.currentOrderedItemListOperations = currentOrderedItemListOperations
        self.currentItemCollectionItemsOperations = currentItemCollectionItemsOperations
        self.currentItemCollectionInfosOperations = currentItemCollectionInfosOperations
        self.currentUpdatedPeerChatStates = currentUpdatedPeerChatStates
        self.updatedAccessChallengeData = updatedAccessChallengeData
        self.currentGlobalTagsOperations = currentGlobalTagsOperations
        self.updatedMedia = updatedMedia
        self.replaceRemoteContactCount = replaceRemoteContactCount
        self.replaceContactPeerIds = replaceContactPeerIds
        self.currentPendingMessageActionsOperations = currentPendingMessageActionsOperations
        self.currentUpdatedMessageActionsSummaries = currentUpdatedMessageActionsSummaries
        self.currentUpdatedMessageTagSummaries = currentUpdatedMessageTagSummaries
        self.currentInvalidateMessageTagSummaries = currentInvalidateMessageTagSummaries
        self.currentUpdatedPendingPeerNotificationSettings = currentUpdatedPendingPeerNotificationSettings
        self.currentUpdatedMasterClientId = currentUpdatedMasterClientId
    }
}
