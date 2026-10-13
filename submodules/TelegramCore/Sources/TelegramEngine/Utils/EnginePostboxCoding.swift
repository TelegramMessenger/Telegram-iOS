import Postbox

public typealias EngineMemoryBuffer = MemoryBuffer
public typealias EnginePostboxDecoder = PostboxDecoder
public typealias EnginePostboxEncoder = PostboxEncoder
public typealias EngineAdaptedPostboxDecoder = AdaptedPostboxDecoder
public typealias EngineAdaptedPostboxEncoder = AdaptedPostboxEncoder
public typealias EngineItemCollectionId = ItemCollectionId
public typealias EngineStoryId = StoryId
public typealias EngineFetchResourceSourceType = FetchResourceSourceType
public typealias EngineMediaBoxFetchPriority = MediaBoxFetchPriority
public typealias EngineFetchResourceError = FetchResourceError
public typealias EngineCodableEntry = CodableEntry
public typealias EngineNoticeEntryKey = NoticeEntryKey
public typealias EngineChatListIndex = ChatListIndex
public typealias EngineTempBoxFile = TempBoxFile
public typealias EngineItemCollectionItemIndex = ItemCollectionItemIndex
public typealias EngineItemCollectionViewEntryIndex = ItemCollectionViewEntryIndex
public typealias EngineValueBoxEncryptionParameters = ValueBoxEncryptionParameters
public typealias EngineMessageAndThreadId = MessageAndThreadId
public typealias EnginePeerStoryStats = PeerStoryStats
public typealias EngineMessageHistoryAnchorIndex = MessageHistoryAnchorIndex
public typealias EngineMessageHistoryEntryLocation = MessageHistoryEntryLocation
public typealias EngineChatListTotalUnreadStateCategory = ChatListTotalUnreadStateCategory
public typealias EngineChatListTotalUnreadStateStats = ChatListTotalUnreadStateStats
public typealias EngineChatListTotalUnreadState = ChatListTotalUnreadState
public typealias EngineItemCacheEntryId = ItemCacheEntryId
public typealias EnginePeerSummaryCounterTags = PeerSummaryCounterTags
public typealias EngineHashFunctions = HashFunctions
public typealias EngineCachedMediaResourceRepresentationResult = CachedMediaResourceRepresentationResult
public typealias EngineMediaResourceDataFetchResult = MediaResourceDataFetchResult
public typealias EngineMediaResourceDataFetchError = MediaResourceDataFetchError
public typealias EngineMediaResourceStatus = MediaResourceStatus
public typealias EnginePostboxCoding = PostboxCoding
public typealias EngineRawItemCollectionInfo = ItemCollectionInfo
public typealias EngineRawItemCollectionInfoEntry = ItemCollectionInfoEntry
public typealias EngineRawItemCollectionItem = ItemCollectionItem
public typealias EngineRawMedia = Media
public typealias EngineRawMessage = Message
public typealias EngineRawPeer = Peer
public typealias EngineRawMediaResource = MediaResource
public typealias EngineRawMediaResourceId = MediaResourceId
public typealias EngineRawMediaResourceData = MediaResourceData
public typealias EngineRawMediaResourceDataFetchCopyLocalItem = MediaResourceDataFetchCopyLocalItem
public typealias EngineRawCachedMediaResourceRepresentation = CachedMediaResourceRepresentation
public typealias EngineCachedMediaRepresentationKeepDuration = CachedMediaRepresentationKeepDuration
public typealias EngineCachedPeerData = CachedPeerData
public typealias EngineMessageHistoryThreadData = MessageHistoryThreadData
public typealias EngineViewUpdateType = ViewUpdateType
public typealias EngineRawPeerPresence = PeerPresence
public typealias EnginePeerGroupId = PeerGroupId
public typealias EngineChatLocationInput = ChatLocationInput
public typealias EngineHistoryViewInputTag = HistoryViewInputTag
public typealias EngineInitialMessageHistoryData = InitialMessageHistoryData
public typealias EngineSimpleDictionary = SimpleDictionary
public typealias EngineRawValueBoxKey = ValueBoxKey
public typealias EngineRawMessageHistoryView = MessageHistoryView
public typealias EngineRawPeerView = PeerView
public typealias EngineRawMessageHistoryEntry = MessageHistoryEntry
public typealias EngineRawMutableMessageHistoryEntryAttributes = MutableMessageHistoryEntryAttributes
public typealias EngineMessageHistoryViewReadState = MessageHistoryViewReadState
public typealias EngineMessageIdNamespaces = MessageIdNamespaces
public typealias EngineHistoryViewInputAnchor = HistoryViewInputAnchor
public typealias EngineRawPostboxViewKey = PostboxViewKey
public typealias EngineRawPreferencesView = PreferencesView
public typealias EngineRawOrderedItemListView = OrderedItemListView
public typealias EngineRawUnreadMessageCountsView = UnreadMessageCountsView
public typealias EngineRawMessageHistoryThreadIndexView = MessageHistoryThreadIndexView
public typealias EngineRawCombinedReadStateView = CombinedReadStateView
public typealias EngineRawMessageHistoryThreadInfoView = MessageHistoryThreadInfoView
public typealias EngineRawBasicPeerView = BasicPeerView
public typealias EngineRawCachedPeerDataView = CachedPeerDataView
public typealias EngineRawUnreadMessageCountsItem = UnreadMessageCountsItem
public typealias EngineRawMessageHistorySavedMessagesIndexView = MessageHistorySavedMessagesIndexView
public typealias EngineRawChatInterfaceStateView = ChatInterfaceStateView

public func engineFileSize(_ path: String, useTotalFileAllocatedSize: Bool = false) -> Int64? {
    return fileSize(path, useTotalFileAllocatedSize: useTotalFileAllocatedSize)
}

public func engineAreMediaArraysEqual(_ lhs: [EngineRawMedia], _ rhs: [EngineRawMedia]) -> Bool {
    return areMediaArraysEqual(lhs, rhs)
}

public func enginePersistentHash32(_ string: String) -> Int32 {
    return persistentHash32(string)
}

public func engineDeclareEncodable(_ type: Any.Type, f: @escaping (EnginePostboxDecoder) -> EnginePostboxCoding) {
    declareEncodable(type, f: f)
}
