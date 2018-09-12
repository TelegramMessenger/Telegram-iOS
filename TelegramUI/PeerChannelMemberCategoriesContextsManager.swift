import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

enum PeerChannelMemberContextKey: Equatable, Hashable {
    case recent
    case recentSearch(String)
    case admins(String?)
    case restrictedAndBanned(String?)
    
    var hashValue: Int {
        switch self {
            case .recent:
                return 1
            case let .recentSearch(query):
                return query.hashValue
            case let .admins(query):
                return query?.hashValue ?? 2
            case let .restrictedAndBanned(query):
                return query?.hashValue ?? 3
        }
    }
}

private final class PeerChannelMemberCategoriesContextsManagerImpl {
    fileprivate var contexts: [PeerId: PeerChannelMemberCategoriesContext] = [:]
    
    func getContext(postbox: Postbox, network: Network, peerId: PeerId, key: PeerChannelMemberContextKey, requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl) {
        if let current = self.contexts[peerId] {
            return current.getContext(key: key, requestUpdate: requestUpdate, updated: updated)
        } else {
            var becameEmptyImpl: ((Bool) -> Void)?
            let context = PeerChannelMemberCategoriesContext(postbox: postbox, network: network, peerId: peerId, becameEmpty: { value in
                becameEmptyImpl?(value)
            })
            becameEmptyImpl = { [weak self, weak context] value in
                assert(Queue.mainQueue().isCurrent())
                if let strongSelf = self {
                    if let current = strongSelf.contexts[peerId], current === context {
                        strongSelf.contexts.removeValue(forKey: peerId)
                    }
                }
            }
            self.contexts[peerId] = context
            return context.getContext(key: key, requestUpdate: requestUpdate, updated: updated)
        }
    }
    
    func loadMore(peerId: PeerId, control: PeerChannelMemberCategoryControl) {
        if let context = self.contexts[peerId] {
            context.loadMore(control)
        }
    }
}

final class PeerChannelMemberCategoriesContextsManager {
    private let impl: QueueLocalObject<PeerChannelMemberCategoriesContextsManagerImpl>
    
    init() {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return PeerChannelMemberCategoriesContextsManagerImpl()
        })
    }
    
    func loadMore(peerId: PeerId, control: PeerChannelMemberCategoryControl?) {
        if let control = control {
            self.impl.with { impl in
                impl.loadMore(peerId: peerId, control: control)
            }
        }
    }
    
    private func getContext(postbox: Postbox, network: Network, peerId: PeerId, key: PeerChannelMemberContextKey, requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        assert(Queue.mainQueue().isCurrent())
        if let (disposable, control) = self.impl.syncWith({ impl in
            return impl.getContext(postbox: postbox, network: network, peerId: peerId, key: key, requestUpdate: requestUpdate, updated: updated)
        }) {
            return (disposable, control)
        } else {
            return (EmptyDisposable, nil)
        }
    }
    
    func externallyAdded(peerId: PeerId, participant: RenderedChannelParticipant) {
        self.impl.with { impl in
            for (contextPeerId, context) in impl.contexts {
                if contextPeerId == peerId {
                    context.replayUpdates([(nil, participant)])
                }
            }
        }
    }
    
    func recent(postbox: Postbox, network: Network, peerId: PeerId, searchQuery: String? = nil, requestUpdate: Bool = true, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        let key: PeerChannelMemberContextKey
        if let searchQuery = searchQuery {
            key = .recentSearch(searchQuery)
        } else {
            key = .recent
        }
        return self.getContext(postbox: postbox, network: network, peerId: peerId, key: key, requestUpdate: requestUpdate, updated: updated)
    }
    
    func admins(postbox: Postbox, network: Network, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, peerId: peerId, key: .admins(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func restrictedAndBanned(postbox: Postbox, network: Network, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, peerId: peerId, key: .restrictedAndBanned(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func updateMemberBannedRights(account: Account, peerId: PeerId, memberId: PeerId, bannedRights: TelegramChannelBannedRights?) -> Signal<Void, NoError> {
        return updateChannelMemberBannedRights(account: account, peerId: peerId, memberId: memberId, rights: bannedRights)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] (previous, updated) in
            if let strongSelf = self {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(previous, updated)])
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
    
    func updateMemberAdminRights(account: Account, peerId: PeerId, memberId: PeerId, adminRights: TelegramChannelAdminRights) -> Signal<Void, NoError> {
        return updatePeerAdminRights(account: account, peerId: peerId, adminId: memberId, rights: adminRights)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, NoError> in
            return .single(nil)
        }
        |> deliverOnMainQueue
        |> beforeNext { [weak self] result in
            if let strongSelf = self, let (previous, updated) = result {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(previous, updated)])
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
    
    func addMember(account: Account, peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
        return addChannelMember(account: account, peerId: peerId, memberId: memberId)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, NoError> in
            return .single(nil)
        }
        |> deliverOnMainQueue
        |> beforeNext { [weak self] result in
            if let strongSelf = self, let (previous, updated) = result {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(previous, updated)])
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
    
    func addMembers(account: Account, peerId: PeerId, memberIds: [PeerId]) -> Signal<Void, NoError> {
        return addChannelMembers(account: account, peerId: peerId, memberIds: memberIds) |> deliverOnMainQueue
            |> beforeNext { [weak self] result in
                if let strongSelf = self {
                    strongSelf.impl.with { impl in
                        for (contextPeerId, context) in impl.contexts {
                            if peerId == contextPeerId {
                                context.reset(.recent)
                            }
                        }
                    }
                }
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .single(Void())
        }
    }
}
