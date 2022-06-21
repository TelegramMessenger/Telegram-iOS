import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit

private let initialBatchSize: Int32 = 64
private let defaultEmptyTimeout: Double = 2.0 * 60.0
private let headUpdateTimeout: Double = 30.0
private let requestBatchSize: Int32 = 64

public enum ChannelMemberListLoadingState: Equatable {
    case loading(initial: Bool)
    case ready(hasMore: Bool)
}

public extension ChannelParticipant {
    var adminInfo: ChannelParticipantAdminInfo? {
        switch self {
            case .creator:
                return nil
            case let .member(_, _, adminInfo, _, _):
                return adminInfo
        }
    }
    
    var banInfo: ChannelParticipantBannedInfo? {
        switch self {
            case .creator:
                return nil
            case let .member(_, _, _, banInfo, _):
                return banInfo
        }
    }
    
    func canBeBannedBy(peerId: PeerId) -> Bool {
        switch self {
            case .creator:
                return false
            case let .member(_, _, adminInfo, _, _):
                if let adminInfo = adminInfo {
                    if adminInfo.promotedBy != peerId {
                        return false
                    }
                }
        }
        return true
    }
}

public struct ChannelMemberListState {
    public let list: [RenderedChannelParticipant]
    public let loadingState: ChannelMemberListLoadingState

    public func withUpdatedList(_ list: [RenderedChannelParticipant]) -> ChannelMemberListState {
        return ChannelMemberListState(list: list, loadingState: self.loadingState)
    }
    
    public func withUpdatedLoadingState(_ loadingState: ChannelMemberListLoadingState) -> ChannelMemberListState {
        return ChannelMemberListState(list: self.list, loadingState: loadingState)
    }
}

enum ChannelMemberListCategory {
    case recent
    case recentSearch(String)
    case mentions(MessageId?, String?)
    case admins(String?)
    case contacts(String?)
    case bots(String?)
    case restricted(String?)
    case banned(String?)
}

private protocol ChannelMemberCategoryListContext {
    var listStateValue: ChannelMemberListState { get }
    var listState: Signal<ChannelMemberListState, NoError> { get }
    func loadMore()
    func reset(_ force: Bool)
    func replayUpdates(_ updates: [(ChannelParticipant?, RenderedChannelParticipant?, Bool?)])
    func forceUpdateHead()
}

private func isParticipantMember(_ participant: ChannelParticipant, infoIsMember: Bool?) -> Bool {
    if let banInfo = participant.banInfo {
        return !banInfo.rights.flags.contains(.banReadMessages) && banInfo.isMember
    } else if let infoIsMember = infoIsMember {
        return infoIsMember
    } else {
        return true
    }
}

private extension CachedChannelAdminRank {
    init(participant: ChannelParticipant) {
        switch participant {
            case let .creator(_, _, rank):
                if let rank = rank {
                    self = .custom(rank)
                } else {
                    self = .owner
                }
            case let .member(_, _, _, _, rank):
                if let rank = rank {
                    self = .custom(rank)
                } else {
                    self = .admin
                }
        }
    }
}

private final class ChannelMemberSingleCategoryListContext: ChannelMemberCategoryListContext {
    private let engine: TelegramEngine
    private let postbox: Postbox
    private let network: Network
    private let accountPeerId: PeerId
    private let peerId: PeerId
    private let category: ChannelMemberListCategory
    
    var listStateValue: ChannelMemberListState {
        didSet {
            self.listStatePromise.set(.single(self.listStateValue))
            if case .admins(nil) = self.category, case .ready = self.listStateValue.loadingState {
                let ranks: [PeerId: CachedChannelAdminRank] = self.listStateValue.list.reduce([:]) { (ranks, participant) in
                    var ranks = ranks
                    ranks[participant.participant.peerId] = CachedChannelAdminRank(participant: participant.participant)
                    return ranks
                }
                let previousRanks: [PeerId: CachedChannelAdminRank] = oldValue.list.reduce([:]) { (ranks, participant) in
                    var ranks = ranks
                    ranks[participant.participant.peerId] = CachedChannelAdminRank(participant: participant.participant)
                    return ranks
                }
                if ranks != previousRanks {
                    let _ = updateCachedChannelAdminRanks(postbox: self.postbox, peerId: self.peerId, ranks: ranks).start()
                }
            }
        }
    }
    private var listStatePromise: Promise<ChannelMemberListState>
    var listState: Signal<ChannelMemberListState, NoError> {
        return self.listStatePromise.get()
    }
    
    private let loadingDisposable = MetaDisposable()
    private let headUpdateDisposable = MetaDisposable()
    
    private var headUpdateTimer: SwiftSignalKit.Timer?
    
    init(engine: TelegramEngine, postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, category: ChannelMemberListCategory) {
        self.engine = engine
        self.postbox = postbox
        self.network = network
        self.accountPeerId = accountPeerId
        self.peerId = peerId
        self.category = category
        
        self.listStateValue = ChannelMemberListState(list: [], loadingState: .ready(hasMore: true))
        self.listStatePromise = Promise(self.listStateValue)
        self.loadMoreInternal(initial: true)
    }
    
    deinit {
        self.loadingDisposable.dispose()
        self.headUpdateDisposable.dispose()
        self.headUpdateTimer?.invalidate()
    }
    
    func loadMore() {
        self.loadMoreInternal(initial: false)
    }
    
    private func loadMoreInternal(initial: Bool) {
        guard case .ready(true) = self.listStateValue.loadingState else {
            return
        }
        
        let loadCount: Int32
        if case .ready(true) = self.listStateValue.loadingState, self.listStateValue.list.isEmpty {
            loadCount = initialBatchSize
        } else {
            loadCount = requestBatchSize
        }
        
        self.listStateValue = self.listStateValue.withUpdatedLoadingState(.loading(initial: initial))
        
        self.loadingDisposable.set((self.loadMoreSignal(count: loadCount)
        |> deliverOnMainQueue).start(next: { [weak self] members in
            self?.appendMembersAndFinishLoading(members)
        }))
    }
    
    func reset(_ force: Bool) {
        if case .loading = self.listStateValue.loadingState, self.listStateValue.list.isEmpty {
        } else {
            var list = self.listStateValue.list
            var loadingState: ChannelMemberListLoadingState = .ready(hasMore: true)
            if list.count > Int(initialBatchSize) && !force {
                list.removeSubrange(Int(initialBatchSize) ..< list.count)
                loadingState = .ready(hasMore: true)
            }
            
            self.loadingDisposable.set(nil)
            self.listStateValue = self.listStateValue.withUpdatedLoadingState(loadingState).withUpdatedList(list)
        }
    }
    
    private func loadSignal(offset: Int32, count: Int32, hash: Int64) -> Signal<[RenderedChannelParticipant]?, NoError> {
        let requestCategory: ChannelMembersCategory
        var adminQuery: String? = nil
        switch self.category {
            case .recent:
                requestCategory = .recent(.all)
            case let .recentSearch(query):
                requestCategory = .recent(.search(query))
            case let .mentions(threadId, query):
                if let query = query, !query.isEmpty {
                    requestCategory = .mentions(threadId: threadId, filter: .search(query))
                } else {
                    requestCategory = .mentions(threadId: threadId, filter: .all)
                }
            case let .admins(query):
                requestCategory = .admins
                adminQuery = query
            case let .contacts(query):
                requestCategory = .contacts(query.flatMap(ChannelMembersCategoryFilter.search) ?? .all)
            case let .bots(query):
                requestCategory = .bots(query.flatMap(ChannelMembersCategoryFilter.search) ?? .all)
            case let .restricted(query):
                requestCategory = .restricted(query.flatMap(ChannelMembersCategoryFilter.search) ?? .all)
            case let .banned(query):
                requestCategory = .banned(query.flatMap(ChannelMembersCategoryFilter.search) ?? .all)
        }
        return self.engine.peers.channelMembers(peerId: self.peerId, category: requestCategory, offset: offset, limit: count, hash: hash) |> map { members in
            switch requestCategory {
                case .admins:
                    if let query = adminQuery {
                        return members?.filter({$0.peer.debugDisplayTitle.lowercased().components(separatedBy: " ").contains(where: {$0.hasPrefix(query.lowercased())})})
                    }
                default:
                    break
            }
            return members
        }
    }
    
    private func loadMoreSignal(count: Int32) -> Signal<[RenderedChannelParticipant], NoError> {
        return self.loadSignal(offset: Int32(self.listStateValue.list.count), count: count, hash: 0)
        |> map { value -> [RenderedChannelParticipant] in
            return value ?? []
        }
    }
    
    private func updateHeadMembers(_ headMembers: [RenderedChannelParticipant]?) {
        if let headMembers = headMembers {
            var existingIds = Set<PeerId>()
            var list = headMembers
            for member in list {
                existingIds.insert(member.peer.id)
            }
            for member in self.listStateValue.list {
                if !existingIds.contains(member.peer.id) {
                    list.append(member)
                }
            }
            self.loadingDisposable.set(nil)
            self.listStateValue = self.listStateValue.withUpdatedList(list)
            if case .loading = self.listStateValue.loadingState {
                self.loadMore()
            }
        }
        
        self.headUpdateTimer?.invalidate()
        self.headUpdateTimer = nil
        self.checkUpdateHead()
    }
    
    private func appendMembersAndFinishLoading(_ members: [RenderedChannelParticipant]) {
        var firstLoad = false
        if case .loading = self.listStateValue.loadingState, self.listStateValue.list.isEmpty {
            firstLoad = true
        }
        var existingIds = Set<PeerId>()
        var list = self.listStateValue.list
        for member in list {
            existingIds.insert(member.peer.id)
        }
        for member in members {
            if !existingIds.contains(member.peer.id) {
                list.append(member)
            }
        }
        self.listStateValue = self.listStateValue.withUpdatedList(list).withUpdatedLoadingState(.ready(hasMore: members.count >= requestBatchSize))
        if firstLoad {
            self.checkUpdateHead()
        }
    }
    
    func forceUpdateHead() {
        self.headUpdateTimer = nil
        self.checkUpdateHead()
    }
    
    private func checkUpdateHead() {
        if self.listStateValue.list.isEmpty {
            return
        }
        
        if self.headUpdateTimer == nil {
            let headUpdateTimer = SwiftSignalKit.Timer(timeout: headUpdateTimeout, repeat: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                var acc: UInt64 = 0
                
                for i in 0 ..< min(strongSelf.listStateValue.list.count, Int(initialBatchSize)) {
                    let peerId = strongSelf.listStateValue.list[i].peer.id
                    combineInt64Hash(&acc, with: peerId)
                }
                let hashResult = finalizeInt64Hash(acc)
                strongSelf.headUpdateDisposable.set((strongSelf.loadSignal(offset: 0, count: initialBatchSize, hash: hashResult)
                |> deliverOnMainQueue).start(next: { members in
                    self?.updateHeadMembers(members)
                }))
            }, queue: Queue.mainQueue())
            self.headUpdateTimer = headUpdateTimer
            headUpdateTimer.start()
        }
    }
    
    fileprivate func replayUpdates(_ updates: [(ChannelParticipant?, RenderedChannelParticipant?, Bool?)]) {
        var list = self.listStateValue.list
        var updatedList = false
        for (maybePrevious, updated, infoIsMember) in updates {
            var previous: ChannelParticipant? = maybePrevious
            if let participantId = maybePrevious?.peerId ?? updated?.peer.id {
                inner: for participant in list {
                    if participant.peer.id == participantId {
                        previous = participant.participant
                        break inner
                    }
                }
            }
            switch self.category {
                case let .admins(query):
                    if let updated = updated, (query == nil || updated.peer.indexName.matchesByTokens(query!)) {
                        if case let .member(_, _, adminInfo, _, _) = updated.participant, adminInfo == nil {
                            loop: for i in 0 ..< list.count {
                                if list[i].peer.id == updated.peer.id {
                                    list.remove(at: i)
                                    updatedList = true
                                    break loop
                                }
                            }
                        } else {
                            var found = false
                            loop: for i in 0 ..< list.count {
                                if list[i].peer.id == updated.peer.id {
                                    list[i] = updated
                                    found = true
                                    updatedList = true
                                    break loop
                                }
                            }
                            if !found {
                                list.insert(updated, at: 0)
                                updatedList = true
                            }
                        }
                    } else if let previous = previous, let _ = previous.adminInfo {
                        loop: for i in 0 ..< list.count {
                            if list[i].peer.id == previous.peerId {
                                list.remove(at: i)
                                updatedList = true
                                break loop
                            }
                        }
                        if let updated = updated, case .creator = updated.participant {
                            list.insert(updated, at: 0)
                            updatedList = true
                        }
                    }
                case .restricted:
                    if let updated = updated, let banInfo = updated.participant.banInfo, !banInfo.rights.flags.contains(.banReadMessages) {
                        var found = false
                        loop: for i in 0 ..< list.count {
                            if list[i].peer.id == updated.peer.id {
                                list[i] = updated
                                found = true
                                updatedList = true
                                break loop
                            }
                        }
                        if !found {
                            list.insert(updated, at: 0)
                            updatedList = true
                        }
                    } else if let previous = previous, let banInfo = previous.banInfo, !banInfo.rights.flags.contains(.banReadMessages) {
                        loop: for i in 0 ..< list.count {
                            if list[i].peer.id == previous.peerId {
                                list.remove(at: i)
                                updatedList = true
                                break loop
                            }
                        }
                    }
                case .banned:
                    if let updated = updated, let banInfo = updated.participant.banInfo, banInfo.rights.flags.contains(.banReadMessages) {
                        var found = false
                        loop: for i in 0 ..< list.count {
                            if list[i].peer.id == updated.peer.id {
                                list[i] = updated
                                found = true
                                updatedList = true
                                break loop
                            }
                        }
                        if !found {
                            list.insert(updated, at: 0)
                            updatedList = true
                        }
                    } else if let previous = previous, let banInfo = previous.banInfo, banInfo.rights.flags.contains(.banReadMessages) {
                        loop: for i in 0 ..< list.count {
                            if list[i].peer.id == previous.peerId {
                                list.remove(at: i)
                                updatedList = true
                                break loop
                            }
                        }
                    }
                case .recent:
                    if let updated = updated, isParticipantMember(updated.participant, infoIsMember: infoIsMember) {
                        var found = false
                        loop: for i in 0 ..< list.count {
                            if list[i].peer.id == updated.peer.id {
                                list[i] = updated
                                found = true
                                updatedList = true
                                break loop
                            }
                        }
                        if !found {
                            list.insert(updated, at: 0)
                            updatedList = true
                        }
                    } else if let previous = previous, isParticipantMember(previous, infoIsMember: nil) {
                        loop: for i in 0 ..< list.count {
                            if list[i].peer.id == previous.peerId {
                                list.remove(at: i)
                                updatedList = true
                                break loop
                            }
                        }
                    }
                case let .contacts(query):
                    if query == nil {
                        if let updated = updated, isParticipantMember(updated.participant, infoIsMember: infoIsMember) {
                            var found = false
                            loop: for i in 0 ..< list.count {
                                if list[i].peer.id == updated.peer.id {
                                    list[i] = updated
                                    found = true
                                    updatedList = true
                                    break loop
                                }
                            }
                            if !found {
                                //list.insert(updated, at: 0)
                                //updatedList = true
                            }
                        } else if let previous = previous, isParticipantMember(previous, infoIsMember: nil) {
                            loop: for i in 0 ..< list.count {
                                if list[i].peer.id == previous.peerId {
                                    list.remove(at: i)
                                    updatedList = true
                                    break loop
                                }
                            }
                        }
                    }
                case let .bots(query):
                    if query == nil {
                        if let updated = updated, isParticipantMember(updated.participant, infoIsMember: infoIsMember) {
                            var found = false
                            loop: for i in 0 ..< list.count {
                                if list[i].peer.id == updated.peer.id {
                                    list[i] = updated
                                    found = true
                                    updatedList = true
                                    break loop
                                }
                            }
                            if !found {
                                //list.insert(updated, at: 0)
                                //updatedList = true
                            }
                        } else if let previous = previous, isParticipantMember(previous, infoIsMember: nil) {
                            loop: for i in 0 ..< list.count {
                                if list[i].peer.id == previous.peerId {
                                    list.remove(at: i)
                                    updatedList = true
                                    break loop
                                }
                            }
                        }
                    }
                case let .recentSearch(query):
                    if let updated = updated, isParticipantMember(updated.participant, infoIsMember: infoIsMember), updated.peer.indexName.matchesByTokens(query) {
                        var found = false
                        loop: for i in 0 ..< list.count {
                            if list[i].peer.id == updated.peer.id {
                                list[i] = updated
                                found = true
                                updatedList = true
                                break loop
                            }
                        }
                        if !found {
                            list.insert(updated, at: 0)
                            updatedList = true
                        }
                    } else if let previous = previous, isParticipantMember(previous, infoIsMember: nil) {
                        loop: for i in 0 ..< list.count {
                            if list[i].peer.id == previous.peerId {
                                list.remove(at: i)
                                updatedList = true
                                break loop
                            }
                        }
                    }
                case .mentions:
                    break
            }
        }
        if updatedList {
            self.listStateValue = self.listStateValue.withUpdatedList(list)
        }
    }
}

private final class ChannelMemberMultiCategoryListContext: ChannelMemberCategoryListContext {
    private var contexts: [ChannelMemberSingleCategoryListContext] = []
    
    var listStateValue: ChannelMemberListState {
        return ChannelMemberMultiCategoryListContext.reduceListStates(self.contexts.map { $0.listStateValue })
    }
    
    private static func reduceListStates(_ listStates: [ChannelMemberListState]) -> ChannelMemberListState {
        var allReady = true
        for listState in listStates {
            if case .loading(true) = listState.loadingState, listState.list.isEmpty {
                allReady = false
                break
            }
        }
        if !allReady {
            return ChannelMemberListState(list: [], loadingState: .loading(initial: true))
        }
        
        var list: [RenderedChannelParticipant] = []
        var existingIds = Set<PeerId>()
        var loadingState: ChannelMemberListLoadingState = .ready(hasMore: false)
        loop: for i in 0 ..< listStates.count {
            for item in listStates[i].list {
                if !existingIds.contains(item.peer.id) {
                    existingIds.insert(item.peer.id)
                    list.append(item)
                }
            }
            switch listStates[i].loadingState {
                case let .loading(initial):
                    loadingState = .loading(initial: initial)
                    break loop
                case let .ready(hasMore):
                    if hasMore {
                        loadingState = .ready(hasMore: true)
                        break loop
                    }
            }
        }
        return ChannelMemberListState(list: list, loadingState: loadingState)
    }
    
    var listState: Signal<ChannelMemberListState, NoError> {
        let signals: [Signal<ChannelMemberListState, NoError>] = self.contexts.map { context in
            return context.listState
        }
        return combineLatest(signals) |> map { listStates -> ChannelMemberListState in
            return ChannelMemberMultiCategoryListContext.reduceListStates(listStates)
        }
    }
    
    init(engine: TelegramEngine, postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, categories: [ChannelMemberListCategory]) {
        self.contexts = categories.map { category in
            return ChannelMemberSingleCategoryListContext(engine: engine, postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, category: category)
        }
    }
    
    func loadMore() {
        loop: for context in self.contexts {
            switch context.listStateValue.loadingState {
                case .loading:
                    break loop
                case let .ready(hasMore):
                    if hasMore {
                        context.loadMore()
                    }
            }
        }
    }
    
    func reset(_ force: Bool) {
        for context in self.contexts {
            context.reset(force)
        }
    }
    
    func forceUpdateHead() {
        for context in self.contexts {
            context.forceUpdateHead()
        }
    }
    
    func replayUpdates(_ updates: [(ChannelParticipant?, RenderedChannelParticipant?, Bool?)]) {
        for context in self.contexts {
            context.replayUpdates(updates)
        }
    }
}

public struct PeerChannelMemberCategoryControl {
    fileprivate let key: PeerChannelMemberContextKey
}

private final class PeerChannelMemberContextWithSubscribers {
    let context: ChannelMemberCategoryListContext
    private let emptyTimeout: Double
    private let subscribers = Bag<(ChannelMemberListState) -> Void>()
    private let disposable = MetaDisposable()
    private let becameEmpty: () -> Void
    
    private var emptyTimer: SwiftSignalKit.Timer?
    
    init(context: ChannelMemberCategoryListContext, emptyTimeout: Double, becameEmpty: @escaping () -> Void) {
        self.context = context
        self.emptyTimeout = emptyTimeout
        self.becameEmpty = becameEmpty
        self.disposable.set((context.listState
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                for f in strongSelf.subscribers.copyItems() {
                    f(value)
                }
            }
        }))
    }
    
    deinit {
        self.disposable.dispose()
        self.emptyTimer?.invalidate()
    }
    
    private func resetAndBeginEmptyTimer() {
        self.context.reset(false)
        self.emptyTimer?.invalidate()
        let emptyTimer = SwiftSignalKit.Timer(timeout: self.emptyTimeout, repeat: false, completion: { [weak self] in
            if let strongSelf = self {
                if strongSelf.subscribers.isEmpty {
                    strongSelf.becameEmpty()
                }
            }
        }, queue: Queue.mainQueue())
        self.emptyTimer = emptyTimer
        emptyTimer.start()
    }
    
    func subscribe(requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> Disposable {
        let wasEmpty = self.subscribers.isEmpty
        let index = self.subscribers.add(updated)
        updated(self.context.listStateValue)
        if wasEmpty {
            self.emptyTimer?.invalidate()
            if requestUpdate {
                self.context.forceUpdateHead()
            }
        }
        return ActionDisposable { [weak self] in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    strongSelf.subscribers.remove(index)
                    if strongSelf.subscribers.isEmpty {
                        strongSelf.resetAndBeginEmptyTimer()
                    }
                }
            }
        }
    }
}

final class PeerChannelMemberCategoriesContext {
    private let engine: TelegramEngine
    private let postbox: Postbox
    private let network: Network
    private let accountPeerId: PeerId
    private let peerId: PeerId
    private var becameEmpty: (Bool) -> Void
    
    private var contexts: [PeerChannelMemberContextKey: PeerChannelMemberContextWithSubscribers] = [:]
    
    init(engine: TelegramEngine, postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, becameEmpty: @escaping (Bool) -> Void) {
        self.engine = engine
        self.postbox = postbox
        self.network = network
        self.accountPeerId = accountPeerId
        self.peerId = peerId
        self.becameEmpty = becameEmpty
    }
    
    func reset(_ key: PeerChannelMemberContextKey) {
        for (contextKey, context) in contexts {
            if contextKey == key {
                context.context.reset(true)
                context.context.loadMore()
            }
        }
    }
    
    func getContext(key: PeerChannelMemberContextKey, requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl) {
        assert(Queue.mainQueue().isCurrent())
        if let current = self.contexts[key] {
            return (current.subscribe(requestUpdate: requestUpdate, updated: updated), PeerChannelMemberCategoryControl(key: key))
        }
        let context: ChannelMemberCategoryListContext
        let emptyTimeout: Double
        switch key {
            case .admins(nil), .banned(nil), .recentSearch(nil), .restricted(nil), .restrictedAndBanned(nil), .recent, .contacts:
                emptyTimeout = defaultEmptyTimeout
            default:
                emptyTimeout = 0.0
        }
        switch key {
            case .recent, .recentSearch, .admins, .contacts, .bots, .mentions:
                let mappedCategory: ChannelMemberListCategory
                switch key {
                    case .recent:
                        mappedCategory = .recent
                    case let .recentSearch(query):
                        mappedCategory = .recentSearch(query)
                    case let .admins(query):
                        mappedCategory = .admins(query)
                    case let .contacts(query):
                        mappedCategory = .contacts(query)
                    case let .bots(query):
                        mappedCategory = .bots(query)
                    case let .mentions(threadId, query):
                        mappedCategory = .mentions(threadId, query)
                    default:
                        mappedCategory = .recent
                }
                context = ChannelMemberSingleCategoryListContext(engine: self.engine, postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId, peerId: self.peerId, category: mappedCategory)
            case let .restrictedAndBanned(query):
                context = ChannelMemberMultiCategoryListContext(engine: self.engine, postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId, peerId: self.peerId, categories: [.restricted(query), .banned(query)])
            case let .restricted(query):
                context = ChannelMemberSingleCategoryListContext(engine: self.engine, postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId, peerId: self.peerId, category: .restricted(query))
            case let .banned(query):
                context = ChannelMemberSingleCategoryListContext(engine: self.engine, postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId, peerId: self.peerId, category: .banned(query))
        }
        let contextWithSubscribers = PeerChannelMemberContextWithSubscribers(context: context, emptyTimeout: emptyTimeout, becameEmpty: { [weak self] in
            assert(Queue.mainQueue().isCurrent())
            if let strongSelf = self {
                strongSelf.contexts.removeValue(forKey: key)
            }
        })
        self.contexts[key] = contextWithSubscribers
        return (contextWithSubscribers.subscribe(requestUpdate: requestUpdate, updated: updated), PeerChannelMemberCategoryControl(key: key))
    }
    
    func loadMore(_ control: PeerChannelMemberCategoryControl) {
        assert(Queue.mainQueue().isCurrent())
        if let context = self.contexts[control.key] {
            context.context.loadMore()
        }
    }
    
    func replayUpdates(_ updates: [(ChannelParticipant?, RenderedChannelParticipant?, Bool?)]) {
        for (_, context) in self.contexts {
            context.context.replayUpdates(updates)
        }
    }
}
