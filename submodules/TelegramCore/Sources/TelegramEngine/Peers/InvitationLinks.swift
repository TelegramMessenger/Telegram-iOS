import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

private func _internal_updateInvitationRequest(account: Account, peerId: PeerId, userId: PeerId, approve: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Never, NoError> in
        if let peer = transaction.getPeer(peerId), let user = transaction.getPeer(userId), let inputPeer = apiInputPeer(peer), let inputUser = apiInputUser(user) {
            var flags: Int32 = 0
            if approve {
                flags |= (1 << 0)
            }
            return account.network.request(Api.functions.messages.hideChatJoinRequest(flags: flags, peer: inputPeer, userId: inputUser))
            |> retryRequest
            |> ignoreValues
        } else {
            return .complete()
        }
    } |> switchToLatest
}

private func _internal_updateAllInvitationRequests(account: Account, peerId: PeerId, link: String?, approve: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Never, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if approve {
                flags |= (1 << 0)
            }
            if let _ = link {
                flags |= (1 << 1)
            }
            return account.network.request(Api.functions.messages.hideAllChatJoinRequests(flags: flags, peer: inputPeer, link: link))
            |> retryRequest
            |> ignoreValues
        } else {
            return .complete()
        }
    } |> switchToLatest
}

func _internal_revokePersistentPeerExportedInvitation(account: Account, peerId: PeerId) -> Signal<ExportedInvitation?, NoError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let flags: Int32 = (1 << 2)
            if let _ = peer as? TelegramChannel {
                return account.network.request(Api.functions.messages.exportChatInvite(flags: flags, peer: inputPeer, expireDate: nil, usageLimit: nil, title: nil))
                |> retryRequest
                |> mapToSignal { result -> Signal<ExportedInvitation?, NoError> in
                    return account.postbox.transaction { transaction -> ExportedInvitation? in
                        let invitation = ExportedInvitation(apiExportedInvite: result)
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let current = current as? CachedChannelData {
                                return current.withUpdatedExportedInvitation(invitation)
                            } else {
                                return CachedChannelData().withUpdatedExportedInvitation(invitation)
                            }
                        })
                        return invitation

                    }
                }
            } else if let _ = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.exportChatInvite(flags: flags, peer: inputPeer, expireDate: nil, usageLimit: nil, title: nil))
                |> retryRequest
                |> mapToSignal { result -> Signal<ExportedInvitation?, NoError> in
                    return account.postbox.transaction { transaction -> ExportedInvitation? in
                        let invitation = ExportedInvitation(apiExportedInvite: result)
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let current = current as? CachedGroupData {
                                return current.withUpdatedExportedInvitation(invitation)
                            } else {
                                return current
                            }
                        })
                        return invitation
                    }
                }
            } else {
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}


public enum CreatePeerExportedInvitationError {
    case generic
}

func _internal_createPeerExportedInvitation(account: Account, peerId: PeerId, title: String?, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Bool?) -> Signal<ExportedInvitation?, CreatePeerExportedInvitationError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, CreatePeerExportedInvitationError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if let _ = expireDate {
                flags |= (1 << 0)
            }
            if let _ = usageLimit {
                flags |= (1 << 1)
            }
            if let requestNeeded = requestNeeded, requestNeeded {
                flags |= (1 << 3)
            }
            if let _ = title {
                flags |= (1 << 4)
            }
            return account.network.request(Api.functions.messages.exportChatInvite(flags: flags, peer: inputPeer, expireDate: expireDate, usageLimit: usageLimit, title: title))
            |> mapError { _ in return CreatePeerExportedInvitationError.generic }
            |> map { result -> ExportedInvitation? in
                return ExportedInvitation(apiExportedInvite: result)
            }
        } else {
            return .complete()
        }
    }
    |> castError(CreatePeerExportedInvitationError.self)
    |> switchToLatest
}

public enum EditPeerExportedInvitationError {
    case generic
}

func _internal_editPeerExportedInvitation(account: Account, peerId: PeerId, link: String, title: String?, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Bool?) -> Signal<ExportedInvitation?, EditPeerExportedInvitationError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, EditPeerExportedInvitationError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if let _ = expireDate {
                flags |= (1 << 0)
            }
            if let _ = usageLimit {
                flags |= (1 << 1)
            }
            if let _ = requestNeeded {
                flags |= (1 << 3)
            }
            if let _ = title {
                flags |= (1 << 4)
            }
            return account.network.request(Api.functions.messages.editExportedChatInvite(flags: flags, peer: inputPeer, link: link, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded.flatMap { $0 ? .boolTrue : .boolFalse }, title: title))
            |> mapError { _ in return EditPeerExportedInvitationError.generic }
            |> mapToSignal { result -> Signal<ExportedInvitation?, EditPeerExportedInvitationError> in
                return account.postbox.transaction { transaction in
                    if case let .exportedChatInvite(invite, users) = result {
                        var peers: [Peer] = []
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        return ExportedInvitation(apiExportedInvite: invite)
                    } else {
                        return nil
                    }
                } |> mapError { _ -> EditPeerExportedInvitationError in }
            }
        } else {
            return .complete()
        }
    }
    |> castError(EditPeerExportedInvitationError.self)
    |> switchToLatest
}

public enum RevokePeerExportedInvitationError {
    case generic
}

public enum RevokeExportedInvitationResult {
    case update(ExportedInvitation)
    case replace(ExportedInvitation, ExportedInvitation)
}

func _internal_revokePeerExportedInvitation(account: Account, peerId: PeerId, link: String) -> Signal<RevokeExportedInvitationResult?, RevokePeerExportedInvitationError> {
    return account.postbox.transaction { transaction -> Signal<RevokeExportedInvitationResult?, RevokePeerExportedInvitationError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let flags: Int32 = (1 << 2)
            return account.network.request(Api.functions.messages.editExportedChatInvite(flags: flags, peer: inputPeer, link: link, expireDate: nil, usageLimit: nil, requestNeeded: nil, title: nil))
            |> mapError { _ in return RevokePeerExportedInvitationError.generic }
            |> mapToSignal { result -> Signal<RevokeExportedInvitationResult?, RevokePeerExportedInvitationError> in
                return account.postbox.transaction { transaction in
                    if case let .exportedChatInvite(invite, users) = result {
                        var peers: [Peer] = []
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        return .update(ExportedInvitation(apiExportedInvite: invite))
                    } else if case let .exportedChatInviteReplaced(invite, newInvite, users) = result {
                        var peers: [Peer] = []
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        
                        let previous = ExportedInvitation(apiExportedInvite: invite)
                        let new = ExportedInvitation(apiExportedInvite: newInvite)
                        
                        if previous.isPermanent && new.isPermanent {
                            transaction.updatePeerCachedData(peerIds: [peerId]) { peerId, current -> CachedPeerData? in
                                if peerId.namespace == Namespaces.Peer.CloudGroup {
                                    var current = current as? CachedGroupData ?? CachedGroupData()
                                    current = current.withUpdatedExportedInvitation(new)
                                    return current
                                } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                                    var current = current as? CachedChannelData ?? CachedChannelData()
                                    current = current.withUpdatedExportedInvitation(new)
                                    return current
                                } else {
                                    return current
                                }
                            }
                        }
                        
                        return .replace(previous, new)
                    } else {
                        return nil
                    }
                } |> mapError { _ -> RevokePeerExportedInvitationError in }
            }
        } else {
            return .complete()
        }
    }
    |> castError(RevokePeerExportedInvitationError.self)
    |> switchToLatest
}

public struct ExportedInvitations : Equatable {
    public let list: [ExportedInvitation]?
    public let totalCount: Int32
}

func _internal_peerExportedInvitations(account: Account, peerId: PeerId, revoked: Bool, adminId: PeerId? = nil, offsetLink: ExportedInvitation? = nil) -> Signal<ExportedInvitations?, NoError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitations?, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer), let adminPeer = transaction.getPeer(adminId ?? account.peerId), let adminId = apiInputUser(adminPeer) {
            var flags: Int32 = 0
            if let _ = offsetLink?.date {
                flags |= (1 << 2)
            }
            if revoked {
                flags |= (1 << 3)
            }
            return account.network.request(Api.functions.messages.getExportedChatInvites(flags: flags, peer: inputPeer, adminId: adminId, offsetDate: offsetLink?.date, offsetLink: offsetLink?.link, limit: 50))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.ExportedChatInvites?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<ExportedInvitations?, NoError> in
                return account.postbox.transaction { transaction -> ExportedInvitations? in
                    if let result = result, case let .exportedChatInvites(count, apiInvites, users) = result {
                        var peers: [Peer] = []
                        var peersMap: [PeerId: Peer] = [:]
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            peersMap[telegramUser.id] = telegramUser
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        
                        let invites = apiInvites.map { ExportedInvitation(apiExportedInvite: $0) }
                        return ExportedInvitations(list: invites, totalCount: count)
                    } else {
                        return nil
                    }
                }
            }
        } else {
            return .single(nil)
        }
    } |> switchToLatest
}


public enum DeletePeerExportedInvitationError {
    case generic
}

func _internal_deletePeerExportedInvitation(account: Account, peerId: PeerId, link: String) -> Signal<Never, DeletePeerExportedInvitationError> {
    return account.postbox.transaction { transaction -> Signal<Never, DeletePeerExportedInvitationError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.deleteExportedChatInvite(peer: inputPeer, link: link))
            |> mapError { _ in return DeletePeerExportedInvitationError.generic }
            |> ignoreValues
        } else {
            return .complete()
        }
    }
    |> castError(DeletePeerExportedInvitationError.self)
    |> switchToLatest
}

func _internal_deleteAllRevokedPeerExportedInvitations(account: Account, peerId: PeerId, adminId: PeerId) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Never, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer), let adminPeer = transaction.getPeer(adminId), let inputAdminId = apiInputUser(adminPeer) {
            return account.network.request(Api.functions.messages.deleteRevokedExportedChatInvites(peer: inputPeer, adminId: inputAdminId))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
        } else {
            return .complete()
        }
    }
    |> switchToLatest
}

public struct PeerExportedInvitationsState: Equatable {
    public var invitations: [ExportedInvitation]
    public var isLoadingMore: Bool
    public var hasLoadedOnce: Bool
    public var canLoadMore: Bool
    public var count: Int32
    
    public init() {
        self.invitations = []
        self.isLoadingMore = false
        self.hasLoadedOnce = false
        self.canLoadMore = false
        self.count = 0
    }
    
    public init(invitations: [ExportedInvitation], isLoadingMore: Bool, hasLoadedOnce: Bool, canLoadMore: Bool, count: Int32) {
        self.invitations = invitations
        self.isLoadingMore = isLoadingMore
        self.hasLoadedOnce = hasLoadedOnce
        self.canLoadMore = canLoadMore
        self.count = count
    }
}

final class CachedPeerExportedInvitations: Codable {
    let invitations: [ExportedInvitation]
    let canLoadMore: Bool
    let count: Int32
    
    static func key(peerId: PeerId, revoked: Bool) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: revoked ? 1 : 0)
        return key
    }
    
    init(invitations: [ExportedInvitation], canLoadMore: Bool, count: Int32) {
        self.invitations = invitations
        self.canLoadMore = canLoadMore
        self.count = count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.invitations = try container.decode([ExportedInvitation].self, forKey: "invitations")
        self.canLoadMore = try container.decode(Bool.self, forKey: "canLoadMore")
        self.count = try container.decode(Int32.self, forKey: "count")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.invitations, forKey: "invitations")
        try container.encode(self.canLoadMore, forKey: "canLoadMore")
        try container.encode(self.count, forKey: "count")
    }
}

private final class PeerExportedInvitationsContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    private let adminId: PeerId
    private let revoked: Bool
    private var forceUpdate: Bool
    private let disposable = MetaDisposable()
    private let updateDisposable = MetaDisposable()
    private var isLoadingMore: Bool = false
    private var hasLoadedOnce: Bool = false
    private var canLoadMore: Bool = true
    private var loadedFromCache: Bool = false
    private var results: [ExportedInvitation] = []
    private var count: Int32
    private var populateCache: Bool = true
    private var isMainList: Bool
    
    let state = Promise<PeerExportedInvitationsState>()
    
    init(queue: Queue, account: Account, peerId: PeerId, adminId: PeerId?, revoked: Bool, forceUpdate: Bool) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
        self.adminId = adminId ?? account.peerId
        self.revoked = revoked
        self.forceUpdate = forceUpdate
        self.isMainList = adminId == nil
        
        self.count = 0
        
        if adminId == nil {
            self.isLoadingMore = true
            self.disposable.set((account.postbox.transaction { transaction -> CachedPeerExportedInvitations? in
                return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerExportedInvitations, key: CachedPeerExportedInvitations.key(peerId: peerId, revoked: revoked)))?.get(CachedPeerExportedInvitations.self)
            }
            |> deliverOn(self.queue)).start(next: { [weak self] cachedResult in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isLoadingMore = false
                if let cachedResult = cachedResult {
                    strongSelf.results = cachedResult.invitations
                    strongSelf.count = cachedResult.count
                    strongSelf.hasLoadedOnce = true
                    strongSelf.canLoadMore = cachedResult.canLoadMore
                    strongSelf.loadedFromCache = true
                }
                strongSelf.loadMore()
            }))
        }
                
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
        self.updateDisposable.dispose()
    }
    
    func reload() {
        self.forceUpdate = true
        self.loadMore()
    }
    
    func loadMore() {
        if self.isLoadingMore {
            return
        }
        self.isLoadingMore = true
        let account = self.account
        let peerId = self.peerId
        let adminId = self.adminId
        let revoked = self.revoked
        var lastResult = self.results.last
        
        if self.forceUpdate {
            self.populateCache = self.isMainList
            self.forceUpdate = false
            lastResult = nil
        } else if self.loadedFromCache {
            self.populateCache = false
            self.loadedFromCache = false
        }
        let populateCache = self.populateCache
        
        self.disposable.set((self.account.postbox.transaction { transaction -> (peerId: Api.InputPeer?, adminId: Api.InputUser?) in
            return (transaction.getPeer(peerId).flatMap(apiInputPeer), transaction.getPeer(adminId).flatMap(apiInputUser))
        }
        |> mapToSignal { inputPeer, adminId -> Signal<([ExportedInvitation], Int32), NoError> in
            if let inputPeer = inputPeer, let adminId = adminId {
                let offsetLink = lastResult?.link
                let offsetDate = lastResult?.date
                var flags: Int32 = 0
                if let _ = offsetLink {
                    flags |= (1 << 2)
                }
                if revoked {
                    flags |= (1 << 3)
                }
                let signal = account.network.request(Api.functions.messages.getExportedChatInvites(flags: flags, peer: inputPeer, adminId: adminId, offsetDate: offsetDate, offsetLink: offsetLink, limit: lastResult == nil ? 50 : 100))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.ExportedChatInvites?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([ExportedInvitation], Int32), NoError> in
                    return account.postbox.transaction { transaction -> ([ExportedInvitation], Int32) in
                        guard let result = result else {
                            return ([], 0)
                        }
                        switch result {
                        case let .exportedChatInvites(count, invites, users):
                            var peers: [Peer] = []
                            for apiUser in users {
                                peers.append(TelegramUser(user: apiUser))
                            }
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                                return updated
                            })
                            let invitations: [ExportedInvitation] = invites.compactMap { ExportedInvitation(apiExportedInvite: $0) }
                            if populateCache {
                                if let entry = CodableEntry(CachedPeerExportedInvitations(invitations: invitations, canLoadMore: count >= 50, count: count)) {
                                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerExportedInvitations, key: CachedPeerExportedInvitations.key(peerId: peerId, revoked: revoked)), entry: entry)
                                }
                            }
                            return (invitations, count)
                        }
                    }
                }
                return signal
            } else {
                return .single(([], 0))
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] invitations, updatedCount in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.populateCache {
                strongSelf.populateCache = false
                strongSelf.results.removeAll()
            }
            var existingLinks = Set(strongSelf.results.map { $0.link })
            for invitation in invitations {
                if !existingLinks.contains(invitation.link) {
                    strongSelf.results.append(invitation)
                    existingLinks.insert(invitation.link)
                }
            }
            strongSelf.isLoadingMore = false
            strongSelf.hasLoadedOnce = true
            strongSelf.canLoadMore = !invitations.isEmpty
            if strongSelf.canLoadMore {
                strongSelf.count = max(updatedCount, Int32(strongSelf.results.count))
            } else {
                strongSelf.count = Int32(strongSelf.results.count)
            }
            strongSelf.updateState()
            
            if strongSelf.forceUpdate {
                strongSelf.loadMore()
            }
        }))
        self.updateState()
    }
    
    func add(_ invite: ExportedInvitation) {
        var results = self.results
        results.removeAll(where: { $0.link == invite.link})
        results.insert(invite, at: 0)
        self.results = results
        self.updateState()
        self.updateCache()
    }
    
    func update(_ invite: ExportedInvitation) {
        var results = self.results
        if let index = self.results.firstIndex(where: { $0.link == invite.link }) {
            results[index] = invite
        }
        self.results = results
        self.updateState()
        self.updateCache()
    }
    
    func remove(_ invite: ExportedInvitation) {
        var results = self.results
        results.removeAll(where: { $0.link == invite.link})
        self.results = results
        self.updateState()
        self.updateCache()
    }
    
    func clear() {
        self.results = []
        self.count = 0
        self.updateState()
        self.updateCache()
    }
    
    private func updateCache() {
        guard self.isMainList && self.hasLoadedOnce && !self.isLoadingMore else {
            return
        }
        
        let peerId = self.peerId
        let revoked = self.revoked
        let invitations = Array(self.results.prefix(50))
        let canLoadMore = self.canLoadMore
        let count = self.count
        self.updateDisposable.set(self.account.postbox.transaction({ transaction in
            if let entry = CodableEntry(CachedPeerExportedInvitations(invitations: invitations, canLoadMore: canLoadMore, count: count)) {
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerExportedInvitations, key: CachedPeerExportedInvitations.key(peerId: peerId, revoked: revoked)), entry: entry)
            }
        }).start())
    }
    
    private func updateState() {
        self.state.set(.single(PeerExportedInvitationsState(invitations: self.results, isLoadingMore: self.isLoadingMore, hasLoadedOnce: self.hasLoadedOnce, canLoadMore: self.canLoadMore, count: self.count)))
    }
}

public final class PeerExportedInvitationsContext {
    private let queue: Queue = Queue()
    private let impl: QueueLocalObject<PeerExportedInvitationsContextImpl>
    
    public var state: Signal<PeerExportedInvitationsState, NoError> {
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
    
    init(account: Account, peerId: PeerId, adminId: PeerId?, revoked: Bool, forceUpdate: Bool) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return PeerExportedInvitationsContextImpl(queue: queue, account: account, peerId: peerId, adminId: adminId, revoked: revoked, forceUpdate: forceUpdate)
        })
    }
    
    public func reload() {
        self.impl.with { impl in
            impl.reload()
        }
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    public func add(_ invite: ExportedInvitation) {
        self.impl.with { impl in
            impl.add(invite)
        }
    }
    
    public func update(_ invite: ExportedInvitation) {
        self.impl.with { impl in
            impl.update(invite)
        }
    }
    
    public func remove(_ invite: ExportedInvitation) {
        self.impl.with { impl in
            impl.remove(invite)
        }
    }
    
    public func clear() {
        self.impl.with { impl in
            impl.clear()
        }
    }
}

public struct PeerInvitationImportersState: Equatable {
    public struct Importer: Equatable {
        public var peer: RenderedPeer
        public var date: Int32
        public var about: String?
        public var approvedBy: PeerId?
    }
    public var importers: [Importer]
    public var isLoadingMore: Bool
    public var hasLoadedOnce: Bool
    public var canLoadMore: Bool
    public var count: Int32
    
    public var waitingCount: Int {
        return Int(count)
    }
    
    public static var Empty = PeerInvitationImportersState(importers: [], isLoadingMore: false, hasLoadedOnce: true, canLoadMore: false, count: 0)
    
    public static var Loading = PeerInvitationImportersState(importers: [], isLoadingMore: false, hasLoadedOnce: false, canLoadMore: false, count: 0)
}

final class CachedPeerInvitationImporters: Codable {
    private struct DictionaryPair: Codable, Hashable {
        var key: Int64
        var value: String
        
        init(_ key: Int64, value: String) {
            self.key = key
            self.value = value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            self.key = try container.decode(Int64.self, forKey: "k")
            self.value = try container.decode(String.self, forKey: "v")
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(self.key, forKey: "k")
            try container.encode(self.value, forKey: "v")
        }
    }
    
    let peerIds: [PeerId]
    let dates: [PeerId: Int32]
    let abouts: [PeerId: String]
    let count: Int32
    
    static func key(peerId: PeerId, link: String, requested: Bool) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: Int32(HashFunctions.murMurHash32(link + (requested ? "_requested" : ""))))
        return key
    }
    
    init(importers: [PeerInvitationImportersState.Importer], count: Int32) {
        self.peerIds = importers.map { $0.peer.peerId }
        self.dates = importers.reduce(into: [PeerId: Int32]()) {
            $0[$1.peer.peerId] = $1.date
        }
        self.abouts = importers.reduce(into: [PeerId: String]()) {
            if let about = $1.about {
                $0[$1.peer.peerId] = about
            }
        }
        self.count = count
    }
    
    init(peerIds: [PeerId], dates: [PeerId: Int32], abouts: [PeerId: String], count: Int32) {
        self.peerIds = peerIds
        self.dates = dates
        self.abouts = abouts
        self.count = count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerIds = (try container.decode([Int64].self, forKey: "peerIds")).map(PeerId.init)
        
        var dates: [PeerId: Int32] = [:]
        let datesArray = try container.decode([Int64].self, forKey: "dates")
        for index in stride(from: 0, to: datesArray.endIndex, by: 2) {
            let userId = datesArray[index]
            let date = datesArray[index + 1]
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            dates[peerId] = Int32(clamping: date)
        }
        self.dates = dates
        
        var abouts: [PeerId: String] = [:]
        let aboutsArray = try container.decodeIfPresent([DictionaryPair].self, forKey: "abouts")
        if let aboutsArray = aboutsArray {
            for aboutPair in aboutsArray {
                let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(aboutPair.key))
                abouts[peerId] = aboutPair.value
            }
        }
        self.abouts = abouts
        
        self.count = try container.decode(Int32.self, forKey: "count")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerIds.map { $0.toInt64() }, forKey: "peerIds")
        
        var dates: [Int64] = []
        for (peerId, date) in self.dates {
            dates.append(peerId.id._internalGetInt64Value())
            dates.append(Int64(date))
        }
        try container.encode(dates, forKey: "dates")
        
        var abouts: [DictionaryPair] = []
        for (peerId, about) in self.abouts {
            abouts.append(DictionaryPair(peerId.id._internalGetInt64Value(), value: about))
        }
        try container.encode(abouts, forKey: "abouts")
        
        try container.encode(self.count, forKey: "count")
    }
}

private final class PeerInvitationImportersContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    private let link: String?
    private let requested: Bool
    private let query: String?
    private let disposable = MetaDisposable()
    private let updateDisposables = DisposableSet()
    private let actionDisposables = DisposableSet()
    private var isLoadingMore: Bool = false
    private var hasLoadedOnce: Bool = false
    private var canLoadMore: Bool = true
    private var loadedFromCache = false
    private var results: [PeerInvitationImportersState.Importer] = []
    private var count: Int32
    private var populateCache: Bool = true
    
    let state = Promise<PeerInvitationImportersState>()
    
    init(queue: Queue, account: Account, peerId: PeerId, subject: PeerInvitationImportersContext.Subject) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
        
        var invite: ExportedInvitation?
        var requested = false
        var query: String?
        switch subject {
            case let .invite(subjectInvite, subjectRequested):
                invite = subjectInvite
                requested = subjectRequested
            case let .requests(maybeQuery):
                query = maybeQuery
        }
        
        var link: String?
        var count: Int32 = 0
        if let invite = invite, case let .link(inviteLink, _, _, _, _, _, _, _, _, _, inviteCount, _) = invite {
            link = inviteLink
            if let inviteCount = inviteCount {
                count = inviteCount
            }
        }
        self.link = link
        self.count = count
        
        self.requested = requested
        self.query = query
        
        self.isLoadingMore = true
        self.disposable.set((account.postbox.transaction { transaction -> (peers: [PeerInvitationImportersState.Importer], count: Int32, canLoadMore: Bool)? in
            guard query == nil else {
                return nil
            }
            let cachedResult = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerInvitationImporters, key: CachedPeerInvitationImporters.key(peerId: peerId, link: link ?? "requests", requested: requested)))?.get(CachedPeerInvitationImporters.self)
            if let cachedResult = cachedResult, (Int(cachedResult.count) == count || invite == nil) {
                var result: [PeerInvitationImportersState.Importer] = []
                for peerId in cachedResult.peerIds {
                    if let peer = transaction.getPeer(peerId), let date = cachedResult.dates[peerId] {
                        result.append(PeerInvitationImportersState.Importer(peer: RenderedPeer(peer: peer), date: date, about: cachedResult.abouts[peerId]))
                    } else {
                        return nil
                    }
                }
                return (result, cachedResult.count, Int(cachedResult.count) > result.count || invite == nil)
            } else {
                return nil
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] cachedPeersCountAndCanLoadMore in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isLoadingMore = false
            if let (cachedPeers, cachedCount, canLoadMore) = cachedPeersCountAndCanLoadMore {
                strongSelf.results = cachedPeers
                strongSelf.count = cachedCount
                strongSelf.hasLoadedOnce = true
                strongSelf.canLoadMore = canLoadMore
                strongSelf.loadedFromCache = true
            }
            strongSelf.loadMore()
        }))
                
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
        self.updateDisposables.dispose()
        self.actionDisposables.dispose()
    }
    
    func reload() {
        self.loadedFromCache = true
        self.populateCache = true
        self.loadMore()
    }
    
    func loadMore() {
        if self.isLoadingMore {
            return
        }
        self.isLoadingMore = true
        let account = self.account
        let peerId = self.peerId
        let link = self.link
        let populateCache = self.populateCache
        let query = self.query
        
        var lastResult = self.results.last
        if self.loadedFromCache {
            self.loadedFromCache = false
            lastResult = nil
        }
        
        self.disposable.set((self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<([PeerInvitationImportersState.Importer], Int32), NoError> in
            if let inputPeer = inputPeer {
                let offsetUser = lastResult?.peer.peer.flatMap { apiInputUser($0) } ?? .inputUserEmpty
                let offsetDate = lastResult?.date ?? 0
                
                var flags: Int32 = 0
                if let _ = link {
                    if self.requested {
                        flags |= (1 << 0)
                    }
                    flags |= (1 << 1)
                } else {
                    flags |= (1 << 0)
                }
                
                if let _ = query {
                    flags |= (1 << 2)
                }
                
                let limit: Int32
                if self.requested {
                    limit = 50
                } else {
                    limit = lastResult == nil ? 10 : 50
                }
                                
                let signal = account.network.request(Api.functions.messages.getChatInviteImporters(flags: flags, peer: inputPeer, link: link, q: query, offsetDate: offsetDate, offsetUser: offsetUser, limit: limit))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.ChatInviteImporters?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([PeerInvitationImportersState.Importer], Int32), NoError> in
                    return account.postbox.transaction { transaction -> ([PeerInvitationImportersState.Importer], Int32) in
                        guard let result = result else {
                            return ([], 0)
                        }
                        switch result {
                        case let .chatInviteImporters(count, importers, users):
                            var peers: [Peer] = []
                            for apiUser in users {
                                peers.append(TelegramUser(user: apiUser))
                            }
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                                return updated
                            })
                            var resultImporters: [PeerInvitationImportersState.Importer] = []
                            for importer in importers {
                                let peerId: PeerId
                                let date: Int32
                                let about: String?
                                let approvedBy: PeerId?
                                switch importer {
                                    case let .chatInviteImporter(_, userId, dateValue, aboutValue, approvedByValue):
                                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                        date = dateValue
                                        about = aboutValue
                                        approvedBy = approvedByValue.flatMap { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) }
                                }
                                if let peer = transaction.getPeer(peerId) {
                                    resultImporters.append(PeerInvitationImportersState.Importer(peer: RenderedPeer(peer: peer), date: date, about: about, approvedBy: approvedBy))
                                }
                            }
                            if populateCache && query == nil {
                                if let entry = CodableEntry(CachedPeerInvitationImporters(importers: resultImporters, count: count)) {
                                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerInvitationImporters, key: CachedPeerInvitationImporters.key(peerId: peerId, link: link ?? "requests", requested: self.requested)), entry: entry)
                                }
                            }
                            return (resultImporters, count)
                        }
                    }
                }
                return signal
            } else {
                return .single(([], 0))
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] importers, updatedCount in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.populateCache {
                strongSelf.populateCache = false
                strongSelf.results.removeAll()
            }
            var existingIds = Set(strongSelf.results.map { $0.peer.peerId })
            for importer in importers {
                if !existingIds.contains(importer.peer.peerId) {
                    strongSelf.results.append(importer)
                    existingIds.insert(importer.peer.peerId)
                }
            }
            strongSelf.isLoadingMore = false
            strongSelf.hasLoadedOnce = true
            strongSelf.canLoadMore = !importers.isEmpty
            if strongSelf.canLoadMore {
                strongSelf.count = max(updatedCount, Int32(strongSelf.results.count))
            } else {
                strongSelf.count = Int32(strongSelf.results.count)
            }
            strongSelf.updateState()
        }))
        self.updateState()
    }
    
    func update(_ peerId: EnginePeer.Id, action: PeerInvitationImportersContext.UpdateAction) {
        self.actionDisposables.add(_internal_updateInvitationRequest(account: self.account, peerId: self.peerId, userId: peerId, approve: action == .approve).start())
        
        var results = self.results
        results.removeAll(where: { $0.peer.peerId == peerId })
        self.results = results
        self.count = max(0, self.count - 1)
        self.updateState()
        self.updateCache()
        
        if case .approve = action {
            self.updateDisposables.add(self.account.postbox.transaction({ transaction in
                let peer = transaction.getPeer(self.peerId)
                if let peer = peer as? TelegramGroup {
                    updatePeers(transaction: transaction, peers: [peer], update: { current, _ in
                        var updated = current
                        if let current = current as? TelegramGroup {
                            updated = current.updateParticipantCount(current.participantCount + 1)
                        }
                        return updated
                    })
                } else if let _ = peer as? TelegramChannel {
                    transaction.updatePeerCachedData(peerIds: Set([self.peerId]), update: { _, current in
                        var updated = current
                        if let current = current as? CachedChannelData, let currentMemberCount = current.participantsSummary.memberCount {
                            let updatedParticipantsSummary = current.participantsSummary.withUpdatedMemberCount(currentMemberCount + 1)
                            updated = current.withUpdatedParticipantsSummary(updatedParticipantsSummary)
                        }
                        return updated
                    })
                }
            }).start())
        }
    }
    
    func updateAll(action: PeerInvitationImportersContext.UpdateAction) {
        self.actionDisposables.add(_internal_updateAllInvitationRequests(account: self.account, peerId: self.peerId, link: nil, approve: action == .approve).start())
        
        self.results = []
        self.count = 0
        
        self.updateState()
        self.updateCache()
    }
    
    private func updateCache() {
        guard self.hasLoadedOnce && !self.isLoadingMore && self.query == nil else {
            return
        }
        
        let peerId = self.peerId
        let resultImporters = Array(self.results.prefix(50))
        let count = self.count
        let link = self.link
        self.updateDisposables.add(self.account.postbox.transaction({ transaction in
            if let entry = CodableEntry(CachedPeerInvitationImporters(importers: resultImporters, count: count)) {
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerInvitationImporters, key: CachedPeerInvitationImporters.key(peerId: peerId, link: link ?? "requests", requested: self.requested)), entry: entry)
            }
        }).start())
    }
    
    private func updateState() {
        self.state.set(.single(PeerInvitationImportersState(importers: self.results, isLoadingMore: self.isLoadingMore, hasLoadedOnce: self.hasLoadedOnce, canLoadMore: self.canLoadMore, count: self.count)))
    }
}

public final class PeerInvitationImportersContext {
    public enum Subject {
        case invite(invite: ExportedInvitation, requested: Bool)
        case requests(query: String?)
    }
    
    public enum UpdateAction {
        case approve
        case deny
    }
    
    private let queue: Queue = Queue()
    private let impl: QueueLocalObject<PeerInvitationImportersContextImpl>
    
    public var state: Signal<PeerInvitationImportersState, NoError> {
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
    
    init(account: Account, peerId: PeerId, subject: Subject) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return PeerInvitationImportersContextImpl(queue: queue, account: account, peerId: peerId, subject: subject)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    public func reload() {
        self.impl.with { impl in
            impl.reload()
        }
    }
    
    public func update(_ peerId: EnginePeer.Id, action: UpdateAction) {
        self.impl.with { impl in
            impl.update(peerId, action: action)
        }
    }
    
    public func updateAll(action: UpdateAction) {
        self.impl.with { impl in
            impl.updateAll(action: action)
        }
    }
}

public struct ExportedInvitationCreator : Equatable {
    public let peer: RenderedPeer
    public let count: Int32
    public let revokedCount: Int32
}

func _internal_peerExportedInvitationsCreators(account: Account, peerId: PeerId) -> Signal<[ExportedInvitationCreator], NoError> {
    return account.postbox.transaction { transaction -> Signal<[ExportedInvitationCreator], NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var isCreator = false
            if let peer = peer as? TelegramGroup, case .creator = peer.role {
                isCreator = true
            } else if let peer = peer as? TelegramChannel, peer.flags.contains(.isCreator) {
                isCreator = true
            }
            if !isCreator {
                return .single([])
            } else {
                return account.network.request(Api.functions.messages.getAdminsWithInvites(peer: inputPeer))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.ChatAdminsWithInvites?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<[ExportedInvitationCreator], NoError> in
                    return account.postbox.transaction { transaction -> [ExportedInvitationCreator] in
                        if let result = result, case let .chatAdminsWithInvites(admins, users) = result {
                            var creators: [ExportedInvitationCreator] = []
                            var peers: [Peer] = []
                            var peersMap: [PeerId: Peer] = [:]
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                                peersMap[telegramUser.id] = telegramUser
                            }
                            
                            for admin in admins {
                                switch admin {
                                case let .chatAdminWithInvites(adminId, invitesCount, revokedInvitesCount):
                                    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(adminId))
                                    if let peer = peersMap[peerId], peerId != account.peerId {
                                        creators.append(ExportedInvitationCreator(peer: RenderedPeer(peer: peer), count: invitesCount, revokedCount: revokedInvitesCount))
                                    }
                                }
                            }
                            
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                return updated
                            })
                            
                            return creators
                        } else {
                            return []
                        }
                    }
                }
            }
        } else {
            return .single([])
        }
    } |> switchToLatest
}

