import Foundation
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore
import AccountContext
import TemporaryCachedPeerDataManager

enum PeerInfoMember: Equatable {
    case channelMember(RenderedChannelParticipant)
    
    var id: PeerId {
        switch self {
        case let .channelMember(channelMember):
            return channelMember.peer.id
        }
    }
    
    var peer: Peer {
        switch self {
            case let .channelMember(channelMember):
            return channelMember.peer
        }
    }
    
    var presence: TelegramUserPresence? {
        switch self {
        case let .channelMember(channelMember):
            return channelMember.presences[channelMember.peer.id] as? TelegramUserPresence
        }
    }
}

enum PeerInfoMembersDataState: Equatable {
    case loading(isInitial: Bool)
    case ready(canLoadMore: Bool)
}

struct PeerInfoMembersState: Equatable {
    var members: [PeerInfoMember]
    var dataState: PeerInfoMembersDataState
}

private final class PeerInfoMembersContextImpl {
    private let queue: Queue
    private let context: AccountContext
    private let peerId: PeerId
    
    private var members: [PeerInfoMember] = []
    private var dataState: PeerInfoMembersDataState = .loading(isInitial: true)
    
    private let stateValue = Promise<PeerInfoMembersState>()
    var state: Signal<PeerInfoMembersState, NoError> {
        return self.stateValue.get()
    }
    private let disposable = MetaDisposable()
    
    private var channelMembersControl: PeerChannelMemberCategoryControl?
    
    init(queue: Queue, context: AccountContext, peerId: PeerId) {
        self.queue = queue
        self.context = context
        self.peerId = peerId
        
        self.pushState()
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            let (disposable, control) = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, updated: { [weak self] state in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.members = state.list.map(PeerInfoMember.channelMember)
                    switch state.loadingState {
                    case let .loading(initial):
                        strongSelf.dataState = .loading(isInitial: initial)
                    case let .ready(hasMore):
                        strongSelf.dataState = .ready(canLoadMore: hasMore)
                    }
                    strongSelf.pushState()
                }
            })
            self.disposable.set(disposable)
            self.channelMembersControl = control
        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
            disposable.set((context.account.postbox.peerView(id: peerId)
            |> deliverOn(self.queue)).start(next: { [weak self] view in
                guard let strongSelf = self, let cachedData = view.cachedData as? CachedGroupData, let participantsData = cachedData.participants else {
                    return
                }
                var members: [PeerInfoMember] = []
                for participant in participantsData.participants {
                    if let peer = view.peers[participant.peerId] {
                        
                    }
                }
                strongSelf.dataState = .ready(canLoadMore: false)
                strongSelf.pushState()
            }))
        } else {
            self.dataState = .ready(canLoadMore: false)
            self.pushState()
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    private func pushState() {
        self.stateValue.set(.single(PeerInfoMembersState(members: self.members, dataState: self.dataState)))
    }
    
    func loadMore() {
        if case .ready(true) = self.dataState, let channelMembersControl = self.channelMembersControl {
            self.context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: self.peerId, control: channelMembersControl)
        }
    }
}

final class PeerInfoMembersContext: Equatable {
    private let queue = Queue.mainQueue()
    private let impl: QueueLocalObject<PeerInfoMembersContextImpl>
    
    var state: Signal<PeerInfoMembersState, NoError> {
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
    
    init(context: AccountContext, peerId: PeerId) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return PeerInfoMembersContextImpl(queue: queue, context: context, peerId: peerId)
        })
    }
    
    func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    static func ==(lhs: PeerInfoMembersContext, rhs: PeerInfoMembersContext) -> Bool {
        return lhs === rhs
    }
}
