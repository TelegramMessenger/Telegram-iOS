import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public final class StarGiftsList: Codable, Equatable {
    public let items: [StarGift]
    public let hashValue: Int32

    public init(items: [StarGift], hashValue: Int32) {
        self.items = items
        self.hashValue = hashValue
    }

    public static func ==(lhs: StarGiftsList, rhs: StarGiftsList) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.hashValue != rhs.hashValue {
            return false
        }
        return true
    }
}

public struct StarGift: Equatable, Codable, PostboxCoding {
    enum CodingKeys: String, CodingKey {
        case id
        case file
        case price
        case convertStars
        case availability
    }
    
    public struct Availability: Equatable, Codable, PostboxCoding {
        enum CodingKeys: String, CodingKey {
            case remains
            case total
        }

        public let remains: Int32
        public let total: Int32
        
        init(remains: Int32, total: Int32) {
            self.remains = remains
            self.total = total
        }
        
        public init(decoder: PostboxDecoder) {
            self.remains = decoder.decodeInt32ForKey(CodingKeys.remains.rawValue, orElse: 0)
            self.total = decoder.decodeInt32ForKey(CodingKeys.total.rawValue, orElse: 0)
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(self.remains, forKey: CodingKeys.remains.rawValue)
            encoder.encodeInt32(self.total, forKey: CodingKeys.total.rawValue)
        }
    }
    
    public enum DecodingError: Error {
        case generic
    }
    
    public let id: Int64
    public let file: TelegramMediaFile
    public let price: Int64
    public let convertStars: Int64
    public let availability: Availability?
    
    public init(id: Int64, file: TelegramMediaFile, price: Int64, convertStars: Int64, availability: Availability?) {
        self.id = id
        self.file = file
        self.price = price
        self.convertStars = convertStars
        self.availability = availability
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int64.self, forKey: .id)
        
        if let fileData = try container.decodeIfPresent(Data.self, forKey: .file), let file = PostboxDecoder(buffer: MemoryBuffer(data: fileData)).decodeRootObject() as? TelegramMediaFile {
            self.file = file
        } else {
            throw DecodingError.generic
        }
        
        self.price = try container.decode(Int64.self, forKey: .price)
        self.convertStars = try container.decodeIfPresent(Int64.self, forKey: .convertStars) ?? 0
        self.availability = try container.decodeIfPresent(Availability.self, forKey: .availability)
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey(CodingKeys.id.rawValue, orElse: 0)
        self.file = decoder.decodeObjectForKey(CodingKeys.file.rawValue) as! TelegramMediaFile
        self.price = decoder.decodeInt64ForKey(CodingKeys.price.rawValue, orElse: 0)
        self.convertStars = decoder.decodeInt64ForKey(CodingKeys.convertStars.rawValue, orElse: 0)
        self.availability = decoder.decodeObjectForKey(CodingKeys.availability.rawValue, decoder: { StarGift.Availability(decoder: $0) }) as? StarGift.Availability
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
    
        let encoder = PostboxEncoder()
        encoder.encodeRootObject(self.file)
        let fileData = encoder.makeData()
        try container.encode(fileData, forKey: .file)
        
        try container.encode(self.price, forKey: .price)
        try container.encode(self.convertStars, forKey: .convertStars)
        try container.encodeIfPresent(self.availability, forKey: .availability)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: CodingKeys.id.rawValue)
        encoder.encodeObject(self.file, forKey: CodingKeys.file.rawValue)
        encoder.encodeInt64(self.price, forKey: CodingKeys.price.rawValue)
        encoder.encodeInt64(self.convertStars, forKey: CodingKeys.convertStars.rawValue)
        if let availability = self.availability {
            encoder.encodeObject(availability, forKey: CodingKeys.availability.rawValue)
        } else {
            encoder.encodeNil(forKey: CodingKeys.availability.rawValue)
        }
    }
}

extension StarGift {
    init?(apiStarGift: Api.StarGift) {
        switch apiStarGift {
        case let .starGift(_, id, sticker, stars, availabilityRemains, availabilityTotal, convertStars, _, _):
            var availability: Availability?
            if let availabilityRemains, let availabilityTotal {
                availability = Availability(remains: availabilityRemains, total: availabilityTotal)
            }
            guard let file = telegramMediaFileFromApiDocument(sticker, altDocuments: nil) else {
                return nil
            }
            self.init(id: id, file: file, price: stars, convertStars: convertStars, availability: availability)
        }
    }
}

func _internal_cachedStarGifts(postbox: Postbox) -> Signal<StarGiftsList?, NoError> {
    let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.starGifts()]))
    return postbox.combinedView(keys: [viewKey])
    |> map { views -> StarGiftsList? in
        guard let view = views.views[viewKey] as? PreferencesView else {
            return nil
        }
        guard let value = view.values[PreferencesKeys.starGifts()]?.get(StarGiftsList.self) else {
            return nil
        }
        return value
    }
}

func _internal_keepCachedStarGiftsUpdated(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let updateSignal = _internal_cachedStarGifts(postbox: postbox)
    |> take(1)
    |> mapToSignal { list -> Signal<Never, NoError> in
        return network.request(Api.functions.payments.getStarGifts(hash: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.payments.StarGifts?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result else {
                return .complete()
            }
            
            return postbox.transaction { transaction in
                switch result {
                case let .starGifts(hash, gifts):
                    let starGiftsLists = StarGiftsList(items: gifts.compactMap { StarGift(apiStarGift: $0) }, hashValue: hash)
                    transaction.setPreferencesEntry(key: PreferencesKeys.starGifts(), value: PreferencesEntry(starGiftsLists))
                case .starGiftsNotModified:
                    break
                }
            }
            |> ignoreValues
        }
    }
    
    return updateSignal
}

func managedStarGiftsUpdates(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let poll = _internal_keepCachedStarGiftsUpdated(postbox: postbox, network: network)
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func _internal_convertStarGift(account: Account, messageId: EngineMessage.Id) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<Never, NoError> in
        guard let inputUser else {
            return .complete()
        }
        return account.network.request(Api.functions.payments.convertStarGift(userId: inputUser, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result in
            if let result, case .boolTrue = result {
                return account.postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, cachedData -> CachedPeerData? in
                        if let cachedData = cachedData as? CachedUserData, let starGiftsCount = cachedData.starGiftsCount {
                            var updatedData = cachedData
                            updatedData = updatedData.withUpdatedStarGiftsCount(max(0, starGiftsCount - 1))
                            return updatedData
                        } else {
                            return cachedData
                        }
                    })
                }
            }
            return .complete()
        }
        |> ignoreValues
    }
}

func _internal_updateStarGiftAddedToProfile(account: Account, messageId: EngineMessage.Id, added: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<Never, NoError> in
        guard let inputUser else {
            return .complete()
        }
        var flags: Int32 = 0
        if !added {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.payments.saveStarGift(flags: flags, userId: inputUser, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        }
        |> ignoreValues
    }
}

private final class ProfileGiftsContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    
    private let disposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    
    private var gifts: [ProfileGiftsContext.State.StarGift] = []
    private var count: Int32?
    private var dataState: ProfileGiftsContext.State.DataState = .ready(canLoadMore: true, nextOffset: nil)
    
    private let stateValue = Promise<ProfileGiftsContext.State>()
    var state: Signal<ProfileGiftsContext.State, NoError> {
        return self.stateValue.get()
    }
    
    init(queue: Queue, account: Account, peerId: EnginePeer.Id) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
        
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
        self.actionDisposable.dispose()
    }
    
    func loadMore() {
        if case let .ready(true, nextOffset) = self.dataState {
            self.dataState = .loading
            self.pushState()
            
            let peerId = self.peerId
            let accountPeerId = self.account.peerId
            let network = self.account.network
            let postbox = self.account.postbox
            let signal: Signal<([ProfileGiftsContext.State.StarGift], Int32, String?), NoError> = self.account.postbox.transaction { transaction -> Api.InputUser? in
                return transaction.getPeer(peerId).flatMap(apiInputUser)
            }
            |> mapToSignal { inputUser -> Signal<([ProfileGiftsContext.State.StarGift], Int32, String?), NoError> in
                guard let inputUser else {
                    return .single(([], 0, nil))
                }
                return network.request(Api.functions.payments.getUserStarGifts(userId: inputUser, offset: nextOffset ?? "", limit: 32))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.payments.UserStarGifts?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([ProfileGiftsContext.State.StarGift], Int32, String?), NoError> in
                    guard let result else {
                        return .single(([], 0, nil))
                    }
                    return postbox.transaction { transaction -> ([ProfileGiftsContext.State.StarGift], Int32, String?) in
                        switch result {
                        case let .userStarGifts(_, count, apiGifts, nextOffset, users):
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [], users: users)
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                            
                            let gifts = apiGifts.compactMap { ProfileGiftsContext.State.StarGift(apiUserStarGift: $0, transaction: transaction) }
                            return (gifts, count, nextOffset)
                        }
                    }
                }
            }
            
            self.disposable.set((signal
            |> deliverOn(self.queue)).start(next: { [weak self] (gifts, count, nextOffset) in
                guard let strongSelf = self else {
                    return
                }
                for gift in gifts {
                    strongSelf.gifts.append(gift)
                }
                
                let updatedCount = max(Int32(strongSelf.gifts.count), count)
                strongSelf.count = updatedCount
                strongSelf.dataState = .ready(canLoadMore: count != 0 && updatedCount > strongSelf.gifts.count && nextOffset != nil, nextOffset: nextOffset)
                strongSelf.pushState()
            }))
        }
    }
    
    func updateStarGiftAddedToProfile(messageId: EngineMessage.Id, added: Bool) {
        self.actionDisposable.set(
            _internal_updateStarGiftAddedToProfile(account: self.account, messageId: messageId, added: added).startStrict()
        )
        if let index = self.gifts.firstIndex(where: { $0.messageId == messageId }) {
            self.gifts[index] = self.gifts[index].withSavedToProfile(added)
        }
        self.pushState()
    }
    
    func convertStarGift(messageId: EngineMessage.Id) {
        self.actionDisposable.set(
            _internal_convertStarGift(account: self.account, messageId: messageId).startStrict()
        )
        if let count = self.count {
            self.count = max(0, count - 1)
        }
        self.gifts.removeAll(where: { $0.messageId == messageId })
        self.pushState()
    }
    
    private func pushState() {
        self.stateValue.set(.single(ProfileGiftsContext.State(gifts: self.gifts, count: self.count, dataState: self.dataState)))
    }
}

public final class ProfileGiftsContext {
    public struct State: Equatable {
        public struct StarGift: Equatable {
            public let gift: TelegramCore.StarGift
            public let fromPeer: EnginePeer?
            public let date: Int32
            public let text: String?
            public let entities: [MessageTextEntity]?
            public let messageId: EngineMessage.Id?
            public let nameHidden: Bool
            public let savedToProfile: Bool
            public let convertStars: Int64?
            
            public func withSavedToProfile(_ savedToProfile: Bool) -> StarGift {
                return StarGift(
                    gift: self.gift,
                    fromPeer: self.fromPeer,
                    date: self.date,
                    text: self.text,
                    entities: self.entities,
                    messageId: self.messageId,
                    nameHidden: self.nameHidden,
                    savedToProfile: savedToProfile,
                    convertStars: self.convertStars
                )
            }
        }
        
        public enum DataState: Equatable {
            case loading
            case ready(canLoadMore: Bool, nextOffset: String?)
        }
        
        public var gifts: [ProfileGiftsContext.State.StarGift]
        public var count: Int32?
        public var dataState: ProfileGiftsContext.State.DataState
    }
    
    private let queue: Queue = .mainQueue()
    private let impl: QueueLocalObject<ProfileGiftsContextImpl>
    
    public var state: Signal<ProfileGiftsContext.State, NoError> {
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
    
    public init(account: Account, peerId: EnginePeer.Id) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ProfileGiftsContextImpl(queue: queue, account: account, peerId: peerId)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    public func updateStarGiftAddedToProfile(messageId: EngineMessage.Id, added: Bool) {
        self.impl.with { impl in
            impl.updateStarGiftAddedToProfile(messageId: messageId, added: added)
        }
    }
    
    public func convertStarGift(messageId: EngineMessage.Id) {
        self.impl.with { impl in
            impl.convertStarGift(messageId: messageId)
        }
    }
}

private extension ProfileGiftsContext.State.StarGift {
    init?(apiUserStarGift: Api.UserStarGift, transaction: Transaction) {
        switch apiUserStarGift {
        case let .userStarGift(flags, fromId, date, apiGift, message, msgId, convertStars):
            guard let gift = StarGift(apiStarGift: apiGift) else {
                return nil
            }
            self.gift = gift
            if let fromPeerId = fromId.flatMap({ EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value($0)) }) {
                self.fromPeer = transaction.getPeer(fromPeerId).flatMap(EnginePeer.init)
            } else {
                self.fromPeer = nil
            }
            self.date = date

            if let message {
                switch message {
                case let .textWithEntities(text, entities):
                    self.text = text
                    self.entities = messageTextEntitiesFromApiEntities(entities)
                }
            } else {
                self.text = nil
                self.entities = nil
            }
            if let fromPeer = self.fromPeer, let msgId {
                self.messageId = EngineMessage.Id(peerId: fromPeer.id, namespace: Namespaces.Message.Cloud, id: msgId)
            } else {
                self.messageId = nil
            }
            self.nameHidden = (flags & (1 << 0)) != 0
            self.savedToProfile = (flags & (1 << 5)) == 0
            self.convertStars = convertStars
        }
    }
}
