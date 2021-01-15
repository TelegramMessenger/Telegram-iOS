import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public func ensuredExistingPeerExportedInvitation(account: Account, peerId: PeerId, revokeExisted: Bool = false) -> Signal<ExportedInvitation?, NoError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = (1 << 2)
            if let _ = peer as? TelegramChannel {
                if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData, cachedData.exportedInvitation != nil && !revokeExisted {
                    return .single(cachedData.exportedInvitation)
                } else {
                    return account.network.request(Api.functions.messages.exportChatInvite(flags: flags, peer: inputPeer, expireDate: nil, usageLimit: nil))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<ExportedInvitation?, NoError> in
                        return account.postbox.transaction { transaction -> ExportedInvitation? in
                            if let invitation = ExportedInvitation(apiExportedInvite: result) {
                                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedChannelData {
                                        return current.withUpdatedExportedInvitation(invitation)
                                    } else {
                                        return CachedChannelData().withUpdatedExportedInvitation(invitation)
                                    }
                                })
                                return invitation
                            } else {
                                return nil
                            }
                        }
                    }
                }
            } else if let _ = peer as? TelegramGroup {
                if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedGroupData, cachedData.exportedInvitation != nil && !revokeExisted {
                    return .complete()
                } else {
                    return account.network.request(Api.functions.messages.exportChatInvite(flags: flags, peer: inputPeer, expireDate: nil, usageLimit: nil))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<ExportedInvitation?, NoError> in
                        return account.postbox.transaction { transaction -> ExportedInvitation? in
                            if let invitation = ExportedInvitation(apiExportedInvite: result) {
                                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedGroupData {
                                        return current.withUpdatedExportedInvitation(invitation)
                                    } else {
                                        return current
                                    }
                                })
                                return invitation
                            } else {
                                return nil
                            }
                        }
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

public func createPeerExportedInvitation(account: Account, peerId: PeerId, expireDate: Int32?, usageLimit: Int32?) -> Signal<ExportedInvitation?, NoError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if let _ = expireDate {
                flags |= (1 << 0)
            }
            if let _ = usageLimit {
                flags |= (1 << 1)
            }
            return account.network.request(Api.functions.messages.exportChatInvite(flags: flags, peer: inputPeer, expireDate: expireDate, usageLimit: usageLimit))
            |> retryRequest
            |> map { result -> ExportedInvitation? in
                if let invitation = ExportedInvitation(apiExportedInvite: result) {
                    return invitation
                } else {
                    return nil
                }
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public struct ExportedInvitations : Equatable {
    public let list: [ExportedInvitation]?
    public let totalCount: Int32
}

public func peerExportedInvitations(account: Account, peerId: PeerId, offsetLink: String? = nil) -> Signal<ExportedInvitations?, NoError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitations?, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if let _ = offsetLink {
                flags |= (1 << 2)
            }
            return account.network.request(Api.functions.messages.getExportedChatInvites(flags: 0, peer: inputPeer, adminId: nil, offsetLink: offsetLink, limit: 100))
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
                        
                        var invites: [ExportedInvitation] = []
                        for apiInvite in apiInvites {
                            if let invite = ExportedInvitation(apiExportedInvite: apiInvite) {
                                invites.append(invite)
                            }
                        }
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

public enum EditPeerExportedInvitationError {
    case generic
}

public func editPeerExportedInvitation(account: Account, peerId: PeerId, link: String, expireDate: Int32?, usageLimit: Int32?) -> Signal<ExportedInvitation?, EditPeerExportedInvitationError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, EditPeerExportedInvitationError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if let _ = expireDate {
                flags |= (1 << 0)
            }
            if let _ = usageLimit {
                flags |= (1 << 1)
            }
            return account.network.request(Api.functions.messages.editExportedChatInvite(flags: flags, peer: inputPeer, link: link, expireDate: expireDate, usageLimit: usageLimit))
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
                } |> mapError { _ in .generic }
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

public func revokePeerExportedInvitation(account: Account, peerId: PeerId, link: String) -> Signal<ExportedInvitation?, RevokePeerExportedInvitationError> {
    return account.postbox.transaction { transaction -> Signal<ExportedInvitation?, RevokePeerExportedInvitationError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let flags: Int32 = (1 << 2)
            return account.network.request(Api.functions.messages.editExportedChatInvite(flags: flags, peer: inputPeer, link: link, expireDate: nil, usageLimit: nil))
            |> mapError { _ in return RevokePeerExportedInvitationError.generic }
                |> mapToSignal { result -> Signal<ExportedInvitation?, RevokePeerExportedInvitationError> in
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
                    } |> mapError { _ in .generic }
                }
        } else {
            return .complete()
        }
    }
    |> castError(RevokePeerExportedInvitationError.self)
    |> switchToLatest
}

private let cachedPeerInvitationImportersCollectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 10, highWaterItemCount: 20)

public struct PeerInvitationImportersState: Equatable {
    public struct Importer: Equatable {
        public var peer: RenderedPeer
        public var date: Int32
    }
    public var importers: [Importer]
    public var isLoadingMore: Bool
    public var hasLoadedOnce: Bool
    public var canLoadMore: Bool
    public var count: Int
}

final class CachedPeerInvitationImporters: PostboxCoding {
    let peerIds: [PeerId]
    let dates: [PeerId: Int32]
    let count: Int32
    
    public static func key(peerId: PeerId, link: String) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: Int32(HashFunctions.murMurHash32(link)))
        return key
    }
    
    init(importers: [PeerInvitationImportersState.Importer], count: Int32) {
        self.peerIds = importers.map { $0.peer.peerId }
        self.dates = importers.reduce(into: [PeerId: Int32]()) {
            $0[$1.peer.peerId] = $1.date
        }
        self.count = count
    }
    
    public init(peerIds: [PeerId], dates: [PeerId: Int32], count: Int32) {
        self.peerIds = peerIds
        self.dates = dates
        self.count = count
    }
    
    public init(decoder: PostboxDecoder) {
        self.peerIds = decoder.decodeInt64ArrayForKey("peerIds").map(PeerId.init)
        
        var dates: [PeerId: Int32] = [:]
        let datesArray = decoder.decodeInt32ArrayForKey("dates")
        for index in stride(from: 0, to: datesArray.endIndex, by: 2) {
            let userId = datesArray[index]
            let date = datesArray[index + 1]
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
            dates[peerId] = date
        }
        self.dates = dates
        
        self.count = decoder.decodeInt32ForKey("count", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64Array(self.peerIds.map { $0.toInt64() }, forKey: "peerIds")
        
        var dates: [Int32] = []
        for (peerId, date) in self.dates {
            dates.append(peerId.id)
            dates.append(date)
        }
        encoder.encodeInt32Array(dates, forKey: "dates")
        
        encoder.encodeInt32(self.count, forKey: "count")
    }
}

private final class PeerInvitationImportersContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    private let link: String
    private let disposable = MetaDisposable()
    private var isLoadingMore: Bool = false
    private var hasLoadedOnce: Bool = false
    private var canLoadMore: Bool = true
    private var results: [PeerInvitationImportersState.Importer] = []
    private var count: Int
    private var populateCache: Bool = true
    
    let state = Promise<PeerInvitationImportersState>()
    
    init(queue: Queue, account: Account, peerId: PeerId, invite: ExportedInvitation) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
        self.link = invite.link
        
        let count = invite.count.flatMap { Int($0) } ?? 0
        self.count = count
        
        self.isLoadingMore = true
        self.disposable.set((account.postbox.transaction { transaction -> (peers: [PeerInvitationImportersState.Importer], canLoadMore: Bool)? in
            let cachedResult = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerInvitationImporters, key: CachedPeerInvitationImporters.key(peerId: peerId, link: invite.link))) as? CachedPeerInvitationImporters
            if let cachedResult = cachedResult, Int(cachedResult.count) == count {
                var result: [PeerInvitationImportersState.Importer] = []
                for peerId in cachedResult.peerIds {
                    if let peer = transaction.getPeer(peerId), let date = cachedResult.dates[peerId] {
                        result.append(PeerInvitationImportersState.Importer(peer: RenderedPeer(peer: peer), date: date))
                    } else {
                        return nil
                    }
                }
                return (result, Int(cachedResult.count) > result.count)
            } else {
                return nil
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] cachedPeersAndCanLoadMore in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isLoadingMore = false
            if let (cachedPeers, canLoadMore) = cachedPeersAndCanLoadMore {
                strongSelf.results = cachedPeers
                strongSelf.hasLoadedOnce = true
                strongSelf.canLoadMore = canLoadMore
            }
            strongSelf.loadMore()
        }))
                
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func loadMore() {
        if self.isLoadingMore {
            return
        }
        self.isLoadingMore = true
        let account = self.account
        let peerId = self.peerId
        let link = self.link
        let lastResult = self.results.last
        let populateCache = self.populateCache
        self.disposable.set((self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<([PeerInvitationImportersState.Importer], Int), NoError> in
            if let inputPeer = inputPeer {
                let offsetUser = lastResult?.peer.peer.flatMap { apiInputUser($0) } ?? .inputUserEmpty
                let offsetDate = lastResult?.date ?? 0
                let signal = account.network.request(Api.functions.messages.getChatInviteImporters(peer: inputPeer, link: link, offsetDate: offsetDate, offsetUser: offsetUser, limit: lastResult == nil ? 10 : 50))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.ChatInviteImporters?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([PeerInvitationImportersState.Importer], Int), NoError> in
                    return account.postbox.transaction { transaction -> ([PeerInvitationImportersState.Importer], Int) in
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
                                switch importer {
                                    case let .chatInviteImporter(userId, dateValue):
                                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                        date = dateValue
                                }
                                if let peer = transaction.getPeer(peerId) {
                                    resultImporters.append(PeerInvitationImportersState.Importer(peer: RenderedPeer(peer: peer), date: date))
                                }
                            }
                            if populateCache {
                                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerInvitationImporters, key: CachedPeerInvitationImporters.key(peerId: peerId, link: link)), entry: CachedPeerInvitationImporters(importers: resultImporters, count: count), collectionSpec: cachedPeerInvitationImportersCollectionSpec)
                            }
                            return (resultImporters, Int(count))
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
                strongSelf.count = max(updatedCount, strongSelf.results.count)
            } else {
                strongSelf.count = strongSelf.results.count
            }
            strongSelf.updateState()
        }))
        self.updateState()
    }
    
    private func updateState() {
        self.state.set(.single(PeerInvitationImportersState(importers: self.results, isLoadingMore: self.isLoadingMore, hasLoadedOnce: self.hasLoadedOnce, canLoadMore: self.canLoadMore, count: self.count)))
    }
}

public final class PeerInvitationImportersContext {
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
    
    public init(account: Account, peerId: PeerId, invite: ExportedInvitation) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return PeerInvitationImportersContextImpl(queue: queue, account: account, peerId: peerId, invite: invite)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}
