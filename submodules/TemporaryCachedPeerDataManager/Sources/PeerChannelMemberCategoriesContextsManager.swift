import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramStringFormatting

enum PeerChannelMemberContextKey: Equatable, Hashable {
    case recent
    case recentSearch(String)
    case admins(String?)
    case contacts(String?)
    case bots(String?)
    case restrictedAndBanned(String?)
    case restricted(String?)
    case banned(String?)
}

private final class PeerChannelMembersOnlineContext {
    let subscribers = Bag<(Int32) -> Void>()
    let disposable: Disposable
    var value: Int32?
    var emptyTimer: SwiftSignalKit.Timer?
    
    init(disposable: Disposable) {
        self.disposable = disposable
    }
}

private final class ProfileDataPreloadContext {
    let subscribers = Bag<() -> Void>()
    
    let disposable: Disposable
    var emptyTimer: SwiftSignalKit.Timer?
    
    init(disposable: Disposable) {
        self.disposable = disposable
    }
}

private final class ProfileDataPhotoPreloadContext {
    let subscribers = Bag<(Any?) -> Void>()
    
    let disposable: Disposable
    var value: Any?
    var emptyTimer: SwiftSignalKit.Timer?
    
    init(disposable: Disposable) {
        self.disposable = disposable
    }
}

private final class PeerChannelMemberCategoriesContextsManagerImpl {
    fileprivate var contexts: [PeerId: PeerChannelMemberCategoriesContext] = [:]
    fileprivate var onlineContexts: [PeerId: PeerChannelMembersOnlineContext] = [:]
    fileprivate var profileDataPreloadContexts: [PeerId: ProfileDataPreloadContext] = [:]
    fileprivate var profileDataPhotoPreloadContexts: [PeerId: ProfileDataPhotoPreloadContext] = [:]
    
    func getContext(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, key: PeerChannelMemberContextKey, requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl) {
        if let current = self.contexts[peerId] {
            return current.getContext(key: key, requestUpdate: requestUpdate, updated: updated)
        } else {
            var becameEmptyImpl: ((Bool) -> Void)?
            let context = PeerChannelMemberCategoriesContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, becameEmpty: { value in
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
    
    func recentOnline(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, updated: @escaping (Int32) -> Void) -> Disposable {
        let context: PeerChannelMembersOnlineContext
        if let current = self.onlineContexts[peerId] {
            context = current
        } else {
            let disposable = MetaDisposable()
            context = PeerChannelMembersOnlineContext(disposable: disposable)
            self.onlineContexts[peerId] = context
            
            let signal = (
                chatOnlineMembers(postbox: postbox, network: network, peerId: peerId)
                |> then(
                    .complete()
                    |> delay(30.0, queue: .mainQueue())
                )
            ) |> restart
            
            disposable.set(signal.start(next: { [weak context] value in
                guard let context = context else {
                    return
                }
                context.value = value
                for f in context.subscribers.copyItems() {
                    f(value)
                }
            }))
        }
        
        if let emptyTimer = context.emptyTimer {
            emptyTimer.invalidate()
            context.emptyTimer = nil
        }
        
        let index = context.subscribers.add({ next in
            updated(next)
        })
        updated(context.value ?? 0)
        
        return ActionDisposable { [weak self, weak context] in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let current = strongSelf.onlineContexts[peerId], let context = context, current === context {
                    current.subscribers.remove(index)
                    if current.subscribers.isEmpty {
                        if current.emptyTimer == nil {
                            let timer = SwiftSignalKit.Timer(timeout: 60.0, repeat: false, completion: { [weak context] in
                                if let current = strongSelf.onlineContexts[peerId], let context = context, current === context {
                                    if current.subscribers.isEmpty {
                                        strongSelf.onlineContexts.removeValue(forKey: peerId)
                                        current.disposable.dispose()
                                    }
                                }
                            }, queue: Queue.mainQueue())
                            current.emptyTimer = timer
                            timer.start()
                        }
                    }
                }
            }
        }
    }
    
    func loadMore(peerId: PeerId, control: PeerChannelMemberCategoryControl) {
        if let context = self.contexts[peerId] {
            context.loadMore(control)
        }
    }
    
    func profileData(postbox: Postbox, network: Network, peerId: PeerId, customData: Signal<Never, NoError>?) -> Disposable {
        let context: ProfileDataPreloadContext
        if let current = self.profileDataPreloadContexts[peerId] {
            context = current
        } else {
            let disposable = DisposableSet()
            context = ProfileDataPreloadContext(disposable: disposable)
            self.profileDataPreloadContexts[peerId] = context
            
            if let customData = customData {
                disposable.add(customData.start())
            }
            
            /*disposable.set(signal.start(next: { [weak context] value in
                guard let context = context else {
                    return
                }
                context.value = value
                for f in context.subscribers.copyItems() {
                    f(value)
                }
            }))*/
        }
        
        if let emptyTimer = context.emptyTimer {
            emptyTimer.invalidate()
            context.emptyTimer = nil
        }
        
        let index = context.subscribers.add({
        })
        //updated(context.value ?? 0)
        
        return ActionDisposable { [weak self, weak context] in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let current = strongSelf.profileDataPreloadContexts[peerId], let context = context, current === context {
                    current.subscribers.remove(index)
                    if current.subscribers.isEmpty {
                        if current.emptyTimer == nil {
                            let timer = SwiftSignalKit.Timer(timeout: 60.0, repeat: false, completion: { [weak context] in
                                if let current = strongSelf.profileDataPreloadContexts[peerId], let context = context, current === context {
                                    if current.subscribers.isEmpty {
                                        strongSelf.profileDataPreloadContexts.removeValue(forKey: peerId)
                                        current.disposable.dispose()
                                    }
                                }
                            }, queue: Queue.mainQueue())
                            current.emptyTimer = timer
                            timer.start()
                        }
                    }
                }
            }
        }
    }
    
    func profilePhotos(postbox: Postbox, network: Network, peerId: PeerId, fetch: Signal<Any, NoError>, updated: @escaping (Any?) -> Void) -> Disposable {
        let context: ProfileDataPhotoPreloadContext
        if let current = self.profileDataPhotoPreloadContexts[peerId] {
            context = current
        } else {
            let disposable = MetaDisposable()
            context = ProfileDataPhotoPreloadContext(disposable: disposable)
            self.profileDataPhotoPreloadContexts[peerId] = context
            
            disposable.set(fetch.start(next: { [weak context] value in
                guard let context = context else {
                    return
                }
                context.value = value
                for f in context.subscribers.copyItems() {
                    f(value)
                }
            }))
        }
        
        if let emptyTimer = context.emptyTimer {
            emptyTimer.invalidate()
            context.emptyTimer = nil
        }
        
        let index = context.subscribers.add({ next in
            updated(next)
        })
        updated(context.value)
        
        return ActionDisposable { [weak self, weak context] in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let current = strongSelf.profileDataPhotoPreloadContexts[peerId], let context = context, current === context {
                    current.subscribers.remove(index)
                    if current.subscribers.isEmpty {
                        if current.emptyTimer == nil {
                            let timer = SwiftSignalKit.Timer(timeout: 60.0, repeat: false, completion: { [weak context] in
                                if let current = strongSelf.profileDataPhotoPreloadContexts[peerId], let context = context, current === context {
                                    if current.subscribers.isEmpty {
                                        strongSelf.profileDataPhotoPreloadContexts.removeValue(forKey: peerId)
                                        current.disposable.dispose()
                                    }
                                }
                            }, queue: Queue.mainQueue())
                            current.emptyTimer = timer
                            timer.start()
                        }
                    }
                }
            }
        }
    }
}

public final class PeerChannelMemberCategoriesContextsManager {
    private let impl: QueueLocalObject<PeerChannelMemberCategoriesContextsManagerImpl>
    
    public init() {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return PeerChannelMemberCategoriesContextsManagerImpl()
        })
    }
    
    public func loadMore(peerId: PeerId, control: PeerChannelMemberCategoryControl?) {
        if let control = control {
            self.impl.with { impl in
                impl.loadMore(peerId: peerId, control: control)
            }
        }
    }
    
    private func getContext(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, key: PeerChannelMemberContextKey, requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        assert(Queue.mainQueue().isCurrent())
        if let (disposable, control) = self.impl.syncWith({ impl in
            return impl.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: key, requestUpdate: requestUpdate, updated: updated)
        }) {
            return (disposable, control)
        } else {
            return (EmptyDisposable, nil)
        }
    }
    
    public func externallyAdded(peerId: PeerId, participant: RenderedChannelParticipant) {
        self.impl.with { impl in
            for (contextPeerId, context) in impl.contexts {
                if contextPeerId == peerId {
                    context.replayUpdates([(nil, participant, nil)])
                }
            }
        }
    }
    
    public func externallyRemoved(peerId: PeerId, memberId: PeerId) {
        self.impl.with { impl in
            for (contextPeerId, context) in impl.contexts {
                if contextPeerId == peerId {
                    context.replayUpdates([(.member(id: memberId, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: nil), nil, nil)])
                }
            }
        }
    }
    
    public func recent(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, requestUpdate: Bool = true, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        let key: PeerChannelMemberContextKey
        if let searchQuery = searchQuery {
            key = .recentSearch(searchQuery)
        } else {
            key = .recent
        }
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: key, requestUpdate: requestUpdate, updated: updated)
    }
    
    public func admins(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .admins(searchQuery), requestUpdate: true, updated: updated)
    }
    
    public func contacts(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .contacts(searchQuery), requestUpdate: true, updated: updated)
    }
    
    public func bots(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .bots(searchQuery), requestUpdate: true, updated: updated)
    }
    
    public func restricted(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .restricted(searchQuery), requestUpdate: true, updated: updated)
    }
    
    public func banned(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .banned(searchQuery), requestUpdate: true, updated: updated)
    }
    
    public func restrictedAndBanned(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .restrictedAndBanned(searchQuery), requestUpdate: true, updated: updated)
    }
    
    public func updateMemberBannedRights(account: Account, peerId: PeerId, memberId: PeerId, bannedRights: TelegramChatBannedRights?) -> Signal<Void, NoError> {
        return updateChannelMemberBannedRights(account: account, peerId: peerId, memberId: memberId, rights: bannedRights)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] (previous, updated, isMember) in
            if let strongSelf = self {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(previous, updated, isMember)])
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
    
    public func updateMemberAdminRights(account: Account, peerId: PeerId, memberId: PeerId, adminRights: TelegramChatAdminRights, rank: String?) -> Signal<Void, UpdateChannelAdminRightsError> {
        return updateChannelAdminRights(account: account, peerId: peerId, adminId: memberId, rights: adminRights, rank: rank)
        |> map(Optional.init)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] result in
            if let strongSelf = self, let (previous, updated) = result {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(previous, updated, nil)])
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, UpdateChannelAdminRightsError> in
            return .complete()
        }
    }
    
    public func transferOwnership(account: Account, peerId: PeerId, memberId: PeerId, password: String) -> Signal<Void, ChannelOwnershipTransferError> {
        return updateChannelOwnership(account: account, accountStateManager: account.stateManager, channelId: peerId, memberId: memberId, password: password)
        |> map(Optional.init)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] results in
            if let strongSelf = self, let results = results {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates(results.map { ($0.0, $0.1, nil) })
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, ChannelOwnershipTransferError> in
            return .complete()
        }
    }
    
    public func join(account: Account, peerId: PeerId) -> Signal<Never, JoinChannelError> {
        return joinChannel(account: account, peerId: peerId)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] result in
            if let strongSelf = self, let updated = result {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(nil, updated, nil)])
                        }
                    }
                }
            }
        }
        |> ignoreValues
    }
    
    public func addMember(account: Account, peerId: PeerId, memberId: PeerId) -> Signal<Never, AddChannelMemberError> {
        return addChannelMember(account: account, peerId: peerId, memberId: memberId)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] result in
            if let strongSelf = self {
                let (previous, updated) = result
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(previous, updated, nil)])
                        }
                    }
                }
            }
        }
        |> ignoreValues
    }
    
    public func addMembers(account: Account, peerId: PeerId, memberIds: [PeerId]) -> Signal<Void, AddChannelMemberError> {
        let signals: [Signal<(ChannelParticipant?, RenderedChannelParticipant)?, AddChannelMemberError>] = memberIds.map({ memberId in
            return addChannelMember(account: account, peerId: peerId, memberId: memberId)
            |> map(Optional.init)
            |> `catch` { error -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, AddChannelMemberError> in
                return .fail(error)
            }
        })
        return combineLatest(signals)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] results in
            if let strongSelf = self {
                strongSelf.impl.with { impl in
                    for result in results {
                        if let (previous, updated) = result {
                            for (contextPeerId, context) in impl.contexts {
                                if peerId == contextPeerId {
                                    context.replayUpdates([(previous, updated, nil)])
                                }
                            }
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, AddChannelMemberError> in
            return .complete()
        }
    }
    
    public func recentOnline(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId) -> Signal<Int32, NoError> {
        return Signal { [weak self] subscriber in
            guard let strongSelf = self else {
                subscriber.putNext(0)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let disposable = strongSelf.impl.syncWith({ impl -> Disposable in
                return impl.recentOnline(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, updated: { value in
                    subscriber.putNext(value)
                })
            })
            return disposable ?? EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
    }
    
    public func recentOnlineSmall(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId) -> Signal<Int32, NoError> {
        return Signal { [weak self] subscriber in
            var previousIds: Set<PeerId>?
            let statusesDisposable = MetaDisposable()
            let disposableAndControl = self?.recent(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, updated: { state in
                var idList: [PeerId] = []
                for item in state.list {
                    idList.append(item.peer.id)
                    if idList.count >= 200 {
                        break
                    }
                }
                let updatedIds = Set(idList)
                if previousIds != updatedIds {
                    previousIds = updatedIds
                    let key: PostboxViewKey = .peerPresences(peerIds: updatedIds)
                    statusesDisposable.set((postbox.combinedView(keys: [key])
                    |> map { view -> Int32 in
                        var count: Int32 = 0
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        if let presences = (view.views[key] as? PeerPresencesView)?.presences {
                            for (_, presence) in presences {
                                if let presence = presence as? TelegramUserPresence {
                                    let relativeStatus = relativeUserPresenceStatus(presence, relativeTo: Int32(timestamp))
                                    switch relativeStatus {
                                    case .online:
                                        count += 1
                                    default:
                                        break
                                    }
                                }
                            }
                        }
                        return count
                    }
                    |> distinctUntilChanged
                    |> deliverOnMainQueue).start(next: { count in
                        subscriber.putNext(count)
                    }))
                }
            })
            return ActionDisposable {
                disposableAndControl?.0.dispose()
                statusesDisposable.dispose()
            }
        }
        |> runOn(Queue.mainQueue())
    }
    
    public func profileData(postbox: Postbox, network: Network, peerId: PeerId, customData: Signal<Never, NoError>?) -> Signal<Never, NoError> {
        return Signal { [weak self] subscriber in
            guard let strongSelf = self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let disposable = strongSelf.impl.syncWith({ impl -> Disposable in
                return impl.profileData(postbox: postbox, network: network, peerId: peerId, customData: customData)
            })
            return disposable ?? EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
    }
    
    public func profilePhotos(postbox: Postbox, network: Network, peerId: PeerId, fetch: Signal<Any, NoError>) -> Signal<Any?, NoError> {
        return Signal { [weak self] subscriber in
            guard let strongSelf = self else {
                subscriber.putNext(0)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let disposable = strongSelf.impl.syncWith({ impl -> Disposable in
                return impl.profilePhotos(postbox: postbox, network: network, peerId: peerId, fetch: fetch, updated: { value in
                    subscriber.putNext(value)
                })
            })
            return disposable ?? EmptyDisposable
        }
        |> runOn(Queue.mainQueue())
    }
}
