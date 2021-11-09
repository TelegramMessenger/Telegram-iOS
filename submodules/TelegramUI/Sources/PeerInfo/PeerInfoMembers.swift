import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TemporaryCachedPeerDataManager

enum PeerInfoMemberRole {
    case creator
    case admin
    case member
}

enum PeerInfoMember: Equatable {
    case channelMember(RenderedChannelParticipant)
    case legacyGroupMember(peer: RenderedPeer, role: PeerInfoMemberRole, invitedBy: PeerId?, presence: TelegramUserPresence?)
    case account(peer: RenderedPeer)
    
    var id: PeerId {
        switch self {
        case let .channelMember(channelMember):
            return channelMember.peer.id
        case let .legacyGroupMember(peer, _, _, _):
            return peer.peerId
        case let .account(peer):
            return peer.peerId
        }
    }
    
    var peer: Peer {
        switch self {
        case let .channelMember(channelMember):
            return channelMember.peer
        case let .legacyGroupMember(peer, _, _, _):
            return peer.peers[peer.peerId]!
        case let .account(peer):
            return peer.peers[peer.peerId]!
        }
    }
    
    var presence: TelegramUserPresence? {
        switch self {
        case let .channelMember(channelMember):
            return channelMember.presences[channelMember.peer.id] as? TelegramUserPresence
        case let .legacyGroupMember(_, _, _, presence):
            return presence
        case .account:
            return nil
        }
    }
    
    var role: PeerInfoMemberRole {
        switch self {
        case let .channelMember(channelMember):
            switch channelMember.participant {
            case .creator:
                return .creator
            case let .member(_, _, adminInfo, _, _):
                if adminInfo != nil {
                    return .admin
                } else {
                    return .member
                }
            }
        case let .legacyGroupMember(_, role, _, _):
            return role
        case .account:
            return .member
        }
    }
    
    var rank: String? {
        switch self {
            case let .channelMember(channelMember):
                switch channelMember.participant {
                case let .creator(_, _, rank):
                    return rank
                case let .member(_, _, _, _, rank):
                    return rank
                }
            case .legacyGroupMember:
                return nil
            case .account:
                return nil
        }
    }
}

enum PeerInfoMembersDataState: Equatable {
    case loading(isInitial: Bool)
    case ready(canLoadMore: Bool)
}

struct PeerInfoMembersState: Equatable {
    var canAddMembers: Bool
    var members: [PeerInfoMember]
    var dataState: PeerInfoMembersDataState
}

private func membersSortedByPresence(_ members: [PeerInfoMember], accountPeerId: PeerId) -> [PeerInfoMember] {
    return members.sorted(by: { lhs, rhs in
        if lhs.id == accountPeerId {
            return true
        } else if rhs.id == accountPeerId {
            return false
        }
        
        let lhsPresence = lhs.presence
        let rhsPresence = rhs.presence
        if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
            if lhsPresence.status < rhsPresence.status {
                return false
            } else if lhsPresence.status > rhsPresence.status {
                return true
            }
        } else if let _ = lhsPresence {
            return true
        } else if let _ = rhsPresence {
            return false
        }
        return lhs.id < rhs.id
    })
}

private final class PeerInfoMembersContextImpl {
    private let queue: Queue
    private let context: AccountContext
    private let peerId: PeerId
    
    private var canAddMembers = false
    private var members: [PeerInfoMember] = []
    private var dataState: PeerInfoMembersDataState = .loading(isInitial: true)
    private var removingMemberIds: [PeerId: Disposable] = [:]
    
    private let stateValue = Promise<PeerInfoMembersState>()
    var state: Signal<PeerInfoMembersState, NoError> {
        return self.stateValue.get()
    }
    private let disposable = MetaDisposable()
    private let peerDisposable = MetaDisposable()
    private var channelMembersControl: PeerChannelMemberCategoryControl?
    
    init(queue: Queue, context: AccountContext, peerId: PeerId) {
        self.queue = queue
        self.context = context
        self.peerId = peerId
        
        self.pushState()
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            let (disposable, control) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, updated: { [weak self] state in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    let unsortedMembers = state.list.map(PeerInfoMember.channelMember)
                    let members: [PeerInfoMember]
                    if unsortedMembers.count <= 50 {
                        members = membersSortedByPresence(unsortedMembers, accountPeerId: strongSelf.context.account.peerId)
                    } else {
                        members = unsortedMembers
                    }
                    strongSelf.members = members
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
            
            self.peerDisposable.set((context.account.postbox.peerView(id: peerId)
            |> deliverOn(self.queue)).start(next: { [weak self] view in
                guard let strongSelf = self else {
                    return
                }
                if let channel = peerViewMainPeer(view) as? TelegramChannel {
                    var canAddMembers = false
                    switch channel.info {
                    case .broadcast:
                        break
                    case .group:
                        if channel.flags.contains(.isCreator) || channel.hasPermission(.inviteMembers) {
                            canAddMembers = true
                        }
                    }
                    strongSelf.canAddMembers = canAddMembers
                    strongSelf.pushState()
                }
            }))
        } else if peerId.namespace == Namespaces.Peer.CloudGroup {
            self.disposable.set((context.account.postbox.peerView(id: peerId)
            |> deliverOn(self.queue)).start(next: { [weak self] view in
                guard let strongSelf = self, let cachedData = view.cachedData as? CachedGroupData, let participantsData = cachedData.participants else {
                    return
                }
                var unsortedMembers: [PeerInfoMember] = []
                for participant in participantsData.participants {
                    if let peer = view.peers[participant.peerId] {
                        let role: PeerInfoMemberRole
                        let invitedBy: PeerId?
                        switch participant {
                        case .creator:
                            role = .creator
                            invitedBy = nil
                        case let .admin(_, invitedByValue, _):
                            role = .admin
                            invitedBy = invitedByValue
                        case let .member(_, invitedByValue, _):
                            role = .member
                            invitedBy = invitedByValue
                        }
                        unsortedMembers.append(.legacyGroupMember(peer: RenderedPeer(peer: peer), role: role, invitedBy: invitedBy, presence: view.peerPresences[participant.peerId] as? TelegramUserPresence))
                    }
                }
                
                if let group = peerViewMainPeer(view) as? TelegramGroup {
                    var canAddMembers = false
                    switch group.role {
                        case .admin, .creator:
                            canAddMembers = true
                        case .member:
                            break
                    }
                    if !group.hasBannedPermission(.banAddMembers) {
                        canAddMembers = true
                    }
                    strongSelf.canAddMembers = canAddMembers
                }
                
                strongSelf.members = membersSortedByPresence(unsortedMembers, accountPeerId: strongSelf.context.account.peerId)
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
        self.peerDisposable.dispose()
    }
    
    private func pushState() {
        if self.removingMemberIds.isEmpty {
            self.stateValue.set(.single(PeerInfoMembersState(canAddMembers: self.canAddMembers, members: self.members, dataState: self.dataState)))
        } else {
            self.stateValue.set(.single(PeerInfoMembersState(canAddMembers: self.canAddMembers, members: self.members.filter { member in
                return self.removingMemberIds[member.id] == nil
            }, dataState: self.dataState)))
        }
    }
    
    func loadMore() {
        if case .ready(true) = self.dataState, let channelMembersControl = self.channelMembersControl {
            self.context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: self.peerId, control: channelMembersControl)
        }
    }
    
    func removeMember(memberId: PeerId) {
        if removingMemberIds[memberId] == nil {
            let signal: Signal<Never, NoError>
            if self.peerId.namespace == Namespaces.Peer.CloudChannel {
                signal = context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: self.context.engine, peerId: self.peerId, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max))
                |> ignoreValues
            } else {
                signal = self.context.engine.peers.removePeerMember(peerId: self.peerId, memberId: memberId)
                |> ignoreValues
            }
            let completed: () -> Void = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let _ = strongSelf.removingMemberIds.removeValue(forKey: memberId) {
                    strongSelf.pushState()
                }
            }
            let disposable = MetaDisposable()
            self.removingMemberIds[memberId] = disposable
            
            self.pushState()
            
            disposable.set((signal
            |> deliverOn(self.queue)).start(completed: {
                completed()
            }))
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
    
    func removeMember(memberId: PeerId) {
        self.impl.with { impl in
            impl.removeMember(memberId: memberId)
        }
    }
    
    static func ==(lhs: PeerInfoMembersContext, rhs: PeerInfoMembersContext) -> Bool {
        return lhs === rhs
    }
}
