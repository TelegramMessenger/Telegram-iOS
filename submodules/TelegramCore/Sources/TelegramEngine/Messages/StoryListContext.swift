import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

enum InternalStoryUpdate {
    case deleted(Int32)
    case added(peerId: PeerId, item: StoryListContext.Item)
    case read(peerId: PeerId, maxId: Int32)
}

public final class StoryListContext {
    public enum Scope {
        case all
        case peer(EnginePeer.Id)
    }
    
    public final class Item: Equatable {
        public let id: Int32
        public let timestamp: Int32
        public let media: EngineMedia
        public let seenCount: Int
        public let seenPeers: [EnginePeer]
        public let privacy: EngineStoryPrivacy?
        
        public init(id: Int32, timestamp: Int32, media: EngineMedia, seenCount: Int, seenPeers: [EnginePeer], privacy: EngineStoryPrivacy?) {
            self.id = id
            self.timestamp = timestamp
            self.media = media
            self.seenCount = seenCount
            self.seenPeers = seenPeers
            self.privacy = privacy
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
                return false
            }
            if lhs.media != rhs.media {
                return false
            }
            if lhs.seenCount != rhs.seenCount {
                return false
            }
            if lhs.seenPeers != rhs.seenPeers {
                return false
            }
            if lhs.privacy != rhs.privacy {
                return false
            }
            return true
        }
    }
    
    public final class PeerItemSet: Equatable {
        public let peerId: EnginePeer.Id
        public let peer: EnginePeer?
        public var maxReadId: Int32
        public fileprivate(set) var items: [Item]
        public fileprivate(set) var totalCount: Int?
        
        public init(peerId: EnginePeer.Id, peer: EnginePeer?, maxReadId: Int32, items: [Item], totalCount: Int?) {
            self.peerId = peerId
            self.peer = peer
            self.maxReadId = maxReadId
            self.items = items
            self.totalCount = totalCount
        }
        
        public static func ==(lhs: PeerItemSet, rhs: PeerItemSet) -> Bool {
            if lhs.peerId != rhs.peerId {
                return false
            }
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.maxReadId != rhs.maxReadId {
                return false
            }
            if lhs.items != rhs.items {
                return false
            }
            if lhs.totalCount != rhs.totalCount {
                return false
            }
            return true
        }
    }
    
    public final class LoadMoreToken: Equatable {
        fileprivate let value: String?
        
        init(value: String?) {
            self.value = value
        }
        
        public static func ==(lhs: LoadMoreToken, rhs: LoadMoreToken) -> Bool {
            if lhs.value != rhs.value {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public var itemSets: [PeerItemSet]
        public var uploadProgress: CGFloat?
        public var loadMoreToken: LoadMoreToken?
        
        public init(itemSets: [PeerItemSet], uploadProgress: CGFloat?, loadMoreToken: LoadMoreToken?) {
            self.itemSets = itemSets
            self.uploadProgress = uploadProgress
            self.loadMoreToken = loadMoreToken
        }
    }
    
    private final class UploadContext {
        let disposable = MetaDisposable()
        
        init() {
        }
    }
    
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let scope: Scope
        
        private let loadMoreDisposable = MetaDisposable()
        private var isLoadingMore = false
        
        private var pollDisposable: Disposable?
        private var updatesDisposable: Disposable?
        private var peerDisposables: [PeerId: Disposable] = [:]
        
        private var uploadContexts: [UploadContext] = [] {
            didSet {
                self.stateValue.uploadProgress = self.uploadContexts.isEmpty ? nil : 0.0
            }
        }
        
        private var stateValue: State {
            didSet {
                self.state.set(.single(self.stateValue))
            }
        }
        let state = Promise<State>()
        
        init(queue: Queue, account: Account, scope: Scope) {
            self.queue = queue
            self.account = account
            self.scope = scope
            
            self.stateValue = State(itemSets: [], uploadProgress: nil, loadMoreToken: LoadMoreToken(value: nil))
            self.state.set(.single(self.stateValue))
            
            let _ = (account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(account.peerId)
            }
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                self.stateValue = State(itemSets: [
                    PeerItemSet(peerId: peer.id, peer: EnginePeer(peer), maxReadId: 0, items: [], totalCount: 0)
                ], uploadProgress: nil, loadMoreToken: LoadMoreToken(value: nil))
            })
            
            self.updatesDisposable = (account.stateManager.storyUpdates
            |> deliverOn(queue)).start(next: { [weak self] updates in
                if updates.isEmpty {
                    return
                }
                
                let _ = account.postbox.transaction({ transaction -> [PeerId: Peer] in
                    var peers: [PeerId: Peer] = [:]
                    
                    if let peer = transaction.getPeer(account.peerId) {
                        peers[peer.id] = peer
                    }
                    
                    for update in updates {
                        switch update {
                        case let .added(peerId, _):
                            if peers[peerId] == nil, let peer = transaction.getPeer(peerId) {
                                peers[peer.id] = peer
                            }
                        case .deleted:
                            break
                        case .read:
                            break
                        }
                    }
                    return peers
                }).start(next: { peers in
                    guard let self else {
                        return
                    }
                    if self.isLoadingMore {
                        return
                    }
                    
                    var itemSets: [PeerItemSet] = self.stateValue.itemSets
                    
                    for update in updates {
                        switch update {
                        case let .deleted(id):
                            for i in 0 ..< itemSets.count {
                                if let index = itemSets[i].items.firstIndex(where: { $0.id == id }) {
                                    var items = itemSets[i].items
                                    items.remove(at: index)
                                    itemSets[i] = PeerItemSet(
                                        peerId: itemSets[i].peerId,
                                        peer: itemSets[i].peer,
                                        maxReadId: itemSets[i].maxReadId,
                                        items: items,
                                        totalCount: items.count
                                    )
                                }
                            }
                        case let .added(peerId, item):
                            var found = false
                            for i in 0 ..< itemSets.count {
                                if itemSets[i].peerId == peerId {
                                    found = true
                                    
                                    var items = itemSets[i].items
                                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                                        items.remove(at: index)
                                    }
                                    
                                    if peerId == self.account.peerId {
                                        items.append(Item(
                                            id: item.id,
                                            timestamp: item.timestamp,
                                            media: item.media,
                                            seenCount: item.seenCount,
                                            seenPeers: item.seenPeers,
                                            privacy: item.privacy
                                        ))
                                    } else {
                                        items.append(item)
                                    }
                                    
                                    items.sort(by: { lhsItem, rhsItem in
                                        if lhsItem.timestamp != rhsItem.timestamp {
                                            return lhsItem.timestamp < rhsItem.timestamp
                                        }
                                        return lhsItem.id < rhsItem.id
                                    })
                                    itemSets[i] = PeerItemSet(
                                        peerId: itemSets[i].peerId,
                                        peer: itemSets[i].peer,
                                        maxReadId: itemSets[i].maxReadId,
                                        items: items,
                                        totalCount: items.count
                                    )
                                }
                            }
                            if !found, let peer = peers[peerId] {
                                itemSets.insert(PeerItemSet(
                                    peerId: peerId,
                                    peer: EnginePeer(peer),
                                    maxReadId: 0,
                                    items: [item],
                                    totalCount: 1
                                ), at: 0)
                            }
                        case let .read(peerId, maxId):
                            for i in 0 ..< itemSets.count {
                                if itemSets[i].peerId == peerId {
                                    let items = itemSets[i].items
                                    itemSets[i] = PeerItemSet(
                                        peerId: itemSets[i].peerId,
                                        peer: itemSets[i].peer,
                                        maxReadId: max(itemSets[i].maxReadId, maxId),
                                        items: items,
                                        totalCount: items.count
                                    )
                                }
                            }
                        }
                    }
                    
                    itemSets.sort(by: { lhs, rhs in
                        guard let lhsItem = lhs.items.first, let rhsItem = rhs.items.first else {
                            if lhs.items.first != nil {
                                return false
                            } else {
                                return true
                            }
                        }
                        
                        if lhsItem.timestamp != rhsItem.timestamp {
                            return lhsItem.timestamp > rhsItem.timestamp
                        }
                        return lhsItem.id > rhsItem.id
                    })
                    
                    if !itemSets.contains(where: { $0.peerId == self.account.peerId }) {
                        if let peer = peers[self.account.peerId] {
                            itemSets.insert(PeerItemSet(peerId: peer.id, peer: EnginePeer(peer), maxReadId: 0, items: [], totalCount: 0), at: 0)
                        }
                    }
                    
                    self.stateValue.itemSets = itemSets
                })
            })
            
            self.loadMore(refresh: true)
        }
        
        deinit {
            self.loadMoreDisposable.dispose()
            self.pollDisposable?.dispose()
            for (_, disposable) in self.peerDisposables {
                disposable.dispose()
            }
        }
        
        func loadPeer(id: EnginePeer.Id) {
            if self.peerDisposables[id] == nil {
                let disposable = MetaDisposable()
                self.peerDisposables[id] = disposable
                
                let account = self.account
                let queue = self.queue
                
                disposable.set((self.account.postbox.transaction { transaction -> Api.InputUser? in
                    return transaction.getPeer(id).flatMap(apiInputUser)
                }
                |> mapToSignal { inputPeer -> Signal<PeerItemSet?, NoError> in
                    guard let inputPeer = inputPeer else {
                        return .single(nil)
                    }
                    return account.network.request(Api.functions.stories.getUserStories(flags: 0, userId: inputPeer, offsetId: 0, limit: 100))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { stories -> Signal<PeerItemSet?, NoError> in
                        guard let stories = stories else {
                            return .single(nil)
                        }
                        return account.postbox.transaction { transaction -> PeerItemSet? in
                            switch stories {
                            case let .stories(_, apiStories, users):
                                var parsedItemSets: [PeerItemSet] = []
                                
                                var peers: [Peer] = []
                                var peerPresences: [PeerId: Api.User] = [:]
                                
                                for user in users {
                                    let telegramUser = TelegramUser(user: user)
                                    peers.append(telegramUser)
                                    peerPresences[telegramUser.id] = user
                                }
                                
                                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                    return updated
                                })
                                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                                
                                let peerId = id
                                
                                for apiStory in apiStories {
                                    switch apiStory {
                                    case let .storyItem(flags, id, date, _, _, media, privacy, recentViewers, viewCount):
                                        let _ = flags
                                        let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                                        if let parsedMedia = parsedMedia {
                                            var seenPeers: [EnginePeer] = []
                                            if let recentViewers = recentViewers {
                                                for id in recentViewers {
                                                    if let peer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))) {
                                                        seenPeers.append(EnginePeer(peer))
                                                    }
                                                }
                                            }
                                            
                                            var parsedPrivacy: EngineStoryPrivacy?
                                            if let privacy = privacy {
                                                var base: EngineStoryPrivacy.Base = .everyone
                                                var additionalPeerIds: [EnginePeer.Id] = []
                                                for rule in privacy {
                                                    switch rule {
                                                    case .privacyValueAllowAll:
                                                        base = .everyone
                                                    case .privacyValueAllowContacts:
                                                        base = .contacts
                                                    case .privacyValueAllowCloseFriends:
                                                        base = .closeFriends
                                                    case let .privacyValueAllowUsers(users):
                                                        for id in users {
                                                            additionalPeerIds.append(EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)))
                                                        }
                                                    case let .privacyValueAllowChatParticipants(chats):
                                                        for id in chats {
                                                            if let peer = transaction.getPeer(EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(id))) {
                                                                additionalPeerIds.append(peer.id)
                                                            } else if let peer = transaction.getPeer(EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(id))) {
                                                                additionalPeerIds.append(peer.id)
                                                            }
                                                        }
                                                    default:
                                                        break
                                                    }
                                                }
                                                parsedPrivacy = EngineStoryPrivacy(base: base, additionallyIncludePeers: additionalPeerIds)
                                            }
                                            
                                            let item = StoryListContext.Item(
                                                id: id,
                                                timestamp: date,
                                                media: EngineMedia(parsedMedia),
                                                seenCount: viewCount.flatMap(Int.init) ?? 0,
                                                seenPeers: seenPeers,
                                                privacy: parsedPrivacy
                                            )
                                            if !parsedItemSets.isEmpty && parsedItemSets[parsedItemSets.count - 1].peerId == peerId {
                                                parsedItemSets[parsedItemSets.count - 1].items.append(item)
                                                parsedItemSets[parsedItemSets.count - 1].totalCount = parsedItemSets[parsedItemSets.count - 1].items.count
                                            } else {
                                                parsedItemSets.append(StoryListContext.PeerItemSet(peerId: peerId, peer: transaction.getPeer(peerId).flatMap(EnginePeer.init), maxReadId: 0, items: [item], totalCount: 1))
                                            }
                                        }
                                    case .storyItemDeleted:
                                        break
                                    }
                                }
                                
                                return parsedItemSets.first
                            }
                        }
                    }
                }
                |> deliverOn(queue)).start(next: { [weak self] itemSet in
                    guard let `self` = self, let itemSet = itemSet else {
                        return
                    }
                    var itemSets = self.stateValue.itemSets
                    if let index = itemSets.firstIndex(where: { $0.peerId == id }) {
                        itemSets[index] = itemSet
                    }
                    self.stateValue.itemSets = itemSets
                }))
            }
        }
        
        func upload(media: EngineStoryInputMedia, privacy: EngineStoryPrivacy) {
            let uploadContext = UploadContext()
            self.uploadContexts.append(uploadContext)
            uploadContext.disposable.set((_internal_uploadStory(account: self.account, media: media, privacy: privacy)
            |> deliverOn(self.queue)).start(next: { _ in
            }, completed: { [weak self, weak uploadContext] in
                guard let `self` = self, let uploadContext = uploadContext else {
                    return
                }
                if let index = self.uploadContexts.firstIndex(where: { $0 === uploadContext }) {
                    self.uploadContexts.remove(at: index)
                }
            }))
        }
        
        func loadMore(refresh: Bool) {
            if self.isLoadingMore {
                return
            }
            
            var effectiveLoadMoreToken: String?
            if refresh {
                effectiveLoadMoreToken = ""
            } else if let loadMoreToken = self.stateValue.loadMoreToken {
                effectiveLoadMoreToken = loadMoreToken.value ?? ""
            }
            guard let loadMoreToken = effectiveLoadMoreToken else {
                return
            }
            
            self.isLoadingMore = true
            let account = self.account
            
            self.pollDisposable?.dispose()
            self.pollDisposable = nil
            
            self.loadMoreDisposable.set((account.network.request(Api.functions.stories.getAllStories(offset: loadMoreToken))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.stories.AllStories?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<([PeerItemSet], LoadMoreToken?), NoError> in
                guard let result else {
                    return .single(([], nil))
                }
                return account.postbox.transaction { transaction -> ([PeerItemSet], LoadMoreToken?) in
                    switch result {
                    case let .allStories(_, userStorySets, nextOffset, users):
                        var parsedItemSets: [PeerItemSet] = []
                        
                        var peers: [Peer] = []
                        var peerPresences: [PeerId: Api.User] = [:]
                        
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            peerPresences[telegramUser.id] = user
                        }
                        
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                        
                        for userStories in userStorySets {
                            let apiUserId: Int64
                            let apiStories: [Api.StoryItem]
                            var apiTotalCount: Int32?
                            switch userStories {
                            case let .userStories(userId, stories):
                                apiUserId = userId
                                apiStories = stories
                            case let .userStoriesSlice(totalCount, userId, stories):
                                apiUserId = userId
                                apiStories = stories
                                apiTotalCount = totalCount
                            }
                            
                            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(apiUserId))
                            for apiStory in apiStories {
                                switch apiStory {
                                case let .storyItem(flags, id, date, _, _, media, privacy, recentViewers, viewCount):
                                    let _ = flags
                                    let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                                    if let parsedMedia = parsedMedia {
                                        var seenPeers: [EnginePeer] = []
                                        if let recentViewers = recentViewers {
                                            for id in recentViewers {
                                                if let peer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))) {
                                                    seenPeers.append(EnginePeer(peer))
                                                }
                                            }
                                        }
                                        
                                        var parsedPrivacy: EngineStoryPrivacy?
                                        if let privacy = privacy {
                                            var base: EngineStoryPrivacy.Base = .everyone
                                            var additionalPeerIds: [EnginePeer.Id] = []
                                            for rule in privacy {
                                                switch rule {
                                                case .privacyValueAllowAll:
                                                    base = .everyone
                                                case .privacyValueAllowContacts:
                                                    base = .contacts
                                                case .privacyValueAllowCloseFriends:
                                                    base = .closeFriends
                                                case let .privacyValueAllowUsers(users):
                                                    for id in users {
                                                        additionalPeerIds.append(EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)))
                                                    }
                                                case let .privacyValueAllowChatParticipants(chats):
                                                    for id in chats {
                                                        if let peer = transaction.getPeer(EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(id))) {
                                                            additionalPeerIds.append(peer.id)
                                                        } else if let peer = transaction.getPeer(EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(id))) {
                                                            additionalPeerIds.append(peer.id)
                                                        }
                                                    }
                                                default:
                                                    break
                                                }
                                            }
                                            parsedPrivacy = EngineStoryPrivacy(base: base, additionallyIncludePeers: additionalPeerIds)
                                        }
                                        
                                        let item = StoryListContext.Item(
                                            id: id,
                                            timestamp: date,
                                            media: EngineMedia(parsedMedia),
                                            seenCount: viewCount.flatMap(Int.init) ?? 0,
                                            seenPeers: seenPeers,
                                            privacy: parsedPrivacy
                                        )
                                        if !parsedItemSets.isEmpty && parsedItemSets[parsedItemSets.count - 1].peerId == peerId {
                                            parsedItemSets[parsedItemSets.count - 1].items.append(item)
                                        } else {
                                            parsedItemSets.append(StoryListContext.PeerItemSet(
                                                peerId: peerId,
                                                peer: transaction.getPeer(peerId).flatMap(EnginePeer.init),
                                                maxReadId: 0,
                                                items: [item],
                                                totalCount: apiTotalCount.flatMap(Int.init)
                                            ))
                                        }
                                    }
                                case .storyItemDeleted:
                                    break
                                }
                            }
                        }
                        
                        if !parsedItemSets.contains(where: { $0.peerId == account.peerId }) {
                            if let peer = transaction.getPeer(account.peerId) {
                                parsedItemSets.insert(PeerItemSet(peerId: peer.id, peer: EnginePeer(peer), maxReadId: 0, items: [], totalCount: 0), at: 0)
                            }
                        }
                        
                        return (parsedItemSets, nextOffset.flatMap { LoadMoreToken(value: $0) })
                    }
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let `self` = self else {
                    return
                }
                self.isLoadingMore = false
                
                var itemSets = self.stateValue.itemSets
                for itemSet in result.0 {
                    if let index = itemSets.firstIndex(where: { $0.peerId == itemSet.peerId }) {
                        let currentItemSet = itemSets[index]
                        
                        var items = currentItemSet.items
                        for item in itemSet.items {
                            if !items.contains(where: { $0.id == item.id }) {
                                items.append(item)
                            }
                        }
                        
                        items.sort(by: { lhsItem, rhsItem in
                            if lhsItem.timestamp != rhsItem.timestamp {
                                return lhsItem.timestamp < rhsItem.timestamp
                            }
                            return lhsItem.id < rhsItem.id
                        })
                        
                        itemSets[index] = PeerItemSet(
                            peerId: itemSet.peerId,
                            peer: itemSet.peer,
                            maxReadId: itemSet.maxReadId,
                            items: items,
                            totalCount: items.count
                        )
                    } else {
                        itemSet.items.sort(by: { lhsItem, rhsItem in
                            if lhsItem.timestamp != rhsItem.timestamp {
                                return lhsItem.timestamp < rhsItem.timestamp
                            }
                            return lhsItem.id < rhsItem.id
                        })
                        itemSets.append(itemSet)
                    }
                }
                
                itemSets.sort(by: { lhs, rhs in
                    guard let lhsItem = lhs.items.first, let rhsItem = rhs.items.first else {
                        if lhs.items.first != nil {
                            return false
                        } else {
                            return true
                        }
                    }
                    
                    if lhsItem.timestamp != rhsItem.timestamp {
                        return lhsItem.timestamp > rhsItem.timestamp
                    }
                    return lhsItem.id > rhsItem.id
                })
                
                self.stateValue = State(itemSets: itemSets, uploadProgress: self.stateValue.uploadProgress, loadMoreToken: result.1)
            }))
        }
        
        func delete(id: Int32) {
            let _ = _internal_deleteStory(account: self.account, id: id).start()
            
            var itemSets: [PeerItemSet] = self.stateValue.itemSets
            for i in (0 ..< itemSets.count).reversed() {
                if let index = itemSets[i].items.firstIndex(where: { $0.id == id }) {
                    var items = itemSets[i].items
                    items.remove(at: index)
                    if items.isEmpty {
                        itemSets.remove(at: i)
                    } else {
                        itemSets[i] = PeerItemSet(
                            peerId: itemSets[i].peerId,
                            peer: itemSets[i].peer,
                            maxReadId: itemSets[i].maxReadId,
                            items: items,
                            totalCount: items.count
                        )
                    }
                }
            }
            self.stateValue.itemSets = itemSets
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.state.get().start(next: subscriber.putNext)
        }
    }
    
    init(account: Account, scope: Scope) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, scope: scope)
        })
    }
    
    public func delete(id: Int32) {
        self.impl.with { impl in
            impl.delete(id: id)
        }
    }
    
    public func upload(media: EngineStoryInputMedia, privacy: EngineStoryPrivacy) {
        self.impl.with { impl in
            impl.upload(media: media, privacy: privacy)
        }
    }
}
