import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public final class EngineStoryViewListContext {
    public struct LoadMoreToken: Equatable {
        var value: String
    }
    
    public enum ListMode {
        case everyone
        case contacts
    }
    
    public enum SortMode {
        case repostsFirst
        case reactionsFirst
        case recentFirst
    }
    
    
    public enum Item: Equatable {
        public final class View: Equatable {
            public let peer: EnginePeer
            public let timestamp: Int32
            public let storyStats: PeerStoryStats?
            public let reaction: MessageReaction.Reaction?
            public let reactionFile: TelegramMediaFile?
            
            public init(
                peer: EnginePeer,
                timestamp: Int32,
                storyStats: PeerStoryStats?,
                reaction: MessageReaction.Reaction?,
                reactionFile: TelegramMediaFile?
            ) {
                self.peer = peer
                self.timestamp = timestamp
                self.storyStats = storyStats
                self.reaction = reaction
                self.reactionFile = reactionFile
            }
            
            public static func ==(lhs: View, rhs: View) -> Bool {
                if lhs.peer != rhs.peer {
                    return false
                }
                if lhs.timestamp != rhs.timestamp {
                    return false
                }
                if lhs.storyStats != rhs.storyStats {
                    return false
                }
                if lhs.reaction != rhs.reaction {
                    return false
                }
                if lhs.reactionFile?.fileId != rhs.reactionFile?.fileId {
                    return false
                }
                return true
            }
        }
        
        public final class Repost: Equatable {
            public let peer: EnginePeer
            public let story: EngineStoryItem
            public let storyStats: PeerStoryStats?
            
            init(peer: EnginePeer, story: EngineStoryItem, storyStats: PeerStoryStats?) {
                self.peer = peer
                self.story = story
                self.storyStats = storyStats
            }
            
            public static func ==(lhs: Repost, rhs: Repost) -> Bool {
                if lhs.peer != rhs.peer {
                    return false
                }
                if lhs.story != rhs.story {
                    return false
                }
                if lhs.storyStats != rhs.storyStats {
                    return false
                }
                return true
            }
        }
        
        public final class Forward: Equatable {
            public let message: EngineMessage
            public let storyStats: PeerStoryStats?
            
            init(message: EngineMessage, storyStats: PeerStoryStats?) {
                self.message = message
                self.storyStats = storyStats
            }
            
            public static func ==(lhs: Forward, rhs: Forward) -> Bool {
                if lhs.message != rhs.message {
                    return false
                }
                if lhs.storyStats != rhs.storyStats {
                    return false
                }
                return true
            }
        }
        
        case view(View)
        case repost(Repost)
        case forward(Forward)
        
        public var peer: EnginePeer {
            switch self {
            case let .view(view):
                return view.peer
            case let .repost(repost):
                return repost.peer
            case let .forward(forward):
                return EnginePeer(forward.message.peers[forward.message.id.peerId]!)
            }
        }
        
        public var timestamp: Int32 {
            switch self {
            case let .view(view):
                return view.timestamp
            case let .repost(repost):
                return repost.story.timestamp
            case let .forward(forward):
                return forward.message.timestamp
            }
        }
        
        public var reaction: MessageReaction.Reaction? {
            switch self {
            case let .view(view):
                return view.reaction
            case .repost:
                return nil
            case .forward:
                return nil
            }
        }
        
        public var story: EngineStoryItem? {
            switch self {
            case .view:
                return nil
            case let .repost(repost):
                return repost.story
            case .forward:
                return nil
            }
        }

        public var message: EngineMessage? {
            switch self {
            case .view:
                return nil
            case .repost:
                return nil
            case let .forward(forward):
                return forward.message
            }
        }
        
        public var storyStats: PeerStoryStats? {
            switch self {
            case let .view(view):
                return view.storyStats
            case let .repost(repost):
                return repost.storyStats
            case let .forward(forward):
                return forward.storyStats
            }
        }
        
        public struct ItemHash: Hashable {
            public var peerId: EnginePeer.Id
            public var storyId: Int32?
            public var messageId: EngineMessage.Id?
        }
        
        public var uniqueId: ItemHash {
            switch self {
            case let .view(view):
                return ItemHash(peerId: view.peer.id, storyId: nil, messageId: nil)
            case let .repost(repost):
                return ItemHash(peerId: repost.peer.id, storyId: repost.story.id, messageId: nil)
            case let .forward(forward):
                return ItemHash(peerId: forward.message.id.peerId, storyId: nil, messageId: forward.message.id)
            }
        }
    }
        
    public struct State: Equatable {
        public var totalCount: Int
        public var totalReactedCount: Int
        public var items: [Item]
        public var loadMoreToken: LoadMoreToken?
        
        public init(
            totalCount: Int,
            totalReactedCount: Int,
            items: [Item],
            loadMoreToken: LoadMoreToken?
        ) {
            self.totalCount = totalCount
            self.totalReactedCount = totalReactedCount
            self.items = items
            self.loadMoreToken = loadMoreToken
        }
    }
    
    private final class Impl {
        struct NextOffset: Equatable {
            var value: String
        }
        
        struct InternalState: Equatable {
            var totalCount: Int
            var totalViewsCount: Int
            var totalForwardsCount: Int
            var totalReactedCount: Int
            var items: [Item]
            var canLoadMore: Bool
            var nextOffset: NextOffset?
        }
        
        let queue: Queue
        
        let account: Account
        let peerId: EnginePeer.Id
        let storyId: Int32
        let listMode: ListMode
        let sortMode: SortMode
        let searchQuery: String?
        
        let disposable = MetaDisposable()
        let storyStatsDisposable = MetaDisposable()
        
        var state: InternalState?
        let statePromise = Promise<InternalState>()
        
        private var parentSource: Impl?
        var isLoadingMore: Bool = false
        
        init(queue: Queue, account: Account, peerId: EnginePeer.Id, storyId: Int32, views: EngineStoryItem.Views, listMode: ListMode, sortMode: SortMode, searchQuery: String?, parentSource: Impl?) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.storyId = storyId
            self.listMode = listMode
            self.sortMode = sortMode
            self.searchQuery = searchQuery
            
            if let parentSource = parentSource, (parentSource.listMode == .everyone || parentSource.listMode == listMode), let parentState = parentSource.state, parentState.totalCount <= 100 {
                self.parentSource = parentSource
                
                let matchesMode = parentSource.listMode == listMode
                if parentState.items.count < 100 && !matchesMode {
                    parentSource.loadMore()
                }
                
                self.disposable.set((parentSource.statePromise.get()
                |> mapToSignal { state -> Signal<InternalState, NoError> in
                    let needUpdate: Signal<Void, NoError>
                    if listMode == .contacts {
                        var keys: [PostboxViewKey] = []
                        for item in state.items {
                            keys.append(.isContact(id: item.peer.id))
                        }
                        needUpdate = account.postbox.combinedView(keys: keys)
                        |> map { views -> [Bool] in
                            var result: [Bool] = []
                            for item in state.items {
                                if let view = views.views[.isContact(id: item.peer.id)] as? IsContactView {
                                    result.append(view.isContact)
                                }
                            }
                            return result
                        }
                        |> distinctUntilChanged
                        |> map { _ -> Void in
                            return Void()
                        }
                    } else {
                        needUpdate = .single(Void())
                    }
                    
                    return needUpdate
                    |> mapToSignal { _ -> Signal<InternalState, NoError> in
                        return account.postbox.transaction { transaction -> InternalState in
                            /*if state.canLoadMore && !matchesMode {
                                return InternalState(
                                    totalCount: listMode == .everyone ? state.totalCount : 100, totalReactedCount: state.totalReactedCount, items: [], canLoadMore: true, nextOffset: state.nextOffset)
                            }*/
                            
                            var items: [Item] = []
                            switch listMode {
                            case .everyone:
                                items = state.items
                            case .contacts:
                                items = state.items.filter { item in
                                    return transaction.isPeerContact(peerId: item.peer.id)
                                }
                            }
                            if let searchQuery = searchQuery, !searchQuery.isEmpty {
                                let normalizedQuery = searchQuery.lowercased()
                                items = state.items.filter { item in
                                    return item.peer.indexName.matchesByTokens(normalizedQuery)
                                }
                            }
                            switch sortMode {
                            case .repostsFirst:
                                items.sort(by: { lhs, rhs in
                                    if (lhs.story == nil) != (rhs.story == nil) {
                                        return lhs.story != nil
                                    }
                                    if (lhs.message == nil) != (rhs.message == nil) {
                                        return lhs.message != nil
                                    }
                                    if lhs.timestamp != rhs.timestamp {
                                        return lhs.timestamp > rhs.timestamp
                                    }
                                    return lhs.peer.id < rhs.peer.id
                                })
                            case .reactionsFirst:
                                items.sort(by: { lhs, rhs in
                                    if (lhs.story == nil) != (rhs.story == nil) {
                                        return lhs.story == nil
                                    }
                                    if (lhs.message == nil) != (rhs.message == nil) {
                                        return lhs.message == nil
                                    }
                                    if (lhs.reaction == nil) != (rhs.reaction == nil) {
                                        return lhs.reaction != nil
                                    }
                                    if lhs.timestamp != rhs.timestamp {
                                        return lhs.timestamp > rhs.timestamp
                                    }
                                    return lhs.peer.id < rhs.peer.id
                                })
                            case .recentFirst:
                                items.sort(by: { lhs, rhs in
                                    if lhs.timestamp != rhs.timestamp {
                                        return lhs.timestamp > rhs.timestamp
                                    }
                                    return lhs.peer.id < rhs.peer.id
                                })
                            }
                            
                            var totalCount = items.count
                            var totalReactedCount = 0
                            for item in items {
                                if item.reaction != nil {
                                    totalReactedCount += 1
                                }
                            }
                            
                            if state.canLoadMore {
                                totalCount = state.totalCount
                                totalReactedCount = state.totalReactedCount
                            }
                            
                            return InternalState(
                                totalCount: totalCount,
                                totalViewsCount: 0,
                                totalForwardsCount: 0,
                                totalReactedCount: totalReactedCount,
                                items: items,
                                canLoadMore: state.canLoadMore
                            )
                        }
                    }
                }
                |> deliverOn(self.queue)).start(next: { [weak self] state in
                    guard let `self` = self else {
                        return
                    }
                    self.updateInternalState(state: state)
                }))
            } else {
                let initialState = State(totalCount: listMode == .everyone ? views.seenCount : 100, totalReactedCount: views.reactedCount, items: [], loadMoreToken: LoadMoreToken(value: ""))
                let state = InternalState(totalCount: initialState.totalCount, totalViewsCount: initialState.totalCount, totalForwardsCount: initialState.totalCount, totalReactedCount: initialState.totalReactedCount, items: initialState.items, canLoadMore: initialState.loadMoreToken != nil, nextOffset: nil)
                self.state = state
                self.statePromise.set(.single(state))
                
                if initialState.loadMoreToken != nil {
                    self.loadMore()
                }
            }
        }
        
        deinit {
            assert(self.queue.isCurrent())
            
            self.disposable.dispose()
            self.storyStatsDisposable.dispose()
        }
        
        func loadMore() {
            if let parentSource = self.parentSource {
                parentSource.loadMore()
                return
            }
            
            guard let state = self.state else {
                return
            }
            
            if !state.canLoadMore {
                return
            }
            if self.isLoadingMore {
                return
            }
            self.isLoadingMore = true
            
            let account = self.account
            let accountPeerId = account.peerId
            let peerId = self.peerId
            let storyId = self.storyId
            let listMode = self.listMode
            let sortMode = self.sortMode
            let searchQuery = self.searchQuery
            let currentOffset = state.nextOffset
            let limit = 50
           
            let signal: Signal<InternalState, NoError> 
            
            if peerId.namespace == Namespaces.Peer.CloudUser {
                signal = self.account.postbox.transaction { transaction -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }
                |> mapToSignal { inputPeer -> Signal<InternalState, NoError> in
                    guard let inputPeer = inputPeer else {
                        return .complete()
                    }
                    
                    var flags: Int32 = 0
                    switch listMode {
                    case .everyone:
                        break
                    case .contacts:
                        flags |= (1 << 0)
                    }
                    switch sortMode {
                    case .reactionsFirst:
                        flags |= (1 << 2)
                    case .recentFirst, .repostsFirst:
                        break
                    }
                    if searchQuery != nil {
                        flags |= (1 << 1)
                    }
                    
                    return account.network.request(Api.functions.stories.getStoryViewsList(flags: flags, peer: inputPeer, q: searchQuery, id: storyId, offset: currentOffset?.value ?? "", limit: Int32(limit)))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.stories.StoryViewsList?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { result -> Signal<InternalState, NoError> in
                        return account.postbox.transaction { transaction -> InternalState in
                            switch result {
                            case let .storyViewsList(_, count, viewsCount, forwardsCount, reactionsCount, views, chats, users, nextOffset):
                                let peers = AccumulatedPeers(chats: chats, users: users)
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: peers)
                                
                                var items: [Item] = []
                                for view in views {
                                    switch view {
                                    case let .storyView(flags, userId, date, reaction):
                                        let isBlocked = (flags & (1 << 0)) != 0
                                        let isBlockedFromStories = (flags & (1 << 1)) != 0
                                        
                                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData in
                                            let previousData: CachedUserData
                                            if let current = cachedData as? CachedUserData {
                                                previousData = current
                                            } else {
                                                previousData = CachedUserData()
                                            }
                                            var updatedFlags = previousData.flags
                                            if isBlockedFromStories {
                                                updatedFlags.insert(.isBlockedFromStories)
                                            } else {
                                                updatedFlags.remove(.isBlockedFromStories)
                                            }
                                            return previousData.withUpdatedIsBlocked(isBlocked).withUpdatedFlags(updatedFlags)
                                        })
                                        if let peer = transaction.getPeer(peerId) {
                                            let parsedReaction = reaction.flatMap(MessageReaction.Reaction.init(apiReaction:))
                                            items.append(.view(Item.View(
                                                peer: EnginePeer(peer),
                                                timestamp: date,
                                                storyStats: transaction.getPeerStoryStats(peerId: peerId),
                                                reaction: parsedReaction,
                                                reactionFile: parsedReaction.flatMap { reaction -> TelegramMediaFile? in
                                                    switch reaction {
                                                    case .builtin:
                                                        return nil
                                                    case let .custom(fileId):
                                                        return transaction.getMedia(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)) as? TelegramMediaFile
                                                    case .stars:
                                                        return nil
                                                    }
                                                }
                                            )))
                                        }
                                    case let .storyViewPublicForward(flags, message):
                                        let _ = flags
                                        if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: false), let message = locallyRenderedMessage(message: storeMessage, peers: peers.peers) {
                                            items.append(.forward(Item.Forward(
                                                message: EngineMessage(message),
                                                storyStats: transaction.getPeerStoryStats(peerId: message.id.peerId)
                                            )))
                                        }
                                    case let .storyViewPublicRepost(flags, peerId, story):
                                        let _ = flags
                                        if let peer = transaction.getPeer(peerId.peerId) {
                                            if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peer.id, transaction: transaction), case let .item(item) = storedItem, let media = item.media {
                                                items.append(.repost(Item.Repost(
                                                    peer: EnginePeer(peer),
                                                    story: EngineStoryItem(
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
                                                        author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) }
                                                    ),
                                                    storyStats: transaction.getPeerStoryStats(peerId: peer.id)
                                                )))
                                            }
                                        }
                                    }
                                }
                                
                                if listMode == .everyone, searchQuery == nil {
                                    if let storedItem = transaction.getStory(id: StoryId(peerId: account.peerId, id: storyId))?.get(Stories.StoredItem.self), case let .item(item) = storedItem, let currentViews = item.views {
                                        let updatedItem: Stories.StoredItem = .item(Stories.Item(
                                            id: item.id,
                                            timestamp: item.timestamp,
                                            expirationTimestamp: item.expirationTimestamp,
                                            media: item.media,
                                            alternativeMediaList: item.alternativeMediaList,
                                            mediaAreas: item.mediaAreas,
                                            text: item.text,
                                            entities: item.entities,
                                            views: Stories.Item.Views(
                                                seenCount: Int(count),
                                                reactedCount: Int(reactionsCount),
                                                forwardCount: Int(forwardsCount),
                                                seenPeerIds: currentViews.seenPeerIds,
                                                reactions: currentViews.reactions,
                                                hasList: currentViews.hasList
                                            ),
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
                                            authorId: item.authorId
                                        ))
                                        if let entry = CodableEntry(updatedItem) {
                                            transaction.setStory(id: StoryId(peerId: account.peerId, id: storyId), value: entry)
                                        }
                                    }
                                    
                                    var currentItems = transaction.getStoryItems(peerId: account.peerId)
                                    for i in 0 ..< currentItems.count {
                                        if currentItems[i].id == storyId {
                                            if case let .item(item) = currentItems[i].value.get(Stories.StoredItem.self), let currentViews = item.views {
                                                let updatedItem: Stories.StoredItem = .item(Stories.Item(
                                                    id: item.id,
                                                    timestamp: item.timestamp,
                                                    expirationTimestamp: item.expirationTimestamp,
                                                    media: item.media,
                                                    alternativeMediaList: item.alternativeMediaList,
                                                    mediaAreas: item.mediaAreas,
                                                    text: item.text,
                                                    entities: item.entities,
                                                    views: Stories.Item.Views(
                                                        seenCount: Int(count),
                                                        reactedCount: Int(reactionsCount),
                                                        forwardCount: Int(forwardsCount),
                                                        seenPeerIds: currentViews.seenPeerIds,
                                                        reactions: currentViews.reactions,
                                                        hasList: currentViews.hasList
                                                    ),
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
                                                    authorId: item.authorId
                                                ))
                                                if let entry = CodableEntry(updatedItem) {
                                                    currentItems[i] = StoryItemsTableEntry(value: entry, id: updatedItem.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends)
                                                }
                                            }
                                        }
                                    }
                                    transaction.setStoryItems(peerId: account.peerId, items: currentItems)
                                }
                                
                                return InternalState(totalCount: Int(count), totalViewsCount: Int(viewsCount), totalForwardsCount: Int(forwardsCount), totalReactedCount: Int(reactionsCount), items: items, canLoadMore: nextOffset != nil, nextOffset: nextOffset.flatMap { NextOffset(value: $0) })
                            case .none:
                                return InternalState(totalCount: 0, totalViewsCount: 0, totalForwardsCount: 0, totalReactedCount: 0, items: [], canLoadMore: false, nextOffset: nil)
                            }
                        }
                    }
                }
            } else {
                signal = self.account.postbox.transaction { transaction -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }
                |> mapToSignal { inputPeer -> Signal<InternalState, NoError> in
                    guard let inputPeer = inputPeer else {
                        return .complete()
                    }
                    
                    var flags: Int32 = 0
                    if let _ = currentOffset {
                        flags |= (1 << 1)
                    }
                    if case .repostsFirst = sortMode {
                        flags |= (1 << 2)
                    }
                    
                    return account.network.request(Api.functions.stories.getStoryReactionsList(flags: flags, peer: inputPeer, id: storyId, reaction: nil, offset: currentOffset?.value, limit: Int32(limit)))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.stories.StoryReactionsList?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { result -> Signal<InternalState, NoError> in
                        return account.postbox.transaction { transaction -> InternalState in
                            switch result {
                            case let .storyReactionsList(_, count, reactions, chats, users, nextOffset):
                                let peers = AccumulatedPeers(chats: chats, users: users)
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: peers)
                                
                                var items: [Item] = []
                                for reaction in reactions {
                                    switch reaction {
                                    case let .storyReaction(peerId, date, reaction):
                                        if let peer = transaction.getPeer(peerId.peerId) {
                                            if let parsedReaction = MessageReaction.Reaction(apiReaction: reaction) {
                                                let reactionFile: TelegramMediaFile?
                                                switch parsedReaction {
                                                case .builtin:
                                                    reactionFile = nil
                                                case let .custom(fileId):
                                                    reactionFile = transaction.getMedia(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)) as? TelegramMediaFile
                                                case .stars:
                                                    reactionFile = nil
                                                }
                                                items.append(.view(Item.View(
                                                    peer: EnginePeer(peer),
                                                    timestamp: date,
                                                    storyStats: transaction.getPeerStoryStats(peerId: peer.id),
                                                    reaction: parsedReaction,
                                                    reactionFile: reactionFile
                                                )))
                                            }
                                        }
                                    case let .storyReactionPublicForward(message):
                                        if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: false), let message = locallyRenderedMessage(message: storeMessage, peers: peers.peers) {
                                            items.append(.forward(Item.Forward(
                                                message: EngineMessage(message),
                                                storyStats: transaction.getPeerStoryStats(peerId: message.id.peerId)
                                            )))
                                        }
                                    case let .storyReactionPublicRepost(peerId, story):
                                        if let peer = transaction.getPeer(peerId.peerId) {
                                            if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peer.id, transaction: transaction), case let .item(item) = storedItem, let media = item.media {
                                                items.append(.repost(Item.Repost(
                                                    peer: EnginePeer(peer),
                                                    story: EngineStoryItem(
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
                                                        author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) }
                                                    ),
                                                    storyStats: transaction.getPeerStoryStats(peerId: peer.id)
                                                )))
                                            }
                                        }
                                    }
                                }
                                return InternalState(totalCount: Int(count), totalViewsCount: 0, totalForwardsCount: 0, totalReactedCount: Int(count), items: items, canLoadMore: nextOffset != nil, nextOffset: nextOffset.flatMap { NextOffset(value: $0) })
                            case .none:
                                return InternalState(totalCount: 0, totalViewsCount: 0, totalForwardsCount: 0, totalReactedCount: 0, items: [], canLoadMore: false, nextOffset: nil)
                            }
                        }
                    }
                }
            }
            self.disposable.set((signal
            |> deliverOn(self.queue)).start(next: { [weak self] state in
                guard let `self` = self else {
                    return
                }
                self.updateInternalState(state: state)
            }))
        }
        
        private func updateInternalState(state: InternalState) {
            var currentState = self.state ?? InternalState(
                totalCount: 0, totalViewsCount: 0, totalForwardsCount: 0, totalReactedCount: 0, items: [], canLoadMore: false, nextOffset: nil)
            
            if self.parentSource != nil {
                currentState.items.removeAll()
            }
            
            var existingItems = Set<Item.ItemHash>()
            for item in currentState.items {
                existingItems.insert(item.uniqueId)
            }
            
            for item in state.items {
                let itemHash = item.uniqueId
                if existingItems.contains(itemHash) {
                    continue
                }
                existingItems.insert(itemHash)
                currentState.items.append(item)
            }
            
            var allReactedCount = 0
            for item in currentState.items {
                if case let .view(view) = item, view.reaction != nil {
                    allReactedCount += 1
                } else {
                    break
                }
            }
            
            if state.canLoadMore {
                currentState.totalCount = max(state.totalCount, currentState.items.count)
                currentState.totalReactedCount = max(state.totalReactedCount, allReactedCount)
            } else {
                currentState.totalCount = currentState.items.count
                currentState.totalReactedCount = allReactedCount
            }
            currentState.canLoadMore = state.canLoadMore
            currentState.nextOffset = state.nextOffset
            
            self.isLoadingMore = false
            self.state = currentState
            self.statePromise.set(.single(currentState))
            
            let statsKey: PostboxViewKey = .peerStoryStats(peerIds: Set(currentState.items.map(\.peer.id)))
            self.storyStatsDisposable.set((self.account.postbox.combinedView(keys: [statsKey])
            |> deliverOn(self.queue)).start(next: { [weak self] views in
                guard let `self` = self, var state = self.state else {
                    return
                }
                guard let view = views.views[statsKey] as? PeerStoryStatsView else {
                    return
                }
                var updated = false
                var items = state.items
                for i in 0 ..< state.items.count {
                    let item = items[i]
                    let value = view.storyStats[item.peer.id]
                    if case let .view(view) = item, view.storyStats != value {
                        updated = true
                        items[i] = .view(Item.View(
                            peer: view.peer,
                            timestamp: view.timestamp,
                            storyStats: value,
                            reaction: view.reaction,
                            reactionFile: view.reactionFile
                        ))
                    }
                }
                if updated {
                    state.items = items
                    self.state = state
                    self.statePromise.set(.single(state))
                }
            }))
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.statePromise.get().start(next: { state in
                    var loadMoreToken: LoadMoreToken?
                    if let nextOffset = state.nextOffset {
                        loadMoreToken = LoadMoreToken(value: nextOffset.value)
                    }
                    subscriber.putNext(State(
                        totalCount: state.totalCount,
                        totalReactedCount: state.totalReactedCount,
                        items: state.items,
                        loadMoreToken: loadMoreToken
                    ))
                }))
            }
            return disposable
        }
    }
    
    init(account: Account, peerId: EnginePeer.Id, storyId: Int32, views: EngineStoryItem.Views, listMode: ListMode, sortMode: SortMode, searchQuery: String?, parentSource: EngineStoryViewListContext?) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, storyId: storyId, views: views, listMode: listMode, sortMode: sortMode, searchQuery: searchQuery, parentSource: parentSource?.impl.syncWith { $0 })
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}
