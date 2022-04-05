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
    }
    
    func loadMore(limit: Int32) {
        if case .ready(true) = self.dataState {
            self.dataState = .loading
            self.pushState()
            
            let maxId = self.peers.last?.peerId.id
            let peerId = self.peerId
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
                        var peers: [Peer] = []
                        for chat in chats {
                            if let peer = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(peer)
                            }
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer? in
                            return updated
                        })
                        
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
