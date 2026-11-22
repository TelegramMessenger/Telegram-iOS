import Foundation
import Postbox
internal import TelegramApi
import SwiftSignalKit
import MtProtoKit

enum InternalStoryUpdate {
    case deleted(peerId: PeerId, id: Int32)
    case added(peerId: PeerId, item: Stories.StoredItem)
    case read(peerId: PeerId, maxId: Int32)
    case updatePinnedToTopList(peerId: PeerId, ids: [Int32])
    case updateAlbumMembership(peerId: PeerId, albumId: Int64, added: [Int32], removed: [Int32])
    case updateAlbumOrder(peerId: PeerId, albumId: Int64)
    case updateViews(peerId: PeerId, views: [Int32: Stories.Item.Views])
    case updateMyReaction(peerId: PeerId, id: Int32, reaction: MessageReaction.Reaction?)
}

enum InternalBotPreviewUpdate {
    case added(peerId: PeerId, language: String?, item: CachedUserData.BotPreview.Item)
    case deleted(peerId: PeerId, language: String?, ids: [MediaId])
}

public final class EngineStoryItem: Equatable {
    public final class Views: Equatable {
        public let seenCount: Int
        public let reactedCount: Int
        public var forwardCount: Int
        public let seenPeers: [EnginePeer]
        public let reactions: [MessageReaction]
        public let hasList: Bool
        
        public init(seenCount: Int, reactedCount: Int, forwardCount: Int, seenPeers: [EnginePeer], reactions: [MessageReaction], hasList: Bool) {
            self.seenCount = seenCount
            self.reactedCount = reactedCount
            self.forwardCount = forwardCount
            self.seenPeers = seenPeers
            self.reactions = reactions
            self.hasList = hasList
        }
        
        public static func ==(lhs: Views, rhs: Views) -> Bool {
            if lhs.seenCount != rhs.seenCount {
                return false
            }
            if lhs.reactedCount != rhs.reactedCount {
                return false
            }
            if lhs.forwardCount != rhs.forwardCount {
                return false
            }
            if lhs.seenPeers != rhs.seenPeers {
                return false
            }
            if lhs.reactions != rhs.reactions {
                return false
            }
            if lhs.hasList != rhs.hasList {
                return false
            }
            return true
        }
    }
    
    public enum ForwardInfo: Equatable {
        case known(peer: EnginePeer, storyId: Int32, isModified: Bool)
        case unknown(name: String, isModified: Bool)
    }
    
    public let id: Int32
    public let timestamp: Int32
    public let expirationTimestamp: Int32
    public let media: EngineMedia
    public let alternativeMediaList: [EngineMedia]
    public let mediaAreas: [MediaArea]
    public let text: String
    public let entities: [MessageTextEntity]
    public let views: Views?
    public let privacy: EngineStoryPrivacy?
    public let isPinned: Bool
    public let isExpired: Bool
    public let isPublic: Bool
    public let isPending: Bool
    public let isCloseFriends: Bool
    public let isContacts: Bool
    public let isSelectedContacts: Bool
    public let isForwardingDisabled: Bool
    public let isEdited: Bool
    public let isMy: Bool
    public let myReaction: MessageReaction.Reaction?
    public let forwardInfo: ForwardInfo?
    public let music: EngineMedia?
    public let author: EnginePeer?
    public let folderIds: [Int64]?
    
    public init(
        id: Int32,
        timestamp: Int32,
        expirationTimestamp: Int32,
        media: EngineMedia,
        alternativeMediaList: [EngineMedia],
        mediaAreas: [MediaArea],
        text: String,
        entities: [MessageTextEntity],
        views: Views?,
        privacy: EngineStoryPrivacy?,
        isPinned: Bool,
        isExpired: Bool,
        isPublic: Bool,
        isPending: Bool,
        isCloseFriends: Bool,
        isContacts: Bool,
        isSelectedContacts: Bool,
        isForwardingDisabled: Bool,
        isEdited: Bool,
        isMy: Bool,
        myReaction: MessageReaction.Reaction?,
        forwardInfo: ForwardInfo?,
        music: EngineMedia?,
        author: EnginePeer?,
        folderIds: [Int64]?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.expirationTimestamp = expirationTimestamp
        self.media = media
        self.alternativeMediaList = alternativeMediaList
        self.mediaAreas = mediaAreas
        self.text = text
        self.entities = entities
        self.views = views
        self.privacy = privacy
        self.isPinned = isPinned
        self.isExpired = isExpired
        self.isPublic = isPublic
        self.isPending = isPending
        self.isCloseFriends = isCloseFriends
        self.isContacts = isContacts
        self.isSelectedContacts = isSelectedContacts
        self.isForwardingDisabled = isForwardingDisabled
        self.isEdited = isEdited
        self.isMy = isMy
        self.myReaction = myReaction
        self.forwardInfo = forwardInfo
        self.music = music
        self.author = author
        self.folderIds = folderIds
    }
    
    public static func ==(lhs: EngineStoryItem, rhs: EngineStoryItem) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.expirationTimestamp != rhs.expirationTimestamp {
            return false
        }
        if lhs.media != rhs.media {
            return false
        }
        if lhs.alternativeMediaList != rhs.alternativeMediaList {
            return false
        }
        if lhs.mediaAreas != rhs.mediaAreas {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if lhs.views != rhs.views {
            return false
        }
        if lhs.privacy != rhs.privacy {
            return false
        }
        if lhs.isPinned != rhs.isPinned {
            return false
        }
        if lhs.isExpired != rhs.isExpired {
            return false
        }
        if lhs.isPublic != rhs.isPublic {
            return false
        }
        if lhs.isPending != rhs.isPending {
            return false
        }
        if lhs.isCloseFriends != rhs.isCloseFriends {
            return false
        }
        if lhs.isContacts != rhs.isContacts {
            return false
        }
        if lhs.isSelectedContacts != rhs.isSelectedContacts {
            return false
        }
        if lhs.isForwardingDisabled != rhs.isForwardingDisabled {
            return false
        }
        if lhs.isEdited != rhs.isEdited {
            return false
        }
        if lhs.isMy != rhs.isMy {
            return false
        }
        if lhs.myReaction != rhs.myReaction {
            return false
        }
        if lhs.forwardInfo != rhs.forwardInfo {
            return false
        }
        if lhs.music != rhs.music {
            return false
        }
        if lhs.author != rhs.author {
            return false
        }
        if lhs.folderIds != rhs.folderIds {
            return false
        }
        return true
    }
}

extension EngineStoryItem.ForwardInfo {
    var storedForwardInfo: Stories.Item.ForwardInfo {
        switch self {
        case let .known(peer, storyId, isModified):
            return .known(peerId: peer.id, storyId: storyId, isModified: isModified)
        case let .unknown(name, isModified):
            return .unknown(name: name, isModified: isModified)
        }
    }
}

public extension EngineStoryItem {
    func asStoryItem() -> Stories.Item {
        return Stories.Item(
            id: self.id,
            timestamp: self.timestamp,
            expirationTimestamp: self.expirationTimestamp,
            media: self.media._asMedia(),
            alternativeMediaList: self.alternativeMediaList.map { $0._asMedia() },
            mediaAreas: self.mediaAreas,
            text: self.text,
            entities: self.entities,
            views: self.views.flatMap { views in
                return Stories.Item.Views(
                    seenCount: views.seenCount,
                    reactedCount: views.reactedCount,
                    forwardCount: views.forwardCount,
                    seenPeerIds: views.seenPeers.map(\.id),
                    reactions: views.reactions,
                    hasList: views.hasList
                )
            },
            privacy: self.privacy.flatMap { privacy in
                return Stories.Item.Privacy(
                    base: privacy.base,
                    additionallyIncludePeers: privacy.additionallyIncludePeers
                )
            },
            isPinned: self.isPinned,
            isExpired: self.isExpired,
            isPublic: self.isPublic,
            isCloseFriends: self.isCloseFriends,
            isContacts: self.isContacts,
            isSelectedContacts: self.isSelectedContacts,
            isForwardingDisabled: self.isForwardingDisabled,
            isEdited: self.isEdited,
            isMy: self.isMy,
            myReaction: self.myReaction,
            forwardInfo: self.forwardInfo?.storedForwardInfo,
            music: self.music?._asMedia() as? TelegramMediaFile,
            authorId: self.author?.id,
            folderIds: self.folderIds
        )
    }
}

public final class StorySubscriptionsContext {
    private enum OpaqueStateMark: Equatable {
        case empty
        case value(String)
    }
    
    private struct TaskState {
        var isRefreshScheduled: Bool = false
        var isLoadMoreScheduled: Bool = false
    }
    
    private final class Impl {
        private let accountPeerId: PeerId
        private let queue: Queue
        private let postbox: Postbox
        private let network: Network
        private let isHidden: Bool
        
        private var taskState = TaskState()
        
        private var isLoading: Bool = false
        
        private var loadedStateMark: OpaqueStateMark?
        private var stateDisposable: Disposable?
        private let loadMoreDisposable = MetaDisposable()
        private let refreshTimerDisposable = MetaDisposable()
        
        init(queue: Queue, accountPeerId: PeerId, postbox: Postbox, network: Network, isHidden: Bool) {
            self.accountPeerId = accountPeerId
            self.queue = queue
            self.postbox = postbox
            self.network = network
            self.isHidden = isHidden
            
            self.taskState.isRefreshScheduled = true
            
            self.updateTasks()
        }
        
        deinit {
            self.stateDisposable?.dispose()
            self.loadMoreDisposable.dispose()
            self.refreshTimerDisposable.dispose()
        }
        
        func loadMore() {
            self.taskState.isLoadMoreScheduled = true
            self.updateTasks()
        }
        
        private func updateTasks() {
            if self.isLoading {
                return
            }
            
            let subscriptionsKey: PostboxStorySubscriptionsKey = self.isHidden ? .hidden : .filtered
            
            if self.taskState.isRefreshScheduled {
                self.isLoading = true
                
                self.stateDisposable = (postbox.combinedView(keys: [PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))])
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] views in
                    guard let `self` = self else {
                        return
                    }
                    guard let storiesStateView = views.views[PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))] as? StoryStatesView else {
                        return
                    }
                    
                    let stateMark: OpaqueStateMark
                    if let subscriptionsState = storiesStateView.value?.get(Stories.SubscriptionsState.self) {
                        stateMark = .value(subscriptionsState.opaqueState)
                    } else {
                        stateMark = .empty
                    }
                    
                    self.loadImpl(isRefresh: true, stateMark: stateMark)
                })
            } else if self.taskState.isLoadMoreScheduled {
                self.isLoading = true
                
                self.stateDisposable = (postbox.combinedView(keys: [PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))])
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] views in
                    guard let `self` = self else {
                        return
                    }
                    guard let storiesStateView = views.views[PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))] as? StoryStatesView else {
                        return
                    }
                    
                    let hasMore: Bool
                    let stateMark: OpaqueStateMark
                    if let subscriptionsState = storiesStateView.value?.get(Stories.SubscriptionsState.self) {
                        hasMore = subscriptionsState.hasMore
                        stateMark = .value(subscriptionsState.opaqueState)
                    } else {
                        stateMark = .empty
                        hasMore = true
                    }
                    
                    if hasMore && self.loadedStateMark != stateMark {
                        self.loadImpl(isRefresh: false, stateMark: stateMark)
                    } else {
                        self.isLoading = false
                        self.taskState.isLoadMoreScheduled = false
                        self.updateTasks()
                    }
                })
            }
        }
        
        private func loadImpl(isRefresh: Bool, stateMark: OpaqueStateMark) {
            var flags: Int32 = 0
            
            if self.isHidden {
                flags |= 1 << 2
            }
            
            var state: String?
            switch stateMark {
            case .empty:
                break
            case let .value(value):
                state = value
                flags |= 1 << 0
                
                if !isRefresh {
                    flags |= 1 << 1
                } else {
                    #if DEBUG
                    if "".isEmpty {
                        state = nil
                        flags &= ~(1 << 0)
                    }
                    #endif
                }
            }
            
            let accountPeerId = self.accountPeerId
            
            let isHidden = self.isHidden
            let subscriptionsKey: PostboxStorySubscriptionsKey = self.isHidden ? .hidden : .filtered
            
            self.loadMoreDisposable.set((self.network.request(Api.functions.stories.getAllStories(flags: flags, state: state))
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let `self` = self else {
                    return
                }
                
                let _ = (self.postbox.transaction { transaction -> Void in
                    var updatedStealthMode: Api.StoriesStealthMode?
                    switch result {
                    case let .allStoriesNotModified(allStoriesNotModifiedData):
                        let (state, stealthMode) = (allStoriesNotModifiedData.state, allStoriesNotModifiedData.stealthMode)
                        self.loadedStateMark = .value(state)
                        let (currentStateValue, _) = transaction.getAllStorySubscriptions(key: subscriptionsKey)
                        let currentState = currentStateValue.flatMap { $0.get(Stories.SubscriptionsState.self) }
                        
                        var hasMore = false
                        if let currentState = currentState {
                            hasMore = currentState.hasMore
                        }
                        
                        transaction.setSubscriptionsStoriesState(key: subscriptionsKey, state: CodableEntry(Stories.SubscriptionsState(
                            opaqueState: state,
                            refreshId: currentState?.refreshId ?? UInt64.random(in: 0 ... UInt64.max),
                            hasMore: hasMore
                        )))
                        
                        if isRefresh && !isHidden {
                            updatedStealthMode = stealthMode
                        }
                    case let .allStories(allStoriesData):
                        let (flags, state, peerStories, chats, users, stealthMode) = (allStoriesData.flags, allStoriesData.state, allStoriesData.peerStories, allStoriesData.chats, allStoriesData.users, allStoriesData.stealthMode)
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        
                        let hasMore: Bool = (flags & (1 << 0)) != 0
                        
                        let (_, currentPeerItems) = transaction.getAllStorySubscriptions(key: subscriptionsKey)
                        var peerEntries: [PeerId] = []
                        
                        for peerStorySet in peerStories {
                            switch peerStorySet {
                            case let .peerStories(peerStoriesData):
                                let (_, peerIdValue, maxReadId, stories) = (peerStoriesData.flags, peerStoriesData.peer, peerStoriesData.maxReadId, peerStoriesData.stories)
                                let peerId = peerIdValue.peerId

                                let previousPeerEntries: [StoryItemsTableEntry] = transaction.getStoryItems(peerId: peerId)

                                var updatedPeerEntries: [StoryItemsTableEntry] = []
                                for story in stories {
                                    if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                        if case .placeholder = storedItem, let previousEntry = previousPeerEntries.first(where: { $0.id == storedItem.id }) {
                                            updatedPeerEntries.append(previousEntry)
                                        } else {
                                            if let codedEntry = CodableEntry(storedItem) {
                                                updatedPeerEntries.append(StoryItemsTableEntry(value: codedEntry, id: storedItem.id, expirationTimestamp: storedItem.expirationTimestamp, isCloseFriends: storedItem.isCloseFriends, isLiveStream: storedItem.isLiveStream))
                                            }
                                        }
                                    }
                                }
                                
                                peerEntries.append(peerId)
                                
                                transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)
                                transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(
                                    maxReadId: maxReadId ?? 0
                                ).postboxRepresentation)
                            }
                        }
                        
                        if isRefresh {
                            if !isHidden {
                                if !peerEntries.contains(where: { $0 == accountPeerId }) {
                                    transaction.setStoryItems(peerId: accountPeerId, items: [])
                                }
                            }
                        } else {
                            let leftPeerIds = currentPeerItems.filter({ !peerEntries.contains($0) })
                            if !leftPeerIds.isEmpty {
                                peerEntries = leftPeerIds + peerEntries
                            }
                        }
                        
                        if isRefresh && !isHidden {
                            updatedStealthMode = stealthMode
                        }
                        
                        transaction.replaceAllStorySubscriptions(key: subscriptionsKey, state: CodableEntry(Stories.SubscriptionsState(
                            opaqueState: state,
                            refreshId: UInt64.random(in: 0 ... UInt64.max),
                            hasMore: hasMore
                        )), peerIds: peerEntries)
                        
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                    }
                    
                    if let updatedStealthMode = updatedStealthMode {
                        var configuration = _internal_getStoryConfigurationState(transaction: transaction)
                        configuration.stealthModeState = Stories.StealthModeState(apiMode: updatedStealthMode)
                        _internal_setStoryConfigurationState(transaction: transaction, state: configuration)
                    }
                }
                |> deliverOn(self.queue)).start(completed: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    
                    self.isLoading = false
                    if isRefresh {
                        self.taskState.isRefreshScheduled = false
                        self.refreshTimerDisposable.set((Signal<Never, NoError>.complete()
                        |> suspendAwareDelay(60.0, queue: self.queue)).start(completed: { [weak self] in
                            guard let `self` = self else {
                                return
                            }
                            self.taskState.isRefreshScheduled = true
                            self.updateTasks()
                        }))
                    } else {
                        self.taskState.isLoadMoreScheduled = false
                    }
                    
                    self.updateTasks()
                })
            }))
        }
    }
    
    private let queue = Queue(name: "StorySubscriptionsContext")
    private let impl: QueueLocalObject<Impl>
    
    init(accountPeerId: PeerId, postbox: Postbox, network: Network, isHidden: Bool) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            Impl(queue: queue, accountPeerId: accountPeerId, postbox: postbox, network: network, isHidden: isHidden)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}

private final class CachedPeerStoryListHead: Codable {
    let items: [Stories.StoredItem]
    let pinnedIds: [Int32]
    let totalCount: Int32
    let folders: [StoryListContext.State.Folder]
    
    init(items: [Stories.StoredItem], pinnedIds: [Int32], totalCount: Int32, folders: [StoryListContext.State.Folder]) {
        self.items = items
        self.pinnedIds = pinnedIds
        self.totalCount = totalCount
        self.folders = folders
    }
}

public struct StoryListContextState: Equatable {
    public final class Item: Equatable {
        public let id: StoryId
        public let storyItem: EngineStoryItem
        public let peer: EnginePeer?
        
        public init(id: StoryId, storyItem: EngineStoryItem, peer: EnginePeer?) {
            self.id = id
            self.storyItem = storyItem
            self.peer = peer
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.id != rhs.id {
                return false
            }
            if lhs.storyItem != rhs.storyItem {
                return false
            }
            if lhs.peer != rhs.peer {
                return false
            }
            return true
        }
    }
    
    public struct Language: Equatable {
        public let id: String
        public let name: String
        
        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }
    
    public struct Folder: Equatable, Codable {
        public let id: Int64
        public let title: String
        
        public init(id: Int64, title: String) {
            self.id = id
            self.title = title
        }
    }
    
    public var peerReference: PeerReference?
    public var items: [Item]
    public var availableLanguages: [Language]
    public var availableFolders: [Folder]
    public var pinnedIds: [Int32]
    public var totalCount: Int
    public var loadMoreToken: AnyHashable?
    public var isCached: Bool
    public var hasCache: Bool
    public var allEntityFiles: [MediaId: TelegramMediaFile]
    public var isLoading: Bool
    public init(
        peerReference: PeerReference?,
        items: [Item],
        availableLanguages: [Language],
        availableFolders: [Folder],
        pinnedIds: [Int32],
        totalCount: Int,
        loadMoreToken: AnyHashable?,
        isCached: Bool,
        hasCache: Bool,
        allEntityFiles: [MediaId: TelegramMediaFile],
        isLoading: Bool
    ) {
        self.peerReference = peerReference
        self.items = items
        self.availableLanguages = availableLanguages
        self.availableFolders = availableFolders
        self.pinnedIds = pinnedIds
        self.totalCount = totalCount
        self.loadMoreToken = loadMoreToken
        self.isCached = isCached
        self.hasCache = hasCache
        self.allEntityFiles = allEntityFiles
        self.isLoading = isLoading
    }
}

public protocol StoryListContext: AnyObject {
    typealias State = StoryListContextState
    
    var state: Signal<State, NoError> { get }
    
    func loadMore(completion: (() -> Void)?)
}

private func _internal_createStoryFolder(account: Account, peerId: PeerId, title: String, items: [EngineStoryItem]) -> Signal<StoryListContextState.Folder?, NoError> {
    var seenIds = Set<Int32>()
    var selectedItems: [EngineStoryItem] = []
    for item in items {
        guard item.id > 0, !item.isPending else {
            return .single(nil)
        }
        if seenIds.insert(item.id).inserted {
            selectedItems.append(item)
        }
    }
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Api.StoryAlbum?, NoError> in
        guard let inputPeer else {
            return .single(nil)
        }
        return account.network.request(Api.functions.stories.createAlbum(peer: inputPeer, title: title, stories: selectedItems.map(\.id)))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.StoryAlbum?, NoError> in
            return .single(nil)
        }
    }
    |> then(.single(nil))
    |> take(1)
    |> mapToSignal { result -> Signal<StoryListContextState.Folder?, NoError> in
        guard let result else {
            return .single(nil)
        }
        let folder: StoryListContextState.Folder
        switch result {
        case let .storyAlbum(data):
            folder = StoryListContextState.Folder(id: Int64(data.albumId), title: data.title)
        }
        return account.postbox.transaction { transaction -> StoryListContextState.Folder? in
            let key = ValueBoxKey(length: 8 + 1)
            key.setInt64(0, value: peerId.toInt64())
            key.setInt8(8, value: 0)
            let cacheId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key)
            let cached = transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedPeerStoryListHead.self)
            var folders = cached?.folders ?? []
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index] = folder
            } else {
                folders.append(folder)
            }
            if let entry = CodableEntry(CachedPeerStoryListHead(items: cached?.items ?? [], pinnedIds: cached?.pinnedIds ?? [], totalCount: cached?.totalCount ?? 0, folders: folders)) {
                transaction.putItemCacheEntry(id: cacheId, entry: entry)
            }
            let folderKey = ValueBoxKey(length: 8 + 1 + 8)
            folderKey.setInt64(0, value: peerId.toInt64())
            folderKey.setInt8(8, value: 0)
            folderKey.setInt64(9, value: folder.id)
            if let entry = CodableEntry(CachedPeerStoryListHead(items: selectedItems.prefix(100).map { .item($0.asStoryItem()) }, pinnedIds: [], totalCount: Int32(clamping: selectedItems.count), folders: [])) {
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: folderKey), entry: entry)
            }
            return folder
        }
    }
}

private enum StoryFolderMutationResult {
    case deleted
    case renamed(StoryListContextState.Folder)
}

private func _internal_updateStoryFolder(account: Account, peerId: PeerId, id: Int64, title: String?) -> Signal<StoryFolderMutationResult?, NoError> {
    guard let albumId = Int32(exactly: id), albumId > 0 else {
        return .single(nil)
    }
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<StoryFolderMutationResult?, NoError> in
        guard let inputPeer else {
            return .single(nil)
        }
        if let title {
            return account.network.request(Api.functions.stories.updateAlbum(flags: 1 << 0, peer: inputPeer, albumId: albumId, title: title, deleteStories: nil, addStories: nil, order: nil))
            |> map { result -> StoryFolderMutationResult? in
                switch result {
                case let .storyAlbum(data):
                    guard data.albumId == albumId else { return nil }
                    return .renamed(StoryListContextState.Folder(id: id, title: data.title))
                }
            }
            |> `catch` { _ -> Signal<StoryFolderMutationResult?, NoError> in
                return .single(nil)
            }
        } else {
            return account.network.request(Api.functions.stories.deleteAlbum(peer: inputPeer, albumId: albumId))
            |> map { result -> StoryFolderMutationResult? in
                guard case .boolTrue = result else { return nil }
                return .deleted
            }
            |> `catch` { _ -> Signal<StoryFolderMutationResult?, NoError> in
                return .single(nil)
            }
        }
    }
    |> then(.single(nil))
    |> take(1)
    |> mapToSignal { result -> Signal<StoryFolderMutationResult?, NoError> in
        guard let result else { return .single(nil) }
        return account.postbox.transaction { transaction -> StoryFolderMutationResult? in
            let key = ValueBoxKey(length: 8 + 1)
            key.setInt64(0, value: peerId.toInt64())
            key.setInt8(8, value: 0)
            let cacheId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key)
            if let cached = transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedPeerStoryListHead.self) {
                var folders = cached.folders
                switch result {
                case .deleted:
                    folders.removeAll(where: { $0.id == id })
                case let .renamed(folder):
                    if let index = folders.firstIndex(where: { $0.id == id }) {
                        folders[index] = folder
                    }
                }
                if let entry = CodableEntry(CachedPeerStoryListHead(items: cached.items, pinnedIds: cached.pinnedIds, totalCount: cached.totalCount, folders: folders)) {
                    transaction.putItemCacheEntry(id: cacheId, entry: entry)
                }
            }
            if case .deleted = result {
                let folderKey = ValueBoxKey(length: 8 + 1 + 8)
                folderKey.setInt64(0, value: peerId.toInt64())
                folderKey.setInt8(8, value: 0)
                folderKey.setInt64(9, value: id)
                transaction.removeItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: folderKey))
            }
            return result
        }
    }
}

private func _internal_reorderedStoryFolders(_ folders: [StoryListContextState.Folder], ids: [Int64]) -> [StoryListContextState.Folder] {
    var remaining = folders
    var ordered: [StoryListContextState.Folder] = []
    for id in ids {
        if let index = remaining.firstIndex(where: { $0.id == id }) {
            ordered.append(remaining.remove(at: index))
        }
    }
    ordered.append(contentsOf: remaining)
    return ordered
}

private func _internal_reorderStoryFolders(account: Account, peerId: PeerId, ids: [Int64]) -> Signal<[Int64]?, NoError> {
    var order: [Int32] = []
    var seenIds = Set<Int32>()
    for id in ids {
        guard let id = Int32(exactly: id), id > 0 else { return .single(nil) }
        if seenIds.insert(id).inserted { order.append(id) }
    }
    guard !order.isEmpty else { return .single([]) }
    let orderedIds = order.map(Int64.init)
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Bool, NoError> in
        guard let inputPeer else { return .single(false) }
        return account.network.request(Api.functions.stories.reorderAlbums(peer: inputPeer, order: order))
        |> map { result -> Bool in
            if case .boolTrue = result { return true }
            return false
        }
        |> `catch` { _ -> Signal<Bool, NoError> in .single(false) }
    }
    |> then(.single(false))
    |> take(1)
    |> mapToSignal { success -> Signal<[Int64]?, NoError> in
        guard success else { return .single(nil) }
        return account.postbox.transaction { transaction -> [Int64]? in
            let key = ValueBoxKey(length: 8 + 1)
            key.setInt64(0, value: peerId.toInt64())
            key.setInt8(8, value: 0)
            let cacheId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key)
            if let cached = transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedPeerStoryListHead.self) {
                let folders = _internal_reorderedStoryFolders(cached.folders, ids: orderedIds)
                if let entry = CodableEntry(CachedPeerStoryListHead(items: cached.items, pinnedIds: cached.pinnedIds, totalCount: cached.totalCount, folders: folders)) {
                    transaction.putItemCacheEntry(id: cacheId, entry: entry)
                }
            }
            return orderedIds
        }
    }
}

private func _internal_storyFolderIds(_ folderIds: [Int64]?, albumId: Int64, isMember: Bool) -> [Int64]? {
    guard var folderIds else { return nil }
    if isMember {
        if !folderIds.contains(albumId) { folderIds.append(albumId) }
    } else {
        folderIds.removeAll(where: { $0 == albumId })
    }
    return folderIds
}

private func _internal_storyWithFolderIds(_ item: Stories.Item, folderIds: [Int64]?) -> Stories.Item {
    return Stories.Item(
        id: item.id,
        timestamp: item.timestamp,
        expirationTimestamp: item.expirationTimestamp,
        media: item.media,
        alternativeMediaList: item.alternativeMediaList,
        mediaAreas: item.mediaAreas,
        text: item.text,
        entities: item.entities,
        views: item.views,
        privacy: item.privacy,
        isPinned: item.isPinned,
        isExpired: item.isExpired,
        isPublic: item.isPublic,
        isCloseFriends: item.isCloseFriends,
        isContacts: item.isContacts,
        isSelectedContacts: item.isSelectedContacts,
        isForwardingDisabled: item.isForwardingDisabled,
        isEdited: item.isEdited,
        isMy: item.isMy,
        myReaction: item.myReaction,
        forwardInfo: item.forwardInfo,
        music: item.music,
        authorId: item.authorId,
        folderIds: folderIds
    )
}

private func _internal_engineStoryWithFolderIds(_ item: EngineStoryItem, folderIds: [Int64]?) -> EngineStoryItem {
    return EngineStoryItem(
        id: item.id,
        timestamp: item.timestamp,
        expirationTimestamp: item.expirationTimestamp,
        media: item.media,
        alternativeMediaList: item.alternativeMediaList,
        mediaAreas: item.mediaAreas,
        text: item.text,
        entities: item.entities,
        views: item.views,
        privacy: item.privacy,
        isPinned: item.isPinned,
        isExpired: item.isExpired,
        isPublic: item.isPublic,
        isPending: item.isPending,
        isCloseFriends: item.isCloseFriends,
        isContacts: item.isContacts,
        isSelectedContacts: item.isSelectedContacts,
        isForwardingDisabled: item.isForwardingDisabled,
        isEdited: item.isEdited,
        isMy: item.isMy,
        myReaction: item.myReaction,
        forwardInfo: item.forwardInfo,
        music: item.music,
        author: item.author,
        folderIds: folderIds
    )
}

private func _internal_storyWithViews(_ item: Stories.Item, views: Stories.Item.Views) -> Stories.Item {
    return Stories.Item(
        id: item.id,
        timestamp: item.timestamp,
        expirationTimestamp: item.expirationTimestamp,
        media: item.media,
        alternativeMediaList: item.alternativeMediaList,
        mediaAreas: item.mediaAreas,
        text: item.text,
        entities: item.entities,
        views: views,
        privacy: item.privacy,
        isPinned: item.isPinned,
        isExpired: item.isExpired,
        isPublic: item.isPublic,
        isCloseFriends: item.isCloseFriends,
        isContacts: item.isContacts,
        isSelectedContacts: item.isSelectedContacts,
        isForwardingDisabled: item.isForwardingDisabled,
        isEdited: item.isEdited,
        isMy: item.isMy,
        myReaction: item.myReaction,
        forwardInfo: item.forwardInfo,
        music: item.music,
        authorId: item.authorId,
        folderIds: item.folderIds
    )
}

private func _internal_engineStoryWithViews(_ item: EngineStoryItem, views: EngineStoryItem.Views) -> EngineStoryItem {
    return EngineStoryItem(
        id: item.id,
        timestamp: item.timestamp,
        expirationTimestamp: item.expirationTimestamp,
        media: item.media,
        alternativeMediaList: item.alternativeMediaList,
        mediaAreas: item.mediaAreas,
        text: item.text,
        entities: item.entities,
        views: views,
        privacy: item.privacy,
        isPinned: item.isPinned,
        isExpired: item.isExpired,
        isPublic: item.isPublic,
        isPending: item.isPending,
        isCloseFriends: item.isCloseFriends,
        isContacts: item.isContacts,
        isSelectedContacts: item.isSelectedContacts,
        isForwardingDisabled: item.isForwardingDisabled,
        isEdited: item.isEdited,
        isMy: item.isMy,
        myReaction: item.myReaction,
        forwardInfo: item.forwardInfo,
        music: item.music,
        author: item.author,
        folderIds: item.folderIds
    )
}

private func _internal_engineStoryWithReaction(_ item: EngineStoryItem, isChannel: Bool, reaction: MessageReaction.Reaction?) -> EngineStoryItem {
    let views = _internal_updateStoryViewsForMyReaction(isChannel: isChannel, views: item.asStoryItem().views, previousReaction: item.myReaction, reaction: reaction)
    return EngineStoryItem(
        id: item.id,
        timestamp: item.timestamp,
        expirationTimestamp: item.expirationTimestamp,
        media: item.media,
        alternativeMediaList: item.alternativeMediaList,
        mediaAreas: item.mediaAreas,
        text: item.text,
        entities: item.entities,
        views: views.map { value in
            EngineStoryItem.Views(seenCount: value.seenCount, reactedCount: value.reactedCount, forwardCount: value.forwardCount, seenPeers: item.views?.seenPeers ?? [], reactions: value.reactions, hasList: value.hasList)
        },
        privacy: item.privacy,
        isPinned: item.isPinned,
        isExpired: item.isExpired,
        isPublic: item.isPublic,
        isPending: item.isPending,
        isCloseFriends: item.isCloseFriends,
        isContacts: item.isContacts,
        isSelectedContacts: item.isSelectedContacts,
        isForwardingDisabled: item.isForwardingDisabled,
        isEdited: item.isEdited,
        isMy: item.isMy,
        myReaction: reaction,
        forwardInfo: item.forwardInfo,
        music: item.music,
        author: item.author,
        folderIds: item.folderIds
    )
}

private func _internal_visitStoryListCaches(transaction: Transaction, peerId: PeerId, id: Int32, visit: (ItemCacheEntryId, CachedPeerStoryListHead) -> Void) {
    var albumIds = Set<Int64>()
    for row in transaction.getStoryItems(peerId: peerId) {
        if case let .item(item) = row.value.get(Stories.StoredItem.self), item.id == row.id { albumIds.formUnion(item.folderIds ?? []) }
    }
    if case let .item(item) = transaction.getStory(id: StoryId(peerId: peerId, id: id))?.get(Stories.StoredItem.self), item.id == id { albumIds.formUnion(item.folderIds ?? []) }
    func updateCache(archived: Int8, albumId: Int64?) {
        let key = ValueBoxKey(length: albumId == nil ? 9 : 17)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt8(8, value: archived)
        if let albumId { key.setInt64(9, value: albumId) }
        let cacheId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key)
        guard let cached = transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedPeerStoryListHead.self) else { return }
        albumIds.formUnion(cached.folders.map(\.id))
        for stored in cached.items {
            if case let .item(item) = stored { albumIds.formUnion(item.folderIds ?? []) }
        }
        visit(cacheId, cached)
    }
    for archived: Int8 in [0, 1] { updateCache(archived: archived, albumId: nil) }
    var visitedAlbums = Set<Int64>()
    while let albumId = albumIds.first(where: { !visitedAlbums.contains($0) }) {
        visitedAlbums.insert(albumId)
        for archived: Int8 in [0, 1] { updateCache(archived: archived, albumId: albumId) }
    }
}

func _internal_storyListCacheSnapshot(transaction: Transaction, peerId: PeerId, id: Int32) -> [ItemCacheEntryId: [Stories.StoredItem]] {
    var result: [ItemCacheEntryId: [Stories.StoredItem]] = [:]
    _internal_visitStoryListCaches(transaction: transaction, peerId: peerId, id: id) { cacheId, cached in
        let items = cached.items.filter { $0.id == id }
        if !items.isEmpty { result[cacheId] = items }
    }
    return result
}

func _internal_transformStoryListCacheItems(transaction: Transaction, peerId: PeerId, id: Int32, transform: (Stories.Item) -> Stories.Item?) {
    _internal_visitStoryListCaches(transaction: transaction, peerId: peerId, id: id) { cacheId, cached in
        var changed = false
        let items = cached.items.map { stored -> Stories.StoredItem in
            guard case let .item(item) = stored, item.id == id, let updated = transform(item) else { return stored }
            changed = true
            return .item(updated)
        }
        if changed, let entry = CodableEntry(CachedPeerStoryListHead(items: items, pinnedIds: cached.pinnedIds, totalCount: cached.totalCount, folders: cached.folders)) {
            transaction.putItemCacheEntry(id: cacheId, entry: entry)
        }
    }
}

func _internal_updateStoryListCacheItem(transaction: Transaction, peerId: PeerId, item: Stories.Item) {
    _internal_visitStoryListCaches(transaction: transaction, peerId: peerId, id: item.id) { cacheId, cached in
        let belongs: Bool
        if cacheId.key.length == 17 {
            let albumId = cacheId.key.getInt64(9)
            belongs = item.folderIds.map { $0.contains(albumId) } ?? true
        } else {
            belongs = cacheId.key.getInt8(8) != 0 || item.isPinned
        }
        let items: [Stories.StoredItem]
        let pinnedIds: [Int32]
        let totalCount: Int32
        if belongs {
            items = cached.items.map { $0.id == item.id ? .item(item) : $0 }
            pinnedIds = cached.pinnedIds
            totalCount = cached.totalCount
        } else {
            items = cached.items.filter { $0.id != item.id }
            pinnedIds = cached.pinnedIds.filter { $0 != item.id }
            totalCount = items.count == cached.items.count ? cached.totalCount : (cached.totalCount > 0 ? cached.totalCount - 1 : 0)
        }
        guard items != cached.items || pinnedIds != cached.pinnedIds else { return }
        if let entry = CodableEntry(CachedPeerStoryListHead(items: items, pinnedIds: pinnedIds, totalCount: totalCount, folders: cached.folders)) {
            transaction.putItemCacheEntry(id: cacheId, entry: entry)
        }
    }
}

func _internal_removeStoryFromListCaches(transaction: Transaction, peerId: PeerId, id: Int32) {
    _internal_removeStoriesFromListCaches(transaction: transaction, peerId: peerId, ids: [id])
}

func _internal_removeStoriesFromListCaches(transaction: Transaction, peerId: PeerId, ids: Set<Int32>) {
    guard !ids.isEmpty else { return }
    var caches: [ItemCacheEntryId: CachedPeerStoryListHead] = [:]
    for id in ids {
        _internal_visitStoryListCaches(transaction: transaction, peerId: peerId, id: id) { cacheId, cached in
            caches[cacheId] = cached
        }
    }
    for (cacheId, cached) in caches {
        let removedIds = Set(cached.items.filter { ids.contains($0.id) }.map(\.id))
        let items = cached.items.filter { !ids.contains($0.id) }
        let pinnedIds = cached.pinnedIds.filter { !ids.contains($0) }
        guard !removedIds.isEmpty || pinnedIds != cached.pinnedIds else { continue }
        let totalCount = removedIds.isEmpty ? cached.totalCount : Int32(max(0, Int64(max(0, cached.totalCount)) - Int64(removedIds.count)))
        if let entry = CodableEntry(CachedPeerStoryListHead(items: items, pinnedIds: pinnedIds, totalCount: totalCount, folders: cached.folders)) {
            transaction.putItemCacheEntry(id: cacheId, entry: entry)
        }
    }
}

func _internal_cachedStoryItemValue(transaction: Transaction, peerId: PeerId, id: Int32) -> Stories.Item? {
    var result: Stories.Item?
    _internal_transformStoryListCacheItems(transaction: transaction, peerId: peerId, id: id) { item in
        if result == nil { result = item }
        return nil
    }
    return result
}

func _internal_cachedStoryReactionValue(transaction: Transaction, peerId: PeerId, id: Int32) -> MessageReaction.Reaction?? {
    if let item = _internal_cachedStoryItemValue(transaction: transaction, peerId: peerId, id: id) { return .some(item.myReaction) }
    return nil
}

func _internal_applyStoryViews(transaction: Transaction, peerId: PeerId, views: [Int32: Stories.Item.Views]) {
    guard !views.isEmpty else { return }
    var albumIds = Set<Int64>()
    func updated(_ stored: Stories.StoredItem) -> Stories.StoredItem? {
        guard case let .item(item) = stored else { return nil }
        albumIds.formUnion(item.folderIds ?? [])
        guard let value = views[item.id], item.views != value else { return nil }
        return .item(_internal_storyWithViews(item, views: value))
    }
    var rows = transaction.getStoryItems(peerId: peerId)
    var changed = false
    for index in rows.indices {
        guard let stored = rows[index].value.get(Stories.StoredItem.self), stored.id == rows[index].id,
              let item = updated(stored), let entry = CodableEntry(item) else { continue }
        rows[index] = StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: item.expirationTimestamp, isCloseFriends: item.isCloseFriends, isLiveStream: item.isLiveStream)
        changed = true
    }
    if changed { transaction.setStoryItems(peerId: peerId, items: rows) }
    for id in views.keys {
        let storyId = StoryId(peerId: peerId, id: id)
        if let stored = transaction.getStory(id: storyId)?.get(Stories.StoredItem.self), stored.id == id,
           let item = updated(stored), let entry = CodableEntry(item) {
            transaction.setStory(id: storyId, value: entry)
        }
    }
    func updateCache(archived: Int8, albumId: Int64?) {
        let key = ValueBoxKey(length: albumId == nil ? 9 : 17)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt8(8, value: archived)
        if let albumId { key.setInt64(9, value: albumId) }
        let cacheId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key)
        guard let cached = transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedPeerStoryListHead.self) else { return }
        albumIds.formUnion(cached.folders.map(\.id))
        var changed = false
        let items = cached.items.map { stored -> Stories.StoredItem in
            if let item = updated(stored) { changed = true; return item }
            return stored
        }
        if changed, let entry = CodableEntry(CachedPeerStoryListHead(items: items, pinnedIds: cached.pinnedIds, totalCount: cached.totalCount, folders: cached.folders)) {
            transaction.putItemCacheEntry(id: cacheId, entry: entry)
        }
    }
    for archived: Int8 in [0, 1] { updateCache(archived: archived, albumId: nil) }
    var visitedAlbums = Set<Int64>()
    while let albumId = albumIds.first(where: { !visitedAlbums.contains($0) }) {
        visitedAlbums.insert(albumId)
        for archived: Int8 in [0, 1] { updateCache(archived: archived, albumId: albumId) }
    }
}

private func _internal_mappedStoryViews(_ views: Stories.Item.Views, peers: [PeerId: Peer]) -> EngineStoryItem.Views {
    return EngineStoryItem.Views(seenCount: views.seenCount, reactedCount: views.reactedCount, forwardCount: views.forwardCount, seenPeers: views.seenPeerIds.compactMap { peers[$0].flatMap(EnginePeer.init) }, reactions: views.reactions, hasList: views.hasList)
}

private func _internal_reorderStoryFolderItems(account: Account, peerId: PeerId, id: Int64, itemIds: [Int32]) -> Signal<Bool, NoError> {
    guard let albumId = Int32(exactly: id), albumId > 0 else { return .single(false) }
    var ids: [Int32] = []
    var seenIds = Set<Int32>()
    for itemId in itemIds {
        guard itemId > 0 else { return .single(false) }
        if seenIds.insert(itemId).inserted { ids.append(itemId) }
    }
    guard !ids.isEmpty else { return .single(true) }
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Bool, NoError> in
        guard let inputPeer else { return .single(false) }
        return account.network.request(Api.functions.stories.updateAlbum(flags: 1 << 3, peer: inputPeer, albumId: albumId, title: nil, deleteStories: nil, addStories: nil, order: ids))
        |> map { result -> Bool in
            switch result {
            case let .storyAlbum(data): return data.albumId == albumId
            }
        }
        |> `catch` { _ -> Signal<Bool, NoError> in .single(false) }
    }
    |> then(.single(false))
    |> take(1)
    |> mapToSignal { success -> Signal<Bool, NoError> in
        guard success else { return .single(false) }
        return account.postbox.transaction { transaction -> Bool in
            let key = ValueBoxKey(length: 17)
            key.setInt64(0, value: peerId.toInt64())
            key.setInt8(8, value: 0)
            key.setInt64(9, value: id)
            transaction.removeItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))
            return true
        }
        |> beforeNext { _ in
            account.stateManager.injectStoryUpdates(updates: [.updateAlbumOrder(peerId: peerId, albumId: id)])
        }
    }
}

private func _internal_updateStoryFolderItems(account: Account, peerId: PeerId, id: Int64, added: [EngineStoryItem], removed: [Int32]) -> Signal<Bool, NoError> {
    guard let albumId = Int32(exactly: id), albumId > 0 else { return .single(false) }
    var addedIds: [Int32] = []
    var removedIds: [Int32] = []
    var seenAdded = Set<Int32>()
    var seenRemoved = Set<Int32>()
    for item in added {
        guard item.id > 0, !item.isPending else { return .single(false) }
        if seenAdded.insert(item.id).inserted { addedIds.append(item.id) }
    }
    for itemId in removed {
        guard itemId > 0, !seenAdded.contains(itemId) else { return .single(false) }
        if seenRemoved.insert(itemId).inserted { removedIds.append(itemId) }
    }
    guard !addedIds.isEmpty || !removedIds.isEmpty else { return .single(true) }
    let flags: Int32 = (addedIds.isEmpty ? 0 : 1 << 2) | (removedIds.isEmpty ? 0 : 1 << 1)
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Bool, NoError> in
        guard let inputPeer else { return .single(false) }
        return account.network.request(Api.functions.stories.updateAlbum(flags: flags, peer: inputPeer, albumId: albumId, title: nil, deleteStories: removedIds.isEmpty ? nil : removedIds, addStories: addedIds.isEmpty ? nil : addedIds, order: nil))
        |> map { result -> Bool in
            switch result {
            case let .storyAlbum(data): return data.albumId == albumId
            }
        }
        |> `catch` { _ -> Signal<Bool, NoError> in .single(false) }
    }
    |> then(.single(false))
    |> take(1)
    |> mapToSignal { success -> Signal<Bool, NoError> in
        guard success else { return .single(false) }
        return account.postbox.transaction { transaction -> Bool in
            let key = ValueBoxKey(length: 8 + 1 + 8)
            key.setInt64(0, value: peerId.toInt64())
            key.setInt8(8, value: 0)
            key.setInt64(9, value: id)
            transaction.removeItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))
            func updated(_ stored: Stories.StoredItem) -> Stories.StoredItem {
                guard case let .item(item) = stored, seenAdded.contains(item.id) || seenRemoved.contains(item.id) else { return stored }
                let folderIds = _internal_storyFolderIds(item.folderIds, albumId: id, isMember: seenAdded.contains(item.id))
                guard folderIds != item.folderIds else { return stored }
                return .item(_internal_storyWithFolderIds(item, folderIds: folderIds))
            }
            for archived: Int8 in [0, 1] {
                let profileKey = ValueBoxKey(length: 9)
                profileKey.setInt64(0, value: peerId.toInt64())
                profileKey.setInt8(8, value: archived)
                let cacheId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: profileKey)
                if let cached = transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedPeerStoryListHead.self) {
                    if let entry = CodableEntry(CachedPeerStoryListHead(items: cached.items.map(updated), pinnedIds: cached.pinnedIds, totalCount: cached.totalCount, folders: cached.folders)) {
                        transaction.putItemCacheEntry(id: cacheId, entry: entry)
                    }
                }
            }
            var items = transaction.getStoryItems(peerId: peerId)
            var changed = false
            for index in items.indices {
                guard seenAdded.contains(items[index].id) || seenRemoved.contains(items[index].id),
                      let stored = items[index].value.get(Stories.StoredItem.self), case .item = stored,
                      case let .item(item) = updated(stored), let entry = CodableEntry(Stories.StoredItem.item(item)) else { continue }
                items[index] = StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: item.expirationTimestamp, isCloseFriends: item.isCloseFriends, isLiveStream: item.isLiveStream)
                changed = true
            }
            if changed { transaction.setStoryItems(peerId: peerId, items: items) }
            for itemId in addedIds + removedIds {
                let storyId = StoryId(peerId: peerId, id: itemId)
                if let stored = transaction.getStory(id: storyId)?.get(Stories.StoredItem.self), case .item = stored,
                   let entry = CodableEntry(updated(stored)) {
                    transaction.setStory(id: storyId, value: entry)
                }
            }
            return true
        }
        |> beforeNext { success in
            if success {
                account.stateManager.injectStoryUpdates(updates: [.updateAlbumMembership(peerId: peerId, albumId: id, added: addedIds, removed: removedIds)])
            }
        }
    }
}

private func _internal_storyEntityFileIds(entities: [MessageTextEntity], mediaAreas: [MediaArea]) -> Set<MediaId> {
    var ids = Set<MediaId>()
    for entity in entities {
        if case let .CustomEmoji(_, id) = entity.type {
            ids.insert(MediaId(namespace: Namespaces.Media.CloudFile, id: id))
        }
    }
    for area in mediaAreas {
        if case let .reaction(_, reaction, _) = area, case let .custom(id) = reaction {
            ids.insert(MediaId(namespace: Namespaces.Media.CloudFile, id: id))
        }
    }
    return ids
}

private func _internal_storyEntityFiles(ids: Set<MediaId>, transaction: Transaction) -> [MediaId: TelegramMediaFile] {
    var files: [MediaId: TelegramMediaFile] = [:]
    for id in ids {
        if let file = transaction.getMedia(id) as? TelegramMediaFile, file.fileId == id {
            files[id] = file
        }
    }
    return files
}

private func _internal_prunedStoryEntityFiles(_ files: [MediaId: TelegramMediaFile], items: [StoryListContextState.Item]) -> [MediaId: TelegramMediaFile] {
    var ids = Set<MediaId>()
    for item in items {
        ids.formUnion(_internal_storyEntityFileIds(entities: item.storyItem.entities, mediaAreas: item.storyItem.mediaAreas))
    }
    return files.filter { ids.contains($0.key) }
}

public final class PeerStoryListContext: StoryListContext {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let peerId: EnginePeer.Id
        private let isArchived: Bool
        private let folderId: Int64?

        private let statePromise = Promise<State>()
        private var stateValue: State {
            didSet {
                self.statePromise.set(.single(self.stateValue))
            }
        }
        var state: Signal<State, NoError> {
            return self.statePromise.get()
        }

        private var isLoadingMore: Bool = false
        private let initializationDisposable = MetaDisposable()
        private let initializationPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
        private var isInitialized = false
        private var pendingUpdateCount = 0
        private var loadAfterUpdates = false
        private let requestDisposable = MetaDisposable()
        private var loadOperationId: UUID?

        private struct Page {
            let items: [State.Item]
            let totalCount: Int
            let peerReference: PeerReference?
            let folders: [State.Folder]?
            let pinnedIds: [Int32]?
            let nextOffset: Int?
            let entityFiles: [MediaId: TelegramMediaFile]
        }

        private var updatesDisposable: Disposable?

        private var completionCallbacksByToken: [AnyHashable: [() -> Void]] = [:]

        init(queue: Queue, account: Account, peerId: EnginePeer.Id, isArchived: Bool, folderId: Int64?) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.isArchived = isArchived
            self.folderId = folderId

            self.stateValue = State(peerReference: nil, items: [], availableLanguages: [], availableFolders: [], pinnedIds: [], totalCount: 0, loadMoreToken: AnyHashable(0 as Int), isCached: true, hasCache: false, allEntityFiles: [:], isLoading: true)

            self.statePromise.set(.single(self.stateValue))
            self.subscribeToStoryUpdates()
            let initializationDisposable = MetaDisposable()
            self.initializationDisposable.set(initializationDisposable)
            initializationDisposable.set((account.postbox.transaction { transaction -> (PeerReference?, [State.Item], [Int32], Int, [MediaId: TelegramMediaFile], [StoryListContext.State.Folder], Bool) in
                let key = ValueBoxKey(length: 8 + 1)
                key.setInt64(0, value: peerId.toInt64())
                key.setInt8(8, value: isArchived ? 1 : 0)
                let cachedMain = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))?.get(CachedPeerStoryListHead.self)
                let mainFolders: [State.Folder] = cachedMain?.folders ?? []

                let cached: CachedPeerStoryListHead
                if let folderId {
                    let key = ValueBoxKey(length: 8 + 1 + 8)
                    key.setInt64(0, value: peerId.toInt64())
                    key.setInt8(8, value: isArchived ? 1 : 0)
                    key.setInt64(8 + 1, value: folderId)
                    let cachedFolder = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))?.get(CachedPeerStoryListHead.self)
                    if let cachedFolder {
                        cached = cachedFolder
                    } else {
                        return (transaction.getPeer(peerId).flatMap(PeerReference.init), [], [], 0, [:], mainFolders, false)
                    }
                } else if let cachedMain {
                    cached = cachedMain
                } else {
                    return (transaction.getPeer(peerId).flatMap(PeerReference.init), [], [], 0, [:], mainFolders, false)
                }

                var items: [State.Item] = []
                var allEntityFiles: [MediaId: TelegramMediaFile] = [:]
                for storedItem in cached.items {
                    if case let .item(item) = storedItem, let media = item.media {
                        let mappedItem = EngineStoryItem(
                            id: item.id,
                            timestamp: item.timestamp,
                            expirationTimestamp: item.expirationTimestamp,
                            media: EngineMedia(media),
                            alternativeMediaList: item.alternativeMediaList.map(EngineMedia.init),
                            mediaAreas: item.mediaAreas,
                            text: item.text,
                            entities: item.entities,
                            views: item.views.flatMap { views in
                                return EngineStoryItem.Views(
                                    seenCount: views.seenCount,
                                    reactedCount: views.reactedCount,
                                    forwardCount: views.forwardCount,
                                    seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                        return transaction.getPeer(id).flatMap(EnginePeer.init)
                                    },
                                    reactions: views.reactions,
                                    hasList: views.hasList
                                )
                            },
                            privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                            isPinned: item.isPinned,
                            isExpired: item.isExpired,
                            isPublic: item.isPublic,
                            isPending: false,
                            isCloseFriends: item.isCloseFriends,
                            isContacts: item.isContacts,
                            isSelectedContacts: item.isSelectedContacts,
                            isForwardingDisabled: item.isForwardingDisabled,
                            isEdited: item.isEdited,
                            isMy: item.isMy,
                            myReaction: item.myReaction,
                            forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, transaction: transaction) },
                            music: item.music.flatMap(EngineMedia.init),
                            author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) },
                            folderIds: item.folderIds
                        )
                        let entry = State.Item(id: StoryId(peerId: peerId, id: mappedItem.id), storyItem: mappedItem, peer: nil)
                        if let index = items.firstIndex(where: { $0.id == entry.id }) {
                            items[index] = entry
                        } else {
                            items.append(entry)
                        }
                    }
                }

                var entityIds = Set<MediaId>()
                for item in items {
                    entityIds.formUnion(_internal_storyEntityFileIds(entities: item.storyItem.entities, mediaAreas: item.storyItem.mediaAreas))
                }
                allEntityFiles = _internal_storyEntityFiles(ids: entityIds, transaction: transaction)
                let peerReference = transaction.getPeer(peerId).flatMap(PeerReference.init)

                return (peerReference, items, cached.pinnedIds, max(items.count, Int(cached.totalCount)), allEntityFiles, mainFolders, true)
            }
            |> deliverOn(self.queue)).start(next: { [weak self] peerReference, items, pinnedIds, totalCount, allEntityFiles, folders, hasCache in
                guard let self else {
                    return
                }

                var updatedState = State(peerReference: peerReference, items: items, availableLanguages: [], availableFolders: folders, pinnedIds: pinnedIds, totalCount: totalCount, loadMoreToken: AnyHashable(0 as Int), isCached: true, hasCache: hasCache, allEntityFiles: allEntityFiles, isLoading: false)
                if self.folderId == nil {
                    updatedState.items.sort(by: { lhs, rhs in
                        let lhsPinned = updatedState.pinnedIds.firstIndex(of: lhs.storyItem.id)
                        let rhsPinned = updatedState.pinnedIds.firstIndex(of: rhs.storyItem.id)

                        if let lhsPinned, let rhsPinned {
                            if lhsPinned != rhsPinned {
                                return lhsPinned < rhsPinned
                            }
                        } else if (lhsPinned == nil) != (rhsPinned == nil) {
                            return lhsPinned != nil
                        }

                        return lhs.storyItem.timestamp > rhs.storyItem.timestamp
                    })
                }
                self.loadAfterUpdates = true
                self.isInitialized = true
                self.stateValue = updatedState
                self.initializationPromise.set(true)
                if self.loadAfterUpdates { self.loadMore(completion: nil) }
            }))
        }

        deinit {
            self.initializationDisposable.dispose()
            self.requestDisposable.dispose()
            self.updatesDisposable?.dispose()
        }

        func loadMore(completion: (() -> Void)?) {
            guard let loadMoreTokenValue = self.stateValue.loadMoreToken, let loadMoreToken = loadMoreTokenValue.base as? Int else {
                completion?()
                return
            }

            if let completion = completion {
                if self.completionCallbacksByToken[loadMoreToken] == nil {
                    self.completionCallbacksByToken[loadMoreToken] = []
                }
                self.completionCallbacksByToken[loadMoreToken]?.append(completion)
            }

            if !self.isInitialized || self.pendingUpdateCount != 0 {
                self.loadAfterUpdates = true
                return
            }
            if self.isLoadingMore {
                return
            }

            self.loadAfterUpdates = false
            self.isLoadingMore = true
            let operationId = UUID()
            self.loadOperationId = operationId
            let requestDisposable = MetaDisposable()
            self.requestDisposable.set(requestDisposable)
            self.stateValue.isLoading = true

            let limit = 100

            let peerId = self.peerId
            let account = self.account
            let accountPeerId = account.peerId
            let isArchived = self.isArchived
            let folderId = self.folderId
            let queue = self.queue
            requestDisposable.set((self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<Page?, NoError> in
                guard let inputPeer else {
                    return .single(nil)
                }

                var signal: Signal<Api.stories.Stories?, MTRpcError>
                var additionalFolders: Signal<Api.stories.Albums?, MTRpcError> = .single(nil)
                if let folderId {
                    signal = account.network.request(Api.functions.stories.getAlbumStories(peer: inputPeer, albumId: Int32(clamping: folderId), offset: Int32(loadMoreToken), limit: Int32(limit))) |> map(Optional.init)
                } else {
                    if isArchived {
                        signal = account.network.request(Api.functions.stories.getStoriesArchive(peer: inputPeer, offsetId: Int32(loadMoreToken), limit: Int32(limit))) |> map(Optional.init)
                    } else {
                        signal = account.network.request(Api.functions.stories.getPinnedStories(peer: inputPeer, offsetId: Int32(loadMoreToken), limit: Int32(limit))) |> map(Optional.init)
                        additionalFolders = account.network.request(Api.functions.stories.getAlbums(peer: inputPeer, hash: 0))
                        |> map(Optional.init)
                    }
                }

                #if DEBUG
                if folderId != nil {
                    //signal = signal |> delay(2.0, queue: queue)
                }
                #endif

                return combineLatest(
                    signal
                    |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
                        return .single(nil)
                    },
                    additionalFolders
                    |> `catch` { _ -> Signal<Api.stories.Albums?, NoError> in
                        return .single(nil)
                    }
                )
                |> mapToSignal { result, updatedFolders -> Signal<Page?, NoError> in
                    guard let result else {
                        return .single(nil)
                    }

                    return account.postbox.transaction { transaction -> Page? in
                        var storyItems: [State.Item] = []
                        var totalCount: Int = 0
                        var nextOffset: Int?
                        var resultPinnedIds: [Int32]?
                        var folderItems: [State.Folder] = []
                        var foldersChanged = false

                        if let updatedFolders {
                            switch updatedFolders {
                            case let .albums(albumsData):
                                foldersChanged = true
                                let albums = albumsData.albums
                                for album in albums {
                                    switch album {
                                    case let .storyAlbum(storyAlbumData):
                                        let (albumId, title, iconPhoto, iconVideo) = (storyAlbumData.albumId, storyAlbumData.title, storyAlbumData.iconPhoto, storyAlbumData.iconVideo)
                                        let _ = iconPhoto
                                        let _ = iconVideo
                                        folderItems.append(State.Folder(
                                            id: Int64(albumId),
                                            title: title
                                        ))
                                    }
                                }
                            case .albumsNotModified:
                                break
                            }
                        } else if !isArchived {
                            let key = ValueBoxKey(length: 8 + 1)
                            key.setInt64(0, value: peerId.toInt64())
                            key.setInt8(8, value: 0)

                            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))?.get(CachedPeerStoryListHead.self) {
                                folderItems = cached.folders
                            }
                        }

                        switch result {
                        case let .stories(storiesData):
                            let (count, stories, pinnedStories, chats, users) = (storiesData.count, storiesData.stories, storiesData.pinnedToTop, storiesData.chats, storiesData.users)
                            totalCount = Int(count)
                            if stories.count >= limit {
                                if folderId != nil {
                                    let offset = loadMoreToken + stories.count
                                    if offset <= Int(Int32.max) { nextOffset = offset }
                                } else if let lastId = stories.last?.id, lastId > 0, Int(lastId) != loadMoreToken {
                                    nextOffset = Int(lastId)
                                }
                            }
                            let pinnedIds = pinnedStories ?? []
                            resultPinnedIds = loadMoreToken == 0 ? pinnedIds : pinnedStories

                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: users))

                            for story in stories {
                                if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                    if case let .item(item) = storedItem, let media = item.media {
                                        let mappedItem = EngineStoryItem(
                                            id: item.id,
                                            timestamp: item.timestamp,
                                            expirationTimestamp: item.expirationTimestamp,
                                            media: EngineMedia(media),
                                            alternativeMediaList: item.alternativeMediaList.map(EngineMedia.init),
                                            mediaAreas: item.mediaAreas,
                                            text: item.text,
                                            entities: item.entities,
                                            views: item.views.flatMap { views in
                                                return EngineStoryItem.Views(
                                                    seenCount: views.seenCount,
                                                    reactedCount: views.reactedCount,
                                                    forwardCount: views.forwardCount,
                                                    seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                                        return transaction.getPeer(id).flatMap(EnginePeer.init)
                                                    },
                                                    reactions: views.reactions,
                                                    hasList: views.hasList
                                                )
                                            },
                                            privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                            isPinned: item.isPinned,
                                            isExpired: item.isExpired,
                                            isPublic: item.isPublic,
                                            isPending: false,
                                            isCloseFriends: item.isCloseFriends,
                                            isContacts: item.isContacts,
                                            isSelectedContacts: item.isSelectedContacts,
                                            isForwardingDisabled: item.isForwardingDisabled,
                                            isEdited: item.isEdited,
                                            isMy: item.isMy,
                                            myReaction: item.myReaction,
                                            forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, transaction: transaction) },
                                            music: item.music.flatMap(EngineMedia.init),
                                            author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) },
                                            folderIds: item.folderIds
                                        )
                                        let mappedEntry = State.Item(id: StoryId(peerId: peerId, id: mappedItem.id), storyItem: mappedItem, peer: nil)
                                        if let index = storyItems.firstIndex(where: { $0.id == mappedEntry.id }) {
                                            storyItems[index] = mappedEntry
                                        } else {
                                            storyItems.append(mappedEntry)
                                        }
                                    }
                                }
                            }

                            if loadMoreToken == 0 {
                                let key: ValueBoxKey
                                if let folderId {
                                    key = ValueBoxKey(length: 8 + 1 + 8)
                                    key.setInt64(0, value: peerId.toInt64())
                                    key.setInt8(8, value: isArchived ? 1 : 0)
                                    key.setInt64(8 + 1, value: folderId)
                                } else {
                                    key = ValueBoxKey(length: 8 + 1)
                                    key.setInt64(0, value: peerId.toInt64())
                                    key.setInt8(8, value: isArchived ? 1 : 0)
                                }
                                if let entry = CodableEntry(CachedPeerStoryListHead(items: storyItems.prefix(100).map { .item($0.storyItem.asStoryItem()) }, pinnedIds: pinnedIds, totalCount: count, folders: folderId == nil ? folderItems : [])) {
                                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key), entry: entry)
                                }
                            } else if folderId == nil && updatedFolders != nil {
                                let key = ValueBoxKey(length: 8 + 1)
                                key.setInt64(0, value: peerId.toInt64())
                                key.setInt8(8, value: 0)

                                if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))?.get(CachedPeerStoryListHead.self) {
                                    if let entry = CodableEntry(CachedPeerStoryListHead(items: cached.items, pinnedIds: cached.pinnedIds, totalCount: cached.totalCount, folders: folderItems)) {
                                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key), entry: entry)
                                    }
                                }
                            }
                        }

                        var entityIds = Set<MediaId>()
                        for item in storyItems {
                            entityIds.formUnion(_internal_storyEntityFileIds(entities: item.storyItem.entities, mediaAreas: item.storyItem.mediaAreas))
                        }
                        let entityFiles = _internal_storyEntityFiles(ids: entityIds, transaction: transaction)
                        return Page(items: storyItems, totalCount: totalCount, peerReference: transaction.getPeer(peerId).flatMap(PeerReference.init), folders: foldersChanged ? folderItems : nil, pinnedIds: resultPinnedIds, nextOffset: nextOffset, entityFiles: entityFiles)
                    }
                }
            }
            |> deliverOn(queue)).start(next: { [weak self] page in
                self?.finishLoading(operationId: operationId, token: loadMoreToken, page: page)
            }, completed: { [weak self] in
                self?.finishLoading(operationId: operationId, token: loadMoreToken, page: nil)
            }))
        }

        private func finishLoading(operationId: UUID, token: Int, page: Page?) {
            guard self.loadOperationId == operationId else { return }
            let callbacks = self.completionCallbacksByToken.removeValue(forKey: AnyHashable(token)) ?? []
            self.loadOperationId = nil
            self.isLoadingMore = false
            var updatedState = self.stateValue
            updatedState.isLoading = false
            if let page {
                if updatedState.isCached {
                    updatedState.items.removeAll()
                    updatedState.isCached = false
                }
                updatedState.hasCache = true
                for item in page.items {
                    if let index = updatedState.items.firstIndex(where: { $0.id == item.id }) {
                        updatedState.items[index] = item
                    } else {
                        updatedState.items.append(item)
                    }
                }
                if let folders = page.folders { updatedState.availableFolders = folders }
                if let pinnedIds = page.pinnedIds { updatedState.pinnedIds = pinnedIds }
                if let peerReference = page.peerReference { updatedState.peerReference = peerReference }
                if self.folderId == nil {
                    updatedState.items.sort { lhs, rhs in
                        let lhsPinned = updatedState.pinnedIds.firstIndex(of: lhs.storyItem.id)
                        let rhsPinned = updatedState.pinnedIds.firstIndex(of: rhs.storyItem.id)
                        if let lhsPinned, let rhsPinned, lhsPinned != rhsPinned { return lhsPinned < rhsPinned }
                        if (lhsPinned == nil) != (rhsPinned == nil) { return lhsPinned != nil }
                        return lhs.storyItem.timestamp > rhs.storyItem.timestamp
                    }
                }
                updatedState.loadMoreToken = page.nextOffset.map(AnyHashable.init)
                updatedState.totalCount = page.nextOffset == nil ? updatedState.items.count : max(page.totalCount, updatedState.items.count)
                updatedState.allEntityFiles.merge(page.entityFiles, uniquingKeysWith: { _, current in current })
                updatedState.allEntityFiles = _internal_prunedStoryEntityFiles(updatedState.allEntityFiles, items: updatedState.items)
            }
            self.stateValue = updatedState
            self.subscribeToStoryUpdates()
            for callback in callbacks { callback() }
        }

        private func beginStoryUpdate() {
            self.pendingUpdateCount += 1
            guard self.loadOperationId != nil else { return }
            let callbacks = self.completionCallbacksByToken.values.flatMap { $0 }
            self.completionCallbacksByToken.removeAll()
            if !callbacks.isEmpty { self.completionCallbacksByToken[AnyHashable(0)] = callbacks }
            self.loadOperationId = nil
            self.isLoadingMore = false
            self.loadAfterUpdates = true
            self.requestDisposable.set(nil)
            var state = self.stateValue
            state.isCached = true
            state.isLoading = false
            state.loadMoreToken = AnyHashable(0)
            self.stateValue = state
        }

        private func finishStoryUpdate() {
            self.pendingUpdateCount = max(0, self.pendingUpdateCount - 1)
            if self.pendingUpdateCount == 0, self.isInitialized, self.loadAfterUpdates {
                self.loadMore(completion: nil)
            }
        }

        private func subscribeToStoryUpdates() {
            guard self.updatesDisposable == nil else { return }
            let updatesDisposable = MetaDisposable()
            self.updatesDisposable = updatesDisposable
            let account = self.account
            let queue = self.queue
            let selfPeerId = self.peerId
            let selfFolderId = self.folderId
            let isArchived = self.isArchived
            let initializationPromise = self.initializationPromise
            updatesDisposable.set((account.stateManager.storyUpdates
            |> filter { updates in
                return updates.contains { update in
                    switch update {
                    case let .added(peerId, _), let .deleted(peerId, _), let .updateAlbumMembership(peerId, _, _, _), let .updateViews(peerId, _), let .updateMyReaction(peerId, _, _):
                        return peerId == selfPeerId
                    case let .updatePinnedToTopList(peerId, _):
                        return peerId == selfPeerId && !isArchived
                    case let .updateAlbumOrder(peerId, albumId):
                        return peerId == selfPeerId && selfFolderId == albumId
                    default:
                        return false
                    }
                }
            }
            |> deliverOn(queue)
            |> beforeNext { [weak self] _ in self?.beginStoryUpdate() }
            |> mapToQueue { [weak self] updates -> Signal<Never, NoError> in
                return initializationPromise.get()
                |> filter { $0 }
                |> take(1)
                |> mapToSignal { _ in
                    return account.postbox.transaction { transaction -> ([PeerId: Peer], [MediaId: TelegramMediaFile]) in
                        var peers: [PeerId: Peer] = [:]
                        var entityIds = Set<MediaId>()
                        for update in updates {
                            switch update {
                            case let .updateViews(peerId, views):
                                guard peerId == selfPeerId else { continue }
                                for view in views.values {
                                    for id in view.seenPeerIds {
                                        if let peer = transaction.getPeer(id) { peers[id] = peer }
                                    }
                                }
                            case let .added(peerId, item):
                                if selfPeerId == peerId {
                                    if case let .item(item) = item {
                                        entityIds.formUnion(_internal_storyEntityFileIds(entities: item.entities, mediaAreas: item.mediaAreas))
                                        if let views = item.views {
                                            for id in views.seenPeerIds {
                                                if let peer = transaction.getPeer(id) {
                                                    peers[peer.id] = peer
                                                }
                                            }
                                        }
                                        if let forwardInfo = item.forwardInfo, case let .known(peerId, _, _) = forwardInfo {
                                            if let peer = transaction.getPeer(peerId) {
                                                peers[peer.id] = peer
                                            }
                                        }
                                        if let peerId = item.authorId {
                                            if let peer = transaction.getPeer(peerId) {
                                                peers[peer.id] = peer
                                            }
                                        }
                                    }
                                }
                            default:
                                break
                            }
                        }

                        return (peers, _internal_storyEntityFiles(ids: entityIds, transaction: transaction))
                    }
                }
                |> deliverOn(queue)
                |> mapToSignal { [weak self] peers, entityFiles -> Signal<Never, NoError> in
                    guard let self else { return .complete() }
                    var state = self.stateValue
                    var changed = false
                    var reloadAlbum = false
                    var invalidateAlbumCache = false
                    var membershipOnly = true
                    var hasStructuralUpdate = false
                    for update in updates {
                        switch update {
                        case let .deleted(peerId, id):
                            guard peerId == self.peerId else { continue }
                            membershipOnly = false
                            hasStructuralUpdate = true
                            if let index = state.items.firstIndex(where: { $0.storyItem.id == id }) {
                                state.items.remove(at: index)
                                state.totalCount = max(0, state.totalCount - 1)
                                changed = true
                            }
                            if state.pinnedIds.contains(id) {
                                state.pinnedIds.removeAll(where: { $0 == id })
                                changed = true
                            }
                            reloadAlbum = reloadAlbum || self.folderId != nil
                        case let .added(peerId, storedItem):
                            guard peerId == self.peerId, case let .item(item) = storedItem else { continue }
                            membershipOnly = false
                            hasStructuralUpdate = true
                            let index = state.items.firstIndex(where: { $0.storyItem.id == item.id })
                            let belongs: Bool
                            if let folderId = self.folderId {
                                belongs = item.folderIds.map { $0.contains(folderId) } ?? (index != nil)
                            } else {
                                belongs = self.isArchived || item.isPinned
                            }
                            if !belongs {
                                if let index {
                                    state.items.remove(at: index)
                                    state.totalCount = max(0, state.totalCount - 1)
                                    changed = true
                                    reloadAlbum = reloadAlbum || self.folderId != nil
                                }
                                if self.folderId == nil && !self.isArchived && state.pinnedIds.contains(item.id) {
                                    state.pinnedIds.removeAll(where: { $0 == item.id })
                                    changed = true
                                }
                                continue
                            }
                            if self.folderId != nil && index == nil {
                                reloadAlbum = true
                                continue
                            }
                            guard let media = item.media else { continue }
                            let mappedItem = State.Item(id: StoryId(peerId: peerId, id: item.id), storyItem: EngineStoryItem(
                                id: item.id,
                                timestamp: item.timestamp,
                                expirationTimestamp: item.expirationTimestamp,
                                media: EngineMedia(media),
                                alternativeMediaList: item.alternativeMediaList.map(EngineMedia.init),
                                mediaAreas: item.mediaAreas,
                                text: item.text,
                                entities: item.entities,
                                views: item.views.flatMap { views in
                                    return EngineStoryItem.Views(
                                        seenCount: views.seenCount,
                                        reactedCount: views.reactedCount,
                                        forwardCount: views.forwardCount,
                                        seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                            return peers[id].flatMap(EnginePeer.init)
                                        },
                                        reactions: views.reactions,
                                        hasList: views.hasList
                                    )
                                },
                                privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                isPinned: item.isPinned,
                                isExpired: item.isExpired,
                                isPublic: item.isPublic,
                                isPending: false,
                                isCloseFriends: item.isCloseFriends,
                                isContacts: item.isContacts,
                                isSelectedContacts: item.isSelectedContacts,
                                isForwardingDisabled: item.isForwardingDisabled,
                                isEdited: item.isEdited,
                                isMy: item.isMy,
                                myReaction: item.myReaction,
                                forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, peers: peers) },
                                music: item.music.flatMap(EngineMedia.init),
                                author: item.authorId.flatMap { peers[$0].flatMap(EnginePeer.init) },
                                folderIds: item.folderIds
                            ), peer: nil)
                            if let index {
                                state.items[index] = mappedItem
                            } else {
                                state.items.append(mappedItem)
                                state.totalCount = state.loadMoreToken == nil ? state.items.count : max(state.totalCount, state.items.count)
                            }
                            changed = true
                        case let .updateMyReaction(peerId, id, reaction):
                            guard peerId == self.peerId else { continue }
                            for index in state.items.indices {
                                let item = state.items[index]
                                guard item.id == StoryId(peerId: peerId, id: id), item.storyItem.id == id, item.storyItem.myReaction != reaction else { continue }
                                state.items[index] = State.Item(id: item.id, storyItem: _internal_engineStoryWithReaction(item.storyItem, isChannel: peerId.namespace == Namespaces.Peer.CloudChannel, reaction: reaction), peer: item.peer)
                                changed = true
                            }
                        case let .updateViews(peerId, views):
                            guard peerId == self.peerId else { continue }
                            for index in state.items.indices {
                                let item = state.items[index]
                                guard item.id.peerId == peerId, let value = views[item.id.id], item.storyItem.id == item.id.id else { continue }
                                let mapped = _internal_mappedStoryViews(value, peers: peers)
                                if item.storyItem.views != mapped {
                                    state.items[index] = State.Item(id: item.id, storyItem: _internal_engineStoryWithViews(item.storyItem, views: mapped), peer: item.peer)
                                    changed = true
                                }
                            }
                        case let .updateAlbumOrder(peerId, albumId):
                            guard peerId == self.peerId, self.folderId == albumId else { continue }
                            reloadAlbum = true
                            invalidateAlbumCache = true
                        case let .updateAlbumMembership(peerId, albumId, added, removed):
                            guard peerId == self.peerId else { continue }
                            hasStructuralUpdate = true
                            let addedIds = Set(added)
                            let removedIds = Set(removed)
                            for index in state.items.indices {
                                let item = state.items[index]
                                guard addedIds.contains(item.id.id) || removedIds.contains(item.id.id) else { continue }
                                let folderIds = _internal_storyFolderIds(item.storyItem.folderIds, albumId: albumId, isMember: addedIds.contains(item.id.id))
                                if folderIds != item.storyItem.folderIds {
                                    state.items[index] = State.Item(id: item.id, storyItem: _internal_engineStoryWithFolderIds(item.storyItem, folderIds: folderIds), peer: item.peer)
                                    changed = true
                                }
                            }
                            if self.folderId == albumId, !added.isEmpty || !removed.isEmpty {
                                let previousCount = state.items.count
                                state.items.removeAll(where: { removedIds.contains($0.id.id) })
                                state.totalCount = max(state.items.count, state.totalCount - (previousCount - state.items.count))
                                reloadAlbum = true
                                invalidateAlbumCache = true
                            }
                        case let .updatePinnedToTopList(peerId, ids):
                            guard peerId == self.peerId, !self.isArchived else { continue }
                            membershipOnly = false
                            hasStructuralUpdate = true
                            if state.pinnedIds != ids {
                                state.pinnedIds = ids
                                changed = true
                            }
                        default:
                            break
                        }
                    }
                    if changed && hasStructuralUpdate {
                        if self.folderId == nil {
                            state.items.sort { lhs, rhs in
                                let lhsPinned = state.pinnedIds.firstIndex(of: lhs.storyItem.id)
                                let rhsPinned = state.pinnedIds.firstIndex(of: rhs.storyItem.id)
                                if let lhsPinned, let rhsPinned, lhsPinned != rhsPinned { return lhsPinned < rhsPinned }
                                if (lhsPinned == nil) != (rhsPinned == nil) { return lhsPinned != nil }
                                return lhs.storyItem.timestamp > rhs.storyItem.timestamp
                            }
                        }
                    }
                    if reloadAlbum {
                        self.loadOperationId = nil
                        self.isLoadingMore = true
                        self.requestDisposable.set(nil)
                        state.isCached = true
                        state.isLoading = true
                        state.loadMoreToken = AnyHashable(0)
                    }
                    guard changed || reloadAlbum else { return .complete() }
                    state.allEntityFiles.merge(entityFiles, uniquingKeysWith: { _, current in current })
                    state.allEntityFiles = _internal_prunedStoryEntityFiles(state.allEntityFiles, items: state.items)
                    self.stateValue = state
                    guard hasStructuralUpdate || reloadAlbum else { return .complete() }
                    let peerId = self.peerId
                    let isArchived = self.isArchived
                    let folderId = self.folderId
                    return account.postbox.transaction { transaction in
                        let key = ValueBoxKey(length: 8 + 1 + (folderId == nil ? 0 : 8))
                        key.setInt64(0, value: peerId.toInt64())
                        key.setInt8(8, value: isArchived ? 1 : 0)
                        if let folderId { key.setInt64(9, value: folderId) }
                        if invalidateAlbumCache {
                            transaction.removeItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))
                        } else if membershipOnly {
                            let cacheId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key)
                            if let cached = transaction.retrieveItemCacheEntry(id: cacheId)?.get(CachedPeerStoryListHead.self) {
                                var items = cached.items
                                for case let .updateAlbumMembership(updatedPeerId, albumId, added, removed) in updates where updatedPeerId == peerId {
                                    let addedIds = Set(added)
                                    let removedIds = Set(removed)
                                    items = items.map { stored in
                                        guard case let .item(item) = stored, addedIds.contains(item.id) || removedIds.contains(item.id) else { return stored }
                                        let folderIds = _internal_storyFolderIds(item.folderIds, albumId: albumId, isMember: addedIds.contains(item.id))
                                        return .item(_internal_storyWithFolderIds(item, folderIds: folderIds))
                                    }
                                }
                                if let entry = CodableEntry(CachedPeerStoryListHead(items: items, pinnedIds: cached.pinnedIds, totalCount: cached.totalCount, folders: cached.folders)) {
                                    transaction.putItemCacheEntry(id: cacheId, entry: entry)
                                }
                            }
                        } else if let entry = CodableEntry(CachedPeerStoryListHead(items: state.items.prefix(100).map { .item($0.storyItem.asStoryItem()) }, pinnedIds: state.pinnedIds, totalCount: Int32(state.totalCount), folders: folderId == nil ? state.availableFolders : [])) {
                            transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key), entry: entry)
                        }
                    }
                    |> deliverOn(queue)
                    |> afterNext { [weak self] _ in
                        if reloadAlbum { self?.reloadAlbumStories() }
                    }
                    |> ignoreValues
                }
                |> afterCompleted { [weak self] in self?.finishStoryUpdate() }
            }).start())
        }

        private func reloadAlbumStories(removingIds: [Int32] = []) {
            guard self.folderId != nil else { return }
            let callbacks = self.completionCallbacksByToken.values.flatMap { $0 }
            self.completionCallbacksByToken.removeAll()
            self.loadOperationId = nil
            self.isLoadingMore = false
            self.requestDisposable.set(nil)
            var state = self.stateValue
            let removedIds = Set(removingIds)
            let previousCount = state.items.count
            state.items.removeAll(where: { removedIds.contains($0.id.id) })
            state.allEntityFiles = _internal_prunedStoryEntityFiles(state.allEntityFiles, items: state.items)
            state.totalCount = max(state.items.count, state.totalCount - (previousCount - state.items.count))
            state.isCached = true
            state.isLoading = false
            state.loadMoreToken = AnyHashable(0)
            self.stateValue = state
            self.loadMore(completion: {
                for callback in callbacks { callback() }
            })
        }

        func addFolder(title: String, items: [EngineStoryItem], completion: @escaping (Int64?) -> Void) -> Disposable {
            return (_internal_createStoryFolder(account: self.account, peerId: self.peerId, title: title, items: items)
            |> deliverOn(self.queue)
            |> beforeNext { [weak self] folder in
                guard let self else {
                    return
                }
                if let folder {
                    var state = self.stateValue
                    if let index = state.availableFolders.firstIndex(where: { $0.id == folder.id }) {
                        state.availableFolders[index] = folder
                    } else {
                        state.availableFolders.append(folder)
                    }
                    self.stateValue = state
                }
            }).start(next: { [weak self] folder in
                guard self != nil else {
                    return
                }
                completion(folder?.id)
            })
        }

        private func updateFolder(id: Int64, title: String?, completion: @escaping (Bool) -> Void) -> Disposable {
            return (_internal_updateStoryFolder(account: self.account, peerId: self.peerId, id: id, title: title)
            |> deliverOn(self.queue)
            |> beforeNext { [weak self] result in
                guard let self, let result else { return }
                var state = self.stateValue
                switch result {
                case .deleted:
                    state.availableFolders.removeAll(where: { $0.id == id })
                case let .renamed(folder):
                    if let index = state.availableFolders.firstIndex(where: { $0.id == id }) {
                        state.availableFolders[index] = folder
                    }
                }
                self.stateValue = state
            }).start(next: { [weak self] result in
                guard self != nil else { return }
                completion(result != nil)
            })
        }

        func removeFolder(id: Int64, completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
            return self.updateFolder(id: id, title: nil, completion: completion)
        }

        func renameFolder(id: Int64, title: String, completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
            return self.updateFolder(id: id, title: title, completion: completion)
        }

        func reorderFolders(ids: [Int64], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
            return (_internal_reorderStoryFolders(account: self.account, peerId: self.peerId, ids: ids)
            |> deliverOn(self.queue)
            |> beforeNext { [weak self] ids in
                guard let self, let ids else { return }
                var state = self.stateValue
                state.availableFolders = _internal_reorderedStoryFolders(state.availableFolders, ids: ids)
                self.stateValue = state
            }).start(next: { [weak self] ids in
                guard self != nil else { return }
                completion(ids != nil)
            })
        }

        func updateFolderStories(id: Int64, added: [EngineStoryItem], removed: [Int32], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
            self.subscribeToStoryUpdates()
            return (_internal_updateStoryFolderItems(account: self.account, peerId: self.peerId, id: id, added: added, removed: removed)
            |> deliverOn(self.queue)).start(next: { [weak self] success in
                guard self != nil else { return }
                completion(success)
            })
        }

        func addToFolder(id: Int64, items: [EngineStoryItem], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
            return self.updateFolderStories(id: id, added: items, removed: [], completion: completion)
        }

        func removeFromFolder(id: Int64, itemIds: [Int32], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
            return self.updateFolderStories(id: id, added: [], removed: itemIds, completion: completion)
        }

        func reorderItemsInFolder(itemIds: [Int32], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
            guard let folderId = self.folderId else {
                completion(false)
                return EmptyDisposable
            }
            self.subscribeToStoryUpdates()
            return (_internal_reorderStoryFolderItems(account: self.account, peerId: self.peerId, id: folderId, itemIds: itemIds)
            |> deliverOn(self.queue)).start(next: { [weak self] success in
                guard self != nil else { return }
                completion(success)
            })
        }

    }
    
    public var state: Signal<State, NoError> {
        return impl.signalWith { impl, subscriber in
            return impl.state.start(next: subscriber.putNext)
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    private let account: Account
    public let peerId: EnginePeer.Id
    public let folderId: Int64?
    
    public init(account: Account, peerId: EnginePeer.Id, isArchived: Bool, folderId: Int64?) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.account = account
        self.peerId = peerId
        self.folderId = folderId
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, isArchived: isArchived, folderId: folderId)
        })
    }
    
    public func loadMore(completion: (() -> Void)? = nil) {
        self.impl.with { impl in
            impl.loadMore(completion : completion)
        }
    }
    
    public func addFolder(title: String, items: [EngineStoryItem], completion: @escaping (Int64?) -> Void) -> Disposable {
        let disposable = MetaDisposable()
        self.impl.with { impl in
            disposable.set(impl.addFolder(title: title, items: items, completion: completion))
        }
        return disposable
    }
    
    public func removeFolder(id: Int64, completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
        let disposable = MetaDisposable()
        self.impl.with { impl in
            disposable.set(impl.removeFolder(id: id, completion: completion))
        }
        return disposable
    }
    
    public func renameFolder(id: Int64, title: String, completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
        let disposable = MetaDisposable()
        self.impl.with { impl in
            disposable.set(impl.renameFolder(id: id, title: title, completion: completion))
        }
        return disposable
    }
    
    public func reorderFolders(ids: [Int64], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
        let disposable = MetaDisposable()
        self.impl.with { impl in
            disposable.set(impl.reorderFolders(ids: ids, completion: completion))
        }
        return disposable
    }
    
    public func updateFolderStories(id: Int64, added: [EngineStoryItem], removed: [Int32], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
        let disposable = MetaDisposable()
        self.impl.with { impl in
            disposable.set(impl.updateFolderStories(id: id, added: added, removed: removed, completion: completion))
        }
        return disposable
    }

    public func addToFolder(id: Int64, items: [EngineStoryItem], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
        let disposable = MetaDisposable()
        self.impl.with { impl in
            disposable.set(impl.addToFolder(id: id, items: items, completion: completion))
        }
        return disposable
    }
    
    public func removeFromFolder(id: Int64, itemIds: [Int32], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
        let disposable = MetaDisposable()
        self.impl.with { impl in
            disposable.set(impl.removeFromFolder(id: id, itemIds: itemIds, completion: completion))
        }
        return disposable
    }
    
    public func reorderItemsInFolder(itemIds: [Int32], completion: @escaping (Bool) -> Void = { _ in }) -> Disposable {
        let disposable = MetaDisposable()
        self.impl.with { impl in
            disposable.set(impl.reorderItemsInFolder(itemIds: itemIds, completion: completion))
        }
        return disposable
    }
    
    public static func addFolderExternal(account: Account, peerId: PeerId, title: String, completion: @escaping (Int64?) -> Void) -> Disposable {
        return _internal_createStoryFolder(account: account, peerId: peerId, title: title, items: []).start(next: { folder in
            completion(folder?.id)
        })
    }

    public static func folderPreviews(peerId: EnginePeer.Id, account: Account) -> Signal<(peer: PeerReference, [(folder: StoryListContext.State.Folder, item: EngineStoryItem?)]), NoError> {
        return account.postbox.transaction { transaction -> (peer: PeerReference, [(folder: StoryListContext.State.Folder, item: EngineStoryItem?)]) in
            let key = ValueBoxKey(length: 8 + 1)
            key.setInt64(0, value: peerId.toInt64())
            key.setInt8(8, value: 0)
            
            var folders: [StoryListContext.State.Folder] = []
            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))?.get(CachedPeerStoryListHead.self) {
                folders = cached.folders
            }
            
            var result: [(folder: StoryListContext.State.Folder, item: EngineStoryItem?)] = []
            
            for folder in folders {
                let key = ValueBoxKey(length: 8 + 1 + 8)
                key.setInt64(0, value: peerId.toInt64())
                key.setInt8(8, value: 0)
                key.setInt64(8 + 1, value: folder.id)
                
                var mappedItem: EngineStoryItem?
                if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))?.get(CachedPeerStoryListHead.self) {
                    if let firstItem = cached.items.first, case let .item(item) = firstItem, let media = item.media {
                        mappedItem = EngineStoryItem(
                            id: item.id,
                            timestamp: item.timestamp,
                            expirationTimestamp: item.expirationTimestamp,
                            media: EngineMedia(media),
                            alternativeMediaList: item.alternativeMediaList.map(EngineMedia.init),
                            mediaAreas: item.mediaAreas,
                            text: item.text,
                            entities: item.entities,
                            views: item.views.flatMap { views in
                                return EngineStoryItem.Views(
                                    seenCount: views.seenCount,
                                    reactedCount: views.reactedCount,
                                    forwardCount: views.forwardCount,
                                    seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                        return transaction.getPeer(id).flatMap(EnginePeer.init)
                                    },
                                    reactions: views.reactions,
                                    hasList: views.hasList
                                )
                            },
                            privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                            isPinned: item.isPinned,
                            isExpired: item.isExpired,
                            isPublic: item.isPublic,
                            isPending: false,
                            isCloseFriends: item.isCloseFriends,
                            isContacts: item.isContacts,
                            isSelectedContacts: item.isSelectedContacts,
                            isForwardingDisabled: item.isForwardingDisabled,
                            isEdited: item.isEdited,
                            isMy: item.isMy,
                            myReaction: item.myReaction,
                            forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, transaction: transaction) },
                            music: item.music.flatMap(EngineMedia.init),
                            author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) },
                            folderIds: item.folderIds
                        )
                    }
                }
                
                result.append((folder, mappedItem))
            }
            
            let peerReference: PeerReference
            if let peer = transaction.getPeer(peerId) {
                peerReference = PeerReference(peer) ?? .user(id: peerId.id._internalGetInt64Value(), accessHash: 0)
            } else {
                peerReference = .user(id: peerId.id._internalGetInt64Value(), accessHash: 0)
            }
            
            return (peerReference, result)
        }
    }
    
    public static func cachedFolderState(peerId: EnginePeer.Id, account: Account, folderId: Int64) -> Signal<(count: Int, ids: [Int32])?, NoError> {
        return account.postbox.transaction { transaction -> (count: Int, ids: [Int32])? in
            let key = ValueBoxKey(length: 8 + 1 + 8)
            key.setInt64(0, value: peerId.toInt64())
            key.setInt8(8, value: 0)
            key.setInt64(8 + 1, value: folderId)
            
            if let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))?.get(CachedPeerStoryListHead.self) {
                return (Int(cached.totalCount), cached.items.map(\.id))
            } else {
                return nil
            }
        }
    }
}

public final class SearchStoryListContext: StoryListContext {
    public enum Source {
        case hashtag(EnginePeer.Id?, String)
        case mediaArea(MediaArea)
    }
    
    private final class Impl {
        private struct Page {
            let items: [State.Item]
            let totalCount: Int
            let nextOffset: String?
            let entityFiles: [MediaId: TelegramMediaFile]
        }

        private struct PendingPage {
            let id: UUID
            let token: String
            let page: Page?
        }

        private struct UpdateBatch {
            let updates: [InternalStoryUpdate]
            let peers: [PeerId: Peer]
            let entityFiles: [MediaId: TelegramMediaFile]
        }

        private let queue: Queue
        private let account: Account
        private let source: Source
        private let statePromise = Promise<State>()
        private var stateValue: State {
            didSet { self.statePromise.set(.single(self.stateValue)) }
        }
        var state: Signal<State, NoError> { self.statePromise.get() }
        private var isLoadingMore = false
        private let requestDisposable = MetaDisposable()
        private var updatesDisposable: Disposable?
        private var loadOperationId: UUID?
        private var pendingPage: PendingPage?
        private var pageUpdates: [UpdateBatch] = []
        private var consumedOffsets = Set<String>()
        private var pendingUpdateCount = 0
        private var completionCallbacksByToken: [AnyHashable: [() -> Void]] = [:]

        init(queue: Queue, account: Account, source: Source) {
            self.queue = queue
            self.account = account
            self.source = source
            self.stateValue = State(peerReference: nil, items: [], availableLanguages: [], availableFolders: [], pinnedIds: [], totalCount: 0, loadMoreToken: AnyHashable(""), isCached: false, hasCache: false, allEntityFiles: [:], isLoading: false)
            self.statePromise.set(.single(self.stateValue))
            self.subscribeToStoryUpdates()
            self.loadMore(completion: nil)
        }

        deinit {
            self.requestDisposable.dispose()
            self.updatesDisposable?.dispose()
        }

        func loadMore(completion: (() -> Void)?) {
            guard let token = self.stateValue.loadMoreToken?.base as? String else { completion?(); return }
            if let completion { self.completionCallbacksByToken[AnyHashable(token), default: []].append(completion) }
            guard !self.isLoadingMore else { return }
            self.isLoadingMore = true
            let operationId = UUID()
            self.loadOperationId = operationId
            self.pendingPage = nil
            self.pageUpdates.removeAll()
            self.stateValue.isLoading = true
            let postbox = self.account.postbox
            let network = self.account.network
            let accountPeerId = self.account.peerId
            var searchHashtag: String?
            var area: Api.MediaArea?
            var peer: Signal<Api.InputPeer?, NoError> = .single(nil)
            var flags: Int32 = 0
            switch self.source {
            case let .hashtag(peerId, query):
                searchHashtag = query.hasPrefix("#") ? String(query.dropFirst()) : query
                flags |= 1 << 0
                if let peerId {
                    peer = postbox.transaction { transaction in transaction.getPeer(peerId).flatMap(apiInputPeer) }
                    flags |= 1 << 2
                }
            case let .mediaArea(mediaArea):
                area = apiMediaAreasFromMediaAreas([mediaArea], transaction: nil).first
                flags |= 1 << 1
            }
            let disposable = MetaDisposable()
            self.requestDisposable.set(disposable)
            disposable.set((peer
            |> mapToSignal { inputPeer -> Signal<Api.stories.FoundStories?, NoError> in
                if flags & (1 << 2) != 0 && inputPeer == nil { return .single(nil) }
                if flags & (1 << 1) != 0 && area == nil { return .single(nil) }
                return network.request(Api.functions.stories.searchPosts(flags: flags, hashtag: searchHashtag, area: area, peer: inputPeer, offset: token, limit: 100))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stories.FoundStories?, NoError> in .single(nil) }
                |> then(.single(nil))
                |> take(1)
            }
            |> mapToSignal { result -> Signal<Page?, NoError> in
                guard let result else { return .single(nil) }
                return postbox.transaction { transaction -> Page? in
                    var storyItems: [State.Item] = []
                    var totalCount = 0
                    var nextOffsetValue: String?
                    switch result {
                    case let .foundStories(data):
                        let (count, stories, nextOffset, chats, users) = (data.count, data.stories, data.nextOffset, data.chats, data.users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: users))
                        totalCount = Int(count)
                        nextOffsetValue = nextOffset
                        for story in stories {
                            switch story {
                            case let .foundStory(foundStoryData):
                                let (peer, story) = (foundStoryData.peer, foundStoryData.story)
                                if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peer.peerId, transaction: transaction) {
                                    if case let .item(item) = storedItem, let media = item.media {
                                        let mappedItem = EngineStoryItem(
                                            id: item.id,
                                            timestamp: item.timestamp,
                                            expirationTimestamp: item.expirationTimestamp,
                                            media: EngineMedia(media),
                                            alternativeMediaList: item.alternativeMediaList.map(EngineMedia.init),
                                            mediaAreas: item.mediaAreas,
                                            text: item.text,
                                            entities: item.entities,
                                            views: item.views.flatMap { views in
                                                return EngineStoryItem.Views(
                                                    seenCount: views.seenCount,
                                                    reactedCount: views.reactedCount,
                                                    forwardCount: views.forwardCount,
                                                    seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                                        return transaction.getPeer(id).flatMap(EnginePeer.init)
                                                    },
                                                    reactions: views.reactions,
                                                    hasList: views.hasList
                                                )
                                            },
                                            privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                            isPinned: item.isPinned,
                                            isExpired: item.isExpired,
                                            isPublic: item.isPublic,
                                            isPending: false,
                                            isCloseFriends: item.isCloseFriends,
                                            isContacts: item.isContacts,
                                            isSelectedContacts: item.isSelectedContacts,
                                            isForwardingDisabled: item.isForwardingDisabled,
                                            isEdited: item.isEdited,
                                            isMy: item.isMy,
                                            myReaction: item.myReaction,
                                            forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, transaction: transaction) },
                                            music: item.music.flatMap(EngineMedia.init),
                                            author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) },
                                            folderIds: item.folderIds
                                        )
                                        storyItems.append(State.Item(
                                            id: StoryId(peerId: peer.peerId, id: mappedItem.id),
                                            storyItem: mappedItem,
                                            peer: transaction.getPeer(peer.peerId).flatMap(EnginePeer.init)
                                        ))
                                    }
                                }
                            }
                        }
                    }
                    
                    let entityIds = storyItems.reduce(into: Set<MediaId>()) { ids, item in
                        ids.formUnion(_internal_storyEntityFileIds(entities: item.storyItem.entities, mediaAreas: item.storyItem.mediaAreas))
                    }
                    return Page(items: storyItems, totalCount: totalCount, nextOffset: nextOffsetValue, entityFiles: _internal_storyEntityFiles(ids: entityIds, transaction: transaction))
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] page in
                guard let self, self.loadOperationId == operationId else { return }
                self.pendingPage = PendingPage(id: operationId, token: token, page: page)
                self.finishLoadingIfReady()
            }))
        }

        private func finishLoadingIfReady() {
            guard self.pendingUpdateCount == 0, let pending = self.pendingPage, self.loadOperationId == pending.id else { return }
            self.pendingPage = nil
            self.loadOperationId = nil
            self.isLoadingMore = false
            self.requestDisposable.set(nil)
            let batches = self.pageUpdates
            self.pageUpdates.removeAll()
            let callbacks = self.completionCallbacksByToken.removeValue(forKey: AnyHashable(pending.token)) ?? []
            var state = self.stateValue
            state.isLoading = false
            if let page = pending.page {
                state.hasCache = true
                for item in page.items where item.id.id > 0 {
                    if let index = state.items.firstIndex(where: { $0.id == item.id }) { state.items[index] = item } else { state.items.append(item) }
                }
                self.consumedOffsets.insert(pending.token)
                let nextOffset = page.nextOffset.flatMap { $0.isEmpty || self.consumedOffsets.contains($0) ? nil : $0 }
                state.loadMoreToken = nextOffset.map(AnyHashable.init)
                state.totalCount = nextOffset == nil ? state.items.count : max(page.totalCount, state.items.count)
                state.allEntityFiles.merge(page.entityFiles, uniquingKeysWith: { _, current in current })
                for batch in batches {
                    if let updated = self.applyingStoryUpdates(batch, to: state) { state = updated }
                }
                state.allEntityFiles = _internal_prunedStoryEntityFiles(state.allEntityFiles, items: state.items)
            }
            self.stateValue = state
            for callback in callbacks { callback() }
        }

        private func subscribeToStoryUpdates() {
            guard self.updatesDisposable == nil else { return }
            let postbox = self.account.postbox
            let source = self.source
            self.updatesDisposable = (self.account.stateManager.storyUpdates
            |> deliverOn(self.queue)
            |> map { [weak self] updates -> (UUID?, [InternalStoryUpdate])? in
                guard let self else { return nil }
                let updates = updates.filter { update in
                    let peerId: PeerId
                    switch update {
                    case let .added(id, _), let .deleted(id, _), let .updateViews(id, _), let .updateMyReaction(id, _, _): peerId = id
                    default: return false
                    }
                    if case let .hashtag(targetPeerId?, _) = source { return peerId == targetPeerId }
                    return true
                }
                guard !updates.isEmpty else { return nil }
                self.pendingUpdateCount += 1
                return (self.loadOperationId, updates)
            }
            |> mapToQueue { [weak self] event -> Signal<Never, NoError> in
                guard let self, let (operationId, updates) = event else { return .complete() }
                return (postbox.transaction { transaction -> UpdateBatch in
                    var peerIds = Set<PeerId>()
                    var entityIds = Set<MediaId>()
                    for update in updates {
                        switch update {
                        case let .added(_, stored):
                            if case let .item(item) = stored {
                                peerIds.formUnion(item.views?.seenPeerIds ?? [])
                                if let forward = item.forwardInfo, case let .known(peerId, _, _) = forward { peerIds.insert(peerId) }
                                if let authorId = item.authorId { peerIds.insert(authorId) }
                                entityIds.formUnion(_internal_storyEntityFileIds(entities: item.entities, mediaAreas: item.mediaAreas))
                            }
                        case let .updateViews(_, views):
                            for value in views.values { peerIds.formUnion(value.seenPeerIds) }
                        default: break
                        }
                    }
                    var peers: [PeerId: Peer] = [:]
                    for id in peerIds { if let peer = transaction.getPeer(id) { peers[id] = peer } }
                    return UpdateBatch(updates: updates, peers: peers, entityFiles: _internal_storyEntityFiles(ids: entityIds, transaction: transaction))
                }
                |> deliverOn(self.queue)
                |> map { [weak self] batch in
                    guard let self else { return }
                    if let operationId, operationId == self.loadOperationId { self.pageUpdates.append(batch) }
                    if let state = self.applyingStoryUpdates(batch, to: self.stateValue) { self.stateValue = state }
                    self.pendingUpdateCount = max(0, self.pendingUpdateCount - 1)
                    self.finishLoadingIfReady()
                }
                |> ignoreValues)
            }).start()
        }

        private func applyingStoryUpdates(_ batch: UpdateBatch, to initial: State) -> State? {
            let peers = batch.peers
            let updates = batch.updates
            var finalUpdatedState: State?
            for update in updates {
                switch update {
                case let .deleted(peerId, id):
                    var updatedState = finalUpdatedState ?? initial
                    let storyId = StoryId(peerId: peerId, id: id)
                    let previousCount = updatedState.items.count
                    updatedState.items.removeAll(where: { $0.id == storyId })
                    if updatedState.items.count != previousCount {
                        updatedState.totalCount = max(updatedState.items.count, max(0, updatedState.totalCount) - 1)
                        updatedState.allEntityFiles = _internal_prunedStoryEntityFiles(updatedState.allEntityFiles, items: updatedState.items)
                        finalUpdatedState = updatedState
                    }
                case let .added(peerId, item):
                    if let index = (finalUpdatedState ?? initial).items.firstIndex(where: { $0.id == StoryId(peerId: peerId, id: item.id) }) {
                        let currentItem = (finalUpdatedState ?? initial).items[index]
                        if case let .item(item) = item, let media = item.media {
                            var updatedState = finalUpdatedState ?? initial
                            updatedState.items[index] = State.Item(
                                id: StoryId(peerId: peerId, id: item.id),
                                storyItem: EngineStoryItem(
                                    id: item.id,
                                    timestamp: item.timestamp,
                                    expirationTimestamp: item.expirationTimestamp,
                                    media: EngineMedia(media),
                                    alternativeMediaList: item.alternativeMediaList.map(EngineMedia.init),
                                    mediaAreas: item.mediaAreas,
                                    text: item.text,
                                    entities: item.entities,
                                    views: item.views.flatMap { views in
                                        return EngineStoryItem.Views(
                                            seenCount: views.seenCount,
                                            reactedCount: views.reactedCount,
                                            forwardCount: views.forwardCount,
                                            seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                                return peers[id].flatMap(EnginePeer.init)
                                            },
                                            reactions: views.reactions,
                                            hasList: views.hasList
                                        )
                                    },
                                    privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                    isPinned: item.isPinned,
                                    isExpired: item.isExpired,
                                    isPublic: item.isPublic,
                                    isPending: false,
                                    isCloseFriends: item.isCloseFriends,
                                    isContacts: item.isContacts,
                                    isSelectedContacts: item.isSelectedContacts,
                                    isForwardingDisabled: item.isForwardingDisabled,
                                    isEdited: item.isEdited,
                                    isMy: item.isMy,
                                    myReaction: item.myReaction,
                                    forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, peers: peers) },
                                    music: item.music.flatMap(EngineMedia.init),
                                    author: item.authorId.flatMap { peers[$0].flatMap(EnginePeer.init) },
                                    folderIds: item.folderIds
                                ),
                                peer: currentItem.peer
                            )
                            finalUpdatedState = updatedState
                        }
                    }
                case let .updateMyReaction(peerId, id, reaction):
                    var state = finalUpdatedState ?? initial
                    var changed = false
                    for index in state.items.indices {
                        let item = state.items[index]
                        guard item.id == StoryId(peerId: peerId, id: id), item.storyItem.id == id, item.storyItem.myReaction != reaction else { continue }
                        state.items[index] = State.Item(id: item.id, storyItem: _internal_engineStoryWithReaction(item.storyItem, isChannel: peerId.namespace == Namespaces.Peer.CloudChannel, reaction: reaction), peer: item.peer)
                        changed = true
                    }
                    if changed { finalUpdatedState = state }
                case let .updateViews(peerId, views):
                    var state = finalUpdatedState ?? initial
                    var changed = false
                    for index in state.items.indices {
                        let item = state.items[index]
                        guard item.id.peerId == peerId, item.id.id == item.storyItem.id, let value = views[item.id.id] else { continue }
                        let mapped = _internal_mappedStoryViews(value, peers: peers)
                        guard item.storyItem.views != mapped else { continue }
                        state.items[index] = State.Item(id: item.id, storyItem: _internal_engineStoryWithViews(item.storyItem, views: mapped), peer: item.peer)
                        changed = true
                    }
                    if changed { finalUpdatedState = state }
                case .read:
                    break
                case .updatePinnedToTopList, .updateAlbumMembership, .updateAlbumOrder:
                    break
                }
            }

            if var state = finalUpdatedState {
                state.allEntityFiles.merge(batch.entityFiles, uniquingKeysWith: { _, current in current })
                state.allEntityFiles = _internal_prunedStoryEntityFiles(state.allEntityFiles, items: state.items)
                return state
            }
            return nil
        }
    }
    

    public var state: Signal<State, NoError> {
        return impl.signalWith { impl, subscriber in
            return impl.state.start(next: subscriber.putNext)
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public init(account: Account, source: Source) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, source: source)
        })
    }
    
    public func loadMore(completion: (() -> Void)? = nil) {
        self.impl.with { impl in
            impl.loadMore(completion : completion)
        }
    }
}

public final class PeerExpiringStoryListContext {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let peerId: EnginePeer.Id
        
        private var listDisposable: Disposable?
        private var pollDisposable: Disposable?
        
        private let statePromise = Promise<State>()
        var state: Signal<State, NoError> {
            return self.statePromise.get()
        }
        
        private let polledOnce = ValuePromise<Bool>(false, ignoreRepeated: true)
        
        init(queue: Queue, account: Account, peerId: EnginePeer.Id) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            
            self.listDisposable = (combineLatest(queue: self.queue,
                account.postbox.combinedView(keys: [
                    PostboxViewKey.storiesState(key: .peer(peerId)),
                    PostboxViewKey.storyItems(peerId: peerId)
                ]),
                self.polledOnce.get()
            )
            |> deliverOn(self.queue)).start(next: { [weak self] views, polledOnce in
                guard let `self` = self else {
                    return
                }
                guard let stateView = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView else {
                    return
                }
                guard let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView else {
                    return
                }
                
                let _ = (self.account.postbox.transaction { transaction -> State? in
                    let state = stateView.value?.get(Stories.PeerState.self)
                    
                    var items: [Item] = []
                    for item in itemsView.items {
                        if let item = item.value.get(Stories.StoredItem.self) {
                            switch item {
                            case let .item(item):
                                if let media = item.media {
                                    let mappedItem = EngineStoryItem(
                                        id: item.id,
                                        timestamp: item.timestamp,
                                        expirationTimestamp: item.expirationTimestamp,
                                        media: EngineMedia(media),
                                        alternativeMediaList: item.alternativeMediaList.map(EngineMedia.init),
                                        mediaAreas: item.mediaAreas,
                                        text: item.text,
                                        entities: item.entities,
                                        views: item.views.flatMap { views in
                                            return EngineStoryItem.Views(
                                                seenCount: views.seenCount,
                                                reactedCount: views.reactedCount,
                                                forwardCount: views.forwardCount,
                                                seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                                    return transaction.getPeer(id).flatMap(EnginePeer.init)
                                                },
                                                reactions: views.reactions,
                                                hasList: views.hasList
                                            )
                                        },
                                        privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                        isPinned: item.isPinned,
                                        isExpired: item.isExpired,
                                        isPublic: item.isPublic,
                                        isPending: false,
                                        isCloseFriends: item.isCloseFriends,
                                        isContacts: item.isContacts,
                                        isSelectedContacts: item.isSelectedContacts,
                                        isForwardingDisabled: item.isForwardingDisabled,
                                        isEdited: item.isEdited,
                                        isMy: item.isMy,
                                        myReaction: item.myReaction,
                                        forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, transaction: transaction) },
                                        music: item.music.flatMap(EngineMedia.init),
                                        author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) },
                                        folderIds: item.folderIds
                                    )
                                    items.append(.item(mappedItem))
                                }
                            case let .placeholder(placeholder):
                                items.append(.placeholder(id: placeholder.id, timestamp: placeholder.timestamp, expirationTimestamp: placeholder.expirationTimestamp))
                            }
                        }
                    }
                    
                    return State(
                        items: items,
                        isCached: false,
                        maxReadId: state?.maxReadId ?? 0,
                        isLoading: items.isEmpty && !polledOnce
                    )
                }
                |> deliverOn(self.queue)).start(next: { [weak self] state in
                    guard let `self` = self else {
                        return
                    }
                    guard let state = state else {
                        return
                    }
                    self.statePromise.set(.single(state))
                })
            })
            
            self.poll()
        }
        
        deinit {
            self.listDisposable?.dispose()
            self.pollDisposable?.dispose()
        }
        
        private func poll() {
            self.pollDisposable?.dispose()
            
            let account = self.account
            let accountPeerId = account.peerId
            let peerId = self.peerId
            self.pollDisposable = (self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<Never, NoError> in
                guard let inputPeer = inputPeer else {
                    return .complete()
                }
                return account.network.request(Api.functions.stories.getPeerStories(peer: inputPeer))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stories.PeerStories?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Never, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        var updatedPeerEntries: [StoryItemsTableEntry] = []
                        updatedPeerEntries.removeAll()
                        
                        if let result = result, case let .peerStories(peerStoriesData) = result {
                            let (stories, chats, users) = (peerStoriesData.stories, peerStoriesData.chats, peerStoriesData.users)
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)

                            switch stories {
                            case let .peerStories(peerStoriesData):
                                let (_, peerIdValue, maxReadId, stories) = (peerStoriesData.flags, peerStoriesData.peer, peerStoriesData.maxReadId, peerStoriesData.stories)
                                let peerId = peerIdValue.peerId

                                let previousPeerEntries: [StoryItemsTableEntry] = transaction.getStoryItems(peerId: peerId)

                                for story in stories {
                                    if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                        if case .placeholder = storedItem, let previousEntry = previousPeerEntries.first(where: { $0.id == storedItem.id }) {
                                            updatedPeerEntries.append(previousEntry)
                                        } else {
                                            if let codedEntry = CodableEntry(storedItem) {
                                                updatedPeerEntries.append(StoryItemsTableEntry(value: codedEntry, id: storedItem.id, expirationTimestamp: storedItem.expirationTimestamp, isCloseFriends: storedItem.isCloseFriends, isLiveStream: storedItem.isLiveStream))
                                            }
                                        }
                                    }
                                }

                                transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(
                                    maxReadId: maxReadId ?? 0
                                ).postboxRepresentation)
                            }

                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        }

                        transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)
                    }
                    |> ignoreValues
                }
            }).start(completed: { [weak self] in
                guard let `self` = self else {
                    return
                }
                
                self.polledOnce.set(true)
                
                self.pollDisposable = (Signal<Never, NoError>.complete() |> suspendAwareDelay(60.0, queue: self.queue) |> deliverOn(self.queue)).start(completed: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    self.poll()
                })
            })
        }
    }
    
    public enum Item: Equatable {
        case item(EngineStoryItem)
        case placeholder(id: Int32, timestamp: Int32, expirationTimestamp: Int32)
        
        public var id: Int32 {
            switch self {
            case let .item(item):
                return item.id
            case let .placeholder(id, _, _):
                return id
            }
        }
        
        public var timestamp: Int32 {
            switch self {
            case let .item(item):
                return item.timestamp
            case let .placeholder(_, timestamp, _):
                return timestamp
            }
        }
        
        public var isCloseFriends: Bool {
            switch self {
            case let .item(item):
                return item.isCloseFriends
            case .placeholder:
                return false
            }
        }
    }
    
    public final class State: Equatable {
        public let items: [Item]
        public let isCached: Bool
        public let maxReadId: Int32
        public let isLoading: Bool
        
        public var hasUnseen: Bool {
            return self.items.contains(where: { $0.id > self.maxReadId })
        }
        
        public var unseenCount: Int {
            var count: Int = 0
            for item in items {
                if item.id > maxReadId {
                    count += 1
                }
            }
            return count
        }
        
        public var hasUnseenCloseFriends: Bool {
            return self.items.contains(where: { $0.id > self.maxReadId && $0.isCloseFriends })
        }
        
        public var hasLiveItems: Bool {
            return self.items.contains(where: { item in
                switch item {
                case let .item(item):
                    if case .liveStream = item.media {
                        return true
                    }
                default:
                    break
                }
                return false
            })
        }
        
        public init(items: [Item], isCached: Bool, maxReadId: Int32, isLoading: Bool) {
            self.items = items
            self.isCached = isCached
            self.maxReadId = maxReadId
            self.isLoading = isLoading
        }
        
        public static func ==(lhs: State, rhs: State) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.items != rhs.items {
                return false
            }
            if lhs.maxReadId != rhs.maxReadId {
                return false
            }
            if lhs.isLoading != rhs.isLoading {
                return false
            }
            return true
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return impl.signalWith { impl, subscriber in
            return impl.state.start(next: subscriber.putNext)
        }
    }
    
    public init(account: Account, peerId: EnginePeer.Id) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId)
        })
    }
}

public func _internal_pollPeerStories(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, peerReference: PeerReference? = nil, stateManager: AccountStateManager? = nil) -> Signal<Never, NoError> {
    let storyReactionContext = stateManager?.storyReactionContext
    let fullContext = stateManager?.storyRefreshContext
    let viewContext = stateManager?.storyViewRefreshContext
    return Signal { [weak stateManager] subscriber in
        let lifecycle = Atomic<(cancelled: Bool, committed: Bool)>(value: (false, false))
        let disposable = (postbox.transaction { transaction -> (Api.InputPeer, PeerStoryPollLease)? in
            guard !lifecycle.with({ $0.cancelled }) else { return nil }
            let reference = peerReference.flatMap { $0.id == peerId ? $0.inputPeer : nil }
            guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) ?? reference else { return nil }
            return (inputPeer, PeerStoryPollLease(postbox: postbox, peerId: peerId, items: transaction.getStoryItems(peerId: peerId)))
        }
        |> mapToSignal { prepared -> Signal<[InternalStoryUpdate], NoError> in
            guard let (inputPeer, lease) = prepared, !lifecycle.with({ $0.cancelled }) else { return .complete() }
            return network.request(Api.functions.stories.getPeerStories(peer: inputPeer))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.stories.PeerStories?, NoError> in .single(nil) }
            |> take(1)
            |> mapToSignal { result -> Signal<[InternalStoryUpdate], NoError> in
                guard let result else { return .complete() }
                return postbox.transaction { transaction -> [InternalStoryUpdate] in
                    var canCommit = false
                    let _ = lifecycle.modify { state in
                        guard !state.cancelled else { return state }
                        canCommit = true
                        return (false, true)
                    }
                    guard canCommit else { return [] }
                    var updates: [InternalStoryUpdate] = []
                    let updatedPeerEntries: [StoryItemsTableEntry]
                    switch result {
                    case let .peerStories(data):
                        switch data.stories {
                        case let .peerStories(peerStories):
                            guard peerStories.peer.peerId == peerId else { return [] }
                            let previousPeerEntries = transaction.getStoryItems(peerId: peerId)
                            guard lease.context.take(peerId: peerId, id: lease.id, items: previousPeerEntries) else { return [] }
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: data.chats, users: data.users))
                            let grouped = Dictionary(grouping: peerStories.stories, by: { $0.id })
                            let deletedIds = Set(peerStories.stories.compactMap { story -> Int32? in
                                guard story.id > 0, grouped[story.id]?.count == 1, case .storyItemDeleted = story else { return nil }
                                return story.id
                            })
                            _internal_removeStoriesFromListCaches(transaction: transaction, peerId: peerId, ids: deletedIds)
                            var seenIds = Set<Int32>()
                            var entries: [StoryItemsTableEntry] = []
                            for story in peerStories.stories where story.id > 0 && seenIds.insert(story.id).inserted {
                                let previous = previousPeerEntries.first(where: { $0.id == story.id && $0.value.get(Stories.StoredItem.self)?.id == story.id })?.value.get(Stories.StoredItem.self)
                                let existingItem = _internal_existingStoryItem(transaction: transaction, peerId: peerId, id: story.id)
                                var storedItem: Stories.StoredItem?
                                if (grouped[story.id]?.count ?? 0) > 1 {
                                    storedItem = existingItem.map { .item($0) } ?? previous
                                } else if case .storyItemDeleted = story {
                                    fullContext?.invalidate(peerId: peerId, ids: [story.id])
                                    viewContext?.invalidate(peerId: peerId, ids: [story.id])
                                    _internal_invalidateStoryResolution(postbox: postbox, peerId: peerId, ids: [story.id], invalidatePeerPoll: false)
                                    updates.append(contentsOf: _internal_applyStoryUpdate(transaction: transaction, peerId: peerId, story: story, storyReactionContext: storyReactionContext, addToActive: false))
                                    continue
                                } else if let parsed = Stories.StoredItem(apiStoryItem: story, existingItem: existingItem, peerId: peerId, transaction: transaction) {
                                    if case .placeholder = parsed, let existingItem {
                                        storedItem = .item(existingItem)
                                    } else {
                                        storedItem = parsed
                                    }
                                } else {
                                    storedItem = existingItem.map { .item($0) } ?? previous
                                }
                                if case let .item(item) = storedItem, let storyReactionContext {
                                    let storyId = StoryId(peerId: peerId, id: story.id)
                                    if let reaction = storyReactionContext.pendingReaction(for: storyId) {
                                        let current = existingItem ?? item
                                        let isChannel = peerId.namespace == Namespaces.Peer.CloudChannel
                                        let views = _internal_updateStoryViewsForMyReaction(isChannel: isChannel, views: current.views, previousReaction: current.myReaction, reaction: reaction)
                                        if item.myReaction != reaction || item.views != views { storyReactionContext.requireRefresh(for: storyId) }
                                        storedItem = .item(_internal_storyWithReaction(item, isChannel: isChannel, reaction: reaction, views: .some(views)))
                                    }
                                }
                                if let storedItem, let codedEntry = CodableEntry(storedItem) {
                                    entries.append(StoryItemsTableEntry(value: codedEntry, id: storedItem.id, expirationTimestamp: storedItem.expirationTimestamp, isCloseFriends: storedItem.isCloseFriends, isLiveStream: storedItem.isLiveStream))
                                }
                            }
                            updatedPeerEntries = entries
                            lease.context.advance(peerId: peerId, from: previousPeerEntries, to: entries)
                            let previousState = transaction.getPeerStoryState(peerId: peerId)?.entry.get(Stories.PeerState.self)
                            let maxReadId = max(0, max(previousState?.maxReadId ?? 0, peerStories.maxReadId ?? 0))
                            if previousState?.maxReadId != maxReadId {
                                transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(maxReadId: maxReadId).postboxRepresentation)
                            }
                        }
                    }
                    if transaction.getStoryItems(peerId: peerId) != updatedPeerEntries {
                        transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)
                    }
                    var isContactOrMember = false
                    if transaction.isPeerContact(peerId: peerId) {
                        isContactOrMember = true
                    } else if let peer = transaction.getPeer(peerId) as? TelegramChannel {
                        if peer.participationStatus == .member {
                            isContactOrMember = true
                        }
                    } else if let peer = transaction.getPeer(peerId) as? TelegramGroup {
                        if case .Member = peer.membership {
                            isContactOrMember = true
                        }
                    }

                    if !updatedPeerEntries.isEmpty, shouldKeepUserStoriesInFeed(peerId: peerId, isContactOrMember: isContactOrMember) {
                        if let user = transaction.getPeer(peerId) as? TelegramUser, let storiesHidden = user.storiesHidden {
                            if storiesHidden {
                                if !transaction.storySubscriptionsContains(key: .hidden, peerId: peerId) {
                                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                                    peerIds.append(peerId)
                                    transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
                                }
                            } else {
                                if !transaction.storySubscriptionsContains(key: .filtered, peerId: peerId) {
                                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                                    peerIds.append(peerId)
                                    transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
                                }
                            }
                        } else if let channel = transaction.getPeer(peerId) as? TelegramChannel, let storiesHidden = channel.storiesHidden {
                            if storiesHidden {
                                if !transaction.storySubscriptionsContains(key: .hidden, peerId: peerId) {
                                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                                    peerIds.append(peerId)
                                    transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
                                }
                            } else {
                                if !transaction.storySubscriptionsContains(key: .filtered, peerId: peerId) {
                                    var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                                    peerIds.append(peerId)
                                    transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
                                }
                            }
                        }
                    }
                    return updates
                }
            }
        }).start(next: { updates in
            if !updates.isEmpty { stateManager?.injectStoryUpdates(updates: updates) }
        }, completed: { subscriber.putCompletion() })
        return ActionDisposable {
            var committed = false
            let _ = lifecycle.modify { state in
                committed = state.committed
                return (true, state.committed)
            }
            if !committed { disposable.dispose() }
        }
    }
}

public final class BotPreviewStoryListContext: StoryListContext {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let engine: TelegramEngine
        private let peerId: EnginePeer.Id
        private let language: String?
        private let isArchived: Bool
        
        private let statePromise = Promise<State>()
        private var stateValue: State {
            didSet {
                self.statePromise.set(.single(self.stateValue))
            }
        }
        var state: Signal<State, NoError> {
            return self.statePromise.get()
        }
        
        private var isLoadingMore: Bool = false
        private var requestDisposable: Disposable?
        private var updatesDisposable: Disposable?
        private var eventsDisposable: Disposable?
        private let reorderDisposable = MetaDisposable()
        
        private var completionCallbacksByToken: [AnyHashable: [() -> Void]] = [:]
        
        private var nextId: Int32 = 1
        private var pendingIdMapping: [Int32: Int32] = [:]
        private var idMapping: [MediaId: Int32] = [:]
        private var reverseIdMapping: [Int32: MediaId] = [:]
        
        private var localItems: [State.Item] = []
        private var remoteItems: [State.Item] = []
        
        init(queue: Queue, account: Account, engine: TelegramEngine, peerId: EnginePeer.Id, language: String?, assumeEmpty: Bool) {
            self.queue = queue
            self.account = account
            self.engine = engine
            self.peerId = peerId
            self.language = language
            
            let isArchived = false
            
            self.isArchived = isArchived
            
            self.stateValue = State(peerReference: nil, items: [], availableLanguages: [], availableFolders: [], pinnedIds: [], totalCount: 0, loadMoreToken: AnyHashable(0 as Int), isCached: true, hasCache: false, allEntityFiles: [:], isLoading: false)
            
            let localStateKey: PostboxViewKey = .storiesState(key: .local)
            
            if let language {
                let _ = (account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(peerId)
                }
                |> deliverOn(self.queue)).start(next: { [weak self] peer in
                    guard let self else {
                        return
                    }
                    
                    self.stateValue = State(
                        peerReference: peer.flatMap(PeerReference.init),
                        items: [],
                        availableLanguages: [],
                        availableFolders: [],
                        pinnedIds: [],
                        totalCount: 0,
                        loadMoreToken: AnyHashable(0),
                        isCached: assumeEmpty,
                        hasCache: assumeEmpty,
                        allEntityFiles: [:],
                        isLoading: !assumeEmpty
                    )
                    
                    self.loadLanguage(language: language, assumeEmpty: assumeEmpty)
                })
            } else {
                self.requestDisposable = (combineLatest(queue: queue,
                    engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                        TelegramEngine.EngineData.Item.Peer.BotPreview(id: peerId),
                        TelegramEngine.EngineData.Item.Configuration.LocalizationList()
                    ),
                    account.postbox.combinedView(keys: [
                        localStateKey
                    ])
                )
                |> deliverOn(self.queue)).start(next: { [weak self] peerAndBotPreview, combinedView in
                    guard let self else {
                        return
                    }
                    
                    let (peer, botPreview, localizationList) = peerAndBotPreview
                    
                    var items: [State.Item] = []
                    var availableLanguages: [StoryListContextState.Language] = []
                    
                    if let stateView = combinedView.views[localStateKey] as? StoryStatesView, let localState = stateView.value?.get(Stories.LocalState.self) {
                        for item in localState.items.reversed() {
                            let mappedId: Int32
                            if let current = self.pendingIdMapping[item.stableId] {
                                mappedId = current
                            } else {
                                mappedId = self.nextId
                                self.nextId += 1
                                self.pendingIdMapping[item.stableId] = mappedId
                            }
                            
                            if let mediaId = _internal_lookUpPendingBotPreviewIdMapping(peerId: self.peerId, stableId: item.stableId) {
                                if let botPreview, botPreview.items.contains(where: { $0.media.id == mediaId }) {
                                    continue
                                }
                            }
                            
                            if case let .botPreview(itemPeerId, itemLanguage) = item.target, itemPeerId == peerId, itemLanguage == language {
                                items.append(State.Item(
                                    id: StoryId(peerId: peerId, id: mappedId),
                                    storyItem: EngineStoryItem(
                                        id: mappedId,
                                        timestamp: 0,
                                        expirationTimestamp: Int32.max,
                                        media: EngineMedia(item.media),
                                        alternativeMediaList: [],
                                        mediaAreas: [],
                                        text: "",
                                        entities: [],
                                        views: nil,
                                        privacy: nil,
                                        isPinned: false,
                                        isExpired: false,
                                        isPublic: false,
                                        isPending: true,
                                        isCloseFriends: false,
                                        isContacts: false,
                                        isSelectedContacts: false,
                                        isForwardingDisabled: false,
                                        isEdited: false,
                                        isMy: false,
                                        myReaction: nil,
                                        forwardInfo: nil,
                                        music: nil,
                                        author: nil,
                                        folderIds: nil
                                    ),
                                    peer: nil
                                ))
                            }
                        }
                    }
                    
                    if let botPreview {
                        for item in botPreview.items {
                            guard let mediaId = item.media.id else {
                                continue
                            }
                            
                            let id: Int32
                            if let current = self.idMapping[mediaId] {
                                id = current
                            } else {
                                id = self.nextId
                                self.nextId += 1
                                self.idMapping[mediaId] = id
                                self.reverseIdMapping[id] = mediaId
                            }
                            
                            items.append(State.Item(
                                id: StoryId(peerId: peerId, id: id),
                                storyItem: EngineStoryItem(
                                    id: id,
                                    timestamp: item.timestamp,
                                    expirationTimestamp: Int32.max,
                                    media: EngineMedia(item.media),
                                    alternativeMediaList: [],
                                    mediaAreas: [],
                                    text: "",
                                    entities: [],
                                    views: nil,
                                    privacy: nil,
                                    isPinned: false,
                                    isExpired: false,
                                    isPublic: false,
                                    isPending: false,
                                    isCloseFriends: false,
                                    isContacts: false,
                                    isSelectedContacts: false,
                                    isForwardingDisabled: false,
                                    isEdited: false,
                                    isMy: false,
                                    myReaction: nil,
                                    forwardInfo: nil,
                                    music: nil,
                                    author: nil,
                                    folderIds: nil
                                ),
                                peer: nil
                            ))
                        }
                        
                        for id in botPreview.alternativeLanguageCodes {
                            inner: for localization in localizationList.availableOfficialLocalizations {
                                if localization.languageCode == id {
                                    availableLanguages.append(StoryListContextState.Language(
                                        id: localization.languageCode,
                                        name: localization.title
                                    ))
                                    break inner
                                }
                            }
                        }
                    }
                    
                    self.stateValue = State(
                        peerReference: (peer?._asPeer()).flatMap(PeerReference.init),
                        items: items,
                        availableLanguages: availableLanguages,
                        availableFolders: [],
                        pinnedIds: [],
                        totalCount: items.count,
                        loadMoreToken: nil,
                        isCached: botPreview != nil,
                        hasCache: botPreview != nil,
                        allEntityFiles: [:],
                        isLoading: botPreview == nil
                    )
                })
            }
        }
        
        deinit {
            self.requestDisposable?.dispose()
            self.updatesDisposable?.dispose()
            self.eventsDisposable?.dispose()
            self.reorderDisposable.dispose()
        }
        
        func loadMore(completion: (() -> Void)?) {
        }
        
        private func loadLanguage(language: String, assumeEmpty: Bool) {
            let account = self.account
            let peerId = self.peerId
            let signal: Signal<(CachedUserData.BotPreview?, Peer?), NoError> = (self.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            }
            |> mapToSignal { peer -> Signal<(CachedUserData.BotPreview?, Peer?), NoError> in
                guard let peer, let inputUser = apiInputUser(peer) else {
                    return .single((nil, nil))
                }
                return _internal_requestBotAdminPreview(network: account.network, peerId: peerId, inputUser: inputUser, language: language)
                |> map { botPreview in
                    return (botPreview, peer)
                }
            })
            
            self.requestDisposable?.dispose()
            self.requestDisposable = (signal
            |> deliverOn(self.queue)).startStrict(next: { [weak self] botPreview, peer in
                guard let self, let peer else {
                    return
                }
                
                var items: [State.Item] = []
                
                if let botPreview {
                    for item in botPreview.items {
                        guard let mediaId = item.media.id else {
                            continue
                        }
                        
                        let id: Int32
                        if let current = self.idMapping[mediaId] {
                            id = current
                        } else {
                            id = self.nextId
                            self.nextId += 1
                            self.idMapping[mediaId] = id
                            self.reverseIdMapping[id] = mediaId
                        }
                        
                        items.append(State.Item(
                            id: StoryId(peerId: peerId, id: id),
                            storyItem: EngineStoryItem(
                                id: id,
                                timestamp: item.timestamp,
                                expirationTimestamp: Int32.max,
                                media: EngineMedia(item.media),
                                alternativeMediaList: [],
                                mediaAreas: [],
                                text: "",
                                entities: [],
                                views: nil,
                                privacy: nil,
                                isPinned: false,
                                isExpired: false,
                                isPublic: false,
                                isPending: false,
                                isCloseFriends: false,
                                isContacts: false,
                                isSelectedContacts: false,
                                isForwardingDisabled: false,
                                isEdited: false,
                                isMy: false,
                                myReaction: nil,
                                forwardInfo: nil,
                                music: nil,
                                author: nil,
                                folderIds: nil
                            ),
                            peer: nil
                        ))
                    }
                }
                
                self.remoteItems = items
                self.stateValue = State(
                    peerReference: PeerReference(peer),
                    items: items,
                    availableLanguages: [],
                    availableFolders: [],
                    pinnedIds: [],
                    totalCount: items.count,
                    loadMoreToken: nil,
                    isCached: botPreview != nil,
                    hasCache: botPreview != nil,
                    allEntityFiles: [:],
                    isLoading: botPreview == nil
                )
                
                if botPreview != nil {
                    self.beginUpdates(language: language)
                }
            })
        }
        
        private func beginUpdates(language: String) {
            let localStateKey: PostboxViewKey = .storiesState(key: .local)
            
            self.updatesDisposable?.dispose()
            self.updatesDisposable = (self.account.postbox.combinedView(keys: [
                localStateKey
            ])
            |> deliverOn(self.queue)).startStrict(next: { [weak self] combinedView in
                guard let self else {
                    return
                }
                
                var items: [State.Item] = []
                if let stateView = combinedView.views[localStateKey] as? StoryStatesView, let localState = stateView.value?.get(Stories.LocalState.self) {
                    for item in localState.items.reversed() {
                        let mappedId: Int32
                        if let current = self.pendingIdMapping[item.stableId] {
                            mappedId = current
                        } else {
                            mappedId = self.nextId
                            self.nextId += 1
                            self.pendingIdMapping[item.stableId] = mappedId
                        }
                        if case let .botPreview(itemPeerId, itemLanguage) = item.target, itemPeerId == self.peerId, itemLanguage == language {
                            items.append(State.Item(
                                id: StoryId(peerId: peerId, id: mappedId),
                                storyItem: EngineStoryItem(
                                    id: mappedId,
                                    timestamp: 0,
                                    expirationTimestamp: Int32.max,
                                    media: EngineMedia(item.media),
                                    alternativeMediaList: [],
                                    mediaAreas: [],
                                    text: "",
                                    entities: [],
                                    views: nil,
                                    privacy: nil,
                                    isPinned: false,
                                    isExpired: false,
                                    isPublic: false,
                                    isPending: true,
                                    isCloseFriends: false,
                                    isContacts: false,
                                    isSelectedContacts: false,
                                    isForwardingDisabled: false,
                                    isEdited: false,
                                    isMy: false,
                                    myReaction: nil,
                                    forwardInfo: nil,
                                    music: nil,
                                    author: nil,
                                    folderIds: nil
                                ),
                                peer: nil
                            ))
                        }
                    }
                }
                
                if self.localItems != items {
                    self.localItems = items
                    
                    if self.stateValue.peerReference != nil {
                        self.pushLanguageItems()
                    }
                }
            })
            
            self.eventsDisposable?.dispose()
            self.eventsDisposable = (self.account.stateManager.botPreviewUpdates
            |> deliverOn(self.queue)).startStrict(next: { [weak self] events in
                guard let self else {
                    return
                }
                var remoteItems = self.remoteItems
                for event in events {
                    switch event {
                    case let .added(peerId, language, item):
                        if let mediaId = item.media.id, self.peerId == peerId, self.language == language {
                            let id: Int32
                            if let current = self.idMapping[mediaId] {
                                id = current
                            } else {
                                id = self.nextId
                                self.nextId += 1
                                self.idMapping[mediaId] = id
                                self.reverseIdMapping[id] = mediaId
                            }
                            
                            let mappedItem = State.Item(
                                id: StoryId(peerId: peerId, id: id),
                                storyItem: EngineStoryItem(
                                    id: id,
                                    timestamp: item.timestamp,
                                    expirationTimestamp: Int32.max,
                                    media: EngineMedia(item.media),
                                    alternativeMediaList: [],
                                    mediaAreas: [],
                                    text: "",
                                    entities: [],
                                    views: nil,
                                    privacy: nil,
                                    isPinned: false,
                                    isExpired: false,
                                    isPublic: false,
                                    isPending: false,
                                    isCloseFriends: false,
                                    isContacts: false,
                                    isSelectedContacts: false,
                                    isForwardingDisabled: false,
                                    isEdited: false,
                                    isMy: false,
                                    myReaction: nil,
                                    forwardInfo: nil,
                                    music: nil,
                                    author: nil,
                                    folderIds: nil
                                ),
                                peer: nil
                            )
                            
                            if let index = remoteItems.firstIndex(where: { $0.storyItem.media.id == item.media.id }) {
                                remoteItems[index] = mappedItem
                            } else {
                                remoteItems.insert(mappedItem, at: 0)
                            }
                        }
                    case let .deleted(peerId, language, ids):
                        if self.peerId == peerId && self.language == language {
                            remoteItems = remoteItems.filter { item in
                                guard let id = item.storyItem.media.id else {
                                    return false
                                }
                                return !ids.contains(id)
                            }
                        }
                    }
                }
                if self.remoteItems != remoteItems {
                    self.remoteItems = remoteItems
                    self.pushLanguageItems()
                }
            })
        }
        
        private func pushLanguageItems() {
            var items: [State.Item] = []
            for item in self.localItems {
                var stableId: Int32?
                inner: for (from, to) in self.pendingIdMapping {
                    if to == item.id.id {
                        stableId = from
                        break inner
                    }
                }
                if let stableId, let mediaId = _internal_lookUpPendingBotPreviewIdMapping(peerId: self.peerId, stableId: stableId) {
                    if self.remoteItems.contains(where: { $0.storyItem.media.id == mediaId }) {
                        continue
                    }
                }
                items.append(item)
            }
            items.append(contentsOf: self.remoteItems)
            
            self.stateValue = State(
                peerReference: self.stateValue.peerReference,
                items: items,
                availableLanguages: [],
                availableFolders: [],
                pinnedIds: [],
                totalCount: items.count,
                loadMoreToken: nil,
                isCached: true,
                hasCache: true,
                allEntityFiles: [:],
                isLoading: false
            )
        }
        
        func reorderItems(media: [Media]) {
            let peerId = self.peerId
            let language = self.language
            
            let _ = (self.account.postbox.transaction({ transaction -> (Api.InputUser?, [Api.InputMedia]) in
                let inputUser = transaction.getPeer(peerId).flatMap(apiInputUser)
                
                var inputMedia: [Api.InputMedia] = []
                for item in media {
                    if let image = item as? TelegramMediaImage, let resource = image.representations.last?.resource as? CloudPhotoSizeMediaResource {
                        inputMedia.append(.inputMediaPhoto(.init(flags: 0, id: .inputPhoto(.init(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))), ttlSeconds: nil, video: nil)))
                        inputMedia.append(Api.InputMedia.inputMediaPhoto(.init(flags: 0, id: Api.InputPhoto.inputPhoto(.init(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))), ttlSeconds: nil, video: nil)))
                    } else if let file = item as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
                        inputMedia.append(.inputMediaDocument(.init(flags: 0, id: .inputDocument(.init(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data()))), videoCover: nil, videoTimestamp: nil, ttlSeconds: nil, query: nil)))
                    }
                }
                
                if language == nil {
                    transaction.updatePeerCachedData(peerIds: Set([self.peerId]), update: { _, current in
                        guard var current = current as? CachedUserData else {
                            return current
                        }
                        guard let currentBotPreview = current.botPreview else {
                            return current
                        }
                        
                        var items: [CachedUserData.BotPreview.Item] = []
                        
                        var seenIds = Set<MediaId>()
                        for item in media {
                            guard let mediaId = item.id else {
                                continue
                            }
                            if let index = currentBotPreview.items.firstIndex(where: { $0.media.id == mediaId }) {
                                seenIds.insert(mediaId)
                                items.append(currentBotPreview.items[index])
                            }
                        }
                        
                        for item in currentBotPreview.items {
                            guard let id = item.media.id else {
                                continue
                            }
                            if !seenIds.contains(id) {
                                items.append(item)
                            }
                        }
                        
                        let botPreview = CachedUserData.BotPreview(items: items, alternativeLanguageCodes: currentBotPreview.alternativeLanguageCodes)
                        current = current.withUpdatedBotPreview(botPreview)
                        return current
                    })
                }
                
                return (inputUser, inputMedia)
            })
            |> deliverOn(self.queue)).startStandalone(next: { [weak self] inputUser, inputMedia in
                guard let self, let inputUser else {
                    return
                }
                
                if language != nil {
                    var updatedItems: [State.Item] = []
                    
                    var seenIds = Set<MediaId>()
                    for item in media {
                        guard let mediaId = item.id else {
                            continue
                        }
                        if let index = self.remoteItems.firstIndex(where: { $0.storyItem.media.id == mediaId }) {
                            seenIds.insert(mediaId)
                            updatedItems.append(self.remoteItems[index])
                        }
                    }
                    
                    for item in self.remoteItems {
                        guard let id = item.storyItem.media.id else {
                            continue
                        }
                        if !seenIds.contains(id) {
                            updatedItems.append(item)
                        }
                    }
                    
                    if self.remoteItems != updatedItems {
                        self.remoteItems = updatedItems
                        self.pushLanguageItems()
                    }
                }
                
                let signal = self.account.network.request(Api.functions.bots.reorderPreviewMedias(bot: inputUser, langCode: language ?? "", order: inputMedia))
                self.reorderDisposable.set(signal.startStrict())
            })
        }
    }
    
    public var state: Signal<State, NoError> {
        return impl.signalWith { impl, subscriber in
            return impl.state.start(next: subscriber.putNext)
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public let language: String?
    
    public init(account: Account, engine: TelegramEngine, peerId: EnginePeer.Id, language: String?, assumeEmpty: Bool) {
        self.language = language
        
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, engine: engine, peerId: peerId, language: language, assumeEmpty: assumeEmpty)
        })
    }
    
    public func loadMore(completion: (() -> Void)? = nil) {
        self.impl.with { impl in
            impl.loadMore(completion: completion)
        }
    }
    
    public func reorderItems(media: [Media]) {
        self.impl.with { impl in
            impl.reorderItems(media: media)
        }
    }
}
