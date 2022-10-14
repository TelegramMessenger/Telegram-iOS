import Foundation

final class PostboxTransaction {
    let currentUpdatedState: PostboxCoding?
    let currentPeerHoleOperations: [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]]
    let currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]]
    let chatListOperations: [PeerGroupId: [ChatListOperation]]
    let currentUpdatedChatListInclusions: [PeerId: PeerChatListInclusion]
    let currentUpdatedPeers: [PeerId: Peer]
    let currentUpdatedPeerNotificationSettings: [PeerId: (PeerNotificationSettings?, PeerNotificationSettings)]
    let currentUpdatedPeerNotificationBehaviorTimestamps: [PeerId: PeerNotificationSettingsBehaviorTimestamp]
    let currentUpdatedCachedPeerData: [PeerId: CachedPeerData]
    let currentUpdatedPeerPresences: [PeerId: PeerPresence]
    let currentUpdatedPeerChatListEmbeddedStates: Set<PeerId>
    let currentUpdatedTotalUnreadStates: [PeerGroupId: ChatListTotalUnreadState]
    let currentUpdatedTotalUnreadSummaries: [PeerGroupId: PeerGroupUnreadCountersCombinedSummary]
    let alteredInitialPeerCombinedReadStates: [PeerId: CombinedPeerReadState]
    let currentPeerMergedOperationLogOperations: [PeerMergedOperationLogOperation]
    let currentTimestampBasedMessageAttributesOperations: [TimestampBasedMessageAttributesOperation]
    let currentPreferencesOperations: [PreferencesOperation]
    let currentOrderedItemListOperations: [Int32: [OrderedItemListOperation]]
    let currentItemCollectionItemsOperations: [ItemCollectionId: [ItemCollectionItemsOperation]]
    let currentItemCollectionInfosOperations: [ItemCollectionInfosOperation]
    let currentUpdatedPeerChatStates: Set<PeerId>
    let currentGlobalTagsOperations: [GlobalMessageHistoryTagsOperation]
    let currentLocalTagsOperations: [IntermediateMessageHistoryLocalTagsOperation]
    let currentPendingMessageActionsOperations: [PendingMessageActionsOperation]
    let currentUpdatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32]
    let currentUpdatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary]
    let currentInvalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation]
    let currentUpdatedPendingPeerNotificationSettings: Set<PeerId>
    
    let unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation]
    let updatedSynchronizePeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?]
    let currentUpdatedGroupSummarySynchronizeOperations: [PeerGroupAndNamespace: Bool]
    let updatedMedia: [MediaId: Media?]
    let replaceRemoteContactCount: Int32?
    let replaceContactPeerIds: Set<PeerId>?
    let currentUpdatedMasterClientId: Int64?
    let replacedAdditionalChatListItems: [AdditionalChatListItem]?
    let updatedNoticeEntryKeys: Set<NoticeEntryKey>
    let updatedCacheEntryKeys: Set<ItemCacheEntryId>
    let updatedFailedMessagePeerIds: Set<PeerId>
    let updatedFailedMessageIds: Set<MessageId>
    let updatedGlobalNotificationSettings: Bool
    let updatedPeerTimeoutAttributes: Bool
    let updatedMessageThreadPeerIds: Set<PeerId>
    let updatedPeerThreadCombinedStates: Set<PeerId>
    let updatedPeerThreadsSummaries: Set<PeerId>
    let updatedPinnedThreads: Set<PeerId>
    
    var isEmpty: Bool {
        if currentUpdatedState != nil {
            return false
        }
        if !currentPeerHoleOperations.isEmpty {
            return false
        }
        if !currentOperationsByPeerId.isEmpty {
            return false
        }
        if !chatListOperations.isEmpty {
            return false
        }
        if !currentUpdatedChatListInclusions.isEmpty {
            return false
        }
        if !currentUpdatedPeers.isEmpty {
            return false
        }
        if !currentUpdatedPeerNotificationSettings.isEmpty {
            return false
        }
        if !currentUpdatedPeerNotificationBehaviorTimestamps.isEmpty {
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
        if !currentUpdatedGroupSummarySynchronizeOperations.isEmpty {
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
        if !currentUpdatedTotalUnreadStates.isEmpty {
            return false
        }
        if !currentUpdatedTotalUnreadSummaries.isEmpty {
            return false
        }
        if !alteredInitialPeerCombinedReadStates.isEmpty {
            return false
        }
        if !alteredInitialPeerCombinedReadStates.isEmpty {
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
        if !self.currentGlobalTagsOperations.isEmpty {
            return false
        }
        if !self.currentLocalTagsOperations.isEmpty {
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
        if self.replacedAdditionalChatListItems != nil {
            return false
        }
        if !self.updatedNoticeEntryKeys.isEmpty {
            return false
        }
        if !self.updatedCacheEntryKeys.isEmpty {
            return false
        }
        if !self.updatedFailedMessagePeerIds.isEmpty {
            return false
        }
        if !self.updatedFailedMessageIds.isEmpty {
            return false
        }
        if self.updatedGlobalNotificationSettings {
            return false
        }
        if self.updatedPeerTimeoutAttributes {
            return false
        }
        if !self.updatedMessageThreadPeerIds.isEmpty {
            return false
        }
        if !self.updatedPeerThreadCombinedStates.isEmpty {
            return false
        }
        if !self.updatedPeerThreadsSummaries.isEmpty {
            return false
        }
        if !self.updatedPinnedThreads.isEmpty {
            return false
        }
        return true
    }
    
    init(currentUpdatedState: PostboxCoding?, currentPeerHoleOperations: [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]] = [:], currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]], chatListOperations: [PeerGroupId: [ChatListOperation]], currentUpdatedChatListInclusions: [PeerId: PeerChatListInclusion], currentUpdatedPeers: [PeerId: Peer], currentUpdatedPeerNotificationSettings: [PeerId: (PeerNotificationSettings?, PeerNotificationSettings)], currentUpdatedPeerNotificationBehaviorTimestamps: [PeerId: PeerNotificationSettingsBehaviorTimestamp], currentUpdatedCachedPeerData: [PeerId: CachedPeerData], currentUpdatedPeerPresences: [PeerId: PeerPresence], currentUpdatedPeerChatListEmbeddedStates: Set<PeerId>, currentUpdatedTotalUnreadStates: [PeerGroupId: ChatListTotalUnreadState], currentUpdatedTotalUnreadSummaries: [PeerGroupId: PeerGroupUnreadCountersCombinedSummary], alteredInitialPeerCombinedReadStates: [PeerId: CombinedPeerReadState], currentPeerMergedOperationLogOperations: [PeerMergedOperationLogOperation], currentTimestampBasedMessageAttributesOperations: [TimestampBasedMessageAttributesOperation], unsentMessageOperations: [IntermediateMessageHistoryUnsentOperation], updatedSynchronizePeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?], currentUpdatedGroupSummarySynchronizeOperations: [PeerGroupAndNamespace: Bool], currentPreferencesOperations: [PreferencesOperation], currentOrderedItemListOperations: [Int32: [OrderedItemListOperation]], currentItemCollectionItemsOperations: [ItemCollectionId: [ItemCollectionItemsOperation]], currentItemCollectionInfosOperations: [ItemCollectionInfosOperation], currentUpdatedPeerChatStates: Set<PeerId>, currentGlobalTagsOperations: [GlobalMessageHistoryTagsOperation], currentLocalTagsOperations: [IntermediateMessageHistoryLocalTagsOperation], updatedMedia: [MediaId: Media?], replaceRemoteContactCount: Int32?, replaceContactPeerIds: Set<PeerId>?, currentPendingMessageActionsOperations: [PendingMessageActionsOperation], currentUpdatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32], currentUpdatedMessageTagSummaries: [MessageHistoryTagsSummaryKey: MessageHistoryTagNamespaceSummary], currentInvalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation], currentUpdatedPendingPeerNotificationSettings: Set<PeerId>, replacedAdditionalChatListItems: [AdditionalChatListItem]?, updatedNoticeEntryKeys: Set<NoticeEntryKey>, updatedCacheEntryKeys: Set<ItemCacheEntryId>, currentUpdatedMasterClientId: Int64?, updatedFailedMessagePeerIds: Set<PeerId>, updatedFailedMessageIds: Set<MessageId>, updatedGlobalNotificationSettings: Bool, updatedPeerTimeoutAttributes: Bool, updatedMessageThreadPeerIds: Set<PeerId>, updatedPeerThreadCombinedStates: Set<PeerId>, updatedPeerThreadsSummaries: Set<PeerId>, updatedPinnedThreads: Set<PeerId>) {
        self.currentUpdatedState = currentUpdatedState
        self.currentPeerHoleOperations = currentPeerHoleOperations
        self.currentOperationsByPeerId = currentOperationsByPeerId
        self.chatListOperations = chatListOperations
        self.currentUpdatedChatListInclusions = currentUpdatedChatListInclusions
        self.currentUpdatedPeers = currentUpdatedPeers
        self.currentUpdatedPeerNotificationSettings = currentUpdatedPeerNotificationSettings
        self.currentUpdatedPeerNotificationBehaviorTimestamps = currentUpdatedPeerNotificationBehaviorTimestamps
        self.currentUpdatedCachedPeerData = currentUpdatedCachedPeerData
        self.currentUpdatedPeerPresences = currentUpdatedPeerPresences
        self.currentUpdatedPeerChatListEmbeddedStates = currentUpdatedPeerChatListEmbeddedStates
        self.currentUpdatedTotalUnreadStates = currentUpdatedTotalUnreadStates
        self.currentUpdatedTotalUnreadSummaries = currentUpdatedTotalUnreadSummaries
        self.alteredInitialPeerCombinedReadStates = alteredInitialPeerCombinedReadStates
        self.currentPeerMergedOperationLogOperations = currentPeerMergedOperationLogOperations
        self.currentTimestampBasedMessageAttributesOperations = currentTimestampBasedMessageAttributesOperations
        self.unsentMessageOperations = unsentMessageOperations
        self.updatedSynchronizePeerReadStateOperations = updatedSynchronizePeerReadStateOperations
        self.currentUpdatedGroupSummarySynchronizeOperations = currentUpdatedGroupSummarySynchronizeOperations
        self.currentPreferencesOperations = currentPreferencesOperations
        self.currentOrderedItemListOperations = currentOrderedItemListOperations
        self.currentItemCollectionItemsOperations = currentItemCollectionItemsOperations
        self.currentItemCollectionInfosOperations = currentItemCollectionInfosOperations
        self.currentUpdatedPeerChatStates = currentUpdatedPeerChatStates
        self.currentGlobalTagsOperations = currentGlobalTagsOperations
        self.currentLocalTagsOperations = currentLocalTagsOperations
        self.updatedMedia = updatedMedia
        self.replaceRemoteContactCount = replaceRemoteContactCount
        self.replaceContactPeerIds = replaceContactPeerIds
        self.currentPendingMessageActionsOperations = currentPendingMessageActionsOperations
        self.currentUpdatedMessageActionsSummaries = currentUpdatedMessageActionsSummaries
        self.currentUpdatedMessageTagSummaries = currentUpdatedMessageTagSummaries
        self.currentInvalidateMessageTagSummaries = currentInvalidateMessageTagSummaries
        self.currentUpdatedPendingPeerNotificationSettings = currentUpdatedPendingPeerNotificationSettings
        self.currentUpdatedMasterClientId = currentUpdatedMasterClientId
        self.replacedAdditionalChatListItems = replacedAdditionalChatListItems
        self.updatedNoticeEntryKeys = updatedNoticeEntryKeys
        self.updatedCacheEntryKeys = updatedCacheEntryKeys
        self.updatedFailedMessagePeerIds = updatedFailedMessagePeerIds
        self.updatedFailedMessageIds = updatedFailedMessageIds
        self.updatedGlobalNotificationSettings = updatedGlobalNotificationSettings
        self.updatedPeerTimeoutAttributes = updatedPeerTimeoutAttributes
        self.updatedMessageThreadPeerIds = updatedMessageThreadPeerIds
        self.updatedPeerThreadCombinedStates = updatedPeerThreadCombinedStates
        self.updatedPeerThreadsSummaries = updatedPeerThreadsSummaries
        self.updatedPinnedThreads = updatedPinnedThreads
    }
}
