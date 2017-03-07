import Foundation

#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

public enum PreloadedMessageHistoryView {
    case Loading
    case Preloaded(MessageHistoryView)
}

public protocol PeerChatState: Coding {
    func equals(_ other: PeerChatState) -> Bool
}

public final class Modifier {
    private weak var postbox: Postbox?
    
    fileprivate init(postbox: Postbox) {
        self.postbox = postbox
    }
    
    public func addMessages(_ messages: [StoreMessage], location: AddMessagesLocation) -> [Int64: MessageId] {
        if let postbox = self.postbox {
            return postbox.addMessages(messages, location: location)
        } else {
            return [:]
        }
    }
    
    public func addHole(_ messageId: MessageId) {
        self.postbox?.addHole(messageId)
    }
    
    public func fillHole(_ hole: MessageHistoryHole, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage]) {
        self.postbox?.fillHole(hole, fillType: fillType, tagMask: tagMask, messages: messages)
    }
    
    public func fillMultipleHoles(_ hole: MessageHistoryHole, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage]) {
        self.postbox?.fillMultipleHoles(hole, fillType: fillType, tagMask: tagMask, messages: messages)
    }
    
    public func replaceChatListHole(_ index: MessageIndex, hole: ChatListHole?) {
        self.postbox?.replaceChatListHole(index, hole: hole)
    }
    
    public func deleteMessages(_ messageIds: [MessageId]) {
        self.postbox?.deleteMessages(messageIds)
    }
    
    public func clearHistory(_ peerId: PeerId) {
        self.postbox?.clearHistory(peerId)
    }
    public func messageIdsForGlobalIds(_ ids: [Int32]) -> [MessageId] {
        if let postbox = self.postbox {
            return postbox.messageIdsForGlobalIds(ids)
        } else {
            return []
        }
    }
    
    public func deleteMessagesWithGlobalIds(_ ids: [Int32]) {
        if let postbox = self.postbox {
            let messageIds = postbox.messageIdsForGlobalIds(ids)
            postbox.deleteMessages(messageIds)
        }
    }
    
    public func messageIdForGloballyUniqueMessageId(peerId: PeerId, id: Int64) -> MessageId? {
        return self.postbox?.messageIdForGloballyUniqueMessageId(peerId: peerId, id: id)
    }
    
    public func resetIncomingReadStates(_ states: [PeerId: [MessageId.Namespace: PeerReadState]]) {
        self.postbox?.resetIncomingReadStates(states)
    }
    
    public func confirmSynchronizedIncomingReadState(_ peerId: PeerId) {
        self.postbox?.confirmSynchronizedIncomingReadState(peerId)
    }
    
    public func applyIncomingReadMaxId(_ messageId: MessageId) {
        self.postbox?.applyIncomingReadMaxId(messageId)
    }
    
    public func applyOutgoingReadMaxId(_ messageId: MessageId) {
        self.postbox?.applyOutgoingReadMaxId(messageId)
    }
    
    public func applyInteractiveReadMaxIndex(_ messageIndex: MessageIndex) -> [MessageId] {
        if let postbox = self.postbox {
            return postbox.applyInteractiveReadMaxIndex(messageIndex)
        } else {
            return []
        }
    }
    
    public func applyOutgoingReadMaxIndex(_ messageIndex: MessageIndex) -> [MessageId] {
        if let postbox = self.postbox {
            return postbox.applyOutgoingReadMaxIndex(messageIndex)
        } else {
            return []
        }
    }
    
    public func getState() -> Coding? {
        return self.postbox?.getState()
    }
    
    public func setState(_ state: Coding) {
        self.postbox?.setState(state)
    }
    
    public func getPeerChatState(_ id: PeerId) -> PeerChatState? {
        return self.postbox?.peerChatStateTable.get(id) as? PeerChatState
    }
    
    public func setPeerChatState(_ id: PeerId, state: PeerChatState) {
        self.postbox?.peerChatStateTable.set(id, state: state)
    }
    
    public func updatePeerChatInterfaceState(_ id: PeerId, update: (PeerChatInterfaceState?) -> (PeerChatInterfaceState?)) {
        self.postbox?.updatePeerChatInterfaceState(id, update: update)
    }
    
    public func getPeer(_ id: PeerId) -> Peer? {
        return self.postbox?.peerTable.get(id)
    }
    
    public func getPeerReadStates(_ id: PeerId) -> [(MessageId.Namespace, PeerReadState)]? {
        return self.postbox?.readStateTable.getCombinedState(id)?.states
    }
    
    public func getCombinedPeerReadState(_ id: PeerId) -> CombinedPeerReadState? {
        return self.postbox?.readStateTable.getCombinedState(id)
    }
    
    public func getPeerNotificationSettings(_ id: PeerId) -> PeerNotificationSettings? {
        return self.postbox?.peerNotificationSettingsTable.get(id)
    }
    
    public func updatePeersInternal(_ peers: [Peer], update: (Peer?, Peer) -> Peer?) {
        self.postbox?.updatePeers(peers, update: update)
    }
    
    public func getPeerChatListInclusion(_ id: PeerId) -> PeerChatListInclusion {
        if let postbox = self.postbox {
            return postbox.getPeerChatListInclusion(id)
        }
        return .never
    }
    
    public func getTopPeerMessageId(peerId: PeerId, namespace: MessageId.Namespace) -> MessageId? {
        return self.postbox?.messageHistoryIndexTable.top(peerId, namespace: namespace)?.index.id
    }
    
    public func updatePeerChatListInclusion(_ id: PeerId, inclusion: PeerChatListInclusion) {
        self.postbox?.updatePeerChatListInclusion(id, inclusion: inclusion)
    }
    
    public func updatePeerNotificationSettings(_ notificationSettings: [PeerId: PeerNotificationSettings]) {
        self.postbox?.updatePeerNotificationSettings(notificationSettings)
    }
    
    public func resetAllPeerNotificationSettings(_ notificationSettings: PeerNotificationSettings) {
        self.postbox?.resetAllPeerNotificationSettings(notificationSettings)
    }
    
    public func updatePeerCachedData(peerIds: Set<PeerId>, update: (PeerId, CachedPeerData?) -> CachedPeerData?) {
        self.postbox?.updatePeerCachedData(peerIds: peerIds, update: update)
    }
    
    public func getPeerCachedData(peerId: PeerId) -> CachedPeerData? {
        return self.postbox?.cachedPeerDataTable.get(peerId)
    }
    
    public func updatePeerPresences(_ peerPresences: [PeerId: PeerPresence]) {
        self.postbox?.updatePeerPresences(peerPresences)
    }
    
    public func replaceContactPeerIds(_ peerIds: Set<PeerId>) {
        self.postbox?.replaceContactPeerIds(peerIds)
    }
    
    public func replaceRecentPeerIds(_ peerIds: [PeerId]) {
        self.postbox?.replaceRecentPeerIds(peerIds)
    }
    
    public func updateMessage(_ id: MessageId, update: (Message) -> StoreMessage) {
        self.postbox?.updateMessage(id, update: update)
    }
    
    public func offsetPendingMessagesTimestamps(lowerBound: MessageId, timestamp: Int32) {
        self.postbox?.offsetPendingMessagesTimestamps(lowerBound: lowerBound, timestamp: timestamp)
    }
    
    public func updateMedia(_ id: MediaId, update: Media?) {
        self.postbox?.updateMedia(id, update: update)
    }
    
    public func replaceItemCollections(namespace: ItemCollectionId.Namespace, itemCollections: [(ItemCollectionId, ItemCollectionInfo, [ItemCollectionItem])]) {
        self.postbox?.replaceItemCollections(namespace: namespace, itemCollections: itemCollections)
    }
    
    public func getItemCollectionItems(collectionId: ItemCollectionId) -> [ItemCollectionItem] {
        if let postbox = self.postbox {
            return postbox.itemCollectionItemTable.collectionItems(collectionId: collectionId)
        } else {
            return []
        }
    }
    
    public func getCollectionsItems(namespace: ItemCollectionId.Namespace) -> [(ItemCollectionId, ItemCollectionInfo, [ItemCollectionItem])] {
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
    
    public func getItemCollectionInfoItems(namespace: ItemCollectionId.Namespace, id:ItemCollectionId) -> (ItemCollectionInfo, [ItemCollectionItem])? {
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
    
    public func searchItemCollection(namespace: ItemCollectionId.Namespace, key: MemoryBuffer) -> [ItemCollectionItem] {
        if let postbox = self.postbox {
            return postbox.itemCollectionItemTable.exactIndexedItems(namespace: namespace, key: ValueBoxKey(key))
        } else {
            return []
        }
    }
    
    public func replaceOrderedItemListItems(collectionId: Int32, items: [OrderedItemListEntry]) {
        self.postbox?.replaceOrderedItemListItems(collectionId: collectionId, items: items)
    }
    
    public func addOrMoveToFirstPositionOrderedItemListItem(collectionId: Int32, item: OrderedItemListEntry, removeTailIfCountExceeds: Int?) {
        self.postbox?.addOrMoveToFirstPositionOrderedItemListItem(collectionId: collectionId, item: item, removeTailIfCountExceeds: removeTailIfCountExceeds)
    }
    
    public func getOrderedListItemIds(collectionId: Int32) -> [MemoryBuffer] {
        if let postbox = postbox {
            return postbox.getOrderedListItemIds(collectionId: collectionId)
        } else {
            return []
        }
    }
    
    public func getMessage(_ id: MessageId) -> Message? {
        if let postbox = self.postbox {
            if let entry = postbox.messageHistoryIndexTable.get(id) {
                if case let .Message(index) = entry {
                    if let message = postbox.messageHistoryTable.getMessage(index) {
                        return postbox.renderIntermediateMessage(message)
                    }
                }
            }
        }
        return nil
    }
    
    public func filterStoredMessageIds(_ messageIds: Set<MessageId>) -> Set<MessageId> {
        if let postbox = self.postbox {
            return postbox.filterStoredMessageIds(messageIds)
        }
        return Set()
    }
    
    public func storedMessageId(peerId: PeerId, namespace: MessageId.Namespace, timestamp: Int32) -> MessageId? {
        return self.postbox?.storedMessageId(peerId: peerId, namespace: namespace, timestamp: timestamp)
    }
    
    public func putItemCacheEntry(id: ItemCacheEntryId, entry: Coding, collectionSpec: ItemCacheCollectionSpec) {
        self.postbox?.putItemCacheEntry(id: id, entry: entry, collectionSpec: collectionSpec)
    }
    
    public func retrieveItemCacheEntry(id: ItemCacheEntryId) -> Coding? {
        return self.postbox?.retrieveItemCacheEntry(id: id)
    }
    
    public func operationLogGetNextEntryLocalIndex(peerId: PeerId, tag: PeerOperationLogTag) -> Int32 {
        if let postbox = self.postbox {
            return postbox.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: tag)
        } else {
            return 0
        }
    }
    
    public func operationLogAddEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: StorePeerOperationLogEntryTagLocalIndex, tagMergedIndex: StorePeerOperationLogEntryTagMergedIndex, contents: Coding) {
        self.postbox?.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, tagMergedIndex: tagMergedIndex, contents: contents)
    }
    
    public func operationLogRemoveEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32) -> Bool {
        if let postbox = self.postbox {
            return postbox.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex)
        } else {
            return false
        }
    }
    
    public func operationLogRemoveAllEntries(peerId: PeerId, tag: PeerOperationLogTag) {
        self.postbox?.operationLogRemoveAllEntries(peerId: peerId, tag: tag)
    }
    
    public func operationLogRemoveEntries(peerId: PeerId, tag: PeerOperationLogTag, withTagLocalIndicesEqualToOrLowerThan maxTagLocalIndex: Int32) {
        self.postbox?.operationLogRemoveEntries(peerId: peerId, tag: tag, withTagLocalIndicesEqualToOrLowerThan: maxTagLocalIndex)
    }
    
    public func operationLogUpdateEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: (PeerOperationLogEntry?) -> PeerOperationLogEntryUpdate) {
        self.postbox?.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, f)
    }
    
    public func operationLogEnumerateEntries(peerId: PeerId, tag: PeerOperationLogTag, _ f: (PeerOperationLogEntry) -> Bool) {
        self.postbox?.operationLogEnumerateEntries(peerId: peerId, tag: tag, f)
    }
    
    public func addTimestampBasedMessageAttribute(tag: UInt16, timestamp: Int32, messageId: MessageId) {
        self.postbox?.addTimestampBasedMessageAttribute(tag: tag, timestamp: timestamp, messageId: messageId)
    }
    
    public func removeTimestampBasedMessageAttribute(tag: UInt16, messageId: MessageId) {
        self.postbox?.removeTimestampBasedMessageAttribute(tag: tag, messageId: messageId)
    }
    
    public func getPreferencesEntry(key: ValueBoxKey) -> PreferencesEntry? {
        return self.postbox?.getPreferencesEntry(key: key)
    }
    
    public func setPreferencesEntry(key: ValueBoxKey, value: PreferencesEntry?) {
        self.postbox?.setPreferencesEntry(key: key, value: value)
    }
    
    public func updatePreferencesEntry(key: ValueBoxKey, _ f: (PreferencesEntry?) -> PreferencesEntry?) {
        self.postbox?.setPreferencesEntry(key: key, value: f(self.postbox?.getPreferencesEntry(key: key)))
    }
    
    public func getPinnedPeerIds() -> [PeerId] {
        if let postbox = self.postbox {
            return postbox.chatListTable.getPinnedPeerIds()
        } else {
            return []
        }
    }
    
    public func setPinnedPeerIds(_ peerIds: [PeerId]) {
        self.postbox?.setPinnedPeerIds(peerIds)
    }
    
    public func getTotalUnreadCount() -> Int32 {
        if let postbox = self.postbox {
            return postbox.messageHistoryMetadataTable.getChatListTotalUnreadCount()
        } else {
            return 0
        }
    }
    
    public func getAccessChallengeData() -> PostboxAccessChallengeData {
        if let postbox = self.postbox {
            return postbox.metadataTable.accessChallengeData()
        } else {
            return .none
        }
    }
    
    public func setAccessChallengeData(_ data: PostboxAccessChallengeData) {
        self.postbox?.metadataTable.setAccessChallengeData(data)
    }
}

fileprivate class PipeNotifier: NSObject {
    let notifier: RLMNotifier
    let thread: Thread
    
    fileprivate init(basePath: String, notify: @escaping () -> Void) {
        self.notifier = RLMNotifier(basePath: basePath, notify: notify)
        self.thread = Thread(target: PipeNotifier.self, selector: #selector(PipeNotifier.threadEntry(_:)), object: self.notifier)
        self.thread.start()
    }
    
    @objc static func threadEntry(_ notifier: RLMNotifier!) {
        notifier.listen()
    }
    
    func notify() {
        notifier.notifyOtherRealms()
    }
}

public final class Postbox {
    private let seedConfiguration: SeedConfiguration
    private let basePath: String
    private let globalMessageIdsNamespace: MessageId.Namespace
    
    private let ipcNotificationsDisposable = MetaDisposable()
    //private var pipeNotifier: PipeNotifier!
    
    private let queue = Queue(name: "org.telegram.postbox.Postbox")
    private var valueBox: ValueBox!
    
    private var transactionStateVersion: Int64 = 0
    
    private var viewTracker: ViewTracker!
    private var nextViewId = 0
    
    private var peerPipes: [PeerId: ValuePipe<Peer>] = [:]
    
    private var currentUpdatedState: Coding?
    private var currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
    private var currentUpdatedChatListInclusions: [PeerId: PeerChatListInclusion] = [:]
    private var currentUnsentOperations: [IntermediateMessageHistoryUnsentOperation] = []
    private var currentUpdatedSynchronizeReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
    private var currentUpdatedMedia: [MediaId: Media?] = [:]
    
    private var currentRemovedHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]] = [:]
    private var currentFilledHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]] = [:]
    private var currentUpdatedPeers: [PeerId: Peer] = [:]
    private var currentUpdatedPeerNotificationSettings: [PeerId: PeerNotificationSettings] = [:]
    private var currentUpdatedCachedPeerData: [PeerId: CachedPeerData] = [:]
    private var currentUpdatedPeerPresences: [PeerId: PeerPresence] = [:]
    private var currentUpdatedPeerChatListEmbeddedStates: [PeerId: PeerChatListEmbeddedInterfaceState?] = [:]
    private var currentUpdatedTotalUnreadCount: Int32?
    private var currentPeerMergedOperationLogOperations: [PeerMergedOperationLogOperation] = []
    private var currentTimestampBasedMessageAttributesOperations: [TimestampBasedMessageAttributesOperation] = []
    private var currentPreferencesOperations: [PreferencesOperation] = []
    private var currentOrderedItemListOperations: [Int32: [OrderedItemListOperation]] = [:]
    
    private var currentReplaceChatListHoles: [(MessageIndex, ChatListHole?)] = []
    private var currentReplacedContactPeerIds: Set<PeerId>?
    private var currentUpdatedMasterClientId: Int64?
    
    private var statePipe: ValuePipe<Coding> = ValuePipe()
    private var masterClientId = Promise<Int64>()
    
    private var sessionClientId: Int64 = {
        var value: Int64 = 0
        arc4random_buf(&value, 8)
        return value
    }()
    
    public let mediaBox: MediaBox
    
    var tables: [Table] = []
    
    var metadataTable: MetadataTable!
    var keychainTable: KeychainTable!
    var peerTable: PeerTable!
    var peerNotificationSettingsTable: PeerNotificationSettingsTable!
    var cachedPeerDataTable: CachedPeerDataTable!
    var peerPresenceTable: PeerPresenceTable!
    var globalMessageIdsTable: GlobalMessageIdsTable!
    var globallyUniqueMessageIdsTable: MessageGloballyUniqueIdTable!
    var messageHistoryIndexTable: MessageHistoryIndexTable!
    var messageHistoryTable: MessageHistoryTable!
    var mediaTable: MessageMediaTable!
    var chatListIndexTable: ChatListIndexTable!
    var chatListTable: ChatListTable!
    var messageHistoryMetadataTable: MessageHistoryMetadataTable!
    var messageHistoryUnsentTable: MessageHistoryUnsentTable!
    var messageHistoryTagsTable: MessageHistoryTagsTable!
    var peerChatStateTable: PeerChatStateTable!
    var readStateTable: MessageHistoryReadStateTable!
    var synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable!
    var contactsTable: ContactTable!
    var itemCollectionInfoTable: ItemCollectionInfoTable!
    var itemCollectionItemTable: ItemCollectionItemTable!
    var itemCollectionReverseIndexTable: ReverseIndexReferenceTable<ItemCollectionItemReverseIndexReference>!
    var peerChatInterfaceStateTable: PeerChatInterfaceStateTable!
    var itemCacheMetaTable: ItemCacheMetaTable!
    var itemCacheTable: ItemCacheTable!
    var peerNameTokenIndexTable: ReverseIndexReferenceTable<PeerIdReverseIndexReference>!
    var peerNameIndexTable: PeerNameIndexTable!
    var peerChatTopTaggedMessageIdsTable: PeerChatTopTaggedMessageIdsTable!
    var peerOperationLogMetadataTable: PeerOperationLogMetadataTable!
    var peerMergedOperationLogIndexTable: PeerMergedOperationLogIndexTable!
    var peerOperationLogTable: PeerOperationLogTable!
    var timestampBasedMessageAttributesTable: TimestampBasedMessageAttributesTable!
    var timestampBasedMessageAttributesIndexTable: TimestampBasedMessageAttributesIndexTable!
    var preferencesTable: PreferencesTable!
    var orderedItemListTable: OrderedItemListTable!
    var orderedItemListIndexTable: OrderedItemListIndexTable!
    
    //temporary
    var peerRatingTable: RatingTable<PeerId>!
    
    
    public init(basePath: String, globalMessageIdsNamespace: MessageId.Namespace, seedConfiguration: SeedConfiguration) {
        self.basePath = basePath
        self.globalMessageIdsNamespace = globalMessageIdsNamespace
        self.seedConfiguration = seedConfiguration
        
        print("MediaBox path: \(self.basePath + "/media")")
        
        //let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        
        self.mediaBox = MediaBox(basePath: self.basePath + "/media")
        
        /*self.pipeNotifier = PipeNotifier(basePath: basePath, notify: { [weak self] in
            //if let strongSelf = self {
                /*strongSelf.queue.async {
                    if strongSelf.valueBox != nil {
                        let _ = strongSelf.modify({ _ -> Void in
                        }).start()
                    }
                }*/
            //}
        })*/
        
        self.openDatabase()
    }
    
    deinit {
        assert(true)
    }
    
    private func debugSaveState(name: String) {
        let path = self.basePath + name
        let _ = try? FileManager.default.removeItem(atPath: path)
        do {
            try FileManager.default.copyItem(atPath: self.basePath, toPath: path)
        } catch (let e) {
            print("(Postbox debugSaveState: error \(e))")
        }
    }
    
    private func debugRestoreState(name: String) {
        let path = self.basePath + name
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        do {
            try FileManager.default.copyItem(atPath: path, toPath: self.basePath)
        } catch (let e) {
            print("(Postbox debugRestoreState: error \(e))")
        }
    }
    
    private func openDatabase() {
        self.queue.justDispatch({
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                try FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
            }
            
            //let _ = try? FileManager.default.removeItem(atPath: self.basePath + "/media")
            
            //#if TARGET_IPHONE_SIMULATOR
            
            //self.debugSaveState(name: "previous")
            //self.debugRestoreState(name: "previous")
            
            //#endif
            
            self.valueBox = SqliteValueBox(basePath: self.basePath + "/db", queue: self.queue)
            
            self.metadataTable = MetadataTable(valueBox: self.valueBox, table: MetadataTable.tableSpec(0))
            
            let userVersion: Int32? = self.metadataTable.userVersion()
            let currentUserVersion: Int32 = 12
            
            if userVersion != currentUserVersion {
                self.valueBox.drop()
                self.metadataTable.setUserVersion(currentUserVersion)
            }
            
            self.keychainTable = KeychainTable(valueBox: self.valueBox, table: KeychainTable.tableSpec(1))
            self.peerTable = PeerTable(valueBox: self.valueBox, table: PeerTable.tableSpec(2))
            self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox, table: GlobalMessageIdsTable.tableSpec(3), namespace: self.globalMessageIdsNamespace)
            self.globallyUniqueMessageIdsTable = MessageGloballyUniqueIdTable(valueBox: self.valueBox, table: MessageGloballyUniqueIdTable.tableSpec(32))
            self.messageHistoryMetadataTable = MessageHistoryMetadataTable(valueBox: self.valueBox, table: MessageHistoryMetadataTable.tableSpec(10))
            self.messageHistoryUnsentTable = MessageHistoryUnsentTable(valueBox: self.valueBox, table: MessageHistoryUnsentTable.tableSpec(11))
            self.messageHistoryTagsTable = MessageHistoryTagsTable(valueBox: self.valueBox, table: MessageHistoryTagsTable.tableSpec(12))
            self.messageHistoryIndexTable = MessageHistoryIndexTable(valueBox: self.valueBox, table: MessageHistoryIndexTable.tableSpec(4), globalMessageIdsTable: self.globalMessageIdsTable, metadataTable: self.messageHistoryMetadataTable, seedConfiguration: self.seedConfiguration)
            self.mediaTable = MessageMediaTable(valueBox: self.valueBox, table: MessageMediaTable.tableSpec(6))
            self.readStateTable = MessageHistoryReadStateTable(valueBox: self.valueBox, table: MessageHistoryReadStateTable.tableSpec(14))
            self.synchronizeReadStateTable = MessageHistorySynchronizeReadStateTable(valueBox: self.valueBox, table: MessageHistorySynchronizeReadStateTable.tableSpec(15))
            self.timestampBasedMessageAttributesIndexTable = TimestampBasedMessageAttributesIndexTable(valueBox: self.valueBox!, table: TimestampBasedMessageAttributesTable.tableSpec(33))
            self.timestampBasedMessageAttributesTable = TimestampBasedMessageAttributesTable(valueBox: self.valueBox!, table: TimestampBasedMessageAttributesTable.tableSpec(34), indexTable: self.timestampBasedMessageAttributesIndexTable)
            self.messageHistoryTable = MessageHistoryTable(valueBox: self.valueBox, table: MessageHistoryTable.tableSpec(7), messageHistoryIndexTable: self.messageHistoryIndexTable, messageMediaTable: self.mediaTable, historyMetadataTable: self.messageHistoryMetadataTable, globallyUniqueMessageIdsTable: self.globallyUniqueMessageIdsTable!, unsentTable: self.messageHistoryUnsentTable!, tagsTable: self.messageHistoryTagsTable, readStateTable: self.readStateTable, synchronizeReadStateTable: self.synchronizeReadStateTable!)
            self.peerChatStateTable = PeerChatStateTable(valueBox: self.valueBox, table: PeerChatStateTable.tableSpec(13))
            self.peerNameTokenIndexTable = ReverseIndexReferenceTable<PeerIdReverseIndexReference>(valueBox: self.valueBox, table: ReverseIndexReferenceTable<PeerIdReverseIndexReference>.tableSpec(26))
            self.peerNameIndexTable = PeerNameIndexTable(valueBox: self.valueBox, table: PeerNameIndexTable.tableSpec(27), peerTable: self.peerTable, peerNameTokenIndexTable: self.peerNameTokenIndexTable)
            self.contactsTable = ContactTable(valueBox: self.valueBox, table: ContactTable.tableSpec(16), peerNameIndexTable: self.peerNameIndexTable)
            self.peerRatingTable = RatingTable<PeerId>(valueBox: self.valueBox, table: RatingTable<PeerId>.tableSpec(17))
            self.cachedPeerDataTable = CachedPeerDataTable(valueBox: self.valueBox, table: CachedPeerDataTable.tableSpec(18))
            self.peerNotificationSettingsTable = PeerNotificationSettingsTable(valueBox: self.valueBox, table: PeerNotificationSettingsTable.tableSpec(19))
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
            self.peerMergedOperationLogIndexTable = PeerMergedOperationLogIndexTable(valueBox: self.valueBox, table: PeerMergedOperationLogIndexTable.tableSpec(30), metadataTable: self.peerOperationLogMetadataTable!)
            self.peerOperationLogTable = PeerOperationLogTable(valueBox: self.valueBox, table: PeerOperationLogTable.tableSpec(31), metadataTable: self.peerOperationLogMetadataTable, mergedIndexTable: self.peerMergedOperationLogIndexTable)
            self.preferencesTable = PreferencesTable(valueBox: self.valueBox, table: PreferencesTable.tableSpec(35))
            self.orderedItemListIndexTable = OrderedItemListIndexTable(valueBox: self.valueBox, table: OrderedItemListIndexTable.tableSpec(37))
            self.orderedItemListTable = OrderedItemListTable(valueBox: self.valueBox, table: OrderedItemListTable.tableSpec(38), indexTable: self.orderedItemListIndexTable)
            
            self.tables.append(self.keychainTable)
            self.tables.append(self.peerTable)
            self.tables.append(self.globalMessageIdsTable)
            self.tables.append(self.globallyUniqueMessageIdsTable)
            self.tables.append(self.messageHistoryMetadataTable)
            self.tables.append(self.messageHistoryUnsentTable)
            self.tables.append(self.messageHistoryTagsTable)
            self.tables.append(self.messageHistoryIndexTable)
            self.tables.append(self.mediaTable)
            self.tables.append(self.readStateTable)
            self.tables.append(self.synchronizeReadStateTable)
            self.tables.append(self.messageHistoryTable)
            self.tables.append(self.chatListIndexTable)
            self.tables.append(self.chatListTable)
            self.tables.append(self.peerChatStateTable)
            self.tables.append(self.contactsTable)
            self.tables.append(self.peerRatingTable)
            self.tables.append(self.peerNotificationSettingsTable)
            self.tables.append(self.cachedPeerDataTable)
            self.tables.append(self.peerPresenceTable)
            self.tables.append(self.itemCollectionInfoTable)
            self.tables.append(self.itemCollectionItemTable)
            self.tables.append(self.itemCollectionReverseIndexTable)
            self.tables.append(self.peerChatInterfaceStateTable)
            self.tables.append(self.itemCacheMetaTable)
            self.tables.append(self.itemCacheTable)
            self.tables.append(self.peerNameIndexTable)
            self.tables.append(self.peerNameTokenIndexTable)
            self.tables.append(self.peerChatTopTaggedMessageIdsTable)
            self.tables.append(self.peerOperationLogMetadataTable)
            self.tables.append(self.peerMergedOperationLogIndexTable)
            self.tables.append(self.peerOperationLogTable)
            self.tables.append(self.preferencesTable)
            self.tables.append(self.orderedItemListTable)
            self.tables.append(self.orderedItemListIndexTable)
            
            self.transactionStateVersion = self.metadataTable.transactionStateVersion()
            
            self.viewTracker = ViewTracker(queue: self.queue, fetchEarlierHistoryEntries: self.fetchEarlierHistoryEntries, fetchLaterHistoryEntries: self.fetchLaterHistoryEntries, fetchEarlierChatEntries: self.fetchEarlierChatEntries, fetchLaterChatEntries: self.fetchLaterChatEntries, fetchAnchorIndex: self.fetchAnchorIndex, renderMessage: self.renderIntermediateMessage, getPeer: { peerId in
                return self.peerTable.get(peerId)
            }, getPeerNotificationSettings: { peerId in
                return self.peerNotificationSettingsTable.get(peerId)
            }, getCachedPeerData: { peerId in
                return self.cachedPeerDataTable.get(peerId)
            }, getPeerPresence: { peerId in
                return self.peerPresenceTable.get(peerId)
            }, getTotalUnreadCount: {
                return self.messageHistoryMetadataTable.getChatListTotalUnreadCount()
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
            }, unsentMessageIds: self.messageHistoryUnsentTable!.get(), synchronizePeerReadStateOperations: self.synchronizeReadStateTable!.get(getCombinedPeerReadState: { peerId in
                return self.readStateTable.getCombinedState(peerId)
            }))
            
            print("(Postbox initialization took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        })
    }
    
    private func takeNextViewId() -> Int {
        let nextId = self.nextViewId
        self.nextViewId += 1
        return nextId
    }
    
    fileprivate func setState(_ state: Coding) {
        self.currentUpdatedState = state
        self.metadataTable.setState(state)
        
        self.statePipe.putNext(state)
    }
    
    fileprivate func getState() -> Coding? {
        return self.metadataTable.state()
    }
    
    public func keychainEntryForKey(_ key: String) -> Data? {
        let metaDisposable = MetaDisposable()
        self.keychainOperationsDisposable.add(metaDisposable)
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var entry: Data? = nil
        let disposable = (self.modify({ modifier -> Data? in
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
        
        let disposable = (self.modify({ modifier -> Void in
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
        
        let disposable = (self.modify({ modifier -> Void in
            self.keychainTable.remove(key)
        }) |> afterDisposed { [weak self, weak metaDisposable] in
            if let strongSelf = self, let metaDisposable = metaDisposable {
                strongSelf.keychainOperationsDisposable.remove(metaDisposable)
            }
        }).start()
        metaDisposable.set(disposable)
    }
    
    fileprivate func addMessages(_ messages: [StoreMessage], location: AddMessagesLocation) -> [Int64: MessageId] {
        return self.messageHistoryTable.addMessages(messages, location: location, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func addHole(_ id: MessageId) {
        self.messageHistoryTable.addHoles([id], operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func fillHole(_ hole: MessageHistoryHole, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        self.messageHistoryTable.fillHole(hole.id, fillType: fillType, tagMask: tagMask, messages: messages, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        for (peerId, operations) in operationsByPeerId {
            if self.currentOperationsByPeerId[peerId] == nil {
                self.currentOperationsByPeerId[peerId] = operations
            } else {
                self.currentOperationsByPeerId[peerId]!.append(contentsOf: operations)
            }
            
            var filledMessageIndices: [MessageIndex: HoleFillDirection] = [:]
            for operation in operations {
                switch operation {
                    case let .InsertHole(hole):
                        filledMessageIndices[hole.maxIndex] = fillType.direction
                    case let .InsertMessage(message):
                        filledMessageIndices[MessageIndex(message)] = fillType.direction
                    default:
                        break
                }
            }
            
            if !filledMessageIndices.isEmpty {
                if self.currentFilledHolesByPeerId[peerId] == nil {
                    self.currentFilledHolesByPeerId[peerId] = filledMessageIndices
                } else {
                    for (messageIndex, direction) in filledMessageIndices {
                        self.currentFilledHolesByPeerId[peerId]![messageIndex] = direction
                    }
                }
            }
            
            if self.currentRemovedHolesByPeerId[peerId] == nil {
                self.currentRemovedHolesByPeerId[peerId] = [hole.maxIndex: fillType.direction]
            } else {
                self.currentRemovedHolesByPeerId[peerId]![hole.maxIndex] = fillType.direction
            }
        }
    }
    
    fileprivate func fillMultipleHoles(_ hole: MessageHistoryHole, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        self.messageHistoryTable.fillMultipleHoles(mainHoleId: hole.id, fillType: fillType, tagMask: tagMask, messages: messages, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        for (peerId, operations) in operationsByPeerId {
            if self.currentOperationsByPeerId[peerId] == nil {
                self.currentOperationsByPeerId[peerId] = operations
            } else {
                self.currentOperationsByPeerId[peerId]!.append(contentsOf: operations)
            }
            
            var filledMessageIndices: [MessageIndex: HoleFillDirection] = [:]
            for operation in operations {
                switch operation {
                case let .InsertHole(hole):
                    filledMessageIndices[hole.maxIndex] = fillType.direction
                case let .InsertMessage(message):
                    filledMessageIndices[MessageIndex(message)] = fillType.direction
                default:
                    break
                }
            }
            
            if !filledMessageIndices.isEmpty {
                if self.currentFilledHolesByPeerId[peerId] == nil {
                    self.currentFilledHolesByPeerId[peerId] = filledMessageIndices
                } else {
                    for (messageIndex, direction) in filledMessageIndices {
                        self.currentFilledHolesByPeerId[peerId]![messageIndex] = direction
                    }
                }
            }
            
            if self.currentRemovedHolesByPeerId[peerId] == nil {
                self.currentRemovedHolesByPeerId[peerId] = [hole.maxIndex: fillType.direction]
            } else {
                self.currentRemovedHolesByPeerId[peerId]![hole.maxIndex] = fillType.direction
            }
        }
    }
    
    fileprivate func replaceChatListHole(_ index: MessageIndex, hole: ChatListHole?) {
        self.currentReplaceChatListHoles.append((index, hole))
    }
    
    fileprivate func deleteMessages(_ messageIds: [MessageId]) {
        self.messageHistoryTable.removeMessages(messageIds, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func clearHistory(_ peerId: PeerId) {
        self.messageHistoryTable.clearHistory(peerId: peerId, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func resetIncomingReadStates(_ states: [PeerId: [MessageId.Namespace: PeerReadState]]) {
        self.messageHistoryTable.resetIncomingReadStates(states, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
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
        return self.messageHistoryTable.applyInteractiveMaxReadIndex(messageIndex, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func applyOutgoingReadMaxIndex(_ messageIndex: MessageIndex) -> [MessageId] {
        return self.messageHistoryTable.applyOutgoingReadMaxIndex(messageIndex, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func fetchEarlierHistoryEntries(_ peerId: PeerId, index: MessageIndex?, count: Int, tagMask: MessageTags? = nil) -> [MutableMessageHistoryEntry] {
        let intermediateEntries: [IntermediateMessageHistoryEntry]
        if let tagMask = tagMask {
            intermediateEntries = self.messageHistoryTable.earlierEntries(tagMask, peerId: peerId, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        } else {
            intermediateEntries = self.messageHistoryTable.earlierEntries(peerId, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        }
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message, nil))
                case let .Hole(index):
                    entries.append(.HoleEntry(index, nil))
            }
        }
        return entries
    }
    
    private func fetchAroundHistoryEntries(_ index: MessageIndex, count: Int, tagMask: MessageTags? = nil) -> (entries: [MutableMessageHistoryEntry], lower: MutableMessageHistoryEntry?, upper: MutableMessageHistoryEntry?) {
        
        let intermediateEntries: [IntermediateMessageHistoryEntry]
        let intermediateLower: IntermediateMessageHistoryEntry?
        let intermediateUpper: IntermediateMessageHistoryEntry?
        
        if let tagMask = tagMask {
            (intermediateEntries, intermediateLower, intermediateUpper) = self.messageHistoryTable.entriesAround(tagMask, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        } else {
            (intermediateEntries, intermediateLower, intermediateUpper) = self.messageHistoryTable.entriesAround(index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        }
        
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message, nil))
                case let .Hole(index):
                    entries.append(.HoleEntry(index, nil))
            }
        }
        
        var lower: MutableMessageHistoryEntry?
        if let intermediateLower = intermediateLower {
            switch intermediateLower {
                case let .Message(message):
                    lower = .IntermediateMessageEntry(message, nil)
                case let .Hole(index):
                    lower = .HoleEntry(index, nil)
            }
        }
        
        var upper: MutableMessageHistoryEntry?
        if let intermediateUpper = intermediateUpper {
            switch intermediateUpper {
                case let .Message(message):
                    upper = .IntermediateMessageEntry(message, nil)
                case let .Hole(index):
                    upper = .HoleEntry(index, nil)
            }
        }
        
        if let tagMask = tagMask {
            return addLocationsToMessageHistoryViewEntries(tagMask: tagMask, earlier: lower, later: upper, entries: entries)
        } else {
            return (entries: entries, lower: lower, upper: upper)
        }
    }
    
    private func fetchLaterHistoryEntries(_ peerId: PeerId, index: MessageIndex?, count: Int, tagMask: MessageTags? = nil) -> [MutableMessageHistoryEntry] {
        let intermediateEntries: [IntermediateMessageHistoryEntry]
        if let tagMask = tagMask {
            intermediateEntries = self.messageHistoryTable.laterEntries(tagMask, peerId: peerId, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        } else {
            intermediateEntries = self.messageHistoryTable.laterEntries(peerId, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        }
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
            case let .Message(message):
                entries.append(.IntermediateMessageEntry(message, nil))
            case let .Hole(index):
                entries.append(.HoleEntry(index, nil))
            }
        }
        return entries
    }
    
    private func fetchAroundChatEntries(_ index: ChatListIndex, count: Int) -> (entries: [MutableChatListEntry], earlier: MutableChatListEntry?, later: MutableChatListEntry?) {
        let (intermediateEntries, intermediateLower, intermediateUpper) = self.chatListTable.entriesAround(index, messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable, count: count)
        var entries: [MutableChatListEntry] = []
        var lower: MutableChatListEntry?
        var upper: MutableChatListEntry?
        
        for entry in intermediateEntries {
            switch entry {
                case let .Message(index, message, embeddedState):
                    entries.append(.IntermediateMessageEntry(index, message, self.readStateTable.getCombinedState(index.messageIndex.id.peerId), self.peerNotificationSettingsTable.get(index.messageIndex.id.peerId), embeddedState))
                case let .Hole(hole):
                    entries.append(.HoleEntry(hole))
            }
        }
        
        if let intermediateLower = intermediateLower {
            switch intermediateLower {
                case let .Message(index, message, embeddedState):
                    lower = .IntermediateMessageEntry(index, message, self.readStateTable.getCombinedState(index.messageIndex.id.peerId), self.peerNotificationSettingsTable.get(index.messageIndex.id.peerId), embeddedState)
                case let .Hole(hole):
                    lower = .HoleEntry(hole)
            }
        }
        
        if let intermediateUpper = intermediateUpper {
            switch intermediateUpper {
                case let .Message(index, message, embeddedState):
                    upper = .IntermediateMessageEntry(index, message, self.readStateTable.getCombinedState(index.messageIndex.id.peerId), self.peerNotificationSettingsTable.get(index.messageIndex.id.peerId), embeddedState)
                case let .Hole(hole):
                    upper = .HoleEntry(hole)
            }
        }
        
        return (entries, lower, upper)
    }
    
    private func fetchEarlierChatEntries(_ index: ChatListIndex?, count: Int) -> [MutableChatListEntry] {
        let intermediateEntries = self.chatListTable.earlierEntries(index, messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable, count: count)
        var entries: [MutableChatListEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(index, message, embeddedState):
                    entries.append(.IntermediateMessageEntry(index, message, self.readStateTable.getCombinedState(index.messageIndex.id.peerId), self.peerNotificationSettingsTable.get(index.messageIndex.id.peerId), embeddedState))
                case let .Hole(hole):
                    entries.append(.HoleEntry(hole))
            }
        }
        return entries
    }
    
    private func fetchLaterChatEntries(_ index: ChatListIndex?, count: Int) -> [MutableChatListEntry] {
        let intermediateEntries = self.chatListTable.laterEntries(index, messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable, count: count)
        var entries: [MutableChatListEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(index, message, embeddedState):
                    entries.append(.IntermediateMessageEntry(index, message, self.readStateTable.getCombinedState(index.messageIndex.id.peerId), self.peerNotificationSettingsTable.get(index.messageIndex.id.peerId), embeddedState))
                case let .Hole(index):
                    entries.append(.HoleEntry(index))
            }
        }
        return entries
    }
    
    private func fetchAnchorIndex(_ id: MessageId) -> MessageHistoryAnchorIndex? {
        return self.messageHistoryTable.anchorIndex(id)
    }
    
    fileprivate func renderIntermediateMessage(_ message: IntermediateMessage) -> Message {
        return self.messageHistoryTable.renderMessage(message, peerTable: self.peerTable)
    }
    
    private func afterBegin() {
        let currentTransactionStateVersion = self.metadataTable.transactionStateVersion()
        if currentTransactionStateVersion != self.transactionStateVersion {
            for table in self.tables {
                table.clearMemoryCache()
            }
            self.viewTracker.refreshViewsDueToExternalTransaction(fetchAroundChatEntries: self.fetchAroundChatEntries, fetchAroundHistoryEntries: self.fetchAroundHistoryEntries, fetchUnsentMessageIds: {
                return self.messageHistoryUnsentTable!.get()
            }, fetchSynchronizePeerReadStateOperations: {
                return self.synchronizeReadStateTable!.get(getCombinedPeerReadState: { peerId in
                    return self.readStateTable.getCombinedState(peerId)
                })
            })
            self.transactionStateVersion = currentTransactionStateVersion
            
            self.masterClientId.set(.single(self.metadataTable.masterClientId()))
        }
    }
    
    private func beforeCommit() -> (updatedTransactionStateVersion: Int64?, updatedMasterClientId: Int64?) {
        var chatListOperations: [ChatListOperation] = []
        self.chatListTable.replay(historyOperationsByPeerId: self.currentOperationsByPeerId, updatedPeerChatListEmbeddedStates: currentUpdatedPeerChatListEmbeddedStates, updatedChatListInclusions: self.currentUpdatedChatListInclusions, messageHistoryTable: self.messageHistoryTable, peerChatInterfaceStateTable: self.peerChatInterfaceStateTable, operations: &chatListOperations)
        for (index, hole) in self.currentReplaceChatListHoles {
            self.chatListTable.replaceHole(index, hole: hole, operations: &chatListOperations)
        }
        
        self.peerChatTopTaggedMessageIdsTable.replay(historyOperationsByPeerId: self.currentOperationsByPeerId)
        
        let transactionUnreadCountDeltas = self.readStateTable.transactionUnreadCountDeltas()
        let transactionParticipationInTotalUnreadCountUpdates = self.peerNotificationSettingsTable.transactionParticipationInTotalUnreadCountUpdates()
        self.chatListIndexTable.commitWithTransactionUnreadCountDeltas(transactionUnreadCountDeltas, transactionParticipationInTotalUnreadCountUpdates: transactionParticipationInTotalUnreadCountUpdates, getPeer: { peerId in
            return self.peerTable.get(peerId)
        }, updatedTotalUnreadCount: &self.currentUpdatedTotalUnreadCount)
        
        let transaction = PostboxTransaction(currentUpdatedState: self.currentUpdatedState, currentOperationsByPeerId: self.currentOperationsByPeerId, peerIdsWithFilledHoles: self.currentFilledHolesByPeerId, removedHolesByPeerId: self.currentRemovedHolesByPeerId, chatListOperations: chatListOperations, currentUpdatedPeers: self.currentUpdatedPeers, currentUpdatedPeerNotificationSettings: self.currentUpdatedPeerNotificationSettings, currentUpdatedCachedPeerData: self.currentUpdatedCachedPeerData, currentUpdatedPeerPresences: currentUpdatedPeerPresences, currentUpdatedPeerChatListEmbeddedStates: self.currentUpdatedPeerChatListEmbeddedStates, currentUpdatedTotalUnreadCount: self.currentUpdatedTotalUnreadCount, peerIdsWithUpdatedUnreadCounts: Set(transactionUnreadCountDeltas.keys), currentPeerMergedOperationLogOperations: self.currentPeerMergedOperationLogOperations, currentTimestampBasedMessageAttributesOperations: self.currentTimestampBasedMessageAttributesOperations, unsentMessageOperations: self.currentUnsentOperations, updatedSynchronizePeerReadStateOperations: self.currentUpdatedSynchronizeReadStateOperations, currentPreferencesOperations: self.currentPreferencesOperations, currentOrderedItemListOperations: self.currentOrderedItemListOperations, updatedMedia: self.currentUpdatedMedia, replaceContactPeerIds: self.currentReplacedContactPeerIds, currentUpdatedMasterClientId: currentUpdatedMasterClientId)
        var updatedTransactionState: Int64?
        var updatedMasterClientId: Int64?
        if !transaction.isEmpty {
            self.viewTracker.updateViews(transaction: transaction)
            self.transactionStateVersion = self.metadataTable.incrementTransactionStateVersion()
            updatedTransactionState = self.transactionStateVersion
            
            if let currentUpdatedMasterClientId = self.currentUpdatedMasterClientId {
                self.metadataTable.setMasterClientId(currentUpdatedMasterClientId)
                updatedMasterClientId = currentUpdatedMasterClientId
            }
        }
        
        self.currentUpdatedState = nil
        self.currentOperationsByPeerId.removeAll()
        self.currentUpdatedChatListInclusions.removeAll()
        self.currentFilledHolesByPeerId.removeAll()
        self.currentRemovedHolesByPeerId.removeAll()
        self.currentUpdatedPeers.removeAll()
        self.currentReplaceChatListHoles.removeAll()
        self.currentUnsentOperations.removeAll()
        self.currentUpdatedSynchronizeReadStateOperations.removeAll()
        self.currentUpdatedMedia.removeAll()
        self.currentReplacedContactPeerIds = nil
        self.currentUpdatedMasterClientId = nil
        self.currentUpdatedPeerNotificationSettings.removeAll()
        self.currentUpdatedCachedPeerData.removeAll()
        self.currentUpdatedPeerPresences.removeAll()
        self.currentUpdatedPeerChatListEmbeddedStates.removeAll()
        self.currentUpdatedTotalUnreadCount = nil
        self.currentPeerMergedOperationLogOperations.removeAll()
        self.currentTimestampBasedMessageAttributesOperations.removeAll()
        self.currentPreferencesOperations.removeAll()
        self.currentOrderedItemListOperations.removeAll()
        
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
    
    fileprivate func messageIdForGloballyUniqueMessageId(peerId: PeerId, id: Int64) -> MessageId? {
        return self.globallyUniqueMessageIdsTable.get(peerId: peerId, globallyUniqueId: id)
    }
    
    fileprivate func updatePeers(_ peers: [Peer], update: (Peer?, Peer) -> Peer?) {
        for peer in peers {
            let currentPeer = self.peerTable.get(peer.id)
            if let updatedPeer = update(currentPeer, peer) {
                self.peerTable.set(updatedPeer)
                self.currentUpdatedPeers[updatedPeer.id] = updatedPeer
                if currentPeer?.indexName != updatedPeer.indexName {
                    self.peerNameIndexTable.markPeerNameUpdated(peerId: peer.id, name: updatedPeer.indexName)
                }
            }
        }
    }
    
    fileprivate func getPeerChatListInclusion(_ id: PeerId) -> PeerChatListInclusion {
        if let inclusion = self.currentUpdatedChatListInclusions[id] {
            return inclusion
        } else {
            return self.chatListIndexTable.get(id).inclusion
        }
    }
    
    fileprivate func updatePeerChatListInclusion(_ id: PeerId, inclusion: PeerChatListInclusion) {
        self.chatListTable.updateInclusion(peerId: id, updatedChatListInclusions: &self.currentUpdatedChatListInclusions, { _ in
            return inclusion
        })
    }
    
    fileprivate func setPinnedPeerIds(_ peerIds: [PeerId]) {
        self.chatListTable.setPinnedPeerIds(peerIds: peerIds, updatedChatListInclusions: &self.currentUpdatedChatListInclusions)
    }
    
    fileprivate func updatePeerNotificationSettings(_ notificationSettings: [PeerId: PeerNotificationSettings]) {
        for (peerId, settings) in notificationSettings {
            let currentSettings = self.peerNotificationSettingsTable.get(peerId)
            if currentSettings == nil || !(currentSettings!.isEqual(to: settings)) {
                self.peerNotificationSettingsTable.set(id: peerId, settings: settings)
                self.currentUpdatedPeerNotificationSettings[peerId] = settings
            }
        }
    }
    
    fileprivate func resetAllPeerNotificationSettings(_ notificationSettings: PeerNotificationSettings) {
        for peerId in self.peerNotificationSettingsTable.resetAll(to: notificationSettings) {
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
    
    fileprivate func updatePeerPresences(_ peerPresences: [PeerId: PeerPresence]) {
        for (peerId, presence) in peerPresences {
            let currentPresence = self.peerPresenceTable.get(peerId)
            if currentPresence == nil || !(currentPresence!.isEqual(to: presence)) {
                self.peerPresenceTable.set(id: peerId, presence: presence)
                self.currentUpdatedPeerPresences[peerId] = presence
            }
        }
    }
    
    fileprivate func updatePeerChatInterfaceState(_ id: PeerId, update: (PeerChatInterfaceState?) -> (PeerChatInterfaceState?)) {
        let updatedState = update(self.peerChatInterfaceStateTable.get(id))
        let (_, updatedEmbeddedState) = self.peerChatInterfaceStateTable.set(id, state: updatedState)
        if updatedEmbeddedState {
            self.currentUpdatedPeerChatListEmbeddedStates[id] = updatedState?.chatListEmbeddedState
        }
    }
    
    fileprivate func replaceContactPeerIds(_ peerIds: Set<PeerId>) {
        self.contactsTable.replace(peerIds)
        
        self.currentReplacedContactPeerIds = peerIds
    }
    
    fileprivate func replaceRecentPeerIds(_ peerIds: [PeerId]) {
        self.peerRatingTable.replace(items: peerIds)
    }
    
    fileprivate func updateMessage(_ id: MessageId, update: (Message) -> StoreMessage) {
        if let indexEntry = self.messageHistoryIndexTable.get(id), let intermediateMessage = self.messageHistoryTable.getMessage(indexEntry.index) {
            let message = self.renderIntermediateMessage(intermediateMessage)
            self.messageHistoryTable.updateMessage(id, message: update(message), operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        }
    }
    
    fileprivate func offsetPendingMessagesTimestamps(lowerBound: MessageId, timestamp: Int32) {
        self.messageHistoryTable.offsetPendingMessagesTimestamps(lowerBound: lowerBound, timestamp: timestamp, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func updateMedia(_ id: MediaId, update: Media?) {
        self.messageHistoryTable.updateMedia(id, media: update, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia)
    }
    
    fileprivate func replaceItemCollections(namespace: ItemCollectionId.Namespace, itemCollections: [(ItemCollectionId, ItemCollectionInfo, [ItemCollectionItem])]) {
        var infos: [(ItemCollectionId, ItemCollectionInfo)] = []
        for (id, info, items) in itemCollections {
            infos.append(id, info)
            self.itemCollectionItemTable.replaceItems(collectionId: id, items: items)
        }
        self.itemCollectionInfoTable.replaceInfos(namespace: namespace, infos: infos)
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
        return self.messageHistoryTable.findMessageId(peerId: peerId, namespace: namespace, timestamp: timestamp)
    }
    
    fileprivate func putItemCacheEntry(id: ItemCacheEntryId, entry: Coding, collectionSpec: ItemCacheCollectionSpec) {
        self.itemCacheTable.put(id: id, entry: entry, metaTable: self.itemCacheMetaTable)
    }
    
    fileprivate func retrieveItemCacheEntry(id: ItemCacheEntryId) -> Coding? {
        return self.itemCacheTable.retrieve(id: id, metaTable: self.itemCacheMetaTable)
    }
    
    public func modify<T>(userInteractive: Bool = false, _ f: @escaping(Modifier) -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            let f: () -> Void = {
                self.valueBox.begin()
                self.afterBegin()
                let result = f(Modifier(postbox: self))
                let (updatedTransactionState, updatedMasterClientId) = self.beforeCommit()
                self.valueBox.commit()
                
                subscriber.putNext(result)
                subscriber.putCompletion()
                
                if updatedTransactionState != nil || updatedMasterClientId != nil {
                    //self.pipeNotifier.notify()
                }
                
                if let updatedMasterClientId = updatedMasterClientId {
                    self.masterClientId.set(.single(updatedMasterClientId))
                }
            }
            if userInteractive {
                self.queue.justDispatchWithQoS(qos: DispatchQoS.userInteractive, f)
            } else {
                self.queue.justDispatch(f)
            }
            return EmptyDisposable
        }
    }
    
    public func aroundUnreadMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, topTaggedMessageIdNamespaces: Set<MessageId.Namespace>, tagMask: MessageTags? = nil, additionalData: [AdditionalMessageHistoryViewData]) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        return self.modify(userInteractive: true, { modifier -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> in
            var index = MessageHistoryAnchorIndex(index: MessageIndex.upperBound(peerId: peerId), exact: true)
            if let maxReadIndex = self.messageHistoryTable.maxReadIndex(peerId) {
                index = maxReadIndex
            }
            return self.syncAroundMessageHistoryViewForPeerId(peerId, index: index.index, count: count, anchorIndex: index, unreadIndex: index.index, fixedCombinedReadState: nil, topTaggedMessageIdNamespaces: topTaggedMessageIdNamespaces, tagMask: tagMask, additionalData: additionalData)
        }) |> switchToLatest
    }
    
    public func aroundIdMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, messageId: MessageId, topTaggedMessageIdNamespaces: Set<MessageId.Namespace>, tagMask: MessageTags? = nil, additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        return self.modify { modifier -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> in
            var index = MessageHistoryAnchorIndex(index: MessageIndex.upperBound(peerId: peerId), exact: true)
            if let anchorIndex = self.messageHistoryTable.anchorIndex(messageId) {
                index = anchorIndex
            }
            return self.syncAroundMessageHistoryViewForPeerId(peerId, index: index.index, count: count, anchorIndex: index, unreadIndex: index.index, fixedCombinedReadState: nil, topTaggedMessageIdNamespaces: topTaggedMessageIdNamespaces, tagMask: tagMask, additionalData: additionalData)
        } |> switchToLatest
    }
    
    public func aroundMessageHistoryViewForPeerId(_ peerId: PeerId, index: MessageIndex, count: Int, anchorIndex: MessageIndex, fixedCombinedReadState: CombinedPeerReadState?, topTaggedMessageIdNamespaces: Set<MessageId.Namespace>, tagMask: MessageTags? = nil, additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        return self.modify { modifier -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> in
            return self.syncAroundMessageHistoryViewForPeerId(peerId, index: index, count: count, anchorIndex: MessageHistoryAnchorIndex(index: anchorIndex, exact: true), unreadIndex: nil, fixedCombinedReadState: fixedCombinedReadState, topTaggedMessageIdNamespaces: topTaggedMessageIdNamespaces, tagMask: tagMask, additionalData: additionalData)
        } |> switchToLatest
    }
    
    private func addLocationsToMessageHistoryViewEntries(tagMask: MessageTags, earlier: MutableMessageHistoryEntry?, later: MutableMessageHistoryEntry?, entries: [MutableMessageHistoryEntry]) -> ([MutableMessageHistoryEntry], MutableMessageHistoryEntry?, MutableMessageHistoryEntry?) {
        if let firstEntry = entries.first {
            if let location = self.messageHistoryTagsTable.entryLocation(at: firstEntry.index, tagMask: tagMask) {
                let mappedEarlier = earlier?.updatedLocation(location.predecessor)
                var mappedEntries: [MutableMessageHistoryEntry] = []
                var previousLocation: MessageHistoryEntryLocation?
                for i in 0 ..< entries.count {
                    if i == 0 {
                        mappedEntries.append(entries[i].updatedLocation(location))
                        previousLocation = location
                    } else {
                        previousLocation = previousLocation?.successor
                        mappedEntries.append(entries[i].updatedLocation(previousLocation))
                    }
                }
                previousLocation = previousLocation?.successor
                let mappedLater = later?.updatedLocation(previousLocation)
                return (mappedEntries, mappedEarlier, mappedLater)
            } else {
                return (entries, earlier, later)
            }
        } else {
            return (entries, earlier, later)
        }
    }
    
    private func syncAroundMessageHistoryViewForPeerId(_ peerId: PeerId, index: MessageIndex, count: Int, anchorIndex: MessageHistoryAnchorIndex, unreadIndex: MessageIndex?, fixedCombinedReadState: CombinedPeerReadState?, topTaggedMessageIdNamespaces: Set<MessageId.Namespace>, tagMask: MessageTags?, additionalData: [AdditionalMessageHistoryViewData]) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        let startTime = CFAbsoluteTimeGetCurrent()
        let (entries, earlier, later) = self.fetchAroundHistoryEntries(index, count: count, tagMask: tagMask)
        print("aroundMessageHistoryViewForPeerId fetchAroundHistoryEntries \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        
        var topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?] = [:]
        for namespace in topTaggedMessageIdNamespaces {
            if let messageId = self.peerChatTopTaggedMessageIdsTable.get(peerId: peerId, namespace: namespace) {
                if let indexEntry = self.messageHistoryIndexTable.get(messageId), case let .Message(index) = indexEntry {
                    if let message = self.messageHistoryTable.getMessage(index) {
                        topTaggedMessages[namespace] = MessageHistoryTopTaggedMessage.intermediate(message)
                    } else {
                        assertionFailure()
                    }
                } else {
                    assertionFailure()
                }
            } else {
                let item: MessageHistoryTopTaggedMessage? = nil
                topTaggedMessages[namespace] = item
            }
        }
        
        var additionalDataEntries: [AdditionalMessageHistoryViewDataEntry] = []
        for data in additionalData {
            switch data {
                case let .cachedPeerData(peerId):
                    additionalDataEntries.append(.cachedPeerData(peerId, self.cachedPeerDataTable.get(peerId)))
            }
        }
        
        let mutableView = MutableMessageHistoryView(id: MessageHistoryViewId(peerId: peerId, id: self.takeNextViewId()), anchorIndex: anchorIndex, combinedReadState: fixedCombinedReadState ?? self.readStateTable.getCombinedState(peerId), earlier: earlier, entries: entries, later: later, tagMask: tagMask, count: count, topTaggedMessages: topTaggedMessages, additionalDatas: additionalDataEntries)
        mutableView.render(self.renderIntermediateMessage)
        
        let initialUpdateType: ViewUpdateType
        if let unreadIndex = unreadIndex {
            initialUpdateType = .InitialUnread(unreadIndex)
        } else {
            initialUpdateType = .Generic
        }
        
        let (index, signal) = self.viewTracker.addMessageHistoryView(peerId, view: mutableView)
        
        let initialData = self.initialMessageHistoryData(peerId: peerId)
        
        return (.single((MessageHistoryView(mutableView), initialUpdateType, initialData))
            |> then(signal |> map { ($0.0, $0.1, nil) }))
            |> afterDisposed { [weak self] in
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeMessageHistoryView(peerId, index: index)
                    }
                }
            }
    }
    
    private func initialMessageHistoryData(peerId: PeerId) -> InitialMessageHistoryData {
        return InitialMessageHistoryData(peer: self.peerTable.get(peerId), chatInterfaceState: self.peerChatInterfaceStateTable.get(peerId))
    }
    
    public func messageIndexAtId(_ id: MessageId) -> Signal<MessageIndex?, NoError> {
        return self.modify { modifier -> Signal<MessageIndex?, NoError> in
            if let entry = self.messageHistoryIndexTable.get(id), case let .Message(index) = entry {
                return .single(index)
            } else if let _ = self.messageHistoryIndexTable.holeContainingId(id) {
                return .single(nil)
            } else {
                return .single(nil)
            }
        } |> switchToLatest
    }
    
    public func messageAtId(_ id: MessageId) -> Signal<Message?, NoError> {
        return self.modify { modifier -> Signal<Message?, NoError> in
            if let entry = self.messageHistoryIndexTable.get(id), case let .Message(index) = entry {
                if let message = self.messageHistoryTable.getMessage(index) {
                    return .single(self.renderIntermediateMessage(message))
                } else {
                    return .single(nil)
                }
            } else if let _ = self.messageHistoryIndexTable.holeContainingId(id) {
                return .single(nil)
            } else {
                return .single(nil)
            }
        } |> switchToLatest
    }
    
    public func messagesAtIds(_ ids: [MessageId]) -> Signal<[Message], NoError> {
        return self.modify { modifier -> Signal<[Message], NoError> in
            var messages: [Message] = []
            for id in ids {
                if let entry = self.messageHistoryIndexTable.get(id), case let .Message(index) = entry {
                    if let message = self.messageHistoryTable.getMessage(index) {
                        messages.append(self.renderIntermediateMessage(message))
                    }
                }
            }
            return .single(messages)
        } |> switchToLatest
    }
    
    public func tailChatListView(_ count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return self.aroundChatListView(ChatListIndex.absoluteUpperBound, count: count)
    }
    
    public func aroundChatListView(_ index: ChatListIndex, count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return self.modify { modifier -> Signal<(ChatListView, ViewUpdateType), NoError> in
            let (entries, earlier, later) = self.fetchAroundChatEntries(index, count: count)
            
            let mutableView = MutableChatListView(earlier: earlier, entries: entries, later: later, count: count)
            mutableView.render(self.renderIntermediateMessage, getPeer: { id in
                return self.peerTable.get(id)
            }, getPeerNotificationSettings: { self.peerNotificationSettingsTable.get($0) })
            
            let (index, signal) = self.viewTracker.addChatListView(mutableView)
            
            return (.single((ChatListView(mutableView), .Generic))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeChatListView(index)
                        }
                    }
                }
        } |> switchToLatest
    }
    
    public func contactPeerIdsView() -> Signal<ContactPeerIdsView, NoError> {
        return self.modify { modifier -> Signal<ContactPeerIdsView, NoError> in
            let view = MutableContactPeerIdsView(peerIds: self.contactsTable.get())
            let (index, signal) = self.viewTracker.addContactPeerIdsView(view)
            
            return (.single(ContactPeerIdsView(view))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeContactPeerIdsView(index)
                        }
                    }
            }
        } |> switchToLatest
    }
    
    public func contactPeersView(accountPeerId: PeerId) -> Signal<ContactPeersView, NoError> {
        return self.modify { modifier -> Signal<ContactPeersView, NoError> in
            var peers: [PeerId: Peer] = [:]
            var peerPresences: [PeerId: PeerPresence] = [:]
            
            for peerId in self.contactsTable.get() {
                if let peer = self.peerTable.get(peerId) {
                    peers[peerId] = peer
                }
                if let presence = self.peerPresenceTable.get(peerId) {
                    peerPresences[peerId] = presence
                }
            }
            
            let view = MutableContactPeersView(peers: peers, peerPresences: peerPresences, accountPeer: self.peerTable.get(accountPeerId))
            let (index, signal) = self.viewTracker.addContactPeersView(view)
            
            return (.single(ContactPeersView(view))
                |> then(signal))
                |> afterDisposed {
                    [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeContactPeersView(index)
                        }
                    }
                }
        } |> switchToLatest
    }
    
    public func searchContacts(query: String) -> Signal<[Peer], NoError> {
        return self.modify { modifier -> Signal<[Peer], NoError> in
            let (_, contactPeerIds) = self.peerNameIndexTable.matchingPeerIds(tokens: (regular: stringIndexTokens(query, transliteration: .none), transliterated: stringIndexTokens(query, transliteration: .transliterated)), categories: [.contacts], chatListIndexTable: self.chatListIndexTable, contactTable: self.contactsTable)
            
            var contactPeers: [Peer] = []
            for peerId in contactPeerIds {
                if let peer = self.peerTable.get(peerId) {
                    contactPeers.append(peer)
                }
            }
            
            contactPeers.sort(by: { $0.indexName.indexName(.lastNameFirst) < $1.indexName.indexName(.lastNameFirst) })
            return .single(contactPeers)
        } |> switchToLatest
    }
    
    public func searchPeers(query: String) -> Signal<[Peer], NoError> {
        return self.modify { modifier -> Signal<[Peer], NoError> in
            var peerIds = Set<PeerId>()
            var chatPeers: [Peer] = []
            
            let (chatPeerIds, contactPeerIds) = self.peerNameIndexTable.matchingPeerIds(tokens: (regular: stringIndexTokens(query, transliteration: .none), transliterated: stringIndexTokens(query, transliteration: .transliterated)), categories: [.chats, .contacts], chatListIndexTable: self.chatListIndexTable, contactTable: self.contactsTable)
            
            for peerId in chatPeerIds {
                if let peer = self.peerTable.get(peerId) {
                    chatPeers.append(peer)
                    peerIds.insert(peerId)
                }
            }
            
            var contactPeers: [Peer] = []
            for peerId in contactPeerIds {
                if !peerIds.contains(peerId) {
                    if let peer = self.peerTable.get(peerId) {
                        contactPeers.append(peer)
                    }
                }
            }
            
            contactPeers.sort(by: { $0.indexName.indexName(.lastNameFirst) < $1.indexName.indexName(.lastNameFirst) })
            return .single(chatPeers + contactPeers)
        } |> switchToLatest
    }
    
    public func peerView(id: PeerId) -> Signal<PeerView, NoError> {
        return self.modify { modifier -> Signal<PeerView, NoError> in
            let view = MutablePeerView(peerId: id, notificationSettings: self.peerNotificationSettingsTable.get(id), cachedData: self.cachedPeerDataTable.get(id), peerIsContact: self.contactsTable.isContact(peerId: id), getPeer: { self.peerTable.get($0) }, getPeerPresence: { self.peerPresenceTable.get($0) })
            let (index, signal) = self.viewTracker.addPeerView(view)
            
            return (.single(PeerView(view))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removePeerView(index)
                        }
                    }
            }
        } |> switchToLatest
    }
    
    public func multiplePeersView(_ ids: [PeerId]) -> Signal<MultiplePeersView, NoError> {
        return self.modify { modifier -> Signal<MultiplePeersView, NoError> in
            let view = MutableMultiplePeersView(peerIds: ids, getPeer: { self.peerTable.get($0) }, getPeerPresence: { self.peerPresenceTable.get($0) })
            let (index, signal) = self.viewTracker.addMultiplePeersView(view)
            
            return (.single(MultiplePeersView(view))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeMultiplePeersView(index)
                        }
                    }
            }
            } |> switchToLatest
    }
    
    public func loadedPeerWithId(_ id: PeerId) -> Signal<Peer, NoError> {
        return self.modify { modifier -> Signal<Peer, NoError> in
            if let peer = self.peerTable.get(id) {
                return .single(peer)
            } else {
                return .never()
            }
        } |> switchToLatest
    }
    
    public func unreadMessageCountsView(items: [UnreadMessageCountsItem]) -> Signal<UnreadMessageCountsView, NoError> {
        return self.modify { modifier -> Signal<UnreadMessageCountsView, NoError> in
            let entries: [UnreadMessageCountsItemEntry] = items.map { item in
                switch item {
                    case .total:
                        return .total(self.messageHistoryMetadataTable.getChatListTotalUnreadCount())
                    case let .peer(peerId):
                        var count: Int32 = 0
                        if let combinedState = self.readStateTable.getCombinedState(peerId) {
                            count = combinedState.count
                        }
                        return .peer(peerId, count)
                }
            }
            let view = MutableUnreadMessageCountsView(entries: entries)
            let (index, signal) = self.viewTracker.addUnreadMessageCountsView(view)
            
            return (.single(UnreadMessageCountsView(view))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeUnreadMessageCountsView(index)
                        }
                    }
            }
        } |> switchToLatest
    }
    
    public func updateMessageHistoryViewVisibleRange(_ id: MessageHistoryViewId, earliestVisibleIndex: MessageIndex, latestVisibleIndex: MessageIndex) {
        let _ = self.modify({ modifier -> Void in
            self.viewTracker.updateMessageHistoryViewVisibleRange(id, earliestVisibleIndex: earliestVisibleIndex, latestVisibleIndex: latestVisibleIndex)
        }).start()
    }
    
    public func recentPeers() -> Signal<[Peer], NoError> {
        return self.modify { modifier -> Signal<[Peer], NoError> in
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
        return self.modify { modifier -> Signal<PostboxStateView, NoError> in
            let mutableView = MutablePostboxStateView(state: self.getState())
            
            let (index, signal) = self.viewTracker.addPostboxStateView(mutableView)
            
            return (.single(PostboxStateView(mutableView))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removePostboxStateView(index)
                        }
                    }
            }
        } |> switchToLatest
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
        return self.modify { modifier -> Signal<ItemCollectionsView, NoError> in
            let itemListViews = orderedItemListCollectionIds.map { collectionId -> MutableOrderedItemListView in
                return MutableOrderedItemListView(collectionId: collectionId, getItems: { collectionId in
                    return self.orderedItemListTable.getItems(collectionId: collectionId)
                })
            }
            
            let mutableView = MutableItemCollectionsView(orderedItemListsViews: itemListViews, namespaces: namespaces, aroundIndex: aroundIndex, count: count, getInfos: { namespace in
                return self.itemCollectionInfoTable.getInfos(namespace: namespace)
            }, lowerCollectionId: { namespaceList, collectionId, collectionIndex in
                return self.itemCollectionInfoTable.lowerCollectionId(namespaceList: namespaceList, collectionId: collectionId, index: collectionIndex)
            }, lowerItems: { collectionId, itemIndex, count in
                return self.itemCollectionItemTable.lowerItems(collectionId: collectionId, itemIndex: itemIndex, count: count)
            }, higherCollectionId: { namespaceList, collectionId, collectionIndex in
                return self.itemCollectionInfoTable.higherCollectionId(namespaceList: namespaceList, collectionId: collectionId, index: collectionIndex)
            }, higherItems: { collectionId, itemIndex, count in
                return self.itemCollectionItemTable.higherItems(collectionId: collectionId, itemIndex: itemIndex, count: count)
            })
            
            let (index, signal) = self.viewTracker.addItemCollectionView(mutableView)
            
            return (.single(ItemCollectionsView(mutableView))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeItemCollectionView(index)
                        }
                    }
            }
        } |> switchToLatest
    }
    
    public func orderedItemListView(collectionId: Int32) -> Signal<OrderedItemListView, NoError> {
        return self.modify { modifier -> Signal<OrderedItemListView, NoError> in
            let mutableView = MutableOrderedItemListView(collectionId: collectionId, getItems: { collectionId in
                return self.orderedItemListTable.getItems(collectionId: collectionId)
            })
            
            let (index, signal) = self.viewTracker.addOrderedItemListView(mutableView)
            
            return (.single(OrderedItemListView(mutableView))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeOrderedItemListView(index)
                        }
                    }
            }
        } |> switchToLatest
    }
    
    public func mergedOperationLogView(tag: PeerOperationLogTag, limit: Int) -> Signal<PeerMergedOperationLogView, NoError> {
        return self.modify { modifier -> Signal<PeerMergedOperationLogView, NoError> in
            let view = MutablePeerMergedOperationLogView(tag: tag, limit: limit, getOperations: { tag, fromIndex, limit in
                return self.peerOperationLogTable.getMergedEntries(tag: tag, fromIndex: fromIndex, limit: limit)
            }, getTailIndex: { tag in
                return self.peerMergedOperationLogIndexTable.tailIndex(tag: tag)
            })
            let (index, signal) = self.viewTracker.addPeerMergedOperationLogView(view)
            
            return (.single(PeerMergedOperationLogView(view))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removePeerMergedOperationLogView(index)
                        }
                    }
            }
        } |> switchToLatest
    }
    
    public func timestampBasedMessageAttributesView(tag: UInt16) -> Signal<TimestampBasedMessageAttributesView, NoError> {
        return self.modify { modifier -> Signal<TimestampBasedMessageAttributesView, NoError> in
            let view = MutableTimestampBasedMessageAttributesView(tag: tag, getHead: { tag in
                return self.timestampBasedMessageAttributesTable.head(tag: tag)
            })
            let (index, signal) = self.viewTracker.addTimestampBasedMessageAttributesView(view)
            
            return (.single(TimestampBasedMessageAttributesView(view))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeTimestampBasedMessageAttributesView(index)
                        }
                    }
            }
        } |> switchToLatest
    }
    
    fileprivate func operationLogGetNextEntryLocalIndex(peerId: PeerId, tag: PeerOperationLogTag) -> Int32 {
        return self.peerOperationLogTable.getNextEntryLocalIndex(peerId: peerId, tag: tag)
    }
    
    fileprivate func operationLogAddEntry(peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: StorePeerOperationLogEntryTagLocalIndex, tagMergedIndex: StorePeerOperationLogEntryTagMergedIndex, contents: Coding) {
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
        return self.modify { modifier -> Signal<MessageView, NoError> in
            let view = MutableMessageView(messageId: messageId, message: modifier.getMessage(messageId))
            let (index, signal) = self.viewTracker.addMessageView(view)
            
            return (.single(MessageView(view))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeMessageView(index)
                        }
                    }
                }
        } |> switchToLatest
    }
    
    public func preferencesView(keys: [ValueBoxKey]) -> Signal<PreferencesView, NoError> {
        return self.modify { modifier -> Signal<PreferencesView, NoError> in
            let view = MutablePreferencesView(keys: Set(keys), get: { key in
                return self.preferencesTable.get(key: key)
            })
            let (index, signal) = self.viewTracker.addPreferencesView(view)
            
            return (.single(PreferencesView(view))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removePreferencesView(index)
                        }
                    }
            }
        } |> switchToLatest
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
    
    fileprivate func getOrderedListItemIds(collectionId: Int32) -> [MemoryBuffer] {
        return self.orderedItemListTable.getItemIds(collectionId: collectionId)
    }
    
    public func isMasterClient() -> Signal<Bool, NoError> {
        return self.modify { modifier -> Signal<Bool, NoError> in
            let sessionClientId = self.sessionClientId
            return self.masterClientId.get()
                |> distinctUntilChanged
                |> map({ $0 == sessionClientId })
        } |> switchToLatest
    }
    
    public func becomeMasterClient() {
        let _ = self.modify({ modifier in
            if self.metadataTable.masterClientId() != self.sessionClientId {
                self.currentUpdatedMasterClientId = self.sessionClientId
            }
        }).start()
    }
    
    public func clearCaches() {
        let _ = self.modify({ _ in
            for table in self.tables {
                table.clearMemoryCache()
            }
        }).start()
    }
}
