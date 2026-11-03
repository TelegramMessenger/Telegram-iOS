import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

public enum CreateCommunityError {
    case generic
    case adminRequired
}

public enum CommunityPeerLinkAction: Equatable {
    case link(visible: Bool)
    case unlink
}

public enum CommunityPeerLinkError {
    case generic
    case adminRequired
    case requestCreated
    case peersTooMuch
    case serverProvided(text: String)
}

public enum CommunityPeerRequestApprovalError {
    case generic
    case adminRequired
    case peersTooMuch
    case serverProvided(text: String)
}

public enum CommunityParticipantBannedError {
    case generic
    case adminRequired
}

public enum CommunityCollapsedInDialogsError {
    case generic
}

public struct CommunitiesState: Codable, Equatable {
    public let communityIds: [EnginePeer.Id]?

    public static let `default` = CommunitiesState(communityIds: nil)

    public init(communityIds: [EnginePeer.Id]?) {
        self.communityIds = communityIds
    }
}

public struct CommunityPeerRequest: Equatable {
    public let peerId: EnginePeer.Id
    public let requestedBy: EnginePeer.Id
    public let date: Int32
    public let isVisible: Bool

    public init(peerId: EnginePeer.Id, requestedBy: EnginePeer.Id, date: Int32, isVisible: Bool) {
        self.peerId = peerId
        self.requestedBy = requestedBy
        self.date = date
        self.isVisible = isVisible
    }
}

public struct CommunityPeerLinkRequests: Equatable {
    public let totalCount: Int32
    public let requests: [CommunityPeerRequest]
    public let nextOffset: String?
    public let peers: [EnginePeer.Id: EnginePeer]

    public init(totalCount: Int32, requests: [CommunityPeerRequest], nextOffset: String?, peers: [EnginePeer.Id: EnginePeer]) {
        self.totalCount = totalCount
        self.requests = requests
        self.nextOffset = nextOffset
        self.peers = peers
    }
}

private final class CachedCommunityPeerLinkRequests: Codable {
    let peerIds: [PeerId]
    let requestedByIds: [PeerId]
    let dates: [Int32]
    let visibility: [Bool]
    let count: Int32

    static func key(communityId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: communityId.toInt64())
        return key
    }

    init(requests: [CommunityPeerRequest], count: Int32) {
        self.peerIds = requests.map(\.peerId)
        self.requestedByIds = requests.map(\.requestedBy)
        self.dates = requests.map(\.date)
        self.visibility = requests.map(\.isVisible)
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerIds = (try container.decode([Int64].self, forKey: "peerIds")).map(PeerId.init)
        self.requestedByIds = (try container.decode([Int64].self, forKey: "requestedByIds")).map(PeerId.init)
        self.dates = try container.decode([Int32].self, forKey: "dates")
        self.visibility = try container.decode([Int32].self, forKey: "visibility").map { $0 == 1 }
        self.count = try container.decode(Int32.self, forKey: "count")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerIds.map { $0.toInt64() }, forKey: "peerIds")
        try container.encode(self.requestedByIds.map { $0.toInt64() }, forKey: "requestedByIds")
        try container.encode(self.dates, forKey: "dates")
        try container.encode(self.visibility.map { Int32($0 ? 1 : 0) }, forKey: "visibility")
        try container.encode(self.count, forKey: "count")
    }
}

public struct CommunityParticipantJoinedChats: Equatable {
    public let creatorChatIds: [EnginePeer.Id]
    public let joinedChatIds: [EnginePeer.Id]
    public let peers: [EnginePeer.Id: EnginePeer]

    public init(creatorChatIds: [EnginePeer.Id], joinedChatIds: [EnginePeer.Id], peers: [EnginePeer.Id: EnginePeer]) {
        self.creatorChatIds = creatorChatIds
        self.joinedChatIds = joinedChatIds
        self.peers = peers
    }
}

private func communityInputChannel(transaction: Transaction, communityId: PeerId) -> Api.InputChannel? {
    guard let peer = transaction.getPeer(communityId) else {
        return nil
    }
    return apiInputChannel(peer)
}

private func inputPeer(transaction: Transaction, peerId: PeerId) -> Api.InputPeer? {
    guard let peer = transaction.getPeer(peerId) else {
        return nil
    }
    return apiInputPeer(peer)
}

private func communitiesChats(_ result: Api.messages.Chats) -> [Api.Chat] {
    switch result {
    case let .chats(chatsData):
        return chatsData.chats
    case let .chatsSlice(chatsSliceData):
        return chatsSliceData.chats
    }
}

func _internal_updatedCommunitiesState(postbox: Postbox) -> Signal<CommunitiesState, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.communitiesState])
    |> map { preferences -> CommunitiesState in
        return preferences.values[PreferencesKeys.communitiesState]?.get(CommunitiesState.self) ?? .default
    }
    |> distinctUntilChanged
}

func _internal_currentCommunitiesState(transaction: Transaction) -> CommunitiesState {
    return transaction.getPreferencesEntry(key: PreferencesKeys.communitiesState)?.get(CommunitiesState.self) ?? .default
}

func updateCommunitiesState(transaction: Transaction, _ f: (CommunitiesState) -> CommunitiesState) -> CommunitiesState {
    var result: CommunitiesState?
    transaction.updatePreferencesEntry(key: PreferencesKeys.communitiesState, { entry in
        let current = entry?.get(CommunitiesState.self) ?? .default
        let updated = f(current)
        result = updated
        return PreferencesEntry(updated)
    })
    return result ?? .default
}

private func _internal_loadJoinedCommunities(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<[EnginePeer], NoError> {
    return network.request(Api.functions.communities.getJoinedCommunities())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<[EnginePeer], NoError> in
        guard let result else {
            return .single([])
        }

        let chats = communitiesChats(result)

        return postbox.transaction { transaction -> [EnginePeer] in
            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)

            var communityIds: [PeerId] = []
            var peers: [EnginePeer] = []
            for chat in chats {
                guard let peer = transaction.getPeer(chat.peerId), peer is TelegramCommunity else {
                    continue
                }
                communityIds.append(peer.id)
                peers.append(EnginePeer(peer))
            }

            let _ = updateCommunitiesState(transaction: transaction, { _ in
                return CommunitiesState(communityIds: communityIds)
            })

            return peers
        }
    }
}

func managedCommunitiesState(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Never, NoError> {
    return _internal_loadJoinedCommunities(postbox: postbox, network: network, accountPeerId: accountPeerId)
    |> ignoreValues
}

func _internal_createCommunity(account: Account, title: String, about: String?, peerId: PeerId, visible: Bool) -> Signal<PeerId, CreateCommunityError> {
    return account.postbox.transaction { transaction -> Signal<PeerId, CreateCommunityError> in
        guard let inputPeer = inputPeer(transaction: transaction, peerId: peerId) else {
            return .fail(.generic)
        }

        var flags: Int32 = 0
        if about != nil {
            flags |= 1 << 0
        }
        if !visible {
            flags |= 1 << 1
        }

        return account.network.request(Api.functions.communities.create(flags: flags, title: title, about: about, peer: inputPeer))
        |> mapError { error -> CreateCommunityError in
            if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                return .adminRequired
            }
            return .generic
        }
        |> mapToSignal { updates -> Signal<PeerId, CreateCommunityError> in
            account.stateManager.addUpdates(updates)
            if let peer = updates.chats.compactMap({ parseTelegramGroupOrChannel(chat: $0) as? TelegramCommunity }).first {
                let communityId = peer.id
                return account.postbox.transaction { transaction -> PeerId in
                    let state = _internal_currentCommunitiesState(transaction: transaction)
                    if var communityIds = state.communityIds, !communityIds.contains(communityId) {
                        communityIds.append(communityId)
                        let _ = updateCommunitiesState(transaction: transaction, { _ in
                            return CommunitiesState(communityIds: communityIds)
                        })
                    }
                    return communityId
                }
                |> castError(CreateCommunityError.self)
            } else {
                return .fail(.generic)
            }
        }
    }
    |> castError(CreateCommunityError.self)
    |> switchToLatest
}

func _internal_joinedCommunities(account: Account) -> Signal<[EnginePeer], NoError> {
    return _internal_loadJoinedCommunities(postbox: account.postbox, network: account.network, accountPeerId: account.peerId)
}

func _internal_toggleCommunityPeerLink(account: Account, communityId: PeerId, peerId: PeerId, action: CommunityPeerLinkAction) -> Signal<Never, CommunityPeerLinkError> {
    return account.postbox.transaction { transaction -> Signal<Never, CommunityPeerLinkError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId), let inputPeer = inputPeer(transaction: transaction, peerId: peerId) else {
            return .fail(.generic)
        }

        let flags: Int32
        switch action {
        case let .link(visible):
            flags = visible ? (1 << 0) : (1 << 1)
        case .unlink:
            flags = 1 << 2
        }

        return account.network.request(Api.functions.communities.togglePeerLink(flags: flags, community: inputCommunity, peer: inputPeer))
        |> mapError { error -> CommunityPeerLinkError in
            if error.errorCode == 406 {
                return .serverProvided(text: error.errorDescription)
            }
            switch error.errorDescription {
            case "COMMUNITY_REQUEST_CREATED":
                return .requestCreated
            case "CHAT_ADMIN_REQUIRED":
                return .adminRequired
            case "COMMUNITY_PEERS_TOO_MUCH":
                return .peersTooMuch
            default:
                return .generic
            }
        }
        |> ignoreValues
    }
    |> castError(CommunityPeerLinkError.self)
    |> switchToLatest
}

private func _internal_communityPeerLinkRequestsResult(account: Account, communityId: PeerId, offset: String?, limit: Int32) -> Signal<CommunityPeerLinkRequests?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return communityInputChannel(transaction: transaction, communityId: communityId)
    }
    |> mapToSignal { inputCommunity -> Signal<Api.communities.PeerLinkRequests?, NoError> in
        guard let inputCommunity else {
            return .single(nil)
        }
        return account.network.request(Api.functions.communities.getPeerLinkRequests(community: inputCommunity, offset: offset ?? "", limit: limit))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.communities.PeerLinkRequests?, NoError> in
            return .single(nil)
        }
    }
    |> mapToSignal { result -> Signal<CommunityPeerLinkRequests?, NoError> in
        guard let result else {
            return .single(nil)
        }

        switch result {
        case let .peerLinkRequests(peerLinkRequestsData):
            let (totalCount, apiRequests, nextOffset, chats, users) = (peerLinkRequestsData.totalCount, peerLinkRequestsData.requests, peerLinkRequestsData.nextOffset, peerLinkRequestsData.chats, peerLinkRequestsData.users)
            return account.postbox.transaction { transaction -> CommunityPeerLinkRequests? in
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)

                let requests = apiRequests.map { request -> CommunityPeerRequest in
                    switch request {
                    case let .communityPeerRequest(requestData):
                        return CommunityPeerRequest(
                            peerId: requestData.peer.peerId,
                            requestedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(requestData.requestedBy)),
                            date: requestData.date,
                            isVisible: (requestData.flags & (1 << 0)) != 0
                        )
                    }
                }

                var peerIds = Set<PeerId>()
                for request in requests {
                    peerIds.insert(request.peerId)
                    peerIds.insert(request.requestedBy)
                }
                for chat in chats {
                    peerIds.insert(chat.peerId)
                }
                for user in users {
                    peerIds.insert(user.peerId)
                }

                var peers: [EnginePeer.Id: EnginePeer] = [:]
                for peerId in peerIds {
                    if let peer = transaction.getPeer(peerId) {
                        peers[peerId] = EnginePeer(peer)
                    }
                }

                return CommunityPeerLinkRequests(totalCount: totalCount, requests: requests, nextOffset: nextOffset, peers: peers)
            }
        }
    }
}

func _internal_communityPeerLinkRequests(account: Account, communityId: PeerId, offset: String?, limit: Int32) -> Signal<CommunityPeerLinkRequests, NoError> {
    return _internal_communityPeerLinkRequestsResult(account: account, communityId: communityId, offset: offset, limit: limit)
    |> map { result -> CommunityPeerLinkRequests in
        return result ?? CommunityPeerLinkRequests(totalCount: 0, requests: [], nextOffset: nil, peers: [:])
    }
}

func _internal_toggleCommunityPeerLinkRequestApproval(account: Account, communityId: PeerId, peerId: PeerId, approve: Bool) -> Signal<Never, CommunityPeerRequestApprovalError> {
    return account.postbox.transaction { transaction -> Signal<Never, CommunityPeerRequestApprovalError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId), let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }

        let flags: Int32 = approve ? 0 : (1 << 0)
        return account.network.request(Api.functions.communities.togglePeerLinkRequestApproval(flags: flags, community: inputCommunity, peer: inputPeer))
        |> mapError { error -> CommunityPeerRequestApprovalError in
            if error.errorCode == 406 {
                return .serverProvided(text: error.errorDescription)
            }
            switch error.errorDescription {
            case "CHAT_ADMIN_REQUIRED":
                return .adminRequired
            case "COMMUNITY_PEERS_TOO_MUCH":
                return .peersTooMuch
            default:
                return .generic
            }
        }
        |> ignoreValues
    }
    |> castError(CommunityPeerRequestApprovalError.self)
    |> switchToLatest
}

func _internal_toggleAllCommunityPeerLinkRequestApproval(account: Account, communityId: PeerId, approve: Bool) -> Signal<Never, CommunityPeerRequestApprovalError> {
    return account.postbox.transaction { transaction -> Signal<Never, CommunityPeerRequestApprovalError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId) else {
            return .fail(.generic)
        }

        let flags: Int32 = approve ? 0 : (1 << 0)
        return account.network.request(Api.functions.communities.toggleAllPeerLinkRequestApproval(flags: flags, community: inputCommunity))
        |> mapError { error -> CommunityPeerRequestApprovalError in
            switch error.errorDescription {
            case "CHAT_ADMIN_REQUIRED":
                return .adminRequired
            case "COMMUNITY_PEERS_TOO_MUCH":
                return .peersTooMuch
            default:
                return .generic
            }
        }
        |> ignoreValues
    }
    |> castError(CommunityPeerRequestApprovalError.self)
    |> switchToLatest
}

func _internal_toggleCommunityParticipantBanned(account: Account, communityId: PeerId, participantId: PeerId, banned: Bool) -> Signal<Void, CommunityParticipantBannedError> {
    return account.postbox.transaction { transaction -> Signal<Void, CommunityParticipantBannedError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId), let inputParticipant = inputPeer(transaction: transaction, peerId: participantId) else {
            return .fail(.generic)
        }

        let flags: Int32 = banned ? 0 : (1 << 0)
        return account.network.request(Api.functions.communities.toggleParticipantBanned(flags: flags, community: inputCommunity, participant: inputParticipant))
        |> mapError { error -> CommunityParticipantBannedError in
            if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                return .adminRequired
            }
            return .generic
        }
        |> map { _ in Void() }
    }
    |> castError(CommunityParticipantBannedError.self)
    |> switchToLatest
}

func _internal_toggleCommunityCollapsedInDialogs(account: Account, communityId: PeerId, collapsed: Bool) -> Signal<Never, CommunityCollapsedInDialogsError> {
    return account.postbox.transaction { transaction -> Signal<Never, CommunityCollapsedInDialogsError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId) else {
            return .fail(.generic)
        }

        let flags: Int32 = collapsed ? (1 << 0) : 0
        return account.network.request(Api.functions.communities.toggleCommunityCollapsedInDialogs(flags: flags, community: inputCommunity))
        |> mapError { _ -> CommunityCollapsedInDialogsError in
            return .generic
        }
        |> mapToSignal { updates -> Signal<Never, CommunityCollapsedInDialogsError> in
            account.stateManager.addUpdates(updates)
            return account.postbox.transaction { transaction -> Void in
                if var community = transaction.getPeer(communityId) as? TelegramCommunity {
                    community = community.withUpdatedCollapsedInDialogs(collapsed)
                    transaction.updatePeersInternal([community]) { _, peer in
                        return peer
                    }
                }
                if let cachedData = transaction.getPeerCachedData(peerId: communityId) as? CachedCommunityData {
                    var linkedPeerIds = Set<PeerId>()
                    for linkedPeer in cachedData.linkedPeers {
                        linkedPeerIds.insert(linkedPeer.peerId)
                    }
                    for peerId in linkedPeerIds {
                        if collapsed {
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        } else if isPeerHiddenByCollapsedCommunity(transaction: transaction, peerId: peerId) {
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        } else if let peer = transaction.getPeer(peerId) {
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(
                                groupId: .root,
                                pinningIndex: transaction.getPeerChatListIndex(peerId)?.1.pinningIndex,
                                minTimestamp: minTimestampForPeerInclusion(peer)
                            ))
                        }
                    }
                }
            }
            |> castError(CommunityCollapsedInDialogsError.self)
            |> ignoreValues
        }
    }
    |> castError(CommunityCollapsedInDialogsError.self)
    |> switchToLatest
}

func _internal_communityParticipantJoinedChats(account: Account, communityId: PeerId, participantId: PeerId) -> Signal<CommunityParticipantJoinedChats, NoError> {
    return account.postbox.transaction { transaction -> (Api.InputChannel?, Api.InputPeer?) in
        return (
            communityInputChannel(transaction: transaction, communityId: communityId),
            inputPeer(transaction: transaction, peerId: participantId)
        )
    }
    |> mapToSignal { inputCommunity, inputParticipant -> Signal<Api.communities.ParticipantJoinedChats?, NoError> in
        guard let inputCommunity, let inputParticipant else {
            return .single(nil)
        }
        return account.network.request(Api.functions.communities.getParticipantJoinedChats(community: inputCommunity, participant: inputParticipant))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.communities.ParticipantJoinedChats?, NoError> in
            return .single(nil)
        }
    }
    |> mapToSignal { result -> Signal<CommunityParticipantJoinedChats, NoError> in
        guard let result else {
            return .single(CommunityParticipantJoinedChats(creatorChatIds: [], joinedChatIds: [], peers: [:]))
        }

        switch result {
        case let .participantJoinedChats(participantJoinedChatsData):
            let (creatorChatIds, joinedChatIds, chats, users) = (participantJoinedChatsData.creatorChatIds, participantJoinedChatsData.joinedChatIds, participantJoinedChatsData.chats, participantJoinedChatsData.users)
            return account.postbox.transaction { transaction -> CommunityParticipantJoinedChats in
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)

                let mappedCreatorChatIds = creatorChatIds.map { PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value($0)) }
                let mappedJoinedChatIds = joinedChatIds.map { PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value($0)) }
                let allPeerIds = Set(mappedCreatorChatIds + mappedJoinedChatIds)

                var peers: [EnginePeer.Id: EnginePeer] = [:]
                for peerId in allPeerIds {
                    if let peer = transaction.getPeer(peerId) {
                        peers[peerId] = EnginePeer(peer)
                    }
                }

                return CommunityParticipantJoinedChats(creatorChatIds: mappedCreatorChatIds, joinedChatIds: mappedJoinedChatIds, peers: peers)
            }
        }
    }
}

public struct CommunityPeerLinkRequestsState: Equatable {
    public var requests: [CommunityPeerRequest]
    public var peers: [EnginePeer.Id: EnginePeer]
    public var isLoadingMore: Bool
    public var hasLoadedOnce: Bool
    public var canLoadMore: Bool
    public var count: Int32

    public static var Loading = CommunityPeerLinkRequestsState(
        requests: [],
        peers: [:],
        isLoadingMore: false,
        hasLoadedOnce: false,
        canLoadMore: false,
        count: 0
    )

    public static var Empty = CommunityPeerLinkRequestsState(
        requests: [],
        peers: [:],
        isLoadingMore: false,
        hasLoadedOnce: true,
        canLoadMore: false,
        count: 0
    )
}

private final class CommunityPeerLinkRequestsContextImpl {
    private let queue: Queue
    private let account: Account
    private let communityId: PeerId
    private let initialLimit: Int32
    private let disposable = MetaDisposable()
    private let actionDisposables = DisposableSet()
    private let updateDisposables = DisposableSet()

    private var requests: [CommunityPeerRequest] = []
    private var peers: [EnginePeer.Id: EnginePeer] = [:]
    private var nextOffset: String?
    private var isLoadingMore = false
    private var hasLoadedOnce = false
    private var canLoadMore = true
    private var loadedFromCache = false
    private var populateCache = true
    private var count: Int32 = 0

    let state = Promise<CommunityPeerLinkRequestsState>()

    init(queue: Queue, account: Account, communityId: PeerId, initialLimit: Int32) {
        self.queue = queue
        self.account = account
        self.communityId = communityId
        self.initialLimit = initialLimit

        self.isLoadingMore = true
        self.updateState()
        self.disposable.set((account.postbox.transaction { transaction -> (requests: [CommunityPeerRequest], peers: [EnginePeer.Id: EnginePeer], count: Int32, canLoadMore: Bool)? in
            guard let cachedResult = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedCommunityPeerLinkRequests, key: CachedCommunityPeerLinkRequests.key(communityId: communityId)))?.get(CachedCommunityPeerLinkRequests.self) else {
                return nil
            }
            guard cachedResult.peerIds.count == cachedResult.requestedByIds.count, cachedResult.peerIds.count == cachedResult.dates.count, cachedResult.peerIds.count == cachedResult.visibility.count else {
                return nil
            }

            var requests: [CommunityPeerRequest] = []
            var peers: [EnginePeer.Id: EnginePeer] = [:]
            for index in cachedResult.peerIds.indices {
                let peerId = cachedResult.peerIds[index]
                let requestedBy = cachedResult.requestedByIds[index]
                guard let peer = transaction.getPeer(peerId), let requestedByPeer = transaction.getPeer(requestedBy) else {
                    return nil
                }
                requests.append(CommunityPeerRequest(peerId: peerId, requestedBy: requestedBy, date: cachedResult.dates[index], isVisible: cachedResult.visibility[index]))
                peers[peerId] = EnginePeer(peer)
                peers[requestedBy] = EnginePeer(requestedByPeer)
            }

            return (requests, peers, cachedResult.count, Int(cachedResult.count) > requests.count)
        }
        |> deliverOn(self.queue)).start(next: { [weak self] cachedResult in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isLoadingMore = false
            if let cachedResult {
                strongSelf.requests = cachedResult.requests
                strongSelf.peers = cachedResult.peers
                strongSelf.count = cachedResult.count
                strongSelf.hasLoadedOnce = true
                strongSelf.canLoadMore = cachedResult.canLoadMore
                strongSelf.loadedFromCache = true
            }
            strongSelf.loadMore(limit: initialLimit)
        }))
        self.loadMore(limit: initialLimit)
    }

    deinit {
        self.disposable.dispose()
        self.actionDisposables.dispose()
        self.updateDisposables.dispose()
    }

    func loadMore(limit: Int32?) {
        if self.isLoadingMore || (!self.canLoadMore && !self.loadedFromCache) {
            return
        }
        self.isLoadingMore = true

        let account = self.account
        let communityId = self.communityId
        let loadedFromCache = self.loadedFromCache
        let offset: String?
        if self.loadedFromCache {
            self.loadedFromCache = false
            self.populateCache = true
            offset = nil
        } else {
            offset = self.nextOffset
        }
        let populateCache = self.populateCache
        let requestLimit = limit ?? self.initialLimit
        self.updateState()

        self.disposable.set((_internal_communityPeerLinkRequestsResult(
            account: account,
            communityId: communityId,
            offset: offset,
            limit: requestLimit
        )
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            guard let result else {
                strongSelf.isLoadingMore = false
                if !strongSelf.hasLoadedOnce {
                    strongSelf.hasLoadedOnce = true
                    strongSelf.canLoadMore = false
                    strongSelf.count = 0
                } else if loadedFromCache {
                    strongSelf.loadedFromCache = true
                }
                strongSelf.updateState()
                return
            }

            if strongSelf.populateCache {
                strongSelf.populateCache = false
                strongSelf.requests.removeAll()
                strongSelf.peers.removeAll()
            }
            var existingIds = Set(strongSelf.requests.map(\.peerId))
            for request in result.requests {
                if existingIds.contains(request.peerId) {
                    continue
                }
                existingIds.insert(request.peerId)
                strongSelf.requests.append(request)
            }
            for (peerId, peer) in result.peers {
                strongSelf.peers[peerId] = peer
            }

            strongSelf.nextOffset = result.nextOffset
            strongSelf.count = max(result.totalCount, Int32(strongSelf.requests.count))
            strongSelf.isLoadingMore = false
            strongSelf.hasLoadedOnce = true
            strongSelf.canLoadMore = result.nextOffset != nil && !result.requests.isEmpty
            if !strongSelf.canLoadMore {
                strongSelf.count = Int32(strongSelf.requests.count)
            }
            if populateCache {
                strongSelf.updateCache()
            }
            strongSelf.updateState()
        }))
    }

    func reload(limit: Int32?) {
        self.disposable.set(nil)
        self.requests = []
        self.peers = [:]
        self.nextOffset = nil
        self.isLoadingMore = false
        self.hasLoadedOnce = false
        self.canLoadMore = true
        self.loadedFromCache = false
        self.populateCache = true
        self.count = 0
        self.updateState()
        self.loadMore(limit: limit ?? self.initialLimit)
    }

    func update(_ request: CommunityPeerRequest, action: CommunityPeerLinkRequestsContext.UpdateAction) {
        self.actionDisposables.add(_internal_toggleCommunityPeerLinkRequestApproval(
            account: self.account,
            communityId: self.communityId,
            peerId: request.peerId,
            approve: action == .approve
        ).start())

        self.requests.removeAll(where: { $0.peerId == request.peerId })
        self.count = max(0, self.count - 1)
        self.updateCachedData(approvedRequests: action == .approve ? [request] : [], pendingRequestsCount: self.count)
        self.updateCache()
        self.updateState()
    }

    func updateAll(action: CommunityPeerLinkRequestsContext.UpdateAction) {
        self.actionDisposables.add(_internal_toggleAllCommunityPeerLinkRequestApproval(
            account: self.account,
            communityId: self.communityId,
            approve: action == .approve
        ).start())

        let approvedRequests = action == .approve ? self.requests : []
        self.requests = []
        self.count = 0
        self.canLoadMore = false
        self.nextOffset = nil
        self.updateCachedData(approvedRequests: approvedRequests, pendingRequestsCount: 0)
        self.updateCache()
        self.updateState()
    }

    private func updateCache() {
        guard self.hasLoadedOnce && !self.isLoadingMore else {
            return
        }

        let communityId = self.communityId
        let requests = Array(self.requests.prefix(100))
        let count = self.count
        self.updateDisposables.add(self.account.postbox.transaction({ transaction in
            if let entry = CodableEntry(CachedCommunityPeerLinkRequests(requests: requests, count: count)) {
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedCommunityPeerLinkRequests, key: CachedCommunityPeerLinkRequests.key(communityId: communityId)), entry: entry)
            }
        }).start())
    }

    private func updateCachedData(approvedRequests: [CommunityPeerRequest], pendingRequestsCount: Int32) {
        let communityId = self.communityId
        self.updateDisposables.add(self.account.postbox.transaction({ transaction in
            transaction.updatePeerCachedData(peerIds: Set([communityId]), update: { _, current in
                guard let current = current as? CachedCommunityData else {
                    return current
                }

                var linkedPeers = current.linkedPeers
                if !approvedRequests.isEmpty {
                    var existingIds = Set(linkedPeers.map(\.peerId))
                    for request in approvedRequests {
                        if existingIds.contains(request.peerId) {
                            continue
                        }
                        existingIds.insert(request.peerId)
                        linkedPeers.append(CachedCommunityData.CommunityLinkedPeer(peerId: request.peerId, visible: request.isVisible))
                    }
                }

                return current
                    .withUpdatedLinkedPeers(linkedPeers)
                    .withUpdatedPendingRequests(pendingRequestsCount)
            })
        }).start())
    }

    private func updateState() {
        self.state.set(.single(CommunityPeerLinkRequestsState(
            requests: self.requests,
            peers: self.peers,
            isLoadingMore: self.isLoadingMore,
            hasLoadedOnce: self.hasLoadedOnce,
            canLoadMore: self.canLoadMore,
            count: self.count
        )))
    }
}

public final class CommunityPeerLinkRequestsContext {
    public enum UpdateAction {
        case approve
        case deny
    }

    private let queue = Queue()
    private let impl: QueueLocalObject<CommunityPeerLinkRequestsContextImpl>

    public var state: Signal<CommunityPeerLinkRequestsState, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }

    init(account: Account, communityId: PeerId, initialLimit: Int32) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return CommunityPeerLinkRequestsContextImpl(queue: queue, account: account, communityId: communityId, initialLimit: initialLimit)
        })
    }

    public func loadMore(limit: Int32 = 100) {
        self.impl.with { impl in
            impl.loadMore(limit: limit)
        }
    }

    public func reload(limit: Int32? = nil) {
        self.impl.with { impl in
            impl.reload(limit: limit)
        }
    }

    public func update(_ request: CommunityPeerRequest, action: UpdateAction) {
        self.impl.with { impl in
            impl.update(request, action: action)
        }
    }

    public func updateAll(action: UpdateAction) {
        self.impl.with { impl in
            impl.updateAll(action: action)
        }
    }
}
