import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit

public struct BlockedPeersContextState: Equatable {
    public var isLoadingMore: Bool
    public var canLoadMore: Bool
    public var totalCount: Int?
    public var peers: [RenderedPeer]
}

public enum BlockedPeersContextAddError {
    case generic
}

public enum BlockedPeersContextRemoveError {
    case generic
}

public final class BlockedPeersContext {
    public enum Subject {
        case blocked
        case stories
    }
    
    private let account: Account
    private let subject: Subject
    private var _state: BlockedPeersContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<BlockedPeersContextState>()
    public var state: Signal<BlockedPeersContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    
    public init(account: Account, subject: Subject) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self.subject = subject
        
        self._state = BlockedPeersContextState(isLoadingMore: false, canLoadMore: true, totalCount: nil, peers: [])
        self._statePromise.set(.single(self._state))
        
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    public func loadMore() {
        assert(Queue.mainQueue().isCurrent())
        
        if self._state.isLoadingMore || !self._state.canLoadMore {
            return
        }
        self._state = BlockedPeersContextState(isLoadingMore: true, canLoadMore: self._state.canLoadMore, totalCount: self._state.totalCount, peers: self._state.peers)
        let postbox = self.account.postbox
        let accountPeerId = self.account.peerId
        
        var flags: Int32 = 0
        if case .stories = self.subject {
            flags |= 1 << 0
        }
        
        var limit: Int32 = 200
        if self._state.peers.count > 0 {
            limit = 100
        }
        
        self.disposable.set((self.account.network.request(Api.functions.contacts.getBlocked(flags: flags, offset: Int32(self._state.peers.count), limit: limit))
        |> retryRequestIfNotFrozen
        |> mapToSignal { result -> Signal<(peers: [RenderedPeer], canLoadMore: Bool, totalCount: Int?), NoError> in
            guard let result else {
                return .single((peers: [], canLoadMore: false, totalCount: 0))
            }
            return postbox.transaction { transaction -> (peers: [RenderedPeer], canLoadMore: Bool, totalCount: Int?) in
                switch result {
                    case let .blocked(blocked, chats, users):
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                            
                        var renderedPeers: [RenderedPeer] = []
                        for blockedPeer in blocked {
                            switch blockedPeer {
                            case let .peerBlocked(peerId, _):
                                if let peer = transaction.getPeer(peerId.peerId) {
                                    renderedPeers.append(RenderedPeer(peer: peer))
                                }
                            }
                        }
                        
                        return (renderedPeers, false, nil)
                    case let .blockedSlice(count, blocked, chats, users):
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        
                        var renderedPeers: [RenderedPeer] = []
                        for blockedPeer in blocked {
                            switch blockedPeer {
                            case let .peerBlocked(peerId, _):
                                if let peer = transaction.getPeer(peerId.peerId) {
                                    renderedPeers.append(RenderedPeer(peer: peer))
                                }
                            }
                        }
                        
                        return (renderedPeers, true, Int(count))
                }
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] (peers, canLoadMore, totalCount) in
            guard let strongSelf = self else {
                return
            }
            
            var mergedPeers = strongSelf._state.peers
            var existingPeerIds = Set(mergedPeers.map { $0.peerId })
            for peer in peers {
                if !existingPeerIds.contains(peer.peerId) {
                    existingPeerIds.insert(peer.peerId)
                    mergedPeers.append(peer)
                }
            }
            
            let updatedTotalCount: Int?
            if !canLoadMore {
                updatedTotalCount = mergedPeers.count
            } else if let totalCount = totalCount {
                updatedTotalCount = totalCount
            } else {
                updatedTotalCount = strongSelf._state.totalCount
            }
            
            strongSelf._state = BlockedPeersContextState(isLoadingMore: false, canLoadMore: canLoadMore, totalCount: updatedTotalCount, peers: mergedPeers)
        }))
    }
    
    public func updatePeerIds(_ peerIds: [EnginePeer.Id]) -> Signal<Never, BlockedPeersContextAddError> {
        assert(Queue.mainQueue().isCurrent())
        
        let network = self.account.network
        let subject = self.subject
        let currentPeers = self._state.peers
        
        var flags: Int32 = 0
        if case .stories = self.subject {
            flags |= 1 << 0
        }
        
        return self.account.postbox.transaction { transaction -> [Peer] in
            var peers: [Peer] = []
            
            var removedPeerIds = Set<EnginePeer.Id>()
            var validPeerIds = Set<EnginePeer.Id>()
            var allPeerIds = Set<EnginePeer.Id>()
            
            for peerId in peerIds {
                if let peer = transaction.getPeer(peerId) {
                    peers.append(peer)
                }
                validPeerIds.insert(peerId)
                allPeerIds.insert(peerId)
            }
            for peer in currentPeers {
                if !validPeerIds.contains(peer.peerId) {
                    removedPeerIds.insert(peer.peerId)
                    allPeerIds.insert(peer.peerId)
                }
            }
            
            transaction.updatePeerCachedData(peerIds: allPeerIds, update: { peerId, current in
                let previous: CachedUserData
                if let current = current as? CachedUserData {
                    previous = current
                } else {
                    previous = CachedUserData()
                }
                if case .stories = subject {
                    var userFlags = previous.flags
                    if validPeerIds.contains(peerId) {
                        userFlags.insert(.isBlockedFromStories)
                    } else if removedPeerIds.contains(peerId) {
                        userFlags.remove(.isBlockedFromStories)
                    }
                    return previous.withUpdatedFlags(userFlags)
                } else {
                    if validPeerIds.contains(peerId) {
                        return previous.withUpdatedIsBlocked(true)
                    } else if removedPeerIds.contains(peerId) {
                        return previous.withUpdatedIsBlocked(false)
                    } else {
                        return previous
                    }
                }
            })
            
            return peers
        }
        |> castError(BlockedPeersContextAddError.self)
        |> mapToSignal { [weak self] peers -> Signal<Never, BlockedPeersContextAddError> in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    strongSelf._state = BlockedPeersContextState(isLoadingMore: strongSelf._state.isLoadingMore, canLoadMore: strongSelf._state.canLoadMore, totalCount: peers.count, peers: peers.map(RenderedPeer.init))
                }
            }
            let inputPeers = peers.compactMap { apiInputPeer($0) }
            return network.request(Api.functions.contacts.setBlocked(flags: flags, id: inputPeers, limit: Int32(max(currentPeers.count, peers.count))))
            |> mapError { _ -> BlockedPeersContextAddError in
                return .generic
            }
            |> mapToSignal { _ -> Signal<Never, BlockedPeersContextAddError> in
                return .complete()
            }
        }
    }
    
    public func add(peerId: PeerId) -> Signal<Never, BlockedPeersContextAddError> {
        assert(Queue.mainQueue().isCurrent())
        
        let postbox = self.account.postbox
        let network = self.account.network
        let subject = self.subject
        
        var flags: Int32 = 0
        if case .stories = self.subject {
            flags |= 1 << 0
        }
    
        return self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> castError(BlockedPeersContextAddError.self)
        |> mapToSignal { [weak self] inputPeer -> Signal<Never, BlockedPeersContextAddError> in
            guard let inputPeer = inputPeer else {
                return .fail(.generic)
            }
            return network.request(Api.functions.contacts.block(flags: flags, id: inputPeer))
            |> mapError { _ -> BlockedPeersContextAddError in
                return .generic
            }
            |> mapToSignal { _ -> Signal<Peer?, BlockedPeersContextAddError> in
                return postbox.transaction { transaction -> Peer? in
                    if peerId.namespace == Namespaces.Peer.CloudUser {
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            let previous: CachedUserData
                            if let current = current as? CachedUserData {
                                previous = current
                            } else {
                                previous = CachedUserData()
                            }
                            if case .stories = subject {
                                var userFlags = previous.flags
                                userFlags.insert(.isBlockedFromStories)
                                return previous.withUpdatedFlags(userFlags)
                            } else {
                                return previous.withUpdatedIsBlocked(true)
                            }
                        })
                    }
                    
                    return transaction.getPeer(peerId)
                }
                |> castError(BlockedPeersContextAddError.self)
            }
            |> deliverOnMainQueue
            |> mapToSignal { peer -> Signal<Never, BlockedPeersContextAddError> in
                guard let strongSelf = self, let peer = peer else {
                    return .complete()
                }
                
                var mergedPeers = strongSelf._state.peers
                let existingPeerIds = Set(mergedPeers.map { $0.peerId })
                if !existingPeerIds.contains(peer.id) {
                    mergedPeers.insert(RenderedPeer(peer: peer), at: 0)
                }
                
                let updatedTotalCount: Int?
                if let totalCount = strongSelf._state.totalCount {
                    updatedTotalCount = totalCount + 1
                } else {
                    updatedTotalCount = nil
                }
                
                strongSelf._state = BlockedPeersContextState(isLoadingMore: strongSelf._state.isLoadingMore, canLoadMore: strongSelf._state.canLoadMore, totalCount: updatedTotalCount, peers: mergedPeers)
                return .complete()
            }
        }
    }
    
    public func remove(peerId: PeerId) -> Signal<Never, BlockedPeersContextRemoveError> {
        assert(Queue.mainQueue().isCurrent())
        let postbox = self.account.postbox
        let network = self.account.network
        let subject = self.subject
        
        var flags: Int32 = 0
        if case .stories = self.subject {
            flags |= 1 << 0
        }
        
        return self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> castError(BlockedPeersContextRemoveError.self)
        |> mapToSignal { [weak self] inputPeer -> Signal<Never, BlockedPeersContextRemoveError> in
            guard let inputPeer = inputPeer else {
                return .fail(.generic)
            }
            return network.request(Api.functions.contacts.unblock(flags: flags, id: inputPeer))
            |> mapError { _ -> BlockedPeersContextRemoveError in
                return .generic
            }
            |> mapToSignal { value in
                return postbox.transaction { transaction -> Peer? in
                    if peerId.namespace == Namespaces.Peer.CloudUser {
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            let previous: CachedUserData
                            if let current = current as? CachedUserData {
                                previous = current
                            } else {
                                previous = CachedUserData()
                            }
                            if case .stories = subject {
                                var userFlags = previous.flags
                                userFlags.remove(.isBlockedFromStories)
                                return previous.withUpdatedFlags(userFlags)
                            } else {
                                return previous.withUpdatedIsBlocked(false)
                            }
                        })
                    }
                    return transaction.getPeer(peerId)
                }
                |> castError(BlockedPeersContextRemoveError.self)
            }
            |> deliverOnMainQueue
            |> mapToSignal { _ -> Signal<Never, BlockedPeersContextRemoveError> in
                guard let strongSelf = self else {
                    return .complete()
                }
                
                var mergedPeers = strongSelf._state.peers
                var found = false
                for i in 0 ..< mergedPeers.count {
                    if mergedPeers[i].peerId == peerId {
                        found = true
                        mergedPeers.remove(at: i)
                        break
                    }
                }
                
                let updatedTotalCount: Int?
                if let totalCount = strongSelf._state.totalCount {
                    if found {
                        updatedTotalCount = totalCount - 1
                    } else {
                        updatedTotalCount = totalCount
                    }
                } else {
                    updatedTotalCount = nil
                }
                
                strongSelf._state = BlockedPeersContextState(isLoadingMore: strongSelf._state.isLoadingMore, canLoadMore: strongSelf._state.canLoadMore, totalCount: updatedTotalCount, peers: mergedPeers)
                return .complete()
            }
        }
    }
}
