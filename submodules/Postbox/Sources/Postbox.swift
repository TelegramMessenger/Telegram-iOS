import Foundation

import SwiftSignalKit

public protocol PeerChatState: PostboxCoding {
    func equals(_ other: PeerChatState) -> Bool
}

public enum PostboxUpdateMessage {
    case update(StoreMessage)
    case skip
}

public final class Transaction {
    private weak var postbox: Postbox?
    var disposed = false
    
    fileprivate init(postbox: Postbox) {
        self.postbox = postbox
    }
    
    public func keychainEntryForKey(_ key: String) -> Data? {
        assert(!self.disposed)
        return self.postbox?.keychainTable.get(key)
    }
    
    public func setKeychainEntry(_ value: Data, forKey key: String) {
        assert(!self.disposed)
        self.postbox?.keychainTable.set(key, value: value)
    }
    
    public func addMessages(_ messages: [StoreMessage], location: AddMessagesLocation) -> [Int64: MessageId] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.addMessages(transaction: self, messages: messages, location: location)
        } else {
            return [:]
        }
    }
    
    public func countIncomingMessage(id: MessageId) {
        assert(!self.disposed)
        if let postbox = self.postbox {
            postbox.countIncomingMessage(id: id)
        }
    }
    
    public func addHole(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, range: ClosedRange<MessageId.Id>) {
        assert(!self.disposed)
        self.postbox?.addHole(peerId: peerId, namespace: namespace, space: space, range: range)
    }
    
    public func removeHole(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, range: ClosedRange<MessageId.Id>) {
        assert(!self.disposed)
        self.postbox?.removeHole(peerId: peerId, namespace: namespace, space: space, range: range)
    }
    
    public func getHole(containing id: MessageId) -> [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] {
        assert(!self.disposed)
        return self.postbox?.messageHistoryHoleIndexTable.containing(id: id) ?? [:]
    }
    
    public func doesChatListGroupContainHoles(groupId: PeerGroupId) -> Bool {
        assert(!self.disposed)
        return self.postbox?.chatListTable.doesGroupContainHoles(groupId: groupId) ?? false
    }
    
    public func recalculateChatListGroupStats(groupId: PeerGroupId) {
        assert(!self.disposed)
        self.postbox?.recalculateChatListGroupStats(groupId: groupId)
    }
    
    public func replaceChatListHole(groupId: PeerGroupId, index: MessageIndex, hole: ChatListHole?) {
        assert(!self.disposed)
        self.postbox?.replaceChatListHole(groupId: groupId, index: index, hole: hole)
    }
    
    public func deleteMessages(_ messageIds: [MessageId], forEachMedia: (Media) -> Void) {
        assert(!self.disposed)
        self.postbox?.deleteMessages(messageIds, forEachMedia: forEachMedia)
    }
    
    public func deleteMessagesInRange(peerId: PeerId, namespace: MessageId.Namespace, minId: MessageId.Id, maxId: MessageId.Id, forEachMedia: (Media) -> Void) {
        assert(!self.disposed)
        self.postbox?.deleteMessagesInRange(peerId: peerId, namespace: namespace, minId: minId, maxId: maxId, forEachMedia: forEachMedia)
    }
    
    public func withAllMessages(peerId: PeerId, namespace: MessageId.Namespace? = nil, _ f: (Message) -> Bool) {
        self.postbox?.withAllMessages(peerId: peerId, namespace: namespace, f)
    }
    
    public func clearHistory(_ peerId: PeerId, namespaces: MessageIdNamespaces, forEachMedia: (Media) -> Void) {
        assert(!self.disposed)
        self.postbox?.clearHistory(peerId, namespaces: namespaces, forEachMedia: forEachMedia)
    }
    
    public func removeAllMessagesWithAuthor(_ peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace, forEachMedia: (Media) -> Void) {
        assert(!self.disposed)
        self.postbox?.removeAllMessagesWithAuthor(peerId, authorId: authorId, namespace: namespace, forEachMedia: forEachMedia)
    }
    
    public func messageIdsForGlobalIds(_ ids: [Int32]) -> [MessageId] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.messageIdsForGlobalIds(ids)
        } else {
            return []
        }
    }
    public func failedMessageIds(for peerId: PeerId) -> [MessageId] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.failedMessageIds(for: peerId)
        } else {
            return []
        }
    }
    
    public func deleteMessagesWithGlobalIds(_ ids: [Int32], forEachMedia: (Media) -> Void) {
        assert(!self.disposed)
        if let postbox = self.postbox {
            let messageIds = postbox.messageIdsForGlobalIds(ids)
            postbox.deleteMessages(messageIds, forEachMedia: forEachMedia)
        }
    }
    
    public func messageIdForGloballyUniqueMessageId(peerId: PeerId, id: Int64) -> MessageId? {
        assert(!self.disposed)
        return self.postbox?.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id)
    }
    
    public func resetIncomingReadStates(_ states: [PeerId: [MessageId.Namespace: PeerReadState]]) {
        assert(!self.disposed)
        self.postbox?.resetIncomingReadStates(states)
    }
    
    public func setNeedsIncomingReadStateSynchronization(_ peerId: PeerId) {
        assert(!self.disposed)
        self.postbox?.setNeedsIncomingReadStateSynchronization(peerId)
    }
    
    public func confirmSynchronizedIncomingReadState(_ peerId: PeerId) {
        assert(!self.disposed)
        self.postbox?.confirmSynchronizedIncomingReadState(peerId)
    }
    
    public func applyIncomingReadMaxId(_ messageId: MessageId) {
        assert(!self.disposed)
        self.postbox?.applyIncomingReadMaxId(messageId)
    }
    
    public func applyOutgoingReadMaxId(_ messageId: MessageId) {
        assert(!self.disposed)
        self.postbox?.applyOutgoingReadMaxId(messageId)
    }
    
    public func applyInteractiveReadMaxIndex(_ messageIndex: MessageIndex) -> [MessageId] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.applyInteractiveReadMaxIndex(messageIndex)
        } else {
            return []
        }
    }
    
    public func applyMarkUnread(peerId: PeerId, namespace: MessageId.Namespace, value: Bool, interactive: Bool) {
        assert(!self.disposed)
        self.postbox?.applyMarkUnread(peerId: peerId, namespace: namespace, value: value, interactive: interactive)
    }
    
    public func applyOutgoingReadMaxIndex(_ messageIndex: MessageIndex) -> [MessageId] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.applyOutgoingReadMaxIndex(messageIndex)
        } else {
            return []
        }
    }
    
    public func resetPeerGroupSummary(groupId: PeerGroupId, namespace: MessageId.Namespace, summary: PeerGroupUnreadCountersSummary) {
        assert(!self.disposed)
        self.postbox?.resetPeerGroupSummary(groupId: groupId, namespace: namespace, summary: summary)
    }
    
    public func setNeedsPeerGroupMessageStatsSynchronization(groupId: PeerGroupId, namespace: MessageId.Namespace) {
        assert(!self.disposed)
        self.postbox?.setNeedsPeerGroupMessageStatsSynchronization(groupId: groupId, namespace: namespace)
    }
    
    public func confirmSynchronizedPeerGroupMessageStats(groupId: PeerGroupId, namespace: MessageId.Namespace) {
        assert(!self.disposed)
        self.postbox?.confirmSynchronizedPeerGroupMessageStats(groupId: groupId, namespace: namespace)
    }
    
    public func getState() -> PostboxCoding? {
        assert(!self.disposed)
        return self.postbox?.getState()
    }
    
    public func setState(_ state: PostboxCoding) {
        assert(!self.disposed)
        self.postbox?.setState(state)
    }
    
    public func getPeerChatState(_ id: PeerId) -> PeerChatState? {
        assert(!self.disposed)
        return self.postbox?.peerChatStateTable.get(id) as? PeerChatState
    }
    
    public func setPeerChatState(_ id: PeerId, state: PeerChatState) {
        assert(!self.disposed)
        self.postbox?.setPeerChatState(id, state: state)
    }
    
    /*public func getPeerGroupState(_ id: PeerGroupId) -> PeerGroupState? {
        assert(!self.disposed)
        return self.postbox?.peerGroupStateTable.get(id)
    }
    
    public func setPeerGroupState(_ id: PeerGroupId, state: PeerGroupState) {
        assert(!self.disposed)
        self.postbox?.setPeerGroupState(id, state: state)
    }*/
    
    public func getPeerChatInterfaceState(_ id: PeerId) -> PeerChatInterfaceState? {
        assert(!self.disposed)
        return self.postbox?.peerChatInterfaceStateTable.get(id)
    }
    
    public func updatePeerChatInterfaceState(_ id: PeerId, update: (PeerChatInterfaceState?) -> (PeerChatInterfaceState?)) {
        assert(!self.disposed)
        self.postbox?.updatePeerChatInterfaceState(id, update: update)
    }
    
    public func getPeer(_ id: PeerId) -> Peer? {
        assert(!self.disposed)
        return self.postbox?.peerTable.get(id)
    }
    
    public func getPeerReadStates(_ id: PeerId) -> [(MessageId.Namespace, PeerReadState)]? {
        assert(!self.disposed)
        return self.postbox?.readStateTable.getCombinedState(id)?.states
    }
    
    public func getCombinedPeerReadState(_ id: PeerId) -> CombinedPeerReadState? {
        assert(!self.disposed)
        return self.postbox?.readStateTable.getCombinedState(id)
    }
    
    public func getPeerNotificationSettings(_ id: PeerId) -> PeerNotificationSettings? {
        assert(!self.disposed)
        return self.postbox?.peerNotificationSettingsTable.getEffective(id)
    }
    
    public func getAllPeerNotificationSettings() -> [PeerId : PeerNotificationSettings]? {
        assert(!self.disposed)
        return self.postbox?.peerNotificationSettingsTable.getAll()
    }
    
    public func getPendingPeerNotificationSettings(_ id: PeerId) -> PeerNotificationSettings? {
        assert(!self.disposed)
        return self.postbox?.peerNotificationSettingsTable.getPending(id)
    }
    
    public func updatePeersInternal(_ peers: [Peer], update: (Peer?, Peer) -> Peer?) {
        assert(!self.disposed)
        self.postbox?.updatePeers(peers, update: update)
    }
    
    public func getPeerChatListInclusion(_ id: PeerId) -> PeerChatListInclusion {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.getPeerChatListInclusion(id)
        }
        return .notIncluded
    }
    
    public func getAssociatedPeerIds(_ id: PeerId) -> Set<PeerId> {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.reverseAssociatedPeerTable.get(peerId: id)
        }
        return []
    }
    
    public func getTopPeerMessageId(peerId: PeerId, namespace: MessageId.Namespace) -> MessageId? {
        assert(!self.disposed)
        return self.getTopPeerMessageIndex(peerId: peerId, namespace: namespace)?.id
    }
    
    public func getTopPeerMessageIndex(peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex? {
        assert(!self.disposed)
        return self.postbox?.getTopPeerMessageIndex(peerId: peerId, namespace: namespace)
    }
    
    public func getTopPeerMessageIndex(peerId: PeerId) -> MessageIndex? {
        assert(!self.disposed)
        return self.postbox?.getTopPeerMessageIndex(peerId: peerId)
    }
    
    public func getPeerChatListIndex(_ peerId: PeerId) -> (PeerGroupId, ChatListIndex)? {
        assert(!self.disposed)
        return self.postbox?.chatListTable.getPeerChatListIndex(peerId: peerId)
    }
    
    public func getUnreadChatListPeerIds(groupId: PeerGroupId) -> [PeerId] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.chatListTable.getUnreadChatListPeerIds(postbox: postbox, groupId: groupId)
        } else {
            return []
        }
    }
    
    public func updatePeerChatListInclusion(_ id: PeerId, inclusion: PeerChatListInclusion) {
        assert(!self.disposed)
        self.postbox?.updatePeerChatListInclusion(id, inclusion: inclusion)
    }
    
    public func updateCurrentPeerNotificationSettings(_ notificationSettings: [PeerId: PeerNotificationSettings]) {
        assert(!self.disposed)
        self.postbox?.updateCurrentPeerNotificationSettings(notificationSettings)
    }
    
    public func updatePendingPeerNotificationSettings(peerId: PeerId, settings: PeerNotificationSettings?) {
        assert(!self.disposed)
        self.postbox?.updatePendingPeerNotificationSettings(peerId: peerId, settings: settings)
    }
    
    public func resetAllPeerNotificationSettings(_ notificationSettings: PeerNotificationSettings) {
        assert(!self.disposed)
        self.postbox?.resetAllPeerNotificationSettings(notificationSettings)
    }
    
    public func getPeerIdsAndNotificationSettingsWithBehaviorTimestampLessThanOrEqualTo(_ timestamp: Int32) -> [(PeerId, PeerNotificationSettings)] {
        assert(!self.disposed)
        guard let postbox = self.postbox else {
            return []
        }
        var result: [(PeerId, PeerNotificationSettings)] = []
        for peerId in postbox.peerNotificationSettingsBehaviorTable.getEarlierThanOrEqualTo(timestamp: timestamp) {
            if let notificationSettings = postbox.peerNotificationSettingsTable.getCurrent(peerId) {
                result.append((peerId, notificationSettings))
            }
        }
        return result
    }
    
    public func updatePeerCachedData(peerIds: Set<PeerId>, update: (PeerId, CachedPeerData?) -> CachedPeerData?) {
        assert(!self.disposed)
        self.postbox?.updatePeerCachedData(peerIds: peerIds, update: update)
    }
    
    public func getPeerCachedData(peerId: PeerId) -> CachedPeerData? {
        assert(!self.disposed)
        return self.postbox?.cachedPeerDataTable.get(peerId)
    }
    
    public func updatePeerPresencesInternal(presences: [PeerId: PeerPresence], merge: (PeerPresence, PeerPresence) -> PeerPresence) {
        assert(!self.disposed)
        self.postbox?.updatePeerPresences(presences: presences, merge: merge)
    }
    
    public func updatePeerPresenceInternal(peerId: PeerId, update: (PeerPresence) -> PeerPresence) {
        assert(!self.disposed)
        self.postbox?.updatePeerPresence(peerId: peerId, update: update)
    }
    
    public func getPeerPresence(peerId: PeerId) -> PeerPresence? {
        assert(!self.disposed)
        return self.postbox?.peerPresenceTable.get(peerId)
    }
    
    public func getContactPeerIds() -> Set<PeerId> {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.contactsTable.get()
        } else {
            return Set()
        }
    }
    
    public func isPeerContact(peerId: PeerId) -> Bool {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.contactsTable.isContact(peerId: peerId)
        } else {
            return false
        }
    }
    
    public func getRemoteContactCount() -> Int32 {
        assert(!self.disposed)
        return self.postbox?.metadataTable.getRemoteContactCount() ?? 0
    }
    
    public func replaceRemoteContactCount(_ count: Int32) {
        assert(!self.disposed)
        self.postbox?.replaceRemoteContactCount(count)
    }
    
    public func replaceContactPeerIds(_ peerIds: Set<PeerId>) {
        assert(!self.disposed)
        self.postbox?.replaceContactPeerIds(peerIds)
    }
    
    public func replaceAdditionalChatListItems(_ peerIds: [PeerId]) {
        assert(!self.disposed)
        self.postbox?.replaceAdditionalChatListItems(peerIds)
    }
    
    public func replaceRecentPeerIds(_ peerIds: [PeerId]) {
        assert(!self.disposed)
        self.postbox?.replaceRecentPeerIds(peerIds)
    }
    
    public func getRecentPeerIds() -> [PeerId] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.peerRatingTable.get()
        } else {
            return []
        }
    }
    
    public func updateMessage(_ id: MessageId, update: (Message) -> PostboxUpdateMessage) {
        assert(!self.disposed)
        self.postbox?.updateMessage(id, update: update)
    }
    
    public func offsetPendingMessagesTimestamps(lowerBound: MessageId, excludeIds: Set<MessageId>, timestamp: Int32) {
        assert(!self.disposed)
        self.postbox?.offsetPendingMessagesTimestamps(lowerBound: lowerBound, excludeIds: excludeIds, timestamp: timestamp)
    }
    
    public func updateMessageGroupingKeysAtomically(_ ids: [MessageId], groupingKey: Int64) {
        assert(!self.disposed)
        self.postbox?.updateMessageGroupingKeysAtomically(ids, groupingKey: groupingKey)
    }
    
    public func updateMedia(_ id: MediaId, update: Media?) -> Set<MessageIndex> {
        assert(!self.disposed)
        return self.postbox?.updateMedia(id, update: update) ?? Set()
    }
    
    public func replaceItemCollections(namespace: ItemCollectionId.Namespace, itemCollections: [(ItemCollectionId, ItemCollectionInfo, [ItemCollectionItem])]) {
        assert(!self.disposed)
        self.postbox?.replaceItemCollections(namespace: namespace, itemCollections: itemCollections)
    }
    
    public func replaceItemCollectionInfos(namespace: ItemCollectionId.Namespace, itemCollectionInfos: [(ItemCollectionId, ItemCollectionInfo)]) {
        assert(!self.disposed)
        self.postbox?.replaceItemCollectionInfos(namespace: namespace, itemCollectionInfos: itemCollectionInfos)
    }
    
    public func replaceItemCollectionItems(collectionId: ItemCollectionId, items: [ItemCollectionItem]) {
        assert(!self.disposed)
        self.postbox?.replaceItemCollectionItems(collectionId: collectionId, items: items)
    }
    
    public func removeItemCollection(collectionId: ItemCollectionId) {
        assert(!self.disposed)
        self.postbox?.removeItemCollection(collectionId: collectionId)
    }
    
    public func getItemCollectionsInfos(namespace: ItemCollectionId.Namespace) -> [(ItemCollectionId, ItemCollectionInfo)] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.itemCollectionInfoTable.getInfos(namespace: namespace).map { ($0.1, $0.2) }
        } else {
            return []
        }
    }
    
    public func getItemCollectionInfo(collectionId: ItemCollectionId) -> ItemCollectionInfo? {
        assert(!self.disposed)
        return self.postbox?.itemCollectionInfoTable.getInfo(id: collectionId)
    }
    
    public func getItemCollectionItems(collectionId: ItemCollectionId) -> [ItemCollectionItem] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.itemCollectionItemTable.collectionItems(collectionId: collectionId)
        } else {
            return []
        }
    }
    
    public func getCollectionsItems(namespace: ItemCollectionId.Namespace) -> [(ItemCollectionId, ItemCollectionInfo, [ItemCollectionItem])] {
        assert(!self.disposed)
        if let postbox = postbox {
            let infos = postbox.itemCollectionInfoTable.getInfos(namespace: namespace)
            var result: [(ItemCollectionId, ItemCollectionInfo, [ItemCollectionItem])] = []
            for info in infos {
                let items = getItemCollectionItems(collectionId: info.1)
                result.append((info.1, info.2, items))
            }
            return result
        } else {
            return []
        }
    }
    
    public func getItemCollectionInfoItems(namespace: ItemCollectionId.Namespace, id: ItemCollectionId) -> (ItemCollectionInfo, [ItemCollectionItem])? {
        assert(!self.disposed)
        if let postbox = postbox {
            let infos = postbox.itemCollectionInfoTable.getInfos(namespace: namespace)
            for info in infos {
                if info.1 == id {
                    return (info.2, getItemCollectionItems(collectionId: id))
                }
            }
        }
        
        return nil
    }
    
    
    public func searchItemCollection(namespace: ItemCollectionId.Namespace, query: ItemCollectionSearchQuery) -> [ItemCollectionItem] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            let itemsByCollectionId = postbox.itemCollectionItemTable.searchIndexedItems(namespace: namespace, query: query)
            let infoIds = postbox.itemCollectionInfoTable.getIds(namespace: namespace)
            var infoIndices: [ItemCollectionId: Int] = [:]
            for i in 0 ..< infoIds.count {
                infoIndices[infoIds[i]] = i
            }
            let sortedKeys = itemsByCollectionId.keys.sorted(by: { lhs, rhs in
                if let lhsIndex = infoIndices[lhs], let rhsIndex = infoIndices[rhs] {
                    return lhsIndex < rhsIndex
                } else if let _ = infoIndices[lhs] {
                    return true
                } else {
                    return false
                }
            })
            var result: [ItemCollectionItem] = []
            for key in sortedKeys {
                result.append(contentsOf: itemsByCollectionId[key]!)
            }
            return result
        } else {
            return []
        }
    }
    
    public func replaceOrderedItemListItems(collectionId: Int32, items: [OrderedItemListEntry]) {
        assert(!self.disposed)
        self.postbox?.replaceOrderedItemListItems(collectionId: collectionId, items: items)
    }
    
    public func addOrMoveToFirstPositionOrderedItemListItem(collectionId: Int32, item: OrderedItemListEntry, removeTailIfCountExceeds: Int?) {
        assert(!self.disposed)
        self.postbox?.addOrMoveToFirstPositionOrderedItemListItem(collectionId: collectionId, item: item, removeTailIfCountExceeds: removeTailIfCountExceeds)
    }
    
    public func getOrderedListItemIds(collectionId: Int32) -> [MemoryBuffer] {
        assert(!self.disposed)
        if let postbox = postbox {
            return postbox.getOrderedListItemIds(collectionId: collectionId)
        } else {
            return []
        }
    }
    
    public func getOrderedListItems(collectionId: Int32) -> [OrderedItemListEntry] {
        assert(!self.disposed)
        if let postbox = postbox {
            return postbox.orderedItemListTable.getItems(collectionId: collectionId)
        } else {
            return []
        }
    }
    
    public func getOrderedItemListItem(collectionId: Int32, itemId: MemoryBuffer) -> OrderedItemListEntry? {
        assert(!self.disposed)
        return self.postbox?.getOrderedItemListItem(collectionId: collectionId, itemId: itemId)
    }
    
    public func updateOrderedItemListItem(collectionId: Int32, itemId: MemoryBuffer, item: OrderedItemListEntryContents) {
        assert(!self.disposed)
        self.postbox?.updateOrderedItemListItem(collectionId: collectionId, itemId: itemId, item: item)
    }
    
    public func removeOrderedItemListItem(collectionId: Int32, itemId: MemoryBuffer) {
        assert(!self.disposed)
        self.postbox?.removeOrderedItemListItem(collectionId: collectionId, itemId: itemId)
    }
    
    public func getMessage(_ id: MessageId) -> Message? {
        assert(!self.disposed)
        return self.postbox?.getMessage(id)
    }
    
    public func getMessageGroup(_ id: MessageId) -> [Message]? {
        assert(!self.disposed)
        return self.postbox?.getMessageGroup(at: id)
    }
    
    public func getMessageForwardedGroup(_ id: MessageId) -> [Message]? {
        assert(!self.disposed)
        return self.postbox?.getMessageForwardedGroup(id)
    }
    
    public func getMessageFailedGroup(_ id: MessageId) -> [Message]? {
        assert(!self.disposed)
        return self.postbox?.getMessageFailedGroup(id)
    }
    
    public func getMedia(_ id: MediaId) -> Media? {
        assert(!self.disposed)
        return self.postbox?.messageHistoryTable.getMedia(id)
    }
    
    public func findMessageIdByTimestamp(peerId: PeerId, namespace: MessageId.Namespace, timestamp: Int32) -> MessageId? {
        assert(!self.disposed)
        return self.postbox?.messageHistoryTable.findMessageId(peerId: peerId, namespace: namespace, timestamp: timestamp)
    }
    
    public func findClosestMessageIdByTimestamp(peerId: PeerId, timestamp: Int32) -> MessageId? {
        assert(!self.disposed)
        return self.postbox?.messageHistoryTable.findClosestMessageIndex(peerId: peerId, timestamp: timestamp)?.id
    }
    
    public func findRandomMessage(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags, ignoreIds: ([MessageId], Set<MessageId>)) -> MessageIndex? {
        assert(!self.disposed)
        return self.postbox?.messageHistoryTable.findRandomMessage(peerId: peerId, namespace: namespace, tag: tag, ignoreIds: ignoreIds)
    }
    
    public func filterStoredMessageIds(_ messageIds: Set<MessageId>) -> Set<MessageId> {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.filterStoredMessageIds(messageIds)
        }
        return Set()
    }
    
    public func storedMessageId(peerId: PeerId, namespace: MessageId.Namespace, timestamp: Int32) -> MessageId? {
        assert(!self.disposed)
        return self.postbox?.storedMessageId(peerId: peerId, namespace: namespace, timestamp: timestamp)
    }
    
    public func putItemCacheEntry(id: ItemCacheEntryId, entry: PostboxCoding, collectionSpec: ItemCacheCollectionSpec) {
        assert(!self.disposed)
        self.postbox?.putItemCacheEntry(id: id, entry: entry, collectionSpec: collectionSpec)
    }
    
    public func removeItemCacheEntry(id: ItemCacheEntryId) {
        assert(!self.disposed)
        self.postbox?.removeItemCacheEntry(id: id)
    }
    
    public func retrieveItemCacheEntry(id: ItemCacheEntryId) -> PostboxCoding? {
        assert(!self.disposed)
        return self.postbox?.retrieveItemCacheEntry(id: id)
    }
    
    public func operationLogGetNextEntryLocalIndex(peerId: PeerId, tag: PeerOperationLogTag) -> Int32 {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: tag)
        } else {
            return 0
        }
    }
    
    public func operationLogResetIndices(peerId: PeerId, tag: PeerOperationLogTag, nextTagLocalIndex: Int32) {
        assert(!self.disposed)
        self.postbox?.peerOperationLogTable.resetIndices(peerId: peerId, tag: tag, nextTagLocalIndex: nextTagLocalIndex)
    }
    
    public func operationLogAddEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: StorePeerOperationLogEntryTagLocalIndex, tagMergedIndex: StorePeerOperationLogEntryTagMergedIndex, contents: PostboxCoding) {
        assert(!self.disposed)
        self.postbox?.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, tagMergedIndex: tagMergedIndex, contents: contents)
    }
    
    public func operationLogRemoveEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32) -> Bool {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex)
        } else {
            return false
        }
    }
    
    public func operationLogRemoveAllEntries(peerId: PeerId, tag: PeerOperationLogTag) {
        assert(!self.disposed)
        self.postbox?.operationLogRemoveAllEntries(peerId: peerId, tag: tag)
    }
    
    public func operationLogRemoveEntries(peerId: PeerId, tag: PeerOperationLogTag, withTagLocalIndicesEqualToOrLowerThan maxTagLocalIndex: Int32) {
        assert(!self.disposed)
        self.postbox?.operationLogRemoveEntries(peerId: peerId, tag: tag, withTagLocalIndicesEqualToOrLowerThan: maxTagLocalIndex)
    }
    
    public func operationLogUpdateEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: (PeerOperationLogEntry?) -> PeerOperationLogEntryUpdate) {
        assert(!self.disposed)
        self.postbox?.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, f)
    }
    
    public func operationLogEnumerateEntries(peerId: PeerId, tag: PeerOperationLogTag, _ f: (PeerOperationLogEntry) -> Bool) {
        assert(!self.disposed)
        self.postbox?.operationLogEnumerateEntries(peerId: peerId, tag: tag, f)
    }
    
    public func addTimestampBasedMessageAttribute(tag: UInt16, timestamp: Int32, messageId: MessageId) {
        assert(!self.disposed)
        self.postbox?.addTimestampBasedMessageAttribute(tag: tag, timestamp: timestamp, messageId: messageId)
    }
    
    public func removeTimestampBasedMessageAttribute(tag: UInt16, messageId: MessageId) {
        assert(!self.disposed)
        self.postbox?.removeTimestampBasedMessageAttribute(tag: tag, messageId: messageId)
    }
    
    public func enumeratePreferencesEntries(_ f: (PreferencesEntry) -> Bool) {
        assert(!self.disposed)
        self.postbox?.enumeratePreferencesEntries(f)
    }
    
    public func getPreferencesEntry(key: ValueBoxKey) -> PreferencesEntry? {
        assert(!self.disposed)
        return self.postbox?.getPreferencesEntry(key: key)
    }
    
    public func setPreferencesEntry(key: ValueBoxKey, value: PreferencesEntry?) {
        assert(!self.disposed)
        self.postbox?.setPreferencesEntry(key: key, value: value)
    }
    
    public func updatePreferencesEntry(key: ValueBoxKey, _ f: (PreferencesEntry?) -> PreferencesEntry?) {
        assert(!self.disposed)
        self.postbox?.setPreferencesEntry(key: key, value: f(self.postbox?.getPreferencesEntry(key: key)))
    }
    
    public func getPinnedItemIds(groupId: PeerGroupId) -> [PinnedItemId] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.getPinnedItemIds(groupId: groupId)
        } else {
            return []
        }
    }
    
    public func setPinnedItemIds(groupId: PeerGroupId, itemIds: [PinnedItemId]) {
        assert(!self.disposed)
        if let postbox = self.postbox {
            postbox.setPinnedItemIds(groupId: groupId, itemIds: itemIds)
        }
    }
    
    public func getTotalUnreadState() -> ChatListTotalUnreadState {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.messageHistoryMetadataTable.getChatListTotalUnreadState()
        } else {
            return ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
        }
    }
    
    public func legacyGetAccessChallengeData() -> PostboxAccessChallengeData {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.metadataTable.accessChallengeData()
        } else {
            return .none
        }
    }
    
    public func enumerateMedia(lowerBound: MessageIndex?, upperBound: MessageIndex?, limit: Int) -> ([PeerId: Set<MediaId>], [MediaId: Media], MessageIndex?) {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.messageHistoryTable.enumerateMedia(lowerBound: lowerBound, upperBound: upperBound, limit: limit)
        } else {
            return ([:], [:], nil)
        }
    }
    
    public func replaceGlobalMessageTagsHole(globalTags: GlobalMessageTags, index: MessageIndex, with updatedIndex: MessageIndex?, messages: [StoreMessage]) {
        assert(!self.disposed)
        self.postbox?.replaceGlobalMessageTagsHole(transaction: self, globalTags: globalTags, index: index, with: updatedIndex, messages: messages)
    }
    
    public func searchMessages(peerId: PeerId?, query: String, tags: MessageTags?) -> [Message] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.searchMessages(peerId: peerId, query: query, tags: tags)
        } else {
            return []
        }
    }
    
    public func unorderedItemListScan(tag: UnorderedItemListEntryTag, _ f: (UnorderedItemListEntry) -> Void) {
        if let postbox = self.postbox {
            postbox.unorderedItemListTable.scan(tag: tag, f)
        }
    }
    
    public func unorderedItemListDifference(tag: UnorderedItemListEntryTag, updatedEntryInfos: [ValueBoxKey: UnorderedItemListEntryInfo]) -> (metaInfo: UnorderedItemListTagMetaInfo?, added: [ValueBoxKey], removed: [UnorderedItemListEntry], updated: [UnorderedItemListEntry]) {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.unorderedItemListTable.difference(tag: tag, updatedEntryInfos: updatedEntryInfos)
        } else {
            return (nil, [], [], [])
        }
    }
    
    public func unorderedItemListApplyDifference(tag: UnorderedItemListEntryTag, previousInfo: UnorderedItemListTagMetaInfo?, updatedInfo: UnorderedItemListTagMetaInfo, setItems: [UnorderedItemListEntry], removeItemIds: [ValueBoxKey]) -> Bool {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.unorderedItemListTable.applyDifference(tag: tag, previousInfo: previousInfo, updatedInfo: updatedInfo, setItems: setItems, removeItemIds: removeItemIds)
        } else {
            return false
        }
    }
    
    public func getAllNoticeEntries() -> [ValueBoxKey: NoticeEntry] {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.noticeTable.getAll()
        } else {
            return [:]
        }
    }
    
    public func getNoticeEntry(key: NoticeEntryKey) -> PostboxCoding? {
        assert(!self.disposed)
        if let postbox = self.postbox {
            return postbox.noticeTable.get(key: key)
        } else {
            return nil
        }
    }
    
    public func setNoticeEntry(key: NoticeEntryKey, value: NoticeEntry?) {
        assert(!self.disposed)
        self.postbox?.setNoticeEntry(key: key, value: value)
    }
    
    public func clearNoticeEntries() {
        assert(!self.disposed)
        self.postbox?.clearNoticeEntries()
    }
    
    public func setPendingMessageAction(type: PendingMessageActionType, id: MessageId, action: PendingMessageActionData?) {
        assert(!self.disposed)
        self.postbox?.setPendingMessageAction(type: type, id: id, action: action)
    }
    
    public func getPendingMessageAction(type: PendingMessageActionType, id: MessageId) -> PendingMessageActionData? {
        assert(!self.disposed)
        return self.postbox?.getPendingMessageAction(type: type, id: id)
    }
    
    public func getMessageTagSummary(peerId: PeerId, tagMask: MessageTags, namespace: MessageId.Namespace) -> MessageHistoryTagNamespaceSummary? {
        assert(!self.disposed)
        return self.postbox?.messageHistoryTagsSummaryTable.get(MessageHistoryTagsSummaryKey(tag: tagMask, peerId: peerId, namespace: namespace))
    }
    
    public func replaceMessageTagSummary(peerId: PeerId, tagMask: MessageTags, namespace: MessageId.Namespace, count: Int32, maxId: MessageId.Id) {
        assert(!self.disposed)
        self.postbox?.replaceMessageTagSummary(peerId: peerId, tagMask: tagMask, namespace: namespace, count: count, maxId: maxId)
    }
    
    public func getMessageIndicesWithTag(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags) -> [MessageIndex] {
        assert(!self.disposed)
        guard let postbox = self.postbox else {
            return []
        }
        return postbox.messageHistoryTagsTable.earlierIndices(tag: tag, peerId: peerId, namespace: namespace, index: nil, includeFrom: false, count: 1000)
    }
    
    public func scanMessages(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags, _ f: (Message) -> Bool) {
        assert(!self.disposed)
        self.postbox?.scanMessages(peerId: peerId, namespace: namespace, tag: tag, f)
    }
    
    public func invalidateMessageHistoryTagsSummary(peerId: PeerId, namespace: MessageId.Namespace, tagMask: MessageTags) {
        assert(!self.disposed)
        self.postbox?.invalidateMessageHistoryTagsSummary(peerId: peerId, namespace: namespace, tagMask: tagMask)
    }
    
    public func removeInvalidatedMessageHistoryTagsSummaryEntry(_ entry: InvalidatedMessageHistoryTagsSummaryEntry) {
        assert(!self.disposed)
        self.postbox?.removeInvalidatedMessageHistoryTagsSummaryEntry(entry)
    }
    
    public func getRelativeUnreadChatListIndex(filtered: Bool, position: ChatListRelativePosition, groupId: PeerGroupId) -> ChatListIndex? {
        assert(!self.disposed)
        return self.postbox?.getRelativeUnreadChatListIndex(filtered: filtered, position: position, groupId: groupId)
    }
    
    public func getDeviceContactImportInfo(_ identifier: ValueBoxKey) -> PostboxCoding? {
        assert(!self.disposed)
        return self.postbox?.deviceContactImportInfoTable.get(identifier)
    }
    
    public func setDeviceContactImportInfo(_ identifier: ValueBoxKey, value: PostboxCoding?) {
        assert(!self.disposed)
        self.postbox?.deviceContactImportInfoTable.set(identifier, value: value)
    }
    
    public func getDeviceContactImportInfoIdentifiers() -> [ValueBoxKey] {
        assert(!self.disposed)
        return self.postbox?.deviceContactImportInfoTable.getIdentifiers() ?? []
    }
    
    public func clearDeviceContactImportInfoIdentifiers() {
        assert(!self.disposed)
        self.postbox?.clearDeviceContactImportInfoIdentifiers()
    }
    
    public func enumerateDeviceContactImportInfoItems(_ f: (ValueBoxKey, PostboxCoding) -> Bool) {
        assert(!self.disposed)
        self.postbox?.deviceContactImportInfoTable.enumerateDeviceContactImportInfoItems(f)
    }
    
    public func getChatListNamespaceEntries(groupId: PeerGroupId, namespace: MessageId.Namespace, summaryTag: MessageTags?) -> [ChatListNamespaceEntry] {
        assert(!self.disposed)
        guard let postbox = self.postbox else {
            return []
        }
        return postbox.chatListTable.getNamespaceEntries(groupId: groupId, namespace: namespace, summaryTag: summaryTag, messageIndexTable: postbox.messageHistoryIndexTable, messageHistoryTable: postbox.messageHistoryTable, peerChatInterfaceStateTable: postbox.peerChatInterfaceStateTable, readStateTable: postbox.readStateTable, summaryTable: postbox.messageHistoryTagsSummaryTable)
    }
    
    public func addHolesEverywhere(peerNamespaces: [PeerId.Namespace], holeNamespace: MessageId.Namespace) {
        assert(!self.disposed)
        self.postbox?.addHolesEverywhere(peerNamespaces: peerNamespaces, holeNamespace: holeNamespace)
    }
    
    public func reindexUnreadCounters() {
        assert(!self.disposed)
        self.postbox?.reindexUnreadCounters()
    }
}

public enum PostboxResult {
    case upgrading(Float)
    case postbox(Postbox)
}

func debugSaveState(basePath:String, name: String) {
    let path = basePath + name
    let _ = try? FileManager.default.removeItem(atPath: path)
    do {
        try FileManager.default.copyItem(atPath: basePath, toPath: path)
    } catch (let e) {
        print("(Postbox debugSaveState: error \(e))")
    }
}

func debugRestoreState(basePath:String, name: String) {
    let path = basePath + name
    if FileManager.default.fileExists(atPath: path) {
        let _ = try? FileManager.default.removeItem(atPath: basePath)
        do {
            try FileManager.default.copyItem(atPath: path, toPath: basePath)
        } catch (let e) {
            print("(Postbox debugRestoreState: error \(e))")
        }
    } else {
        print("(Postbox debugRestoreState: path doesn't exist")
    }
}

private let sharedQueue = Queue(name: "org.telegram.postbox.Postbox")

public func openPostbox(basePath: String, seedConfiguration: SeedConfiguration, encryptionParameters: ValueBoxEncryptionParameters) -> Signal<PostboxResult, NoError> {
    let queue = sharedQueue
    return Signal { subscriber in
        queue.async {
            let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)

            #if DEBUG
            //debugSaveState(basePath: basePath, name: "previous1")
            //debugRestoreState(basePath: basePath, name: "previous1")
            #endif
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            var valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue, encryptionParameters: encryptionParameters, upgradeProgress: { progress in
                subscriber.putNext(.upgrading(progress))
            })
            
            loop: while true {
                let metadataTable = MetadataTable(valueBox: valueBox, table: MetadataTable.tableSpec(0))
                
                let userVersion: Int32? = metadataTable.userVersion()
                let currentUserVersion: Int32 = 25
                
                if let userVersion = userVersion {
                    if userVersion != currentUserVersion {
                        if userVersion > currentUserVersion {
                            postboxLog("Version \(userVersion) is newer than supported")
                            assertionFailure("Version \(userVersion) is newer than supported")
                            valueBox.drop()
                            valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue, encryptionParameters: encryptionParameters, upgradeProgress: { progress in
                                subscriber.putNext(.upgrading(progress))
                            })
                        } else {
                            if let operation = registeredUpgrades()[userVersion] {
                                switch operation {
                                    case let .inplace(f):
                                        valueBox.begin()
                                        f(metadataTable, valueBox, { progress in
                                            subscriber.putNext(.upgrading(progress))
                                        })
                                        valueBox.commit()
                                    case let .standalone(f):
                                        let updatedPath = f(queue, basePath, valueBox, encryptionParameters, { progress in
                                            subscriber.putNext(.upgrading(progress))
                                        })
                                        if let updatedPath = updatedPath {
                                            valueBox.internalClose()
                                            let _ = try? FileManager.default.removeItem(atPath: basePath + "/db")
                                            let _ = try? FileManager.default.moveItem(atPath: updatedPath, toPath: basePath + "/db")
                                            valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue, encryptionParameters: encryptionParameters, upgradeProgress: { progress in
                                                subscriber.putNext(.upgrading(progress))
                                            })
                                        }
                                }
                                continue loop
                            } else {
                                assertionFailure("Couldn't find any upgrade for \(userVersion)")
                                postboxLog("Couldn't find any upgrade for \(userVersion)")
                                valueBox.drop()
                                valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue, encryptionParameters: encryptionParameters, upgradeProgress: { progress in
                                    subscriber.putNext(.upgrading(progress))
                                })
                            }
                        }
                    }
                } else {
                    metadataTable.setUserVersion(currentUserVersion)
                }
                
                let endTime = CFAbsoluteTimeGetCurrent()
                print("Postbox load took \((endTime - startTime) * 1000.0) ms")
                
                subscriber.putNext(.postbox(Postbox(queue: queue, basePath: basePath, seedConfiguration: seedConfiguration, valueBox: valueBox)))
                subscriber.putCompletion()
                break
            }
        }
        
        return EmptyDisposable
    }
}

public final class Postbox {
    private let queue: Queue
    public let seedConfiguration: SeedConfiguration
    private let basePath: String
    let valueBox: SqliteValueBox
    
    private let ipcNotificationsDisposable = MetaDisposable()
    
    private var transactionStateVersion: Int64 = 0
    
    private var viewTracker: ViewTracker!
    private var nextViewId = 0
    
    private var currentUpdatedState: PostboxCoding?
    private var currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
    private var currentUpdatedChatListInclusions: [PeerId: PeerChatListInclusion] = [:]
    private var currentUnsentOperations: [IntermediateMessageHistoryUnsentOperation] = []
    private var currentUpdatedSynchronizeReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
    private var currentUpdatedGroupSummarySynchronizeOperations: [PeerGroupAndNamespace: Bool] = [:]
    private var currentUpdatedMedia: [MediaId: Media?] = [:]
    private var currentGlobalTagsOperations: [GlobalMessageHistoryTagsOperation] = []
    private var currentLocalTagsOperations: [IntermediateMessageHistoryLocalTagsOperation] = []
    
    private var currentPeerHoleOperations: [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]] = [:]
    private var currentUpdatedPeers: [PeerId: Peer] = [:]
    private var currentUpdatedPeerNotificationSettings: [PeerId: PeerNotificationSettings] = [:]
    private var currentUpdatedPeerNotificationBehaviorTimestamps: [PeerId: PeerNotificationSettingsBehaviorTimestamp] = [:]
    private var currentUpdatedCachedPeerData: [PeerId: CachedPeerData] = [:]
    private var currentUpdatedPeerPresences: [PeerId: PeerPresence] = [:]
    private var currentUpdatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
    private var currentUpdatedTotalUnreadState: ChatListTotalUnreadState?
    private var currentUpdatedGroupTotalUnreadSummaries: [PeerGroupId: PeerGroupUnreadCountersCombinedSummary] = [:]
    private var currentPeerMergedOperationLogOperations: [PeerMergedOperationLogOperation] = []
    private var currentTimestampBasedMessageAttributesOperations: [TimestampBasedMessageAttributesOperation] = []
    private var currentPreferencesOperations: [PreferencesOperation] = []
    private var currentOrderedItemListOperations: [Int32: [OrderedItemListOperation]] = [:]
    private var currentItemCollectionItemsOperations: [ItemCollectionId: [ItemCollectionItemsOperation]] = [:]
    private var currentItemCollectionInfosOperations: [ItemCollectionInfosOperation] = []
    private var currentUpdatedPeerChatStates = Set<PeerId>()
    private var currentPendingMessageActionsOperations: [PendingMessageActionsOperation] = []
    private var currentUpdatedMessageActionsSummaries: [PendingMessageActionsSummaryKey: Int32] = [:]
    private var currentUpdatedMessageTagSummaries: [MessageHistoryTagsSummaryKey : MessageHistoryTagNamespaceSummary] = [:]
    private var currentInvalidateMessageTagSummaries: [InvalidatedMessageHistoryTagsSummaryEntryOperation] = []
    private var currentUpdatedPendingPeerNotificationSettings = Set<PeerId>()
    private var currentGroupIdsWithUpdatedReadStats = Set<PeerGroupId>()
    
    private var currentChatListOperations: [PeerGroupId: [ChatListOperation]] = [:]
    private var currentReplaceRemoteContactCount: Int32?
    private var currentReplacedContactPeerIds: Set<PeerId>?
    private var currentUpdatedMasterClientId: Int64?
    
    private var currentReplacedAdditionalChatListItems: [PeerId]?
    private var currentUpdatedNoticeEntryKeys = Set<NoticeEntryKey>()
    private var currentUpdatedCacheEntryKeys = Set<ItemCacheEntryId>()
    
    private let statePipe: ValuePipe<PostboxCoding> = ValuePipe()
    private var masterClientId = Promise<Int64>()
    
    private var sessionClientId: Int64 = {
        var value: Int64 = 0
        arc4random_buf(&value, 8)
        return value
    }()
    
    public let mediaBox: MediaBox
    
    private var nextUniqueId: UInt32 = 1
    func takeNextUniqueId() -> UInt32 {
        assert(self.queue.isCurrent())
        let value = self.nextUniqueId
        self.nextUniqueId += 1
        return value
    }
    
    let tables: [Table]
    
    let metadataTable: MetadataTable
    let keychainTable: KeychainTable
    let peerTable: PeerTable
    let peerNotificationSettingsTable: PeerNotificationSettingsTable
    let pendingPeerNotificationSettingsIndexTable: PendingPeerNotificationSettingsIndexTable
    let peerNotificationSettingsBehaviorTable: PeerNotificationSettingsBehaviorTable
    let peerNotificationSettingsBehaviorIndexTable: PeerNotificationSettingsBehaviorIndexTable
    let cachedPeerDataTable: CachedPeerDataTable
    let peerPresenceTable: PeerPresenceTable
    let globalMessageIdsTable: GlobalMessageIdsTable
    let globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable
    let messageHistoryIndexTable: MessageHistoryIndexTable
    let messageHistoryTable: MessageHistoryTable
    let mediaTable: MessageMediaTable
    let chatListIndexTable: ChatListIndexTable
    let chatListTable: ChatListTable
    let additionalChatListItemsTable: AdditionalChatListItemsTable
    let messageHistoryMetadataTable: MessageHistoryMetadataTable
    let messageHistoryUnsentTable: MessageHistoryUnsentTable
    let messageHistoryFailedTable: MessageHistoryFailedTable
    let messageHistoryTagsTable: MessageHistoryTagsTable
    let globalMessageHistoryTagsTable: GlobalMessageHistoryTagsTable
    let localMessageHistoryTagsTable: LocalMessageHistoryTagsTable
    let peerChatStateTable: PeerChatStateTable
    let readStateTable: MessageHistoryReadStateTable
    let synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable
    let synchronizeGroupMessageStatsTable: InvalidatedGroupMessageStatsTable
    let contactsTable: ContactTable
    let itemCollectionInfoTable: ItemCollectionInfoTable
    let itemCollectionItemTable: ItemCollectionItemTable
    let itemCollectionReverseIndexTable: ReverseIndexReferenceTable<ItemCollectionItemReverseIndexReference>
    let peerChatInterfaceStateTable: PeerChatInterfaceStateTable
    let itemCacheMetaTable: ItemCacheMetaTable
    let itemCacheTable: ItemCacheTable
    let peerNameTokenIndexTable: ReverseIndexReferenceTable<PeerIdReverseIndexReference>
    let peerNameIndexTable: PeerNameIndexTable
    let reverseAssociatedPeerTable: ReverseAssociatedPeerTable
    let peerChatTopTaggedMessageIdsTable: PeerChatTopTaggedMessageIdsTable
    let peerOperationLogMetadataTable: PeerOperationLogMetadataTable
    let peerMergedOperationLogIndexTable: PeerMergedOperationLogIndexTable
    let peerOperationLogTable: PeerOperationLogTable
    let timestampBasedMessageAttributesTable: TimestampBasedMessageAttributesTable
    let timestampBasedMessageAttributesIndexTable: TimestampBasedMessageAttributesIndexTable
    let preferencesTable: PreferencesTable
    let orderedItemListTable: OrderedItemListTable
    let orderedItemListIndexTable: OrderedItemListIndexTable
    let textIndexTable: MessageHistoryTextIndexTable
    let unorderedItemListTable: UnorderedItemListTable
    let noticeTable: NoticeTable
    let messageHistoryTagsSummaryTable: MessageHistoryTagsSummaryTable
    let invalidatedMessageHistoryTagsSummaryTable: InvalidatedMessageHistoryTagsSummaryTable
    let pendingMessageActionsTable: PendingMessageActionsTable
    let pendingMessageActionsMetadataTable: PendingMessageActionsMetadataTable
    let deviceContactImportInfoTable: DeviceContactImportInfoTable
    let messageHistoryHoleIndexTable: MessageHistoryHoleIndexTable
    let groupMessageStatsTable: GroupMessageStatsTable
    
    //temporary
    let peerRatingTable: RatingTable<PeerId>
    
    var installedMessageActionsByPeerId: [PeerId: Bag<([StoreMessage], Transaction) -> Void>] = [:]
    
    init(queue: Queue, basePath: String, seedConfiguration: SeedConfiguration, valueBox: SqliteValueBox) {
        assert(queue.isCurrent())
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        self.queue = queue
        self.basePath = basePath
        self.seedConfiguration = seedConfiguration
        
        print("MediaBox path: \(self.basePath + "/media")")
        
        self.mediaBox = MediaBox(basePath: self.basePath + "/media")
        self.valueBox = valueBox
        
        /*self.pipeNotifier = PipeNotifier(basePath: basePath, notify: { [weak self] in
            //if let strongSelf = self {
                /*strongSelf.queue.async {
                    if strongSelf.valueBox != nil {
                        let _ = strongSelf.transaction({ _ -> Void in
                        }).start()
                    }
                }*/
            //}
        })*/
        
        self.metadataTable = MetadataTable(valueBox: self.valueBox, table: MetadataTable.tableSpec(0))
        
        self.keychainTable = KeychainTable(valueBox: self.valueBox, table: KeychainTable.tableSpec(1))
        self.reverseAssociatedPeerTable = ReverseAssociatedPeerTable(valueBox: self.valueBox, table:ReverseAssociatedPeerTable.tableSpec(40))
        self.peerTable = PeerTable(valueBox: self.valueBox, table: PeerTable.tableSpec(2), reverseAssociatedTable: self.reverseAssociatedPeerTable)
        self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox, table: GlobalMessageIdsTable.tableSpec(3), seedConfiguration: seedConfiguration)
        self.globallyUniqueMessageIdsTable = MessageGloballyUniqueIdTable(valueBox: self.valueBox, table: MessageGloballyUniqueIdTable.tableSpec(32))
        self.messageHistoryMetadataTable = MessageHistoryMetadataTable(valueBox: self.valueBox, table: MessageHistoryMetadataTable.tableSpec(10))
        self.messageHistoryHoleIndexTable = MessageHistoryHoleIndexTable(valueBox: self.valueBox, table: MessageHistoryHoleIndexTable.tableSpec(56), metadataTable: self.messageHistoryMetadataTable, seedConfiguration: self.seedConfiguration)
        self.messageHistoryUnsentTable = MessageHistoryUnsentTable(valueBox: self.valueBox, table: MessageHistoryUnsentTable.tableSpec(11))
        self.messageHistoryFailedTable = MessageHistoryFailedTable(valueBox: self.valueBox, table: MessageHistoryFailedTable.tableSpec(49))
        self.invalidatedMessageHistoryTagsSummaryTable = InvalidatedMessageHistoryTagsSummaryTable(valueBox: self.valueBox, table: InvalidatedMessageHistoryTagsSummaryTable.tableSpec(47))
        self.messageHistoryTagsSummaryTable = MessageHistoryTagsSummaryTable(valueBox: self.valueBox, table: MessageHistoryTagsSummaryTable.tableSpec(44), invalidateTable: self.invalidatedMessageHistoryTagsSummaryTable)
        self.pendingMessageActionsMetadataTable = PendingMessageActionsMetadataTable(valueBox: self.valueBox, table: PendingMessageActionsMetadataTable.tableSpec(45))
        self.pendingMessageActionsTable = PendingMessageActionsTable(valueBox: self.valueBox, table: PendingMessageActionsTable.tableSpec(46), metadataTable: self.pendingMessageActionsMetadataTable)
        self.messageHistoryTagsTable = MessageHistoryTagsTable(valueBox: self.valueBox, table: MessageHistoryTagsTable.tableSpec(12), seedConfiguration: self.seedConfiguration, summaryTable: self.messageHistoryTagsSummaryTable)
        self.globalMessageHistoryTagsTable = GlobalMessageHistoryTagsTable(valueBox: self.valueBox, table: GlobalMessageHistoryTagsTable.tableSpec(39))
        self.localMessageHistoryTagsTable = LocalMessageHistoryTagsTable(valueBox: self.valueBox, table: GlobalMessageHistoryTagsTable.tableSpec(52))
        self.messageHistoryIndexTable = MessageHistoryIndexTable(valueBox: self.valueBox, table: MessageHistoryIndexTable.tableSpec(4), messageHistoryHoleIndexTable: self.messageHistoryHoleIndexTable, globalMessageIdsTable: self.globalMessageIdsTable, metadataTable: self.messageHistoryMetadataTable, seedConfiguration: self.seedConfiguration)
        self.mediaTable = MessageMediaTable(valueBox: self.valueBox, table: MessageMediaTable.tableSpec(6))
        self.readStateTable = MessageHistoryReadStateTable(valueBox: self.valueBox, table: MessageHistoryReadStateTable.tableSpec(14), seedConfiguration: seedConfiguration)
        self.synchronizeReadStateTable = MessageHistorySynchronizeReadStateTable(valueBox: self.valueBox, table: MessageHistorySynchronizeReadStateTable.tableSpec(15))
        self.synchronizeGroupMessageStatsTable = InvalidatedGroupMessageStatsTable(valueBox: self.valueBox, table: InvalidatedGroupMessageStatsTable.tableSpec(59))
        self.timestampBasedMessageAttributesIndexTable = TimestampBasedMessageAttributesIndexTable(valueBox: self.valueBox, table: TimestampBasedMessageAttributesTable.tableSpec(33))
        self.timestampBasedMessageAttributesTable = TimestampBasedMessageAttributesTable(valueBox: self.valueBox, table: TimestampBasedMessageAttributesTable.tableSpec(34), indexTable: self.timestampBasedMessageAttributesIndexTable)
        self.textIndexTable = MessageHistoryTextIndexTable(valueBox: self.valueBox, table: MessageHistoryTextIndexTable.tableSpec(41))
        self.additionalChatListItemsTable = AdditionalChatListItemsTable(valueBox: self.valueBox, table: AdditionalChatListItemsTable.tableSpec(55))
        self.messageHistoryTable = MessageHistoryTable(valueBox: self.valueBox, table: MessageHistoryTable.tableSpec(7), seedConfiguration: seedConfiguration, messageHistoryIndexTable: self.messageHistoryIndexTable, messageHistoryHoleIndexTable: self.messageHistoryHoleIndexTable, messageMediaTable: self.mediaTable, historyMetadataTable: self.messageHistoryMetadataTable, globallyUniqueMessageIdsTable: self.globallyUniqueMessageIdsTable, unsentTable: self.messageHistoryUnsentTable, failedTable: self.messageHistoryFailedTable, tagsTable: self.messageHistoryTagsTable, globalTagsTable: self.globalMessageHistoryTagsTable, localTagsTable: self.localMessageHistoryTagsTable, readStateTable: self.readStateTable, synchronizeReadStateTable: self.synchronizeReadStateTable, textIndexTable: self.textIndexTable, summaryTable: self.messageHistoryTagsSummaryTable, pendingActionsTable: self.pendingMessageActionsTable)
        self.peerChatStateTable = PeerChatStateTable(valueBox: self.valueBox, table: PeerChatStateTable.tableSpec(13))
        self.peerNameTokenIndexTable = ReverseIndexReferenceTable<PeerIdReverseIndexReference>(valueBox: self.valueBox, table: ReverseIndexReferenceTable<PeerIdReverseIndexReference>.tableSpec(26))
        self.peerNameIndexTable = PeerNameIndexTable(valueBox: self.valueBox, table: PeerNameIndexTable.tableSpec(27), peerTable: self.peerTable, peerNameTokenIndexTable: self.peerNameTokenIndexTable)
        self.contactsTable = ContactTable(valueBox: self.valueBox, table: ContactTable.tableSpec(16), peerNameIndexTable: self.peerNameIndexTable)
        self.peerRatingTable = RatingTable<PeerId>(valueBox: self.valueBox, table: RatingTable<PeerId>.tableSpec(17))
        self.cachedPeerDataTable = CachedPeerDataTable(valueBox: self.valueBox, table: CachedPeerDataTable.tableSpec(18))
        self.pendingPeerNotificationSettingsIndexTable = PendingPeerNotificationSettingsIndexTable(valueBox: self.valueBox, table: PendingPeerNotificationSettingsIndexTable.tableSpec(48))
        self.peerNotificationSettingsBehaviorIndexTable = PeerNotificationSettingsBehaviorIndexTable(valueBox: self.valueBox, table: PeerNotificationSettingsBehaviorIndexTable.tableSpec(60))
        self.peerNotificationSettingsBehaviorTable = PeerNotificationSettingsBehaviorTable(valueBox: self.valueBox, table: PeerNotificationSettingsBehaviorTable.tableSpec(61), indexTable: self.peerNotificationSettingsBehaviorIndexTable)
        self.peerNotificationSettingsTable = PeerNotificationSettingsTable(valueBox: self.valueBox, table: PeerNotificationSettingsTable.tableSpec(19), pendingIndexTable: self.pendingPeerNotificationSettingsIndexTable, behaviorTable: self.peerNotificationSettingsBehaviorTable)
        self.peerPresenceTable = PeerPresenceTable(valueBox: self.valueBox, table: PeerPresenceTable.tableSpec(20))
        self.itemCollectionInfoTable = ItemCollectionInfoTable(valueBox: self.valueBox, table: ItemCollectionInfoTable.tableSpec(21))
        self.itemCollectionReverseIndexTable = ReverseIndexReferenceTable<ItemCollectionItemReverseIndexReference>(valueBox: self.valueBox, table: ReverseIndexReferenceTable<ItemCollectionItemReverseIndexReference>.tableSpec(36))
        self.itemCollectionItemTable = ItemCollectionItemTable(valueBox: self.valueBox, table: ItemCollectionItemTable.tableSpec(22), reverseIndexTable: self.itemCollectionReverseIndexTable)
        self.peerChatInterfaceStateTable = PeerChatInterfaceStateTable(valueBox: self.valueBox, table: PeerChatInterfaceStateTable.tableSpec(23))
        self.itemCacheMetaTable = ItemCacheMetaTable(valueBox: self.valueBox, table: ItemCacheMetaTable.tableSpec(24))
        self.itemCacheTable = ItemCacheTable(valueBox: self.valueBox, table: ItemCacheTable.tableSpec(25))
        self.chatListIndexTable = ChatListIndexTable(valueBox: self.valueBox, table: ChatListIndexTable.tableSpec(8), peerNameIndexTable: self.peerNameIndexTable, metadataTable: self.messageHistoryMetadataTable, readStateTable: self.readStateTable, notificationSettingsTable: self.peerNotificationSettingsTable)
        self.chatListTable = ChatListTable(valueBox: self.valueBox, table: ChatListTable.tableSpec(9), indexTable: self.chatListIndexTable, metadataTable: self.messageHistoryMetadataTable, seedConfiguration: self.seedConfiguration)
        self.peerChatTopTaggedMessageIdsTable = PeerChatTopTaggedMessageIdsTable(valueBox: self.valueBox, table: PeerChatTopTaggedMessageIdsTable.tableSpec(28))
        self.peerOperationLogMetadataTable = PeerOperationLogMetadataTable(valueBox: self.valueBox, table: PeerOperationLogMetadataTable.tableSpec(29))
        self.peerMergedOperationLogIndexTable = PeerMergedOperationLogIndexTable(valueBox: self.valueBox, table: PeerMergedOperationLogIndexTable.tableSpec(30), metadataTable: self.peerOperationLogMetadataTable)
        self.peerOperationLogTable = PeerOperationLogTable(valueBox: self.valueBox, table: PeerOperationLogTable.tableSpec(31), metadataTable: self.peerOperationLogMetadataTable, mergedIndexTable: self.peerMergedOperationLogIndexTable)
        self.preferencesTable = PreferencesTable(valueBox: self.valueBox, table: PreferencesTable.tableSpec(35))
        self.orderedItemListIndexTable = OrderedItemListIndexTable(valueBox: self.valueBox, table: OrderedItemListIndexTable.tableSpec(37))
        self.orderedItemListTable = OrderedItemListTable(valueBox: self.valueBox, table: OrderedItemListTable.tableSpec(38), indexTable: self.orderedItemListIndexTable)
        self.unorderedItemListTable = UnorderedItemListTable(valueBox: self.valueBox, table: UnorderedItemListTable.tableSpec(42))
        self.noticeTable = NoticeTable(valueBox: self.valueBox, table: NoticeTable.tableSpec(43))
        self.deviceContactImportInfoTable = DeviceContactImportInfoTable(valueBox: self.valueBox, table: DeviceContactImportInfoTable.tableSpec(54))
        self.groupMessageStatsTable = GroupMessageStatsTable(valueBox: self.valueBox, table: GroupMessageStatsTable.tableSpec(58))
        
        var tables: [Table] = []
        tables.append(self.metadataTable)
        tables.append(self.keychainTable)
        tables.append(self.peerTable)
        tables.append(self.globalMessageIdsTable)
        tables.append(self.globallyUniqueMessageIdsTable)
        tables.append(self.messageHistoryMetadataTable)
        tables.append(self.messageHistoryUnsentTable)
        tables.append(self.messageHistoryFailedTable)
        tables.append(self.messageHistoryTagsTable)
        tables.append(self.globalMessageHistoryTagsTable)
        tables.append(self.localMessageHistoryTagsTable)
        tables.append(self.messageHistoryIndexTable)
        tables.append(self.mediaTable)
        tables.append(self.readStateTable)
        tables.append(self.synchronizeReadStateTable)
        tables.append(self.synchronizeGroupMessageStatsTable)
        tables.append(self.messageHistoryTable)
        tables.append(self.chatListIndexTable)
        tables.append(self.chatListTable)
        tables.append(self.additionalChatListItemsTable)
        tables.append(self.peerChatStateTable)
        tables.append(self.contactsTable)
        tables.append(self.peerRatingTable)
        tables.append(self.peerNotificationSettingsTable)
        tables.append(self.peerNotificationSettingsBehaviorIndexTable)
        tables.append(self.peerNotificationSettingsBehaviorTable)
        tables.append(self.cachedPeerDataTable)
        tables.append(self.peerPresenceTable)
        tables.append(self.itemCollectionInfoTable)
        tables.append(self.itemCollectionItemTable)
        tables.append(self.itemCollectionReverseIndexTable)
        tables.append(self.peerChatInterfaceStateTable)
        tables.append(self.itemCacheMetaTable)
        tables.append(self.itemCacheTable)
        tables.append(self.peerNameIndexTable)
        tables.append(self.reverseAssociatedPeerTable)
        tables.append(self.peerNameTokenIndexTable)
        tables.append(self.peerChatTopTaggedMessageIdsTable)
        tables.append(self.peerOperationLogMetadataTable)
        tables.append(self.peerMergedOperationLogIndexTable)
        tables.append(self.peerOperationLogTable)
        tables.append(self.timestampBasedMessageAttributesTable)
        tables.append(self.timestampBasedMessageAttributesIndexTable)
        tables.append(self.preferencesTable)
        tables.append(self.orderedItemListTable)
        tables.append(self.orderedItemListIndexTable)
        tables.append(self.unorderedItemListTable)
        tables.append(self.noticeTable)
        tables.append(self.messageHistoryTagsSummaryTable)
        tables.append(self.invalidatedMessageHistoryTagsSummaryTable)
        tables.append(self.pendingMessageActionsTable)
        tables.append(self.pendingMessageActionsMetadataTable)
        tables.append(self.deviceContactImportInfoTable)
        tables.append(self.messageHistoryHoleIndexTable)
        tables.append(self.groupMessageStatsTable)
        
        self.tables = tables
        
        self.transactionStateVersion = self.metadataTable.transactionStateVersion()
        
        self.viewTracker = ViewTracker(queue: self.queue, renderMessage: self.renderIntermediateMessage, getPeer: { peerId in
            return self.peerTable.get(peerId)
        }, getPeerNotificationSettings: { peerId in
            return self.peerNotificationSettingsTable.getEffective(peerId)
        }, getCachedPeerData: { peerId in
            return self.cachedPeerDataTable.get(peerId)
        }, getPeerPresence: { peerId in
            return self.peerPresenceTable.get(peerId)
        }, getTotalUnreadState: {
            return self.messageHistoryMetadataTable.getChatListTotalUnreadState()
        }, getPeerReadState: { peerId in
            return self.readStateTable.getCombinedState(peerId)
        }, operationLogGetOperations: { tag, fromIndex, limit in
            return self.peerOperationLogTable.getMergedEntries(tag: tag, fromIndex: fromIndex, limit: limit)
        }, operationLogGetTailIndex: { tag in
            return self.peerMergedOperationLogIndexTable.tailIndex(tag: tag)
        }, getTimestampBasedMessageAttributesHead: { tag in
            return self.timestampBasedMessageAttributesTable.head(tag: tag)
        }, getPreferencesEntry: { key in
            return self.preferencesTable.get(key: key)
        }, unsentMessageIds: self.messageHistoryUnsentTable.get(), synchronizePeerReadStateOperations: self.synchronizeReadStateTable.get(getCombinedPeerReadState: { peerId in
            return self.readStateTable.getCombinedState(peerId)
        }))
        
        print("(Postbox initialization took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        
        let _ = self.transaction({ transaction -> Void in
            let reindexUnreadVersion: Int32 = 1
            if self.messageHistoryMetadataTable.getShouldReindexUnreadCountsState() != reindexUnreadVersion {
                self.messageHistoryMetadataTable.setShouldReindexUnreadCounts(value: true)
                self.messageHistoryMetadataTable.setShouldReindexUnreadCountsState(value: reindexUnreadVersion)
            }
            
            if self.messageHistoryMetadataTable.shouldReindexUnreadCounts() {
                self.groupMessageStatsTable.removeAll()
                let startTime = CFAbsoluteTimeGetCurrent()
                let (rootState, summaries) = self.chatListIndexTable.debugReindexUnreadCounts(postbox: self)
                
                self.messageHistoryMetadataTable.setChatListTotalUnreadState(rootState)
                for (groupId, summary) in summaries {
                    self.groupMessageStatsTable.set(groupId: groupId, summary: summary)
                }
                postboxLog("reindexUnreadCounts took \(CFAbsoluteTimeGetCurrent() - startTime)")
                self.messageHistoryMetadataTable.setShouldReindexUnreadCounts(value: false)
            }
            
            for id in self.messageHistoryUnsentTable.get() {
                transaction.updateMessage(id, update: { message in
                    if !message.flags.contains(.Failed) {
                        var flags = StoreMessageFlags(message.flags)
                        flags.remove(.Unsent)
                        flags.remove(.Sending)
                        flags.insert(.Failed)
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = message.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                        }
                        return .update(StoreMessage(id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, timestamp: message.timestamp, flags: flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: storeForwardInfo, authorId: message.author?.id, text: message.text, attributes: message.attributes, media: message.media))
                    } else {
                        return .skip
                    }
                })
            }
        }).start()
    }
    
    deinit {
        assert(true)
    }
    
    private func takeNextViewId() -> Int {
        let nextId = self.nextViewId
        self.nextViewId += 1
        return nextId
    }
    
    fileprivate func setState(_ state: PostboxCoding) {
        self.currentUpdatedState = state
        self.metadataTable.setState(state)
    }
    
    fileprivate func getState() -> PostboxCoding? {
        return self.metadataTable.state()
    }
    
    public func keychainEntryForKey(_ key: String) -> Data? {
        let metaDisposable = MetaDisposable()
        self.keychainOperationsDisposable.add(metaDisposable)
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var entry: Data? = nil
        let disposable = (self.transaction({ transaction -> Data? in
            return self.keychainTable.get(key)
        }) |> afterDisposed { [weak self, weak metaDisposable] in
            if let strongSelf = self, let metaDisposable = metaDisposable {
                strongSelf.keychainOperationsDisposable.remove(metaDisposable)
            }
        }).start(next: { data in
            entry = data
            semaphore.signal()
        })
        metaDisposable.set(disposable)
        
        semaphore.wait()
        return entry
    }
    
    private var keychainOperationsDisposable = DisposableSet()
    
    public func setKeychainEntryForKey(_ key: String, value: Data) {
        let metaDisposable = MetaDisposable()
        self.keychainOperationsDisposable.add(metaDisposable)
        
        let disposable = (self.transaction({ transaction -> Void in
            self.keychainTable.set(key, value: value)
        }) |> afterDisposed { [weak self, weak metaDisposable] in
            if let strongSelf = self, let metaDisposable = metaDisposable {
                strongSelf.keychainOperationsDisposable.remove(metaDisposable)
            }
        }).start()
        metaDisposable.set(disposable)
    }
    
    public func removeKeychainEntryForKey(_ key: String) {
        let metaDisposable = MetaDisposable()
        self.keychainOperationsDisposable.add(metaDisposable)
        
        let disposable = (self.transaction({ transaction -> Void in
            self.keychainTable.remove(key)
        }) |> afterDisposed { [weak self, weak metaDisposable] in
            if let strongSelf = self, let metaDisposable = metaDisposable {
                strongSelf.keychainOperationsDisposable.remove(metaDisposable)
            }
        }).start()
        metaDisposable.set(disposable)
    }
    
    fileprivate func addMessages(transaction: Transaction, messages: [StoreMessage], location: AddMessagesLocation) -> [Int64: MessageId] {
        var addedMessagesByPeerId: [PeerId: [StoreMessage]] = [:]
        let addResult = self.messageHistoryTable.addMessages(messages: messages, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations, globalTagsOperations: &self.currentGlobalTagsOperations, pendingActionsOperations: &self.currentPendingMessageActionsOperations, updatedMessageActionsSummaries: &self.currentUpdatedMessageActionsSummaries, updatedMessageTagSummaries: &self.currentUpdatedMessageTagSummaries, invalidateMessageTagSummaries: &self.currentInvalidateMessageTagSummaries, localTagsOperations: &self.currentLocalTagsOperations, processMessages: { messagesByPeerId in
            addedMessagesByPeerId = messagesByPeerId
        })
        
        for (peerId, peerMessages) in addedMessagesByPeerId {
            switch location {
                case .Random:
                    break
                case .UpperHistoryBlock:
                    var earliestByNamespace: [MessageId.Namespace: MessageId] = [:]
                    for message in peerMessages {
                        if case let .Id(id) = message.id {
                            if let currentEarliestId = earliestByNamespace[id.namespace] {
                                if id < currentEarliestId {
                                    earliestByNamespace[id.namespace] = id
                                }
                            } else {
                                earliestByNamespace[id.namespace] = id
                            }
                        }
                    }
                    for (_, id) in earliestByNamespace {
                        self.messageHistoryHoleIndexTable.remove(peerId: id.peerId, namespace: id.namespace, space: .everywhere, range: id.id ... (Int32.max - 1), operations: &self.currentPeerHoleOperations)
                    }
            }
            
            if let bag = self.installedMessageActionsByPeerId[peerId] {
                for f in bag.copyItems() {
                    f(peerMessages, transaction)
                }
            }
        }
        
        return addResult
    }
    
    fileprivate func countIncomingMessage(id: MessageId) {
        let (combinedState, _) = self.readStateTable.addIncomingMessages(id.peerId, indices: Set([MessageIndex(id: id, timestamp: 1)]))
        if self.currentOperationsByPeerId[id.peerId] == nil {
            self.currentOperationsByPeerId[id.peerId] = []
        }
        if let combinedState = combinedState {
        self.currentOperationsByPeerId[id.peerId]!.append(.UpdateReadState(id.peerId, combinedState))
        }
    }
    
    fileprivate func addHole(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, range: ClosedRange<MessageId.Id>) {
        self.messageHistoryHoleIndexTable.add(peerId: peerId, namespace: namespace, space: space, range: range, operations: &self.currentPeerHoleOperations)
    }
    
    fileprivate func removeHole(peerId: PeerId, namespace: MessageId.Namespace, space: MessageHistoryHoleSpace, range: ClosedRange<MessageId.Id>) {
        self.messageHistoryHoleIndexTable.remove(peerId: peerId, namespace: namespace, space: space, range: range, operations: &self.currentPeerHoleOperations)
    }
    
    fileprivate func recalculateChatListGroupStats(groupId: PeerGroupId) {
        let summary = self.chatListIndexTable.reindexPeerGroupUnreadCounts(postbox: self, groupId: groupId)
        self.groupMessageStatsTable.set(groupId: groupId, summary: summary)
        self.currentUpdatedGroupTotalUnreadSummaries[groupId] = summary
    }
    
    fileprivate func replaceChatListHole(groupId: PeerGroupId, index: MessageIndex, hole: ChatListHole?) {
        self.chatListTable.replaceHole(groupId: groupId, index: index, hole: hole, operations: &self.currentChatListOperations)
    }
    
    fileprivate func deleteMessages(_ messageIds: [MessageId], forEachMedia: (Media) -> Void) {
        self.messageHistoryTable.removeMessages(messageIds, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations, globalTagsOperations: &self.currentGlobalTagsOperations, pendingActionsOperations: &self.currentPendingMessageActionsOperations, updatedMessageActionsSummaries: &self.currentUpdatedMessageActionsSummaries, updatedMessageTagSummaries: &self.currentUpdatedMessageTagSummaries, invalidateMessageTagSummaries: &self.currentInvalidateMessageTagSummaries, localTagsOperations: &self.currentLocalTagsOperations, forEachMedia: forEachMedia)
    }
    
    fileprivate func deleteMessagesInRange(peerId: PeerId, namespace: MessageId.Namespace, minId: MessageId.Id, maxId: MessageId.Id, forEachMedia: (Media) -> Void) {
        self.messageHistoryTable.removeMessagesInRange(peerId: peerId, namespace: namespace, minId: minId, maxId: maxId, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations, globalTagsOperations: &self.currentGlobalTagsOperations, pendingActionsOperations: &self.currentPendingMessageActionsOperations, updatedMessageActionsSummaries: &self.currentUpdatedMessageActionsSummaries, updatedMessageTagSummaries: &self.currentUpdatedMessageTagSummaries, invalidateMessageTagSummaries: &self.currentInvalidateMessageTagSummaries, localTagsOperations: &self.currentLocalTagsOperations, forEachMedia: forEachMedia)
    }
    
    fileprivate func withAllMessages(peerId: PeerId, namespace: MessageId.Namespace?, _ f: (Message) -> Bool) {
        for index in self.messageHistoryTable.allMessageIndices(peerId: peerId, namespace: namespace) {
            if let message = self.messageHistoryTable.getMessage(index) {
                if !f(self.renderIntermediateMessage(message)) {
                    break
                }
            } else {
                assertionFailure()
            }
        }
    }
    
    fileprivate func clearHistory(_ peerId: PeerId, namespaces: MessageIdNamespaces, forEachMedia: (Media) -> Void) {
        self.messageHistoryTable.clearHistory(peerId: peerId, namespaces: namespaces, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations, globalTagsOperations: &self.currentGlobalTagsOperations, pendingActionsOperations: &self.currentPendingMessageActionsOperations, updatedMessageActionsSummaries: &self.currentUpdatedMessageActionsSummaries, updatedMessageTagSummaries: &self.currentUpdatedMessageTagSummaries, invalidateMessageTagSummaries: &self.currentInvalidateMessageTagSummaries, localTagsOperations: &self.currentLocalTagsOperations, forEachMedia: forEachMedia)
        for namespace in self.messageHistoryHoleIndexTable.existingNamespaces(peerId: peerId, holeSpace: .everywhere) where namespaces.contains(namespace) {
            self.messageHistoryHoleIndexTable.remove(peerId: peerId, namespace: namespace, space: .everywhere, range: 1 ... Int32.max - 1, operations: &self.currentPeerHoleOperations)
        }
    }
    
    fileprivate func removeAllMessagesWithAuthor(_ peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace, forEachMedia: (Media) -> Void) {
        self.messageHistoryTable.removeAllMessagesWithAuthor(peerId: peerId, authorId: authorId, namespace: namespace, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations, globalTagsOperations: &self.currentGlobalTagsOperations, pendingActionsOperations: &self.currentPendingMessageActionsOperations, updatedMessageActionsSummaries: &self.currentUpdatedMessageActionsSummaries, updatedMessageTagSummaries: &self.currentUpdatedMessageTagSummaries, invalidateMessageTagSummaries: &self.currentInvalidateMessageTagSummaries, localTagsOperations: &self.currentLocalTagsOperations, forEachMedia: forEachMedia)
    }
    
    fileprivate func resetIncomingReadStates(_ states: [PeerId: [MessageId.Namespace: PeerReadState]]) {
        self.messageHistoryTable.resetIncomingReadStates(states, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func setNeedsIncomingReadStateSynchronization(_ peerId: PeerId) {
        self.synchronizeReadStateTable.set(peerId, operation: .Validate, operations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func confirmSynchronizedIncomingReadState(_ peerId: PeerId) {
        self.synchronizeReadStateTable.set(peerId, operation: nil, operations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func applyIncomingReadMaxId(_ messageId: MessageId) {
        self.messageHistoryTable.applyIncomingReadMaxId(messageId, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func applyOutgoingReadMaxId(_ messageId: MessageId) {
        self.messageHistoryTable.applyOutgoingReadMaxId(messageId, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func applyInteractiveReadMaxIndex(_ messageIndex: MessageIndex) -> [MessageId] {
        let peerIds = self.peerIdsForLocation(.peer(messageIndex.id.peerId), tagMask: nil)
        switch peerIds {
            case let .associated(_, messageId):
                if let messageId = messageId, let readState = self.readStateTable.getCombinedState(messageId.peerId), readState.count != 0 {
                    if let topMessage = self.messageHistoryTable.topMessage(messageId.peerId) {
                        let _ = self.messageHistoryTable.applyInteractiveMaxReadIndex(postbox: self, messageIndex: topMessage.index, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
                    }
                }
            default:
                break
        }
        let initialCombinedStates = self.readStateTable.getCombinedState(messageIndex.id.peerId)
        var resultIds = self.messageHistoryTable.applyInteractiveMaxReadIndex(postbox: self, messageIndex: messageIndex, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        if let states = initialCombinedStates?.states {
            for (namespace, state) in states {
                if namespace != messageIndex.id.namespace && state.count != 0 {
                    if let item = self.messageHistoryTable.fetch(peerId: messageIndex.id.peerId, namespace: namespace, tag: nil, from: MessageIndex(id: MessageId(peerId: messageIndex.id.peerId, namespace: namespace, id: 1), timestamp: messageIndex.timestamp), includeFrom: true, to: MessageIndex.lowerBound(peerId: messageIndex.id.peerId, namespace: namespace), limit: 1).first {
                        resultIds.append(contentsOf:  self.messageHistoryTable.applyInteractiveMaxReadIndex(postbox: self, messageIndex: item.index, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations))
                    }
                }
            }
        }
        
        return resultIds
    }
    
    func applyMarkUnread(peerId: PeerId, namespace: MessageId.Namespace, value: Bool, interactive: Bool) {
        if let combinedState = self.readStateTable.applyInteractiveMarkUnread(peerId: peerId, namespace: namespace, value: value) {
            if self.currentOperationsByPeerId[peerId] == nil {
                self.currentOperationsByPeerId[peerId] = []
            }
            self.currentOperationsByPeerId[peerId]!.append(.UpdateReadState(peerId, combinedState))
            if interactive {
                self.synchronizeReadStateTable.set(peerId, operation: .Push(state: self.readStateTable.getCombinedState(peerId), thenSync: false), operations: &self.currentUpdatedSynchronizeReadStateOperations)
            }
        }
    }
    
    fileprivate func applyOutgoingReadMaxIndex(_ messageIndex: MessageIndex) -> [MessageId] {
        return self.messageHistoryTable.applyOutgoingReadMaxIndex(messageIndex, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func resetPeerGroupSummary(groupId: PeerGroupId, namespace: MessageId.Namespace, summary: PeerGroupUnreadCountersSummary) {
        var combinedSummary = self.groupMessageStatsTable.get(groupId: groupId)
        if combinedSummary.namespaces[namespace] != summary {
            combinedSummary.namespaces[namespace] = summary
            self.groupMessageStatsTable.set(groupId: groupId, summary: combinedSummary)
            self.currentUpdatedGroupTotalUnreadSummaries[groupId] = combinedSummary
        }
    }
    
    fileprivate func setNeedsPeerGroupMessageStatsSynchronization(groupId: PeerGroupId, namespace: MessageId.Namespace) {
        self.synchronizeGroupMessageStatsTable.set(groupId: groupId, namespace: namespace, needsValidation: true, operations: &self.currentUpdatedGroupSummarySynchronizeOperations)
    }
    
    fileprivate func confirmSynchronizedPeerGroupMessageStats(groupId: PeerGroupId, namespace: MessageId.Namespace) {
        self.synchronizeGroupMessageStatsTable.set(groupId: groupId, namespace: namespace, needsValidation: false, operations: &self.currentUpdatedGroupSummarySynchronizeOperations)
    }
    
    func fetchAroundChatEntries(groupId: PeerGroupId, index: ChatListIndex, count: Int) -> (entries: [MutableChatListEntry], earlier: MutableChatListEntry?, later: MutableChatListEntry?) {
        let (intermediateEntries, intermediateLower, intermediateUpper) = self.chatListTable.entriesAround(groupId: groupId, index: index, messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable, count: count)
        let entries: [MutableChatListEntry] = intermediateEntries.map { entry in
            return MutableChatListEntry(entry, cachedDataTable: self.cachedPeerDataTable, readStateTable: self.readStateTable, messageHistoryTable: self.messageHistoryTable)
        }
        let lower: MutableChatListEntry? = intermediateLower.flatMap { entry in
            return MutableChatListEntry(entry, cachedDataTable: self.cachedPeerDataTable, readStateTable: self.readStateTable, messageHistoryTable: self.messageHistoryTable)
        }
        let upper: MutableChatListEntry? = intermediateUpper.flatMap { entry in
            return MutableChatListEntry(entry, cachedDataTable: self.cachedPeerDataTable, readStateTable: self.readStateTable, messageHistoryTable: self.messageHistoryTable)
        }
        
        return (entries, lower, upper)
    }
    
    func fetchEarlierChatEntries(groupId: PeerGroupId, index: ChatListIndex?, count: Int) -> [MutableChatListEntry] {
        let intermediateEntries = self.chatListTable.earlierEntries(groupId: groupId, index: index.flatMap({ ($0, true) }), messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable, count: count)
        let entries: [MutableChatListEntry] = intermediateEntries.map { entry in
            return MutableChatListEntry(entry, cachedDataTable: self.cachedPeerDataTable, readStateTable: self.readStateTable, messageHistoryTable: self.messageHistoryTable)
        }
        return entries
    }
    
    func fetchLaterChatEntries(groupId: PeerGroupId, index: ChatListIndex?, count: Int) -> [MutableChatListEntry] {
        let intermediateEntries = self.chatListTable.laterEntries(groupId: groupId, index: index.flatMap({ ($0, true) }), messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable, count: count)
        let entries: [MutableChatListEntry] = intermediateEntries.map { entry in
            return MutableChatListEntry(entry, cachedDataTable: self.cachedPeerDataTable, readStateTable: self.readStateTable, messageHistoryTable: self.messageHistoryTable)
        }
        return entries
    }
    
    func renderIntermediateMessage(_ message: IntermediateMessage) -> Message {
        let renderedMessage = self.messageHistoryTable.renderMessage(message, peerTable: self.peerTable)
        
        return renderedMessage
    }
    
    private func afterBegin() {
        let currentTransactionStateVersion = self.metadataTable.transactionStateVersion()
        if currentTransactionStateVersion != self.transactionStateVersion {
            for table in self.tables {
                table.clearMemoryCache()
            }
            self.viewTracker.refreshViewsDueToExternalTransaction(postbox: self, fetchUnsentMessageIds: {
                return self.messageHistoryUnsentTable.get()
            }, fetchSynchronizePeerReadStateOperations: {
                return self.synchronizeReadStateTable.get(getCombinedPeerReadState: { peerId in
                    return self.readStateTable.getCombinedState(peerId)
                })
            })
            self.transactionStateVersion = currentTransactionStateVersion
            
            self.masterClientId.set(.single(self.metadataTable.masterClientId()))
        }
    }
    
    private func beforeCommit() -> (updatedTransactionStateVersion: Int64?, updatedMasterClientId: Int64?) {
        self.chatListTable.replay(historyOperationsByPeerId: self.currentOperationsByPeerId, updatedPeerChatListEmbeddedStates: self.currentUpdatedPeerChatListEmbeddedStates, updatedChatListInclusions: self.currentUpdatedChatListInclusions, messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable, operations: &self.currentChatListOperations)
        
        self.peerChatTopTaggedMessageIdsTable.replay(historyOperationsByPeerId: self.currentOperationsByPeerId)
        
        let alteredInitialPeerCombinedReadStates = self.readStateTable.transactionAlteredInitialPeerCombinedReadStates()
        let updatedPeers = self.peerTable.transactionUpdatedPeers()
        let transactionParticipationInTotalUnreadCountUpdates = self.peerNotificationSettingsTable.transactionParticipationInTotalUnreadCountUpdates(postbox: self)
        self.chatListIndexTable.commitWithTransaction(postbox: self, alteredInitialPeerCombinedReadStates: alteredInitialPeerCombinedReadStates, updatedPeers: updatedPeers, transactionParticipationInTotalUnreadCountUpdates: transactionParticipationInTotalUnreadCountUpdates, updatedRootUnreadState: &self.currentUpdatedTotalUnreadState, updatedGroupTotalUnreadSummaries: &self.currentUpdatedGroupTotalUnreadSummaries, currentUpdatedGroupSummarySynchronizeOperations: &self.currentUpdatedGroupSummarySynchronizeOperations)
        
        let transaction = PostboxTransaction(currentUpdatedState: self.currentUpdatedState, currentPeerHoleOperations: self.currentPeerHoleOperations, currentOperationsByPeerId: self.currentOperationsByPeerId, chatListOperations: self.currentChatListOperations, currentUpdatedChatListInclusions: self.currentUpdatedChatListInclusions, currentUpdatedPeers: self.currentUpdatedPeers, currentUpdatedPeerNotificationSettings: self.currentUpdatedPeerNotificationSettings, currentUpdatedPeerNotificationBehaviorTimestamps: self.currentUpdatedPeerNotificationBehaviorTimestamps, currentUpdatedCachedPeerData: self.currentUpdatedCachedPeerData, currentUpdatedPeerPresences: currentUpdatedPeerPresences, currentUpdatedPeerChatListEmbeddedStates: self.currentUpdatedPeerChatListEmbeddedStates, currentUpdatedTotalUnreadState: self.currentUpdatedTotalUnreadState, currentUpdatedTotalUnreadSummaries: self.currentUpdatedGroupTotalUnreadSummaries, alteredInitialPeerCombinedReadStates: alteredInitialPeerCombinedReadStates, currentPeerMergedOperationLogOperations: self.currentPeerMergedOperationLogOperations, currentTimestampBasedMessageAttributesOperations: self.currentTimestampBasedMessageAttributesOperations, unsentMessageOperations: self.currentUnsentOperations, updatedSynchronizePeerReadStateOperations: self.currentUpdatedSynchronizeReadStateOperations, currentUpdatedGroupSummarySynchronizeOperations: self.currentUpdatedGroupSummarySynchronizeOperations, currentPreferencesOperations: self.currentPreferencesOperations, currentOrderedItemListOperations: self.currentOrderedItemListOperations, currentItemCollectionItemsOperations: self.currentItemCollectionItemsOperations, currentItemCollectionInfosOperations: self.currentItemCollectionInfosOperations, currentUpdatedPeerChatStates: self.currentUpdatedPeerChatStates, currentGlobalTagsOperations: self.currentGlobalTagsOperations, currentLocalTagsOperations: self.currentLocalTagsOperations, updatedMedia: self.currentUpdatedMedia, replaceRemoteContactCount: self.currentReplaceRemoteContactCount, replaceContactPeerIds: self.currentReplacedContactPeerIds, currentPendingMessageActionsOperations: self.currentPendingMessageActionsOperations, currentUpdatedMessageActionsSummaries: self.currentUpdatedMessageActionsSummaries, currentUpdatedMessageTagSummaries: self.currentUpdatedMessageTagSummaries, currentInvalidateMessageTagSummaries: self.currentInvalidateMessageTagSummaries, currentUpdatedPendingPeerNotificationSettings: self.currentUpdatedPendingPeerNotificationSettings, replacedAdditionalChatListItems: self.currentReplacedAdditionalChatListItems, updatedNoticeEntryKeys: self.currentUpdatedNoticeEntryKeys, updatedCacheEntryKeys: self.currentUpdatedCacheEntryKeys, currentUpdatedMasterClientId: currentUpdatedMasterClientId, updatedFailedMessagePeerIds: self.messageHistoryFailedTable.updatedPeerIds, updatedFailedMessageIds: self.messageHistoryFailedTable.updatedMessageIds)
        var updatedTransactionState: Int64?
        var updatedMasterClientId: Int64?
        if !transaction.isEmpty {
            self.viewTracker.updateViews(postbox: self, transaction: transaction)
            self.transactionStateVersion = self.metadataTable.incrementTransactionStateVersion()
            updatedTransactionState = self.transactionStateVersion
            
            if let currentUpdatedMasterClientId = self.currentUpdatedMasterClientId {
                self.metadataTable.setMasterClientId(currentUpdatedMasterClientId)
                updatedMasterClientId = currentUpdatedMasterClientId
            }
        }
        
        self.currentPeerHoleOperations.removeAll()
        self.currentOperationsByPeerId.removeAll()
        self.currentUpdatedChatListInclusions.removeAll()
        self.currentUpdatedPeers.removeAll()
        self.currentChatListOperations.removeAll()
        self.currentUpdatedChatListInclusions.removeAll()
        self.currentUnsentOperations.removeAll()
        self.currentUpdatedSynchronizeReadStateOperations.removeAll()
        self.currentUpdatedGroupSummarySynchronizeOperations.removeAll()
        self.currentGlobalTagsOperations.removeAll()
        self.currentLocalTagsOperations.removeAll()
        self.currentUpdatedMedia.removeAll()
        self.currentReplaceRemoteContactCount = nil
        self.currentReplacedContactPeerIds = nil
        self.currentReplacedAdditionalChatListItems = nil
        self.currentUpdatedNoticeEntryKeys.removeAll()
        self.currentUpdatedCacheEntryKeys.removeAll()
        self.currentUpdatedMasterClientId = nil
        self.currentUpdatedPeerNotificationSettings.removeAll()
        self.currentUpdatedPeerNotificationBehaviorTimestamps.removeAll()
        self.currentUpdatedCachedPeerData.removeAll()
        self.currentUpdatedPeerPresences.removeAll()
        self.currentUpdatedPeerChatListEmbeddedStates.removeAll()
        self.currentUpdatedTotalUnreadState = nil
        self.currentUpdatedGroupTotalUnreadSummaries.removeAll()
        self.currentPeerMergedOperationLogOperations.removeAll()
        self.currentTimestampBasedMessageAttributesOperations.removeAll()
        self.currentPreferencesOperations.removeAll()
        self.currentOrderedItemListOperations.removeAll()
        self.currentItemCollectionItemsOperations.removeAll()
        self.currentItemCollectionInfosOperations.removeAll()
        self.currentUpdatedPeerChatStates.removeAll()
        self.currentPendingMessageActionsOperations.removeAll()
        self.currentUpdatedMessageActionsSummaries.removeAll()
        self.currentUpdatedMessageTagSummaries.removeAll()
        self.currentInvalidateMessageTagSummaries.removeAll()
        self.currentUpdatedPendingPeerNotificationSettings.removeAll()
        self.currentGroupIdsWithUpdatedReadStats.removeAll()
        
        for table in self.tables {
            table.beforeCommit()
        }
        
        return (updatedTransactionState, updatedMasterClientId)
    }
    
    fileprivate func messageIdsForGlobalIds(_ ids: [Int32]) -> [MessageId] {
        var result: [MessageId] = []
        for globalId in ids {
            if let id = self.globalMessageIdsTable.get(globalId) {
                result.append(id)
            }
        }
        return result
    }
    fileprivate func failedMessageIds(for peerId: PeerId) -> [MessageId] {
        return self.messageHistoryFailedTable.get(peerId: peerId)
    }
    
    fileprivate func messageIdForGloballyUniqueMessageId(peerId: PeerId, id: Int64) -> MessageId? {
        return self.globallyUniqueMessageIdsTable.get(peerId: peerId, globallyUniqueId: id)
    }
    
    fileprivate func updatePeers(_ peers: [Peer], update: (Peer?, Peer) -> Peer?) {
        for peer in peers {
            let currentPeer = self.peerTable.get(peer.id)
            if let updatedPeer = update(currentPeer, peer) {
                self.peerTable.set(updatedPeer)
                self.currentUpdatedPeers[updatedPeer.id] = updatedPeer
                var previousIndexNameWasEmpty = true
                
                if let currentPeer = currentPeer {
                    if !currentPeer.indexName.isEmpty {
                        previousIndexNameWasEmpty = false
                    }
                }
                
                let indexNameIsEmpty = updatedPeer.indexName.isEmpty
                
                if !previousIndexNameWasEmpty || !indexNameIsEmpty {
                    if currentPeer?.indexName != updatedPeer.indexName {
                        self.peerNameIndexTable.markPeerNameUpdated(peerId: peer.id, name: updatedPeer.indexName)
                        for reverseAssociatedPeerId in self.reverseAssociatedPeerTable.get(peerId: peer.id) {
                            self.peerNameIndexTable.markPeerNameUpdated(peerId: reverseAssociatedPeerId, name: updatedPeer.indexName)
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func getTopPeerMessageIndex(peerId: PeerId, namespace: MessageId.Namespace) -> MessageIndex? {
        if let index = self.messageHistoryTable.topIndexEntry(peerId: peerId, namespace: namespace) {
            return index
        } else {
            return nil
        }
    }

    fileprivate func getTopPeerMessageIndex(peerId: PeerId) -> MessageIndex? {
        var indices: [MessageIndex] = []
        for namespace in self.messageHistoryIndexTable.existingNamespaces(peerId: peerId) where self.seedConfiguration.chatMessagesNamespaces.contains(namespace) {
            if let index = self.messageHistoryTable.topIndexEntry(peerId: peerId, namespace: namespace) {
                indices.append(index)
            }
        }
        return indices.max()
    }
    
    fileprivate func getPeerChatListInclusion(_ id: PeerId) -> PeerChatListInclusion {
        if let inclusion = self.currentUpdatedChatListInclusions[id] {
            return inclusion
        } else {
            return self.chatListIndexTable.get(peerId: id).inclusion
        }
    }
    
    fileprivate func updatePeerChatListInclusion(_ id: PeerId, inclusion: PeerChatListInclusion) {
        self.chatListTable.updateInclusion(peerId: id, updatedChatListInclusions: &self.currentUpdatedChatListInclusions, { _ in
            return inclusion
        })
    }
    
    fileprivate func getPinnedItemIds(groupId: PeerGroupId) -> [PinnedItemId] {
        var itemIds = self.chatListTable.getPinnedItemIds(groupId: groupId, messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable)
        for (peerId, inclusion) in self.currentUpdatedChatListInclusions {
            var found = false
            inner: for i in 0 ..< itemIds.count {
                if case .peer(peerId) = itemIds[i].id {
                    found = true
                    switch inclusion {
                        case let .ifHasMessagesOrOneOf(updatedGroupId, pinningIndex, _):
                            if updatedGroupId != groupId || pinningIndex == nil {
                                itemIds.remove(at: i)
                            }
                        default:
                            itemIds.remove(at: i)
                    }
                    break inner
                }
            }
            if !found {
                switch inclusion {
                    case let .ifHasMessagesOrOneOf(updatedGroupId, pinningIndex, _):
                        if updatedGroupId == groupId, let pinningIndex = pinningIndex {
                            itemIds.append((.peer(peerId), Int(pinningIndex)))
                        }
                    default:
                        break
                }
            }
        }
        return itemIds.sorted(by: { $0.1 < $1.1 }).map({ $0.0 })
    }
    
    fileprivate func setPinnedItemIds(groupId: PeerGroupId, itemIds: [PinnedItemId]) {
        self.chatListTable.setPinnedItemIds(groupId: groupId, itemIds: itemIds, updatedChatListInclusions: &self.currentUpdatedChatListInclusions, messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable)
    }
    
    fileprivate func updateCurrentPeerNotificationSettings(_ notificationSettings: [PeerId: PeerNotificationSettings]) {
        for (peerId, settings) in notificationSettings {
            if let updated = self.peerNotificationSettingsTable.setCurrent(id: peerId, settings: settings, updatedTimestamps: &self.currentUpdatedPeerNotificationBehaviorTimestamps) {
                self.currentUpdatedPeerNotificationSettings[peerId] = updated
            }
        }
    }
    
    fileprivate func updatePendingPeerNotificationSettings(peerId: PeerId, settings: PeerNotificationSettings?) {
        if let updated = self.peerNotificationSettingsTable.setPending(id: peerId, settings: settings, updatedSettings: &self.currentUpdatedPendingPeerNotificationSettings) {
            self.currentUpdatedPeerNotificationSettings[peerId] = updated
        }
    }
    
    fileprivate func resetAllPeerNotificationSettings(_ notificationSettings: PeerNotificationSettings) {
        for peerId in self.peerNotificationSettingsTable.resetAll(to: notificationSettings, updatedSettings: &self.currentUpdatedPendingPeerNotificationSettings, updatedTimestamps: &self.currentUpdatedPeerNotificationBehaviorTimestamps) {
            self.currentUpdatedPeerNotificationSettings[peerId] = notificationSettings
        }
    }
    
    fileprivate func updatePeerCachedData(peerIds: Set<PeerId>, update: (PeerId, CachedPeerData?) -> CachedPeerData?) {
        for peerId in peerIds {
            let currentData = self.cachedPeerDataTable.get(peerId)
            if let updatedData = update(peerId, currentData) {
                self.cachedPeerDataTable.set(id: peerId, data: updatedData)
                self.currentUpdatedCachedPeerData[peerId] = updatedData
            }
        }
    }
    
    fileprivate func updatePeerPresences(presences: [PeerId: PeerPresence], merge: (PeerPresence, PeerPresence) -> PeerPresence) {
        for (peerId, presence) in presences {
            let updated: PeerPresence
            let shouldUpdate: Bool
            if let current = self.peerPresenceTable.get(peerId) {
                updated = merge(current, presence)
                shouldUpdate = !current.isEqual(to: updated)
            } else {
                updated = presence
                shouldUpdate = true
            }
            if shouldUpdate {
                self.peerPresenceTable.set(id: peerId, presence: updated)
                self.currentUpdatedPeerPresences[peerId] = updated
            }
        }
    }
    
    fileprivate func updatePeerPresence(peerId: PeerId, update: (PeerPresence) -> PeerPresence) {
        if let current = self.peerPresenceTable.get(peerId) {
            let updated = update(current)
            if !current.isEqual(to: updated) {
                self.peerPresenceTable.set(id: peerId, presence: updated)
                self.currentUpdatedPeerPresences[peerId] = updated
            }
        }
    }
    
    fileprivate func setPeerChatState(_ id: PeerId, state: PeerChatState) {
        self.peerChatStateTable.set(id, state: state)
        self.currentUpdatedPeerChatStates.insert(id)
    }
    
    fileprivate func updatePeerChatInterfaceState(_ id: PeerId, update: (PeerChatInterfaceState?) -> (PeerChatInterfaceState?)) {
        let updatedState = update(self.peerChatInterfaceStateTable.get(id))
        let (_, updatedEmbeddedState) = self.peerChatInterfaceStateTable.set(id, state: updatedState)
        if updatedEmbeddedState {
            self.currentUpdatedPeerChatListEmbeddedStates[id] = updatedState?.chatListEmbeddedState
        }
    }
    
    fileprivate func replaceRemoteContactCount(_ count: Int32) {
        self.metadataTable.setRemoteContactCount(count)
        self.currentReplaceRemoteContactCount = count
    }
    
    fileprivate func replaceContactPeerIds(_ peerIds: Set<PeerId>) {
        self.contactsTable.replace(peerIds)
        
        self.currentReplacedContactPeerIds = peerIds
    }
    
    fileprivate func replaceAdditionalChatListItems(_ peerIds: [PeerId]) {
        assert(peerIds.count == Set(peerIds).count)
        if self.additionalChatListItemsTable.set(peerIds) {
            self.currentReplacedAdditionalChatListItems = peerIds
        }
    }
    
    fileprivate func replaceRecentPeerIds(_ peerIds: [PeerId]) {
        self.peerRatingTable.replace(items: peerIds)
    }
    
    fileprivate func updateMessage(_ id: MessageId, update: (Message) -> PostboxUpdateMessage) {
        if let index = self.messageHistoryIndexTable.getIndex(id), let intermediateMessage = self.messageHistoryTable.getMessage(index) {
            let message = self.renderIntermediateMessage(intermediateMessage)
            if case let .update(updatedMessage) = update(message) {
                self.messageHistoryTable.updateMessage(id, message: updatedMessage, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations, globalTagsOperations: &self.currentGlobalTagsOperations, pendingActionsOperations: &self.currentPendingMessageActionsOperations, updatedMessageActionsSummaries: &self.currentUpdatedMessageActionsSummaries, updatedMessageTagSummaries: &self.currentUpdatedMessageTagSummaries, invalidateMessageTagSummaries: &self.currentInvalidateMessageTagSummaries, localTagsOperations: &self.currentLocalTagsOperations)
            }
        }
    }
    
    fileprivate func offsetPendingMessagesTimestamps(lowerBound: MessageId, excludeIds: Set<MessageId>, timestamp: Int32) {
        self.messageHistoryTable.offsetPendingMessagesTimestamps(lowerBound: lowerBound, excludeIds: excludeIds, timestamp: timestamp, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations, globalTagsOperations: &self.currentGlobalTagsOperations, pendingActionsOperations: &self.currentPendingMessageActionsOperations, updatedMessageActionsSummaries: &self.currentUpdatedMessageActionsSummaries, updatedMessageTagSummaries: &self.currentUpdatedMessageTagSummaries, invalidateMessageTagSummaries: &self.currentInvalidateMessageTagSummaries, localTagsOperations: &self.currentLocalTagsOperations)
    }
    
    fileprivate func updateMessageGroupingKeysAtomically(_ ids: [MessageId], groupingKey: Int64) {
        self.messageHistoryTable.updateMessageGroupingKeysAtomically(ids: ids, groupingKey: groupingKey, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations, globalTagsOperations: &self.currentGlobalTagsOperations, pendingActionsOperations: &self.currentPendingMessageActionsOperations, updatedMessageActionsSummaries: &self.currentUpdatedMessageActionsSummaries, updatedMessageTagSummaries: &self.currentUpdatedMessageTagSummaries, invalidateMessageTagSummaries: &self.currentInvalidateMessageTagSummaries)
    }
    
    fileprivate func updateMedia(_ id: MediaId, update: Media?) -> Set<MessageIndex> {
        var updatedMessageIndices = Set<MessageIndex>()
        self.messageHistoryTable.updateMedia(id, media: update, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia, updatedMessageIndices: &updatedMessageIndices)
        return updatedMessageIndices
    }
    
    fileprivate func replaceItemCollections(namespace: ItemCollectionId.Namespace, itemCollections: [(ItemCollectionId, ItemCollectionInfo, [ItemCollectionItem])]) {
        var infos: [(ItemCollectionId, ItemCollectionInfo)] = []
        for (id, info, items) in itemCollections {
            infos.append((id, info))
            self.itemCollectionItemTable.replaceItems(collectionId: id, items: items)
            if self.currentItemCollectionItemsOperations[id] == nil {
                self.currentItemCollectionItemsOperations[id] = []
            }
            self.currentItemCollectionItemsOperations[id]!.append(.replaceItems)
        }
        self.itemCollectionInfoTable.replaceInfos(namespace: namespace, infos: infos)
        self.currentItemCollectionInfosOperations.append(.replaceInfos(namespace))
    }
    
    fileprivate func replaceItemCollectionInfos(namespace: ItemCollectionId.Namespace, itemCollectionInfos: [(ItemCollectionId, ItemCollectionInfo)]) {
        self.itemCollectionInfoTable.replaceInfos(namespace: namespace, infos: itemCollectionInfos)
        self.currentItemCollectionInfosOperations.append(.replaceInfos(namespace))
    }
    
    fileprivate func replaceItemCollectionItems(collectionId: ItemCollectionId, items: [ItemCollectionItem]) {
        self.itemCollectionItemTable.replaceItems(collectionId: collectionId, items: items)
        if self.currentItemCollectionItemsOperations[collectionId] == nil {
            self.currentItemCollectionItemsOperations[collectionId] = []
        }
        self.currentItemCollectionItemsOperations[collectionId]!.append(.replaceItems)
    }
    
    fileprivate func removeItemCollection(collectionId: ItemCollectionId) {
        var infos = self.itemCollectionInfoTable.getInfos(namespace: collectionId.namespace)
        if let index = infos.firstIndex(where: { $0.1 == collectionId }) {
            infos.remove(at: index)
            self.replaceItemCollectionInfos(namespace: collectionId.namespace, itemCollectionInfos: infos.map { ($0.1, $0.2) })
        }
        self.replaceItemCollectionItems(collectionId: collectionId, items: [])
    }
    
    fileprivate func filterStoredMessageIds(_ messageIds: Set<MessageId>) -> Set<MessageId> {
        var filteredIds = Set<MessageId>()
        
        for id in messageIds {
            if self.messageHistoryIndexTable.exists(id) {
                filteredIds.insert(id)
            }
        }
        
        return filteredIds
    }
    
    fileprivate func storedMessageId(peerId: PeerId, namespace: MessageId.Namespace, timestamp: Int32) -> MessageId? {
        if let id = self.messageHistoryTable.findMessageId(peerId: peerId, namespace: namespace, timestamp: timestamp), id.namespace == namespace {
            return id
        } else {
            return nil
        }
    }
    
    fileprivate func putItemCacheEntry(id: ItemCacheEntryId, entry: PostboxCoding, collectionSpec: ItemCacheCollectionSpec) {
        self.itemCacheTable.put(id: id, entry: entry, metaTable: self.itemCacheMetaTable)
        self.currentUpdatedCacheEntryKeys.insert(id)
    }
    
    func retrieveItemCacheEntry(id: ItemCacheEntryId) -> PostboxCoding? {
        return self.itemCacheTable.retrieve(id: id, metaTable: self.itemCacheMetaTable)
    }
    
    fileprivate func removeItemCacheEntry(id: ItemCacheEntryId) {
        self.itemCacheTable.remove(id: id, metaTable: self.itemCacheMetaTable)
    }
    
    fileprivate func replaceGlobalMessageTagsHole(transaction: Transaction, globalTags: GlobalMessageTags, index: MessageIndex, with updatedIndex: MessageIndex?, messages: [StoreMessage]) {
        var allTagsMatch = true
        for tag in globalTags {
            self.globalMessageHistoryTagsTable.ensureInitialized(tag)
            
            if let entry = self.globalMessageHistoryTagsTable.get(tag, index: index), case .hole = entry {
                
            } else {
                allTagsMatch = false
            }
        }
        if allTagsMatch {
            for tag in globalTags {
                self.globalMessageHistoryTagsTable.remove(tag, index: index)
                self.currentGlobalTagsOperations.append(.remove([(tag, index)]))
                
                if let updatedIndex = updatedIndex {
                    self.globalMessageHistoryTagsTable.addHole(tag, index: updatedIndex)
                    self.currentGlobalTagsOperations.append(.insertHole(tag, updatedIndex))
                }
            }
            
            let _ = self.addMessages(transaction: transaction, messages: messages, location: .Random)
        }
    }
    
    fileprivate func setNoticeEntry(key: NoticeEntryKey, value: NoticeEntry?) {
        let current = self.noticeTable.get(key: key)
        let updated: Bool
        if let current = current, let value = value {
            updated = !current.isEqual(to: value)
        } else if (current != nil) != (value != nil) {
            updated = true
        } else {
            updated = false
        }
        if updated {
            self.noticeTable.set(key: key, value: value)
            self.currentUpdatedNoticeEntryKeys.insert(key)
        }
    }
    
    fileprivate func clearNoticeEntries() {
        self.noticeTable.clear()
    }
    
    fileprivate func setPendingMessageAction(type: PendingMessageActionType, id: MessageId, action: PendingMessageActionData?) {
        self.messageHistoryTable.setPendingMessageAction(id: id, type: type, action: action, pendingActionsOperations: &self.currentPendingMessageActionsOperations, updatedMessageActionsSummaries: &self.currentUpdatedMessageActionsSummaries)
    }
    
    fileprivate func getPendingMessageAction(type: PendingMessageActionType, id: MessageId) -> PendingMessageActionData? {
        return self.pendingMessageActionsTable.getAction(id: id, type: type)
    }
    
    fileprivate func replaceMessageTagSummary(peerId: PeerId, tagMask: MessageTags, namespace: MessageId.Namespace, count: Int32, maxId: MessageId.Id) {
        let key = MessageHistoryTagsSummaryKey(tag: tagMask, peerId: peerId, namespace: namespace)
        self.messageHistoryTagsSummaryTable.replace(key: key, count: count, maxId: maxId, updatedSummaries: &self.currentUpdatedMessageTagSummaries)
    }
    
    fileprivate func searchMessages(peerId: PeerId?, query: String, tags: MessageTags?) -> [Message] {
        var result: [Message] = []
        for messageId in self.textIndexTable.search(peerId: peerId, text: query, tags: tags) {
            if let index = self.messageHistoryIndexTable.getIndex(messageId), let message = self.messageHistoryTable.getMessage(index) {
                result.append(self.messageHistoryTable.renderMessage(message, peerTable: self.peerTable))
            } else {
                assertionFailure()
            }
        }
        return result
    }
    
    private let canBeginTransactionsValue = Atomic<Bool>(value: true)
    public func setCanBeginTransactions(_ value: Bool) {
        self.queue.async {
            let previous = self.canBeginTransactionsValue.swap(value)
            if previous != value && value {
                let fs = self.queuedInternalTransactions.swap([])
                for f in fs {
                    f()
                }
            }
        }
    }
    
    private var queuedInternalTransactions = Atomic<[() -> Void]>(value: [])
    
    private func beginInternalTransaction(ignoreDisabled: Bool = false, _ f: @escaping () -> Void) {
        assert(self.queue.isCurrent())
        if ignoreDisabled || self.canBeginTransactionsValue.with({ $0 }) {
            f()
        } else {
            let _ = self.queuedInternalTransactions.modify { fs in
                var fs = fs
                fs.append(f)
                return fs
            }
        }
    }
    
    private func internalTransaction<T>(_ f: (Transaction) -> T) -> (result: T, updatedTransactionStateVersion: Int64?, updatedMasterClientId: Int64?) {
        self.valueBox.begin()
        self.afterBegin()
        let transaction = Transaction(postbox: self)
        let result = f(transaction)
        transaction.disposed = true
        let (updatedTransactionState, updatedMasterClientId) = self.beforeCommit()
        self.valueBox.commit()
        
        if let currentUpdatedState = self.currentUpdatedState {
            self.statePipe.putNext(currentUpdatedState)
        }
        self.currentUpdatedState = nil
        
        return (result, updatedTransactionState, updatedMasterClientId)
    }
    
    public func transactionSignal<T, E>(userInteractive: Bool = false, _ f: @escaping(Subscriber<T, E>, Transaction) -> Disposable) -> Signal<T, E> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            let f: () -> Void = {
                self.beginInternalTransaction {
                    let (_, updatedTransactionState, updatedMasterClientId) = self.internalTransaction({ transaction in
                        disposable.set(f(subscriber, transaction))
                    })
                    
                    if updatedTransactionState != nil || updatedMasterClientId != nil {
                        //self.pipeNotifier.notify()
                    }
                    
                    if let updatedMasterClientId = updatedMasterClientId {
                        self.masterClientId.set(.single(updatedMasterClientId))
                    }
                }
            }
            if userInteractive {
                self.queue.justDispatchWithQoS(qos: DispatchQoS.userInteractive, f)
            } else {
                self.queue.justDispatch(f)
            }
            
            return disposable
        }
    }
    
    public func transaction<T>(userInteractive: Bool = false, ignoreDisabled: Bool = false, _ f: @escaping(Transaction) -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            let f: () -> Void = {
                self.beginInternalTransaction(ignoreDisabled: ignoreDisabled, {
                    let (result, updatedTransactionState, updatedMasterClientId) = self.internalTransaction({ transaction in
                        return f(transaction)
                    })
                    
                    if updatedTransactionState != nil || updatedMasterClientId != nil {
                        //self.pipeNotifier.notify()
                    }
                    
                    if let updatedMasterClientId = updatedMasterClientId {
                        self.masterClientId.set(.single(updatedMasterClientId))
                    }
                    
                    subscriber.putNext(result)
                    subscriber.putCompletion()
                })
            }
            if self.queue.isCurrent() && Queue.mainQueue().isCurrent() {
                f()
            } else if userInteractive {
                self.queue.justDispatchWithQoS(qos: DispatchQoS.userInteractive, f)
            } else {
                self.queue.justDispatch(f)
            }
            return EmptyDisposable
        }
    }
    
    func peerIdsForLocation(_ chatLocation: ChatLocation, tagMask: MessageTags?) -> MessageHistoryViewPeerIds {
        var peerIds: MessageHistoryViewPeerIds
        switch chatLocation {
            case let .peer(peerId):
                peerIds = .single(peerId)
                if let associatedMessageId = self.cachedPeerDataTable.get(peerId)?.associatedHistoryMessageId, associatedMessageId.peerId != peerId {
                    peerIds = .associated(peerId, associatedMessageId)
                }
        }
        return peerIds
    }
    
    public func aroundMessageOfInterestHistoryViewForChatLocation(_ chatLocation: ChatLocation, count: Int, topTaggedMessageIdNamespaces: Set<MessageId.Namespace>, tagMask: MessageTags?, namespaces: MessageIdNamespaces, orderStatistics: MessageHistoryViewOrderStatistics, additionalData: [AdditionalMessageHistoryViewData]) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        return self.transactionSignal(userInteractive: true, { subscriber, transaction in
            let peerIds = self.peerIdsForLocation(chatLocation, tagMask: tagMask)
            
            var anchor: HistoryViewInputAnchor = .upperBound
            switch peerIds {
            case let .single(peerId):
                if self.chatListTable.getPeerChatListIndex(peerId: peerId) != nil {
                    if let combinedState = self.readStateTable.getCombinedState(peerId), let state = combinedState.states.first, state.1.count != 0 {
                        switch state.1 {
                            case let .idBased(maxIncomingReadId, _, _, _, _):
                                anchor = .message(MessageId(peerId: peerId, namespace: state.0, id: maxIncomingReadId))
                            case let .indexBased(maxIncomingReadIndex, _, _, _):
                                anchor = .index(maxIncomingReadIndex)
                        }
                    } else if let scrollIndex = self.peerChatInterfaceStateTable.get(peerId)?.historyScrollMessageIndex {
                        anchor = .index(scrollIndex)
                    }
                }
            case let .associated(mainId, associatedId):
                var ids: [PeerId] = []
                ids.append(mainId)
                if let associatedId = associatedId {
                    ids.append(associatedId.peerId)
                }
                
                var found = false
                loop: for peerId in ids.reversed() {
                    if self.chatListTable.getPeerChatListIndex(peerId: mainId) != nil, let combinedState = self.readStateTable.getCombinedState(peerId), let state = combinedState.states.first, state.1.count != 0 {
                        found = true
                        switch state.1 {
                            case let .idBased(maxIncomingReadId, _, _, _, _):
                                anchor = .message(MessageId(peerId: peerId, namespace: state.0, id: maxIncomingReadId))
                            case let .indexBased(maxIncomingReadIndex, _, _, _):
                                anchor = .index(maxIncomingReadIndex)
                        }
                        break loop
                    }
                }
            
                if !found {
                    if let scrollIndex = self.peerChatInterfaceStateTable.get(mainId)?.historyScrollMessageIndex {
                        anchor = .index(scrollIndex)
                    }
                }
            }
            return self.syncAroundMessageHistoryViewForPeerId(subscriber: subscriber, peerIds: peerIds, count: count, anchor: anchor, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: topTaggedMessageIdNamespaces, tagMask: tagMask, namespaces: namespaces, orderStatistics: orderStatistics, additionalData: additionalData)
        })
    }
    
    public func aroundIdMessageHistoryViewForLocation(_ chatLocation: ChatLocation, count: Int, messageId: MessageId, topTaggedMessageIdNamespaces: Set<MessageId.Namespace>, tagMask: MessageTags?, namespaces: MessageIdNamespaces, orderStatistics: MessageHistoryViewOrderStatistics, additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        return self.transactionSignal { subscriber, transaction in
            let peerIds = self.peerIdsForLocation(chatLocation, tagMask: tagMask)
            return self.syncAroundMessageHistoryViewForPeerId(subscriber: subscriber, peerIds: peerIds, count: count, anchor: .message(messageId), fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: topTaggedMessageIdNamespaces, tagMask: tagMask, namespaces: namespaces, orderStatistics: orderStatistics, additionalData: additionalData)
        }
    }
    
    public func aroundMessageHistoryViewForLocation(_ chatLocation: ChatLocation, anchor: HistoryViewInputAnchor, count: Int, fixedCombinedReadStates: MessageHistoryViewReadState?, topTaggedMessageIdNamespaces: Set<MessageId.Namespace>, tagMask: MessageTags?, namespaces: MessageIdNamespaces, orderStatistics: MessageHistoryViewOrderStatistics, additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        return self.transactionSignal { subscriber, transaction in
            let peerIds = self.peerIdsForLocation(chatLocation, tagMask: tagMask)
            
            return self.syncAroundMessageHistoryViewForPeerId(subscriber: subscriber, peerIds: peerIds, count: count, anchor: anchor, fixedCombinedReadStates: fixedCombinedReadStates, topTaggedMessageIdNamespaces: topTaggedMessageIdNamespaces, tagMask: tagMask, namespaces: namespaces, orderStatistics: orderStatistics, additionalData: additionalData)
        }
    }
    
    private func syncAroundMessageHistoryViewForPeerId(subscriber: Subscriber<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>, peerIds: MessageHistoryViewPeerIds, count: Int, anchor: HistoryViewInputAnchor, fixedCombinedReadStates: MessageHistoryViewReadState?, topTaggedMessageIdNamespaces: Set<MessageId.Namespace>, tagMask: MessageTags?, namespaces: MessageIdNamespaces, orderStatistics: MessageHistoryViewOrderStatistics, additionalData: [AdditionalMessageHistoryViewData]) -> Disposable {
        var topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?] = [:]
        var mainPeerId: PeerId?
        switch peerIds {
            case let .single(id):
                mainPeerId = id
            case let .associated(id, _):
                mainPeerId = id
        }
        if let peerId = mainPeerId {
            for namespace in topTaggedMessageIdNamespaces {
                if let messageId = self.peerChatTopTaggedMessageIdsTable.get(peerId: peerId, namespace: namespace) {
                    if let index = self.messageHistoryIndexTable.getIndex(messageId) {
                        if let message = self.messageHistoryTable.getMessage(index) {
                            topTaggedMessages[namespace] = MessageHistoryTopTaggedMessage.intermediate(message)
                        } else {
                            assertionFailure()
                        }
                    } else {
                        //assertionFailure()
                    }
                } else {
                    let item: MessageHistoryTopTaggedMessage? = nil
                    topTaggedMessages[namespace] = item
                }
            }
        }
        
        var additionalDataEntries: [AdditionalMessageHistoryViewDataEntry] = []
        for data in additionalData {
            switch data {
                case let .cachedPeerData(peerId):
                    additionalDataEntries.append(.cachedPeerData(peerId, self.cachedPeerDataTable.get(peerId)))
                case let .cachedPeerDataMessages(peerId):
                    var messages: [MessageId: Message] = [:]
                    if let messageIds = self.cachedPeerDataTable.get(peerId)?.messageIds {
                        for id in messageIds {
                            if let message = self.getMessage(id) {
                                messages[id] = message
                            }
                        }
                    }
                    additionalDataEntries.append(.cachedPeerDataMessages(peerId, messages))
                case let .peerChatState(peerId):
                    additionalDataEntries.append(.peerChatState(peerId, self.peerChatStateTable.get(peerId) as? PeerChatState))
                case .totalUnreadState:
                    additionalDataEntries.append(.totalUnreadState(self.messageHistoryMetadataTable.getChatListTotalUnreadState()))
                case let .peerNotificationSettings(peerId):
                    var notificationPeerId = peerId
                    if let peer = self.peerTable.get(peerId), let associatedPeerId = peer.associatedPeerId {
                        notificationPeerId = associatedPeerId
                    }
                    additionalDataEntries.append(.peerNotificationSettings(self.peerNotificationSettingsTable.getEffective(notificationPeerId)))
                case let .cacheEntry(entryId):
                    additionalDataEntries.append(.cacheEntry(entryId, self.retrieveItemCacheEntry(id: entryId)))
                case let .preferencesEntry(key):
                    additionalDataEntries.append(.preferencesEntry(key, self.preferencesTable.get(key: key)))
                case let .peerIsContact(peerId):
                    let value: Bool
                    if let contactPeer = self.peerTable.get(peerId), let associatedPeerId = contactPeer.associatedPeerId {
                        value = self.contactsTable.isContact(peerId: associatedPeerId)
                    } else {
                        value = self.contactsTable.isContact(peerId: peerId)
                    }
                    additionalDataEntries.append(.peerIsContact(peerId, value))
                case let .peer(peerId):
                    additionalDataEntries.append(.peer(peerId, self.peerTable.get(peerId)))
            }
        }
        
        var readStates: MessageHistoryViewReadState?
        var transientReadStates: MessageHistoryViewReadState?
        switch peerIds {
            case let .single(peerId):
                if let readState = self.readStateTable.getCombinedState(peerId) {
                    transientReadStates = .peer([peerId: readState])
                }
            case let .associated(peerId, _):
                if let readState = self.readStateTable.getCombinedState(peerId) {
                    transientReadStates = .peer([peerId: readState])
                }
        }
        
        if let fixedCombinedReadStates = fixedCombinedReadStates {
            readStates = fixedCombinedReadStates
        } else {
            readStates = transientReadStates
        }
        
        let mutableView = MutableMessageHistoryView(postbox: self, orderStatistics: orderStatistics, peerIds: peerIds, anchor: anchor, combinedReadStates: readStates, transientReadStates: transientReadStates, tag: tagMask, namespaces: namespaces, count: count, topTaggedMessages: topTaggedMessages, additionalDatas: additionalDataEntries, getMessageCountInRange: { lowerBound, upperBound in
            if let tagMask = tagMask {
                return Int32(self.messageHistoryTable.getMessageCountInRange(peerId: lowerBound.id.peerId, namespace: lowerBound.id.namespace, tag: tagMask, lowerBound: lowerBound, upperBound: upperBound))
            } else {
                return 0
            }
        })
        
        let initialUpdateType: ViewUpdateType = .Initial
        
        let (index, signal) = self.viewTracker.addMessageHistoryView(mutableView)
        
        let initialData: InitialMessageHistoryData
        switch peerIds {
            case let .single(peerId):
                initialData = self.initialMessageHistoryData(peerId: peerId)
            case let .associated(peerId, _):
                initialData = self.initialMessageHistoryData(peerId: peerId)
        }
        
        subscriber.putNext((MessageHistoryView(mutableView), initialUpdateType, initialData))
        let disposable = signal.start(next: { next in
            subscriber.putNext((next.0, next.1, nil))
        })
        return ActionDisposable { [weak self] in
            disposable.dispose()
            if let strongSelf = self {
                strongSelf.queue.async {
                    strongSelf.viewTracker.removeMessageHistoryView(index: index)
                }
            }
        }
    }
    
    private func initialMessageHistoryData(peerId: PeerId) -> InitialMessageHistoryData {
        let chatInterfaceState = self.peerChatInterfaceStateTable.get(peerId)
        var associatedMessages: [MessageId: Message] = [:]
        if let chatInterfaceState = chatInterfaceState {
            for id in chatInterfaceState.associatedMessageIds {
                if let message = self.getMessage(id) {
                    associatedMessages[message.id] = message
                }
            }
        }
        return InitialMessageHistoryData(peer: self.peerTable.get(peerId), chatInterfaceState: chatInterfaceState, associatedMessages: associatedMessages)
    }
    
    public func messageIndexAtId(_ id: MessageId) -> Signal<MessageIndex?, NoError> {
        return self.transaction { transaction -> Signal<MessageIndex?, NoError> in
            if let index = self.messageHistoryIndexTable.getIndex(id) {
                return .single(index)
            } else {
                return .single(nil)
            }
        }
        |> switchToLatest
    }
    
    public func messageAtId(_ id: MessageId) -> Signal<Message?, NoError> {
        return self.transaction { transaction -> Signal<Message?, NoError> in
            if let index = self.messageHistoryIndexTable.getIndex(id) {
                if let message = self.messageHistoryTable.getMessage(index) {
                    return .single(self.renderIntermediateMessage(message))
                } else {
                    return .single(nil)
                }
            } else {
                return .single(nil)
            }
        }
        |> switchToLatest
    }
    
    public func messagesAtIds(_ ids: [MessageId]) -> Signal<[Message], NoError> {
        return self.transaction { transaction -> Signal<[Message], NoError> in
            var messages: [Message] = []
            for id in ids {
                if let index = self.messageHistoryIndexTable.getIndex(id) {
                    if let message = self.messageHistoryTable.getMessage(index) {
                        messages.append(self.renderIntermediateMessage(message))
                    }
                }
            }
            return .single(messages)
        }
        |> switchToLatest
    }
    
    public func tailChatListView(groupId: PeerGroupId, count: Int, summaryComponents: ChatListEntrySummaryComponents) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return self.aroundChatListView(groupId: groupId, index: ChatListIndex.absoluteUpperBound, count: count, summaryComponents: summaryComponents, userInteractive: true)
    }
    
    public func aroundChatListView(groupId: PeerGroupId, index: ChatListIndex, count: Int, summaryComponents: ChatListEntrySummaryComponents, userInteractive: Bool = false) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return self.transactionSignal(userInteractive: userInteractive, { subscriber, transaction in
            let (entries, earlier, later) = self.fetchAroundChatEntries(groupId: groupId, index: index, count: count)
            
            let mutableView = MutableChatListView(postbox: self, groupId: groupId, earlier: earlier, entries: entries, later: later, count: count, summaryComponents: summaryComponents)
            mutableView.render(postbox: self, renderMessage: self.renderIntermediateMessage, getPeer: { id in
                return self.peerTable.get(id)
            }, getPeerNotificationSettings: { self.peerNotificationSettingsTable.getEffective($0) }, getPeerPresence: { self.peerPresenceTable.get($0) })
            
            let (index, signal) = self.viewTracker.addChatListView(mutableView)
            
            subscriber.putNext((ChatListView(mutableView), .Generic))
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeChatListView(index)
                    }
                }
            }
        })
    }
    
    public func contactPeerIdsView() -> Signal<ContactPeerIdsView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let view = MutableContactPeerIdsView(remoteTotalCount: self.metadataTable.getRemoteContactCount(), peerIds: self.contactsTable.get())
            let (index, signal) = self.viewTracker.addContactPeerIdsView(view)
            
            subscriber.putNext(ContactPeerIdsView(view))
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeContactPeerIdsView(index)
                    }
                }
            }
        }
    }
    
    public func contactPeersView(accountPeerId: PeerId?, includePresences: Bool) -> Signal<ContactPeersView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            var peers: [PeerId: Peer] = [:]
            var peerPresences: [PeerId: PeerPresence] = [:]
            
            for peerId in self.contactsTable.get() {
                if let peer = self.peerTable.get(peerId) {
                    peers[peerId] = peer
                }
                if includePresences {
                    if let presence = self.peerPresenceTable.get(peerId) {
                        peerPresences[peerId] = presence
                    }
                }
            }
            
            let view = MutableContactPeersView(peers: peers, peerPresences: peerPresences, accountPeer: accountPeerId.flatMap(self.peerTable.get), includePresences: includePresences)
            let (index, signal) = self.viewTracker.addContactPeersView(view)
            
            subscriber.putNext(ContactPeersView(view))
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable {
                [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeContactPeersView(index)
                    }
                }
            }
        }
    }
    
    public func searchContacts(query: String) -> Signal<([Peer], [PeerId: PeerPresence]), NoError> {
        return self.transaction { transaction -> Signal<([Peer], [PeerId: PeerPresence]), NoError> in
            let (_, contactPeerIds) = self.peerNameIndexTable.matchingPeerIds(tokens: (regular: stringIndexTokens(query, transliteration: .none), transliterated: stringIndexTokens(query, transliteration: .transliterated)), categories: [.contacts], chatListIndexTable: self.chatListIndexTable, contactTable: self.contactsTable)
            
            var contactPeers: [Peer] = []
            var presences: [PeerId: PeerPresence] = [:]
            for peerId in contactPeerIds {
                if let peer = self.peerTable.get(peerId) {
                    contactPeers.append(peer)
                    if let presence = self.peerPresenceTable.get(peerId) {
                        presences[peerId] = presence
                    }
                }
            }
            
            contactPeers.sort(by: { $0.indexName.indexName(.lastNameFirst) < $1.indexName.indexName(.lastNameFirst) })
            return .single((contactPeers, presences))
        } |> switchToLatest
    }
    
    public func searchPeers(query: String) -> Signal<[RenderedPeer], NoError> {
        return self.transaction { transaction -> Signal<[RenderedPeer], NoError> in
            var peerIds = Set<PeerId>()
            var chatPeers: [RenderedPeer] = []
            
            var (chatPeerIds, contactPeerIds) = self.peerNameIndexTable.matchingPeerIds(tokens: (regular: stringIndexTokens(query, transliteration: .none), transliterated: stringIndexTokens(query, transliteration: .transliterated)), categories: [.chats, .contacts], chatListIndexTable: self.chatListIndexTable, contactTable: self.contactsTable)
            
            var additionalChatPeerIds: [PeerId] = []
            for peerId in chatPeerIds {
                for associatedId in self.reverseAssociatedPeerTable.get(peerId: peerId) {
                    let inclusionIndex = self.chatListIndexTable.get(peerId: associatedId)
                    if inclusionIndex.includedIndex(peerId: associatedId) != nil {
                        additionalChatPeerIds.append(associatedId)
                    }
                }
            }
            chatPeerIds.append(contentsOf: additionalChatPeerIds)
            
            for peerId in chatPeerIds {
                if let peer = self.peerTable.get(peerId) {
                    var peers = SimpleDictionary<PeerId, Peer>()
                    peers[peer.id] = peer
                    if let associatedPeerId = peer.associatedPeerId {
                        if let associatedPeer = self.peerTable.get(associatedPeerId) {
                            peers[associatedPeer.id] = associatedPeer
                        }
                    }
                    chatPeers.append(RenderedPeer(peerId: peer.id, peers: peers))
                    peerIds.insert(peerId)
                }
            }
            
            var contactPeers: [RenderedPeer] = []
            for peerId in contactPeerIds {
                if !peerIds.contains(peerId) {
                    if let peer = self.peerTable.get(peerId) {
                        var peers = SimpleDictionary<PeerId, Peer>()
                        peers[peer.id] = peer
                        contactPeers.append(RenderedPeer(peerId: peer.id, peers: peers))
                    }
                }
            }
            
            contactPeers.sort(by: { lhs, rhs in
                lhs.peers[lhs.peerId]!.indexName.indexName(.lastNameFirst) < rhs.peers[rhs.peerId]!.indexName.indexName(.lastNameFirst)
            })
            return .single(chatPeers + contactPeers)
        } |> switchToLatest
    }
    
    public func peerView(id: PeerId) -> Signal<PeerView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let view = MutablePeerView(postbox: self, peerId: id, components: .all)
            let (index, signal) = self.viewTracker.addPeerView(view)
            
            subscriber.putNext(PeerView(view))
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removePeerView(index)
                    }
                }
            }
        }
    }
    
    public func multiplePeersView(_ ids: [PeerId]) -> Signal<MultiplePeersView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let view = MutableMultiplePeersView(peerIds: ids, getPeer: { self.peerTable.get($0) }, getPeerPresence: { self.peerPresenceTable.get($0) })
            let (index, signal) = self.viewTracker.addMultiplePeersView(view)
            
            subscriber.putNext(MultiplePeersView(view))
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeMultiplePeersView(index)
                    }
                }
            }
        }
    }
    
    public func loadedPeerWithId(_ id: PeerId) -> Signal<Peer, NoError> {
        return self.transaction { transaction -> Signal<Peer, NoError> in
            if let peer = self.peerTable.get(id) {
                return .single(peer)
            } else {
                return .never()
            }
        } |> switchToLatest
    }
    
    public func unreadMessageCountsView(items: [UnreadMessageCountsItem]) -> Signal<UnreadMessageCountsView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let view = MutableUnreadMessageCountsView(postbox: self, items: items)
            let (index, signal) = self.viewTracker.addUnreadMessageCountsView(view)
            
            subscriber.putNext(UnreadMessageCountsView(view))
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeUnreadMessageCountsView(index)
                    }
                }
            }
        }
    }
    
    public func recentPeers() -> Signal<[Peer], NoError> {
        return self.transaction { transaction -> Signal<[Peer], NoError> in
            let peerIds = self.peerRatingTable.get()
            var peers: [Peer] = []
            for peerId in peerIds {
                if let peer: Peer = self.peerTable.get(peerId) {
                    peers.append(peer)
                }
            }
            return .single(peers)
        } |> switchToLatest
    }
    
    public func stateView() -> Signal<PostboxStateView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let mutableView = MutablePostboxStateView(state: self.getState())
            
            subscriber.putNext(PostboxStateView(mutableView))
            
            let (index, signal) = self.viewTracker.addPostboxStateView(mutableView)
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removePostboxStateView(index)
                    }
                }
            }
        }
    }
    
    public func messageHistoryHolesView() -> Signal<MessageHistoryHolesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                disposable.set(self.viewTracker.messageHistoryHolesViewSignal().start(next: { view in
                    subscriber.putNext(view)
                }))
            }
            return disposable
        }
    }
    
    public func chatListHolesView() -> Signal<ChatListHolesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                disposable.set(self.viewTracker.chatListHolesViewSignal().start(next: { view in
                    subscriber.putNext(view)
                }))
            }
            return disposable
        }
    }
    
    public func unsentMessageIdsView() -> Signal<UnsentMessageIdsView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                disposable.set(self.viewTracker.unsentMessageIdsViewSignal().start(next: { view in
                    subscriber.putNext(view)
                }))
            }
            return disposable
        }
    }
    
    public func synchronizePeerReadStatesView() -> Signal<SynchronizePeerReadStatesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                disposable.set(self.viewTracker.synchronizePeerReadStatesViewSignal().start(next: { view in
                    subscriber.putNext(view)
                }))
            }
            return disposable
        }
    }
    
    public func itemCollectionsView(orderedItemListCollectionIds: [Int32], namespaces: [ItemCollectionId.Namespace], aroundIndex: ItemCollectionViewEntryIndex?, count: Int) -> Signal<ItemCollectionsView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let itemListViews = orderedItemListCollectionIds.map { collectionId -> MutableOrderedItemListView in
                return MutableOrderedItemListView(postbox: self, collectionId: collectionId)
            }
            
            let mutableView = MutableItemCollectionsView(postbox: self, orderedItemListsViews: itemListViews, namespaces: namespaces, aroundIndex: aroundIndex, count: count)
            
            subscriber.putNext(ItemCollectionsView(mutableView))
            
            let (index, signal) = self.viewTracker.addItemCollectionView(mutableView)
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeItemCollectionView(index)
                    }
                }
            }
        }
    }
    
    public func mergedOperationLogView(tag: PeerOperationLogTag, limit: Int) -> Signal<PeerMergedOperationLogView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let view = MutablePeerMergedOperationLogView(tag: tag, limit: limit, getOperations: { tag, fromIndex, limit in
                return self.peerOperationLogTable.getMergedEntries(tag: tag, fromIndex: fromIndex, limit: limit)
            }, getTailIndex: { tag in
                return self.peerMergedOperationLogIndexTable.tailIndex(tag: tag)
            })
            
            subscriber.putNext(PeerMergedOperationLogView(view))
            
            let (index, signal) = self.viewTracker.addPeerMergedOperationLogView(view)
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removePeerMergedOperationLogView(index)
                    }
                }
            }
        }
    }
    
    public func timestampBasedMessageAttributesView(tag: UInt16) -> Signal<TimestampBasedMessageAttributesView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let view = MutableTimestampBasedMessageAttributesView(tag: tag, getHead: { tag in
                return self.timestampBasedMessageAttributesTable.head(tag: tag)
            })
            let (index, signal) = self.viewTracker.addTimestampBasedMessageAttributesView(view)
            
            subscriber.putNext(TimestampBasedMessageAttributesView(view))
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeTimestampBasedMessageAttributesView(index)
                    }
                }
            }
        }
    }
    
    fileprivate func operationLogGetNextEntryLocalIndex(peerId: PeerId, tag: PeerOperationLogTag) -> Int32 {
        return self.peerOperationLogTable.getNextEntryLocalIndex(peerId: peerId, tag: tag)
    }
    
    fileprivate func operationLogAddEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: StorePeerOperationLogEntryTagLocalIndex, tagMergedIndex: StorePeerOperationLogEntryTagMergedIndex, contents: PostboxCoding) {
        self.peerOperationLogTable.addEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, tagMergedIndex: tagMergedIndex, contents: contents, operations: &self.currentPeerMergedOperationLogOperations)
    }
    
    fileprivate func operationLogRemoveEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32) -> Bool {
        return self.peerOperationLogTable.removeEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, operations: &self.currentPeerMergedOperationLogOperations)
    }
    
    fileprivate func operationLogRemoveAllEntries(peerId: PeerId, tag: PeerOperationLogTag) {
        self.peerOperationLogTable.removeAllEntries(peerId: peerId, tag: tag, operations: &self.currentPeerMergedOperationLogOperations)
    }
    
    fileprivate func operationLogRemoveEntries(peerId: PeerId, tag: PeerOperationLogTag, withTagLocalIndicesEqualToOrLowerThan maxTagLocalIndex: Int32) {
        self.peerOperationLogTable.removeEntries(peerId: peerId, tag: tag, withTagLocalIndicesEqualToOrLowerThan: maxTagLocalIndex, operations: &self.currentPeerMergedOperationLogOperations)
    }
    
    fileprivate func operationLogUpdateEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: (PeerOperationLogEntry?) -> PeerOperationLogEntryUpdate) {
        self.peerOperationLogTable.updateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, f: f, operations: &self.currentPeerMergedOperationLogOperations)
    }
    
    fileprivate func operationLogEnumerateEntries(peerId: PeerId, tag: PeerOperationLogTag, _ f: (PeerOperationLogEntry) -> Bool) {
        self.peerOperationLogTable.enumerateEntries(peerId: peerId, tag: tag, f)
    }
    
    fileprivate func addTimestampBasedMessageAttribute(tag: UInt16, timestamp: Int32, messageId: MessageId) {
        self.timestampBasedMessageAttributesTable.set(tag: tag, id: messageId, timestamp: timestamp, operations: &self.currentTimestampBasedMessageAttributesOperations)
    }
    
    fileprivate func removeTimestampBasedMessageAttribute(tag: UInt16, messageId: MessageId) {
        self.timestampBasedMessageAttributesTable.remove(tag: tag, id: messageId, operations: &self.currentTimestampBasedMessageAttributesOperations)
    }
    
    public func messageView(_ messageId: MessageId) -> Signal<MessageView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let view = MutableMessageView(messageId: messageId, message: transaction.getMessage(messageId))
            
            subscriber.putNext(MessageView(view))
            
            let (index, signal) = self.viewTracker.addMessageView(view)
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeMessageView(index)
                    }
                }
            }
        }
    }
    
    public func preferencesView(keys: [ValueBoxKey]) -> Signal<PreferencesView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let view = MutablePreferencesView(postbox: self, keys: Set(keys))
            let (index, signal) = self.viewTracker.addPreferencesView(view)
            
            subscriber.putNext(PreferencesView(view))
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removePreferencesView(index)
                    }
                }
            }
        }
    }
    
    public func combinedView(keys: [PostboxViewKey]) -> Signal<CombinedView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            var views: [PostboxViewKey: MutablePostboxView] = [:]
            for key in keys {
                views[key] = postboxViewForKey(postbox: self, key: key)
            }
            let view = CombinedMutableView(views: views)
            let (index, signal) = self.viewTracker.addCombinedView(view)
            
            subscriber.putNext(view.immutableView())
            
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeCombinedView(index)
                    }
                }
            }
        }
    }
    
    fileprivate func enumeratePreferencesEntries(_ f: (PreferencesEntry) -> Bool) {
        self.preferencesTable.enumerateEntries(f)
    }
    
    fileprivate func getPreferencesEntry(key: ValueBoxKey) -> PreferencesEntry? {
        return self.preferencesTable.get(key: key)
    }
    
    fileprivate func setPreferencesEntry(key: ValueBoxKey, value: PreferencesEntry?) {
        self.preferencesTable.set(key: key, value: value, operations: &self.currentPreferencesOperations)
    }
    
    fileprivate func replaceOrderedItemListItems(collectionId: Int32, items: [OrderedItemListEntry]) {
        self.orderedItemListTable.replaceItems(collectionId: collectionId, items: items, operations: &self.currentOrderedItemListOperations)
    }
    
    fileprivate func addOrMoveToFirstPositionOrderedItemListItem(collectionId: Int32, item: OrderedItemListEntry, removeTailIfCountExceeds: Int?) {
        self.orderedItemListTable.addItemOrMoveToFirstPosition(collectionId: collectionId, item: item, removeTailIfCountExceeds: removeTailIfCountExceeds, operations: &self.currentOrderedItemListOperations)
    }
    
    fileprivate func removeOrderedItemListItem(collectionId: Int32, itemId: MemoryBuffer) {
        self.orderedItemListTable.remove(collectionId: collectionId, itemId: itemId, operations: &self.currentOrderedItemListOperations)
    }
    
    fileprivate func getOrderedListItemIds(collectionId: Int32) -> [MemoryBuffer] {
        return self.orderedItemListTable.getItemIds(collectionId: collectionId)
    }
    
    fileprivate func getOrderedItemListItem(collectionId: Int32, itemId: MemoryBuffer) -> OrderedItemListEntry? {
        return self.orderedItemListTable.getItem(collectionId: collectionId, itemId: itemId)
    }
    
    fileprivate func updateOrderedItemListItem(collectionId: Int32, itemId: MemoryBuffer, item: OrderedItemListEntryContents) {
        self.orderedItemListTable.updateItem(collectionId: collectionId, itemId: itemId, item: item, operations: &self.currentOrderedItemListOperations)
    }
    
    public func installStoreMessageAction(peerId: PeerId, _ f: @escaping ([StoreMessage], Transaction) -> Void) -> Disposable {
        let disposable = MetaDisposable()
        self.queue.async {
            if self.installedMessageActionsByPeerId[peerId] == nil {
                self.installedMessageActionsByPeerId[peerId] = Bag()
            }
            let index = self.installedMessageActionsByPeerId[peerId]!.add(f)
            disposable.set(ActionDisposable {
                self.queue.async {
                    if let bag = self.installedMessageActionsByPeerId[peerId] {
                        bag.remove(index)
                    }
                }
            })
        }
        return disposable
    }
    
    fileprivate func scanMessages(peerId: PeerId, namespace: MessageId.Namespace, tag: MessageTags, _ f: (Message) -> Bool) {
        var index = MessageIndex.lowerBound(peerId: peerId, namespace: namespace)
        while true {
            let indices = self.messageHistoryTagsTable.laterIndices(tag: tag, peerId: peerId, namespace: namespace, index: index, includeFrom: false, count: 10)
            for index in indices {
                if let message = self.messageHistoryTable.getMessage(index) {
                    if !f(self.renderIntermediateMessage(message)) {
                        break
                    }
                } else {
                    assertionFailure()
                    break
                }
            }
            if let last = indices.last {
                index = last
            } else {
                break
            }
        }
    }
    
    fileprivate func invalidateMessageHistoryTagsSummary(peerId: PeerId, namespace: MessageId.Namespace, tagMask: MessageTags) {
        self.invalidatedMessageHistoryTagsSummaryTable.insert(InvalidatedMessageHistoryTagsSummaryKey(peerId: peerId, namespace: namespace, tagMask: tagMask), operations: &self.currentInvalidateMessageTagSummaries)
    }
    
    fileprivate func removeInvalidatedMessageHistoryTagsSummaryEntry(_ entry: InvalidatedMessageHistoryTagsSummaryEntry) {
        self.invalidatedMessageHistoryTagsSummaryTable.remove(entry, operations: &self.currentInvalidateMessageTagSummaries)
    }
    
    fileprivate func getRelativeUnreadChatListIndex(filtered: Bool, position: ChatListRelativePosition, groupId: PeerGroupId) -> ChatListIndex? {
        return self.chatListTable.getRelativeUnreadChatListIndex(postbox: self, filtered: filtered, position: position, groupId: groupId)
    }
    
    func getMessage(_ id: MessageId) -> Message? {
        if let index = self.messageHistoryIndexTable.getIndex(id) {
            if let message = self.messageHistoryTable.getMessage(index) {
                return self.renderIntermediateMessage(message)
            }
        }
        return nil
    }
    
    fileprivate func getMessageGroup(at id: MessageId) -> [Message]? {
        guard let index = self.messageHistoryIndexTable.getIndex(id) else {
            return nil
        }
        if let messages = self.messageHistoryTable.getMessageGroup(at: index, limit: 16) {
            return messages.map(self.renderIntermediateMessage)
        } else {
            return nil
        }
    }
    
    fileprivate func getMessageForwardedGroup(_ id: MessageId) -> [Message]? {
        guard let index = self.messageHistoryIndexTable.getIndex(id) else {
            return nil
        }
        if let messages = self.messageHistoryTable.getMessageForwardedGroup(at: index, limit: 200) {
            return messages.map(self.renderIntermediateMessage)
        } else {
            return nil
        }
    }
    
    fileprivate func getMessageFailedGroup(_ id: MessageId) -> [Message]? {
        guard let index = self.messageHistoryIndexTable.getIndex(id) else {
            return nil
        }
        if let messages = self.messageHistoryTable.getMessageFailedGroup(at: index, limit: 100) {
            return messages.sorted(by: { lhs, rhs in
                return lhs.index < rhs.index
            }).map(self.renderIntermediateMessage)
        } else {
            return nil
        }
    }
    
    fileprivate func clearDeviceContactImportInfoIdentifiers() {
        let identifiers = self.deviceContactImportInfoTable.getIdentifiers()
        for identifier in identifiers {
            self.deviceContactImportInfoTable.set(identifier, value: nil)
        }
    }
    
    public func isMasterClient() -> Signal<Bool, NoError> {
        return self.transaction { transaction -> Signal<Bool, NoError> in
            let sessionClientId = self.sessionClientId
            return self.masterClientId.get()
                |> distinctUntilChanged
                |> map({ $0 == sessionClientId })
        } |> switchToLatest
    }
    
    public func becomeMasterClient() {
        let _ = self.transaction({ transaction in
            if self.metadataTable.masterClientId() != self.sessionClientId {
                self.currentUpdatedMasterClientId = self.sessionClientId
            }
        }).start()
    }
    
    public func clearCaches() {
        let _ = self.transaction({ _ in
            for table in self.tables {
                table.clearMemoryCache()
            }
        }).start()
    }
    
    public func optimizeStorage() -> Signal<Never, NoError> {
        return Signal { subscriber in
            self.valueBox.vacuum()
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    fileprivate func addHolesEverywhere(peerNamespaces: [PeerId.Namespace], holeNamespace: MessageId.Namespace) {
        for peerId in self.chatListIndexTable.getAllPeerIds() {
            if peerNamespaces.contains(peerId.namespace) && self.messageHistoryMetadataTable.isInitialized(peerId) {
                self.addHole(peerId: peerId, namespace: holeNamespace, space: .everywhere, range: 1 ... Int32.max - 1)
            }
        }
    }
    
    fileprivate func reindexUnreadCounters() {
        self.groupMessageStatsTable.removeAll()
        let startTime = CFAbsoluteTimeGetCurrent()
        let (rootState, summaries) = self.chatListIndexTable.debugReindexUnreadCounts(postbox: self)
        
        self.messageHistoryMetadataTable.setChatListTotalUnreadState(rootState)
        self.currentUpdatedTotalUnreadState = rootState
        for (groupId, summary) in summaries {
            self.groupMessageStatsTable.set(groupId: groupId, summary: summary)
            self.currentUpdatedGroupTotalUnreadSummaries[groupId] = summary
        }
    }
    
    public func failedMessageIdsView(peerId: PeerId) -> Signal<FailedMessageIdsView, NoError> {
        return self.transactionSignal { subscriber, transaction in
            let view = MutableFailedMessageIdsView(peerId: peerId, ids: self.failedMessageIds(for: peerId))
            let (index, signal) = self.viewTracker.addFailedMessageIdsView(view)
            subscriber.putNext(view.immutableView())
            let disposable = signal.start(next: { next in
                subscriber.putNext(next)
            })
            
            return ActionDisposable { [weak self] in
                disposable.dispose()
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeFailedMessageIdsView(index)
                    }
                }
            }
        }
    }
    
}
