import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public enum GroupsInCommonDataState: Equatable {
    case loading
    case ready(canLoadMore: Bool)
}

public struct GroupsInCommonState: Equatable {
    public var peers: [RenderedPeer]
    public var count: Int?
    public var dataState: GroupsInCommonDataState
}

private final class GroupsInCommonContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    private let hintGroupInCommon: PeerId?
    
    private let disposable = MetaDisposable()
    private let cacheDisposable = MetaDisposable()
    
    private var peers: [RenderedPeer] = []
    private var count: Int?
    private var dataState: GroupsInCommonDataState = .ready(canLoadMore: true)
    
    private let stateValue = Promise<GroupsInCommonState>()
    var state: Signal<GroupsInCommonState, NoError> {
        return self.stateValue.get()
    }
    
    init(queue: Queue, account: Account, peerId: PeerId, hintGroupInCommon: PeerId?) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
        self.hintGroupInCommon = hintGroupInCommon
        
        if let hintGroupInCommon = hintGroupInCommon {
            let _ = (self.account.postbox.loadedPeerWithId(hintGroupInCommon)
            |> deliverOn(self.queue)).start(next: { [weak self] peer in
                if let strongSelf = self {
                    strongSelf.peers.append(RenderedPeer(peer: peer))
                    strongSelf.pushState()
                }
            })
        }
        
        self.loadMore(limit: 32)
    }
    
    deinit {
        self.disposable.dispose()
        self.cacheDisposable.dispose()
    }
    
    func loadMore(limit: Int32) {
        let peerId = self.peerId
        
        if case .ready(true) = self.dataState {
            if self.peers.isEmpty {
                self.cacheDisposable.set((self.account.postbox.transaction { transaction -> ([RenderedPeer], Int32)? in
                    if let cached = transaction.retrieveItemCacheEntry(id: entryId(peerId: peerId))?.get(CachedGroupsInCommon.self) {
                        var peers: [RenderedPeer] = []
                        for peerId in cached.peerIds {
                            if let peer = transaction.getPeer(peerId) {
                                peers.append(RenderedPeer(peer: peer))
                            }
                        }
                        return (peers, cached.count)
                    }
                    return nil
                } |> deliverOn(self.queue)).start(next: { [weak self] peersAndCount in
                    guard let self else {
                        return
                    }
                    if case .loading = self.dataState, let (peers, count) = peersAndCount {
                        self.peers = peers
                        self.count = Int(count)
                        self.pushState()
                    }
                }))
            }
            
            self.dataState = .loading
            self.pushState()
            
            let maxId = self.peers.last?.peerId.id
            let accountPeerId = self.account.peerId
            let network = self.account.network
            let postbox = self.account.postbox
            let signal: Signal<([Peer], Int), NoError> = self.account.postbox.transaction { transaction -> Api.InputUser? in
                return transaction.getPeer(peerId).flatMap(apiInputUser)
            }
            |> mapToSignal { inputUser -> Signal<([Peer], Int), NoError> in
                guard let inputUser = inputUser else {
                    return .single(([], 0))
                }
                return network.request(Api.functions.messages.getCommonChats(userId: inputUser, maxId: maxId?._internalGetInt64Value() ?? 0, limit: limit))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([Peer], Int), NoError> in
                    let chats: [Api.Chat]
                    let count: Int?
                    if let result = result {
                        switch result {
                        case let .chats(apiChats):
                            chats = apiChats
                            count = nil
                        case let .chatsSlice(apiCount, apiChats):
                            chats = apiChats
                            count = Int(apiCount)
                        }
                    } else {
                        chats = []
                        count = nil
                    }
                    
                    return postbox.transaction { transaction -> ([Peer], Int) in
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        
                        var peers: [Peer] = []
                        for chat in chats {
                            if let peer = transaction.getPeer(chat.peerId) {
                                peers.append(peer)
                            }
                        }
                        return (peers, count ?? 0)
                    }
                }
            }
            
            self.disposable.set((signal
            |> deliverOn(self.queue)).start(next: { [weak self] (peers, count) in
                guard let strongSelf = self else {
                    return
                }
                var existingPeers = Set(strongSelf.peers.map { $0.peerId })
                for peer in peers {
                    if !existingPeers.contains(peer.id) {
                        existingPeers.insert(peer.id)
                        strongSelf.peers.append(RenderedPeer(peer: peer))
                    }
                }
                
                if maxId == nil {
                    strongSelf.cacheDisposable.set(postbox.transaction { transaction in
                        if let entry = CodableEntry(CachedGroupsInCommon(peerIds: peers.map { $0.id }, count: Int32(count))) {
                            transaction.putItemCacheEntry(id: entryId(peerId: peerId), entry: entry)
                        }
                    }.start())
                }
                
                let updatedCount = max(strongSelf.peers.count, count)
                strongSelf.count = updatedCount
                strongSelf.dataState = .ready(canLoadMore: count != 0 && updatedCount > strongSelf.peers.count)
                strongSelf.pushState()
            }))
        }
    }
    
    private func pushState() {
        self.stateValue.set(.single(GroupsInCommonState(peers: self.peers, count: self.count, dataState: self.dataState)))
    }
}

public final class GroupsInCommonContext {
    private let queue: Queue = .mainQueue()
    private let impl: QueueLocalObject<GroupsInCommonContextImpl>
    
    public var state: Signal<GroupsInCommonState, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                disposable.set(impl.state.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            
            return disposable
        }
    }
    
    public init(account: Account, peerId: PeerId, hintGroupInCommon: PeerId? = nil) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return GroupsInCommonContextImpl(queue: queue, account: account, peerId: peerId, hintGroupInCommon: hintGroupInCommon)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore(limit: 32)
        }
    }
}

private final class CachedGroupsInCommon: Codable {
    enum CodingKeys: String, CodingKey {
        case peerIds
        case count
    }
    
    var peerIds: [PeerId]
    let count: Int32
    
    init(peerIds: [PeerId], count: Int32) {
        self.peerIds = peerIds
        self.count = count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.peerIds = try container.decode([PeerId].self, forKey: .peerIds)
        self.count = try container.decode(Int32.self, forKey: .count)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.peerIds, forKey: .peerIds)
        try container.encode(self.count, forKey: .count)
    }
}

private func entryId(peerId: EnginePeer.Id) -> ItemCacheEntryId {
    let cacheKey = ValueBoxKey(length: 8)
    cacheKey.setInt64(0, value: peerId.toInt64())
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedGroupsInCommon, key: cacheKey)
}
