import Foundation
import QuartzCore
import TelegramCore
import SwiftSignalKit
import AccountContext
import ChatListUI

// One selection shared by the grid, recommendations, folders and search results.
struct ShareScreenSelection {
    private(set) var peers: [EnginePeer] = []
    private(set) var topics: [EnginePeer.Id: Int64] = [:]
    private(set) var topicPeers: [EnginePeer.Id: EnginePeer] = [:]
    private(set) var topicData: [EnginePeer.Id: MessageHistoryThreadData] = [:]

    func contains(_ id: EnginePeer.Id) -> Bool {
        return self.peers.contains(where: { $0.id == id })
    }

    mutating func toggle(_ peer: EnginePeer, topicId: Int64? = nil, topicData: MessageHistoryThreadData? = nil, topicPeer: EnginePeer? = nil) {
        if case .community = peer { return }
        if let index = self.peers.firstIndex(where: { $0.id == peer.id }) {
            self.peers.remove(at: index)
            self.topics.removeValue(forKey: peer.id)
            self.topicData.removeValue(forKey: peer.id)
            self.topicPeers.removeValue(forKey: peer.id)
        } else {
            self.peers.append(peer)
            self.topics[peer.id] = topicId
            self.topicData[peer.id] = topicData
            self.topicPeers[peer.id] = topicPeer
        }
    }
}

final class ShareScreenState {
    let context: AccountContext
    var updated: ((Bool) -> Void)?
    private(set) var revision = 0
    var selection = ShareScreenSelection()
    var isSearching = false
    private(set) var query = ""
    private(set) var filterId: Int32 = 0
    private(set) var filters: [ChatListFilter] = []
    private(set) var peers: [EnginePeer] = []
    private(set) var recommendations: [EnginePeer] = []
    private(set) var accountPeer: EnginePeer?
    private(set) var presences: [EnginePeer.Id: EnginePeer.Presence] = [:]
    private(set) var participantCounts: [EnginePeer.Id: Int] = [:]
    private(set) var isLoading = true
    private(set) var createdGroup: EnginePeer?
    private(set) var foundPeers: [EnginePeer] = []
    var didPlayRepostAnimation = false
    var firstLoadCompleted: (() -> Void)?
    var appearanceAnimationStart: Double?
    var defersItemsUntilFirstLoad = false
    private(set) var didCompleteFirstLoad = false
    private let creationTimestamp = CACurrentMediaTime()

    var gridPeers: [EnginePeer] {
        guard !self.foundPeers.isEmpty else { return self.peers }
        let foundIds = Set(self.foundPeers.map(\.id))
        return self.foundPeers + self.peers.filter { !foundIds.contains($0.id) }
    }

    func noteSelectedInSearch(_ peer: EnginePeer) {
        guard self.isSearching, self.selection.contains(peer.id), peer.id != self.context.account.peerId else { return }
        self.foundPeers.removeAll(where: { $0.id == peer.id })
        self.foundPeers.insert(peer, at: 0)
    }
    private(set) var messagingRequirements: [EnginePeer.Id: ShareScreenMessagingRequirement] = [:]
    private var requirementPeerIds = Set<EnginePeer.Id>()
    private let requirementsDisposable = MetaDisposable()
    private let displayPeersDisposable = MetaDisposable()
    private var displayPeers: [EnginePeer.Id: EnginePeer] = [:]

    func displayPeer(_ peer: EnginePeer) -> EnginePeer {
        if case let .channel(channel) = peer, channel.isMonoForum, let id = channel.linkedMonoforumId {
            return self.displayPeers[id] ?? peer
        }
        return peer
    }

    func messagingRequirement(for peer: EnginePeer) -> ShareScreenMessagingRequirement {
        if let requirement = self.messagingRequirements[peer.id] { return requirement }
        if case let .channel(channel) = peer { return ShareScreenMessagingRequirement(stars: channel.sendPaidMessageStars) }
        return ShareScreenMessagingRequirement()
    }

    private func updateMessagingRequirements() {
        let peers = self.peers + self.recommendations + self.communityPeers + self.selection.peers + self.folderCache.values.flatMap { $0.peers }
        let ids = Set(peers.map(\.id))
        guard ids != self.requirementPeerIds else { return }
        let newIds = ids.subtracting(self.requirementPeerIds)
        self.requirementPeerIds = ids
        let linkedIds = Set(peers.compactMap { peer -> EnginePeer.Id? in
            guard case let .channel(channel) = peer, channel.isMonoForum else { return nil }
            return channel.linkedMonoforumId
        })
        self.displayPeersDisposable.set((self.context.engine.data.subscribe(
            EngineDataMap(linkedIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
        ) |> deliverOnMainQueue).start(next: { [weak self] peers in
            guard let self else { return }
            let displayPeers = peers.compactMapValues { $0 }
            if self.displayPeers != displayPeers {
                self.displayPeers = displayPeers
                self.scheduleChange()
            }
        }))
        let refreshIds = Set(peers.compactMap { peer -> EnginePeer.Id? in
            guard newIds.contains(peer.id), case let .user(user) = peer,
                  user.flags.contains(.requirePremium) || user.flags.contains(.requireStars) else { return nil }
            return peer.id
        })
        if !refreshIds.isEmpty {
            self.context.account.viewTracker.refreshCanSendMessagesForPeerIds(peerIds: Array(refreshIds))
        }
        self.requirementsDisposable.set((self.context.engine.data.subscribe(
            EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.IsPremiumRequiredForMessaging.init(id:))),
            EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.SendPaidMessageStars.init(id:)))
        ) |> deliverOnMainQueue).start(next: { [weak self] premium, stars in
            guard let self else { return }
            var changed = false
            for id in ids {
                let value = ShareScreenMessagingRequirement(requiresPremium: premium[id] ?? false, stars: stars[id] ?? nil)
                if self.messagingRequirements[id] != value {
                    self.messagingRequirements[id] = value
                    changed = true
                }
            }
            if changed { self.scheduleChange() }
        }))
    }

    struct FolderPage {
        var peers: [EnginePeer]
        var isLoading: Bool
    }
    private var folderCache: [Int32: FolderPage] = [:]
    private var emptyQueryPeers: [Int32: [EnginePeer]] = [:]
    private var folderDisposables: [Int32: MetaDisposable] = [:]
    private var folderDetailsDisposables: [Int32: MetaDisposable] = [:]

    func folderPage(_ id: Int32) -> FolderPage {
        if id == self.filterId { return FolderPage(peers: self.peers, isLoading: self.isLoading) }
        return self.folderCache[id] ?? FolderPage(peers: [], isLoading: true)
    }

    private func reloadFolderPages() {
        for disposable in self.folderDisposables.values { disposable.dispose() }
        for disposable in self.folderDetailsDisposables.values { disposable.dispose() }
        self.folderDisposables.removeAll()
        self.folderDetailsDisposables.removeAll()
        self.folderCache.removeAll()
        guard self.isSearching else { return }
        if self.query.isEmpty {
            for (id, peers) in self.emptyQueryPeers {
                self.folderCache[id] = FolderPage(peers: peers, isLoading: false)
            }
        }
        self.loadFolderPages()
    }

    private func loadFolderPages() {
        guard self.isSearching else { return }
        for id in [Int32(0)] + self.filters.map(\.id).filter({ $0 != 0 }) {
            self.loadFolderPage(id)
        }
    }

    private func loadFolderPage(_ id: Int32) {
        guard id != self.filterId, self.folderDisposables[id] == nil, self.folderCache[id] == nil else { return }
        let disposable = MetaDisposable()
        let detailsDisposable = MetaDisposable()
        self.folderDisposables[id] = disposable
        self.folderDetailsDisposables[id] = detailsDisposable
        disposable.set((self.peersSignal(filterId: id) |> deliverOnMainQueue).start(next: { [weak self] peers, _ in
            guard let self else { return }
            let peers = self.filteredPeers(peers, filterId: id)
            self.folderCache[id] = FolderPage(peers: peers, isLoading: false)
            if self.query.isEmpty {
                self.emptyQueryPeers[id] = peers
            }
            self.updateMessagingRequirements()
            self.scheduleChange()
            let ids = peers.map(\.id)
            detailsDisposable.set((self.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Presence.init)),
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
            ) |> deliverOnMainQueue).start(next: { [weak self] presences, counts in
                self?.applyDetails(ids: ids, presences: presences, counts: counts)
            }))
        }))
    }

    private func applyDetails(ids: [EnginePeer.Id], presences: [EnginePeer.Id: EnginePeer.Presence?], counts: [EnginePeer.Id: Int?]) {
        var updated = false
        for id in ids {
            let presence = presences[id] ?? nil
            if self.presences[id] != presence {
                self.presences[id] = presence
                updated = true
            }
            let count = counts[id] ?? nil
            if self.participantCounts[id] != count {
                self.participantCounts[id] = count
                updated = true
            }
        }
        if updated {
            self.scheduleChange()
        }
    }

    private var generation = 0
    private let peersDisposable = MetaDisposable()
    private let detailsDisposable = MetaDisposable()
    private let filtersDisposable = MetaDisposable()
    private let recommendationsDisposable = MetaDisposable()
    private let accountPeerDisposable = MetaDisposable()
    private var searchDataStarted = false

    init(context: AccountContext) {
        self.context = context
        self.accountPeerDisposable.set((context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> deliverOnMainQueue).start(next: { [weak self] accountPeer in
            guard let self else { return }
            if self.accountPeer != accountPeer {
                self.accountPeer = accountPeer
                self.scheduleChange()
            }
        }))
        self.reload()
    }

    private func startSearchDataIfNeeded() {
        guard !self.searchDataStarted else { return }
        self.searchDataStarted = true
        let context = self.context
        self.filtersDisposable.set((context.engine.peers.updatedChatListFilters()
        |> deliverOnMainQueue).start(next: { [weak self] filters in
            guard let self else { return }
            self.filters = filters
            self.reloadFolderPages()
            if self.filterId != 0 && !filters.contains(where: { $0.id == self.filterId }) {
                self.filterId = 0
                self.reload()
            } else {
                self.scheduleChange()
            }
        }))
        self.recommendationsDisposable.set((context.engine.peers.recentPeers()
        |> deliverOnMainQueue).start(next: { [weak self] recent in
            guard let self else { return }
            if case let .peers(peers) = recent {
                self.recommendations = peers.map(EnginePeer.init).filter { canSendMessagesToPeer($0) && $0.id != context.account.peerId }
            } else {
                self.recommendations = []
            }
            self.updateMessagingRequirements()
            self.scheduleChange()
        }))
    }

    deinit {
        for disposable in self.folderDisposables.values { disposable.dispose() }
        for disposable in self.folderDetailsDisposables.values { disposable.dispose() }
        self.requirementsDisposable.dispose()
        self.displayPeersDisposable.dispose()
        self.communityDisposable.dispose()
        self.topicsDisposable.dispose()
        self.pendingForumTimer.dispose()
        self.peersDisposable.dispose()
        self.detailsDisposable.dispose()
        self.filtersDisposable.dispose()
        self.recommendationsDisposable.dispose()
        self.accountPeerDisposable.dispose()
    }

    private var communityChatIds: [EnginePeer.Id: Set<EnginePeer.Id>] = [:]

    func selectedCommunityChats(_ id: EnginePeer.Id) -> [EnginePeer] {
        return self.selection.peers.filter {
            $0._asPeer().containerPeerId == id || self.communityChatIds[id]?.contains($0.id) == true
        }
    }

    private(set) var communityUsesGrid = false
    private(set) var communityPeer: EnginePeer?
    private(set) var communityPeers: [EnginePeer] = []
    private(set) var communityParticipantCounts: [EnginePeer.Id: Int] = [:]
    private(set) var communityLoading = false
    private let communityDisposable = MetaDisposable()
    private var communityCache: [EnginePeer.Id: ([EnginePeer], [EnginePeer.Id: Int])] = [:]

    var navigationWillChange: ((EnginePeer.Id, Bool) -> Void)?

    func openCommunity(_ peer: EnginePeer) {
        self.navigationWillChange?(peer.id, true)
        self.communityUsesGrid = !self.isSearching
        self.communityPeer = peer
        let cached = self.communityCache[peer.id]
        self.communityPeers = cached?.0 ?? []
        self.communityParticipantCounts = cached?.1 ?? [:]
        self.communityLoading = cached == nil
        // Navigation starts on the tap; database updates only populate the page.
        self.changed(animated: true)
        self.communityDisposable.set((self.context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.CachedData(id: peer.id)
        ) |> mapToSignal { [weak self] cachedData -> Signal<([EnginePeer], [EnginePeer.Id: Int], Bool), NoError> in
            guard let self, let data = cachedData as? CachedCommunityData else { return .single(([], [:], true)) }
            let ids = data.linkedPeers.map(\.peerId)
            return self.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))),
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Messages.TopMessage.init(id:))),
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init(id:)))
            )
            |> map { peers, topMessages, counts in
                let joinedPeers = ids.compactMap { peers[$0] ?? nil }.filter { peer in
                    guard canSendMessagesToPeer(peer) else { return false }
                    switch peer {
                    case let .channel(channel):
                        return channel.participationStatus == .member
                    case let .legacyGroup(group):
                        return group.membership == .Member
                    default:
                        return false
                    }
                }
                let sortedPeers = joinedPeers.enumerated().sorted { lhs, rhs in
                    let lhsTimestamp = (topMessages[lhs.element.id] ?? nil)?.timestamp
                    let rhsTimestamp = (topMessages[rhs.element.id] ?? nil)?.timestamp
                    switch (lhsTimestamp, rhsTimestamp) {
                    case let (lhsTimestamp?, rhsTimestamp?) where lhsTimestamp != rhsTimestamp:
                        return lhsTimestamp > rhsTimestamp
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    default:
                        return lhs.offset < rhs.offset
                    }
                }.map(\.element)
                return (sortedPeers, counts.compactMapValues { $0 }, false)
            }
        } |> deliverOnMainQueue).start(next: { [weak self] peers, counts, loading in
            guard let self, self.communityPeer?.id == peer.id else { return }
            self.communityPeers = peers
            self.updateMessagingRequirements()
            if !loading {
                self.communityChatIds[peer.id] = Set(peers.map(\.id))
                self.communityCache[peer.id] = (peers, counts)
            }
            self.communityParticipantCounts = counts
            self.communityLoading = loading
            self.changed()
        }))
        self.context.account.viewTracker.forceUpdateCachedPeerData(peerId: peer.id)
    }

    func closeCommunity() {
        if let peer = self.communityPeer { self.navigationWillChange?(peer.id, false) }
        self.communityDisposable.set(nil)
        self.communityPeer = nil
        self.communityPeers = []
        self.communityParticipantCounts = [:]
        self.communityLoading = false
        self.changed(animated: true)
    }

    struct Topic {
        let id: Int64
        let peer: EnginePeer
        let data: MessageHistoryThreadData?
        var title: String { self.data?.info.title ?? self.peer.compactDisplayTitle }
    }

    private(set) var forumPeer: EnginePeer?
    private(set) var forumTopics: [Topic] = []
    private(set) var topicsLoading = false
    private let topicsDisposable = MetaDisposable()
    private var topicsCache: [EnginePeer.Id: [Topic]] = [:]

    private var pendingForumPeer: EnginePeer?
    private let pendingForumTimer = MetaDisposable()

    func openForum(_ peer: EnginePeer) {
        guard self.forumPeer == nil, self.pendingForumPeer?.id != peer.id else { return }
        if let cached = self.topicsCache[peer.id] {
            self.presentForum(peer, topics: cached, isLoading: false)
            self.subscribeTopics(peer)
            return
        }
        self.pendingForumPeer = peer
        self.subscribeTopics(peer)
        self.pendingForumTimer.set((Signal<Never, NoError>.complete() |> delay(1.0, queue: Queue.mainQueue())).start(completed: { [weak self] in
            guard let self, self.pendingForumPeer?.id == peer.id else { return }
            self.pendingForumPeer = nil
            self.presentForum(peer, topics: self.forumTopics, isLoading: self.topicsLoading)
        }))
    }

    private func presentForum(_ peer: EnginePeer, topics: [Topic], isLoading: Bool) {
        self.pendingForumTimer.set(nil)
        self.navigationWillChange?(peer.id, true)
        self.forumPeer = peer
        self.forumTopics = topics
        self.topicsLoading = isLoading
        self.changed(animated: true)
    }

    private func subscribeTopics(_ peer: EnginePeer) {
        self.forumTopics = self.topicsCache[peer.id] ?? []
        self.topicsLoading = self.topicsCache[peer.id] == nil
        self.topicsDisposable.set((self.context.engine.messages.peerThreads(peerId: peer.id, isMonoforum: peer.isMonoForum)
        |> deliverOnMainQueue).start(next: { [weak self] threads, isLoading in
            guard let self, self.forumPeer?.id == peer.id || self.pendingForumPeer?.id == peer.id else { return }
            self.forumTopics = threads.map { thread in
                return Topic(id: thread.id, peer: thread.peer ?? peer, data: thread.data)
            }
            self.topicsLoading = isLoading
            if !isLoading { self.topicsCache[peer.id] = self.forumTopics }
            if self.pendingForumPeer?.id == peer.id {
                if !isLoading {
                    self.pendingForumPeer = nil
                    self.presentForum(peer, topics: self.forumTopics, isLoading: false)
                }
            } else {
                self.changed()
            }
        }))
    }

    func closeForum() {
        if let peer = self.forumPeer { self.navigationWillChange?(peer.id, false) }
        self.pendingForumPeer = nil
        self.pendingForumTimer.set(nil)
        self.topicsDisposable.set(nil)
        self.forumPeer = nil
        self.forumTopics = []
        self.changed(animated: true)
    }

    func selectTopic(_ topic: Topic) {
        guard let peer = self.forumPeer else { return }
        self.selection.toggle(peer, topicId: topic.id, topicData: topic.data, topicPeer: topic.data == nil ? topic.peer : nil)
        self.noteSelectedInSearch(peer)
        self.closeForum()
        if self.isSearching && !self.query.isEmpty {
            self.setSearching(false)
        }
    }

    func selectCreatedGroup(_ peer: EnginePeer) {
        for selectedPeer in self.selection.peers {
            if case .user = selectedPeer { self.selection.toggle(selectedPeer) }
        }
        if !self.selection.contains(peer.id) { self.selection.toggle(peer) }
        self.createdGroup = peer
        self.isSearching = false
        self.query = ""
        self.filterId = 0
        self.peers.removeAll(where: { $0.id == peer.id })
        self.peers.insert(peer, at: 0)
        self.reload(keepPeers: true, animated: true)
    }

    private var changeScheduled = false

    func scheduleChange() {
        guard !self.changeScheduled else { return }
        self.changeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.changeScheduled else { return }
            self.changed()
        }
    }

    func changed(animated: Bool = false) {
        self.changeScheduled = false
        self.revision += 1
        self.updated?(animated)
    }

    func search(_ query: String) {
        guard self.query != query else { return }
        self.query = query
        self.reloadFolderPages()
        if query.isEmpty, let peers = self.emptyQueryPeers[self.filterId] {
            self.peers = peers
            self.reload(keepPeers: true)
        } else {
            self.reload()
        }
    }

    func setSearching(_ value: Bool) {
        guard self.isSearching != value else { return }
        self.isSearching = value
        if value {
            self.startSearchDataIfNeeded()
        }
        self.reloadFolderPages()
        if !value && (!self.query.isEmpty || self.filterId != 0) {
            self.query = ""
            self.filterId = 0
            self.reload(animated: true)
        } else {
            self.changed(animated: true)
        }
    }

    func selectFilter(_ id: Int32) {
        guard self.filterId != id else { return }
        self.filterId = id
        self.peers = self.folderCache[id]?.peers ?? []
        self.reload(keepPeers: true)
    }

    private func peersSignal(filterId: Int32) -> Signal<([EnginePeer], Bool), NoError> {
        let context = self.context
        let filterData: ChatListFilterData? = self.filters.compactMap { filter in
            if filter.id == filterId, case let .filter(_, _, _, data) = filter {
                return data
            }
            return nil
        }.first
        let predicate = filterData.map { chatListFilterPredicate(filter: $0, accountPeerId: context.account.peerId) }
        let query = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let signal: Signal<([EnginePeer], Bool), NoError>
        if query.isEmpty {
            signal = context.engine.messages.chatListPeers(group: .root, filterPredicate: predicate, count: 150) |> take(1)
        } else {
            let remote: Signal<([FoundPeer], [FoundPeer]), NoError>
            if predicate == nil {
                remote = .single(([], [])) |> then(context.engine.contacts.searchRemotePeers(query: query) |> delay(0.2, queue: Queue.mainQueue()))
            } else {
                remote = .single(([], []))
            }
            signal = combineLatest(context.engine.contacts.searchLocalPeers(query: query, predicate: predicate), remote)
            |> map { local, remote in
                return (local.compactMap(\.peer) + (remote.0 + remote.1).map(\.peer), false)
            }
        }
        return signal
    }

    private func filteredPeers(_ peers: [EnginePeer], filterId: Int32) -> [EnginePeer] {
        var seen = Set<EnginePeer.Id>()
        let query = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = peers.filter { peer in
            let isCommunity: Bool
            if case .community = peer { isCommunity = true } else { isCommunity = false }
            return seen.insert(peer.id).inserted && (isCommunity || canSendMessagesToPeer(peer)) && (!query.isEmpty || peer.id != self.context.account.peerId)
        }
        if query.isEmpty, filterId == 0, let createdGroup = self.createdGroup {
            result.removeAll(where: { $0.id == createdGroup.id })
            result.insert(createdGroup, at: 0)
        }
        return result
    }

    private func reload(keepPeers: Bool = false, animated: Bool = false) {
        self.generation += 1
        let generation = self.generation
        let context = self.context
        self.isLoading = true
        if !keepPeers { self.peers = [] }
        self.changed(animated: animated)
        let signal = self.peersSignal(filterId: self.filterId)
        self.peersDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] peers, _ in
            guard let self, self.generation == generation else { return }
            self.peers = self.filteredPeers(peers, filterId: self.filterId)
            self.folderCache[self.filterId] = FolderPage(peers: self.peers, isLoading: false)
            DispatchQueue.main.async { [weak self] in
                self?.startSearchDataIfNeeded()
            }
            if self.query.isEmpty {
                self.emptyQueryPeers[self.filterId] = self.peers
            }
            self.updateMessagingRequirements()
            self.isLoading = false
            if !self.didCompleteFirstLoad {
                self.didCompleteFirstLoad = true
                if self.defersItemsUntilFirstLoad && CACurrentMediaTime() - self.creationTimestamp > 0.2 {
                    self.appearanceAnimationStart = CACurrentMediaTime()
                }
            }
            self.changed()
            if let firstLoadCompleted = self.firstLoadCompleted {
                self.firstLoadCompleted = nil
                firstLoadCompleted()
            }
            let ids = self.peers.map(\.id)
            self.detailsDisposable.set((context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Presence.init)),
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
            ) |> deliverOnMainQueue).start(next: { [weak self] presences, counts in
                guard let self, self.generation == generation else { return }
                self.applyDetails(ids: ids, presences: presences, counts: counts)
            }))
        }))
    }
}
