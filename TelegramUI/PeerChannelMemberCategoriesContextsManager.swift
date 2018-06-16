import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

enum PeerChannelMemberContextKey: Hashable {
    case recent
    case recentSearch(String)
    case admins
    case restrictedAndBanned
}

private final class PeerChannelMemberCategoriesContextsManagerImpl {
    fileprivate var contexts: [PeerId: PeerChannelMemberCategoriesContext] = [:]
    
    func getContext(postbox: Postbox, network: Network, peerId: PeerId, key: PeerChannelMemberContextKey, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl) {
        if let current = self.contexts[peerId] {
            return current.getContext(key: key, updated: updated)
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
            return context.getContext(key: key, updated: updated)
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
    
    private func getContext(postbox: Postbox, network: Network, peerId: PeerId, key: PeerChannelMemberContextKey, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        assert(Queue.mainQueue().isCurrent())
        if let (disposable, control) = self.impl.syncWith({ impl in
            return impl.getContext(postbox: postbox, network: network, peerId: peerId, key: key, updated: updated)
        }) {
            return (disposable, control)
        } else {
            return (EmptyDisposable, nil)
        }
    }
    
    func recent(postbox: Postbox, network: Network, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        let key: PeerChannelMemberContextKey
        if let searchQuery = searchQuery {
            key = .recentSearch(searchQuery)
        } else {
            key = .recent
        }
        return self.getContext(postbox: postbox, network: network, peerId: peerId, key: key, updated: updated)
    }
    
    func admins(postbox: Postbox, network: Network, peerId: PeerId, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, peerId: peerId, key: .admins, updated: updated)
    }
    
    func restrictedAndBanned(postbox: Postbox, network: Network, peerId: PeerId, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, peerId: peerId, key: .restrictedAndBanned, updated: updated)
    }
    
    func updateMemberBannedRights(account: Account, peerId: PeerId, memberId: PeerId, bannedRights: TelegramChannelBannedRights?) -> Signal<Void, NoError> {
        return updateChannelMemberBannedRights(account: account, peerId: peerId, memberId: memberId, rights: bannedRights)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] (previous, updated) in
            if let strongSelf = self {
                strongSelf.impl.with { impl in
                    for (_, context) in impl.contexts {
                        context.replayUpdates([(previous, updated)])
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
                    for (_, context) in impl.contexts {
                        context.replayUpdates([(previous, updated)])
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
                    for (_, context) in impl.contexts {
                        context.replayUpdates([(previous, updated)])
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
}
