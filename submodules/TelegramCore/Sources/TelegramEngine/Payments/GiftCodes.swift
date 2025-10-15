import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public struct PremiumGiftCodeInfo: Equatable {
    public let slug: String
    public let fromPeerId: EnginePeer.Id?
    public let messageId: EngineMessage.Id?
    public let toPeerId: EnginePeer.Id?
    public let date: Int32
    public let months: Int32
    public let usedDate: Int32?
    public let isGiveaway: Bool
}

public struct PremiumGiftCodeOption: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case users
        case months
        case storeProductId
        case storeQuantity
        case currency
        case amount
    }
    
    public let users: Int32
    public let months: Int32
    public let storeProductId: String?
    public let storeQuantity: Int32
    public let currency: String
    public let amount: Int64
    
    public init(users: Int32, months: Int32, storeProductId: String?, storeQuantity: Int32, currency: String, amount: Int64) {
        self.users = users
        self.months = months
        self.storeProductId = storeProductId
        self.storeQuantity = storeQuantity
        self.currency = currency
        self.amount = amount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.users = try container.decode(Int32.self, forKey: .users)
        self.months = try container.decode(Int32.self, forKey: .months)
        self.storeProductId = try container.decodeIfPresent(String.self, forKey: .storeProductId)
        self.storeQuantity = try container.decodeIfPresent(Int32.self, forKey: .storeQuantity) ?? 1
        self.currency = try container.decode(String.self, forKey: .currency)
        self.amount = try container.decode(Int64.self, forKey: .amount)

    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.users, forKey: .users)
        try container.encode(self.months, forKey: .months)
        try container.encodeIfPresent(self.storeProductId, forKey: .storeProductId)
        try container.encode(self.storeQuantity, forKey: .storeQuantity)
        try container.encode(self.currency, forKey: .currency)
        try container.encode(self.amount, forKey: .amount)
    }
}

public enum PremiumGiveawayInfo: Equatable {
    public enum OngoingStatus: Equatable {
        public enum DisallowReason: Equatable {
            case joinedTooEarly(Int32)
            case channelAdmin(EnginePeer.Id)
            case disallowedCountry(String)
        }
        
        case notQualified
        case notAllowed(DisallowReason)
        case participating
        case almostOver
    }
    
    public enum ResultStatus: Equatable {
        case notWon
        case wonPremium(slug: String)
        case wonStars(stars: Int64)
        case refunded
    }
    
    case ongoing(startDate: Int32, status: OngoingStatus)
    case finished(status: ResultStatus, startDate: Int32, finishDate: Int32, winnersCount: Int32, activatedCount: Int32?)
}

public struct PrepaidGiveaway: Equatable {
    public enum Prize: Equatable {
        case premium(months: Int32)
        case stars(stars: Int64, boosts: Int32)
    }
    
    public let id: Int64
    public let prize: Prize
    public let quantity: Int32
    public let date: Int32
}

func _internal_getPremiumGiveawayInfo(account: Account, peerId: EnginePeer.Id, messageId: EngineMessage.Id) -> Signal<PremiumGiveawayInfo?, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> mapToSignal { peer in
        guard let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        return account.network.request(Api.functions.payments.getGiveawayInfo(peer: inputPeer, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.payments.GiveawayInfo?, NoError> in
            return .single(nil)
        }
        |> map { result -> PremiumGiveawayInfo? in
            if let result = result {
                switch result {
                case let .giveawayInfo(flags, startDate, joinedTooEarlyDate, adminDisallowedChatId, disallowedCountry):
                    if (flags & (1 << 3)) != 0 {
                        return .ongoing(startDate: startDate, status: .almostOver)
                    } else if (flags & (1 << 0)) != 0 {
                        return .ongoing(startDate: startDate, status: .participating)
                    } else if let disallowedCountry = disallowedCountry {
                        return .ongoing(startDate: startDate, status: .notAllowed(.disallowedCountry(disallowedCountry)))
                    } else if let joinedTooEarlyDate = joinedTooEarlyDate {
                        return .ongoing(startDate: startDate, status: .notAllowed(.joinedTooEarly(joinedTooEarlyDate)))
                    } else if let adminDisallowedChatId = adminDisallowedChatId {
                        return .ongoing(startDate: startDate, status: .notAllowed(.channelAdmin(EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(adminDisallowedChatId)))))
                    } else {
                        return .ongoing(startDate: startDate, status: .notQualified)
                    }
                case let .giveawayInfoResults(flags, startDate, giftCodeSlug, stars, finishDate, winnersCount, activatedCount):
                    let status: PremiumGiveawayInfo.ResultStatus
                    if (flags & (1 << 1)) != 0 {
                        status = .refunded
                    } else if let stars {
                        status = .wonStars(stars: stars)
                    } else if let giftCodeSlug = giftCodeSlug {
                        status = .wonPremium(slug: giftCodeSlug)
                    } else {
                        status = .notWon
                    }
                    return .finished(status: status, startDate: startDate, finishDate: finishDate, winnersCount: winnersCount, activatedCount: activatedCount)
                }
            } else {
                return nil
            }
        }
    }
}

public final class CachedPremiumGiftCodeOptions: Codable {
    public let options: [PremiumGiftCodeOption]
    
    public init(options: [PremiumGiftCodeOption]) {
        self.options = options
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.options = try container.decode([PremiumGiftCodeOption].self, forKey: "t")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.options, forKey: "t")
    }
}

func _internal_premiumGiftCodeOptions(account: Account, peerId: EnginePeer.Id?, onlyCached: Bool = false) -> Signal<[PremiumGiftCodeOption], NoError> {
    if let peerId {
        if peerId.namespace == Namespaces.Peer.SecretChat {
            return .single([])
        }
    }
    
    let cached = account.postbox.transaction { transaction -> Signal<[PremiumGiftCodeOption], NoError> in
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPremiumGiftCodeOptions, key: ValueBoxKey(length: 0)))?.get(CachedPremiumGiftCodeOptions.self) {
            return .single(entry.options)
        }
        return .single([])
    } |> switchToLatest
    
    let remote = account.postbox.transaction { transaction -> Peer? in
        if let peerId = peerId {
            return transaction.getPeer(peerId)
        }
        return nil
    }
    |> mapToSignal { peer in
        let inputPeer = peer.flatMap(apiInputPeer)
        var flags: Int32 = 0
        if let _ = inputPeer {
            flags |= 1 << 0
        }
        return account.network.request(Api.functions.payments.getPremiumGiftCodeOptions(flags: flags, boostPeer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<[Api.PremiumGiftCodeOption]?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { results -> Signal<[PremiumGiftCodeOption], NoError> in
            let options = results?.map { PremiumGiftCodeOption(apiGiftCodeOption: $0) } ?? []
            return account.postbox.transaction { transaction -> [PremiumGiftCodeOption] in
                if peerId == nil {
                    if let entry = CodableEntry(CachedPremiumGiftCodeOptions(options: options)) {
                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPremiumGiftCodeOptions, key: ValueBoxKey(length: 0)), entry: entry)
                    }
                }
                return options
            }
        }
    }
    if peerId == nil {
        return cached
        |> mapToSignal { cached in
            if onlyCached && !cached.isEmpty {
                return .single(cached)
            } else {
                return .single(cached)
                |> then(remote)
            }
        }
    } else {
        return remote
    }
}


func _internal_premiumGiftCodeOptions(account: Account, peerId: EnginePeer.Id?) -> Signal<[PremiumGiftCodeOption], NoError> {
    if let peerId {
        if peerId.namespace == Namespaces.Peer.SecretChat {
            return .single([])
        }
    }
    
    var flags: Int32 = 0
    if let _ = peerId {
        flags |= 1 << 0
    }
    return account.postbox.transaction { transaction -> Peer? in
        if let peerId = peerId {
            return transaction.getPeer(peerId)
        }
        return nil
    }
    |> mapToSignal { peer in
        let inputPeer = peer.flatMap(apiInputPeer)
        return account.network.request(Api.functions.payments.getPremiumGiftCodeOptions(flags: flags, boostPeer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<[Api.PremiumGiftCodeOption]?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { results -> Signal<[PremiumGiftCodeOption], NoError> in
            if let results = results {
                return .single(results.map { PremiumGiftCodeOption(apiGiftCodeOption: $0) })
            } else {
                return .single([])
            }
        }
    }
}

func _internal_checkPremiumGiftCode(account: Account, slug: String) -> Signal<PremiumGiftCodeInfo?, NoError> {
    return account.network.request(Api.functions.payments.checkGiftCode(slug: slug))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.payments.CheckedGiftCode?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<PremiumGiftCodeInfo?, NoError> in
        if let result = result {
            switch result {
            case let .checkedGiftCode(_, _, _, _, _, _, _, chats, users):
                return account.postbox.transaction { transaction in
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                    return PremiumGiftCodeInfo(apiCheckedGiftCode: result, slug: slug)
                }
            }
        } else {
            return .single(nil)
        }
    }
}

public enum ApplyPremiumGiftCodeError {
    case generic
    case waitForExpiration(Int32)
}

func _internal_applyPremiumGiftCode(account: Account, slug: String) -> Signal<Never, ApplyPremiumGiftCodeError> {
    return account.network.request(Api.functions.payments.applyGiftCode(slug: slug))
    |> mapError { error -> ApplyPremiumGiftCodeError in
        if error.errorDescription.hasPrefix("PREMIUM_SUB_ACTIVE_UNTIL_") {
            if let range = error.errorDescription.range(of: "_", options: .backwards) {
                if let value = Int32(error.errorDescription[range.upperBound...]) {
                    return .waitForExpiration(value)
                }
            }
        }
        return .generic
    }
    |> mapToSignal { updates -> Signal<Never, ApplyPremiumGiftCodeError> in
        account.stateManager.addUpdates(updates)
        return .complete()
    }
}

public enum LaunchPrepaidGiveawayError {
    case generic
}
public enum LaunchGiveawayPurpose {
    case premium
    case stars(stars: Int64, users: Int32)
}

func _internal_launchPrepaidGiveaway(account: Account, peerId: EnginePeer.Id, purpose: LaunchGiveawayPurpose, id: Int64, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32) -> Signal<Never, LaunchPrepaidGiveawayError> {
    return account.postbox.transaction { transaction -> Signal<Never, LaunchPrepaidGiveawayError> in
        var flags: Int32 = 0
        if onlyNewSubscribers {
            flags |= (1 << 0)
        }
        if showWinners {
            flags |= (1 << 3)
        }
        var inputPeer: Api.InputPeer?
        if let peer = transaction.getPeer(peerId), let apiPeer = apiInputPeer(peer) {
            inputPeer = apiPeer
        }
        var additionalPeers: [Api.InputPeer] = []
        if !additionalPeerIds.isEmpty {
            flags |= (1 << 1)
            for peerId in additionalPeerIds {
                if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                    additionalPeers.append(inputPeer)
                }
            }
        }
        if !countries.isEmpty {
            flags |= (1 << 2)
        }
        if let _ = prizeDescription {
            flags |= (1 << 4)
        }
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        
        let inputPurpose: Api.InputStorePaymentPurpose
        switch purpose {
        case let .stars(stars, users):
            inputPurpose = .inputStorePaymentStarsGiveaway(flags: flags, stars: stars, boostPeer: inputPeer, additionalPeers: additionalPeers, countriesIso2: countries, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, currency: "", amount: 0, users: users)
        case .premium:
            inputPurpose = .inputStorePaymentPremiumGiveaway(flags: flags, boostPeer: inputPeer, additionalPeers: additionalPeers, countriesIso2: countries, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, currency: "", amount: 0)
        }
        
        return account.network.request(Api.functions.payments.launchPrepaidGiveaway(peer: inputPeer, giveawayId: id, purpose: inputPurpose))
        |> mapError { _ -> LaunchPrepaidGiveawayError in
            return .generic
        }
        |> mapToSignal { updates -> Signal<Never, LaunchPrepaidGiveawayError> in
            account.stateManager.addUpdates(updates)
            return .complete()
        }
    }
    |> castError(LaunchPrepaidGiveawayError.self)
    |> switchToLatest
}

extension PremiumGiftCodeOption {
    init(apiGiftCodeOption: Api.PremiumGiftCodeOption) {
        switch apiGiftCodeOption {
        case let .premiumGiftCodeOption(_, users, months, storeProduct, storeQuantity, curreny, amount):
            self.init(users: users, months: months, storeProductId: storeProduct, storeQuantity: storeQuantity ?? 1, currency: curreny, amount: amount)
        }
    }
}

extension PremiumGiftCodeInfo {
    init(apiCheckedGiftCode: Api.payments.CheckedGiftCode, slug: String) {
        switch apiCheckedGiftCode {
        case let .checkedGiftCode(flags, fromId, giveawayMsgId, toId, date, months, usedDate, _, _):
            self.slug = slug
            self.fromPeerId = fromId?.peerId
            if let fromId = fromId, let giveawayMsgId = giveawayMsgId {
                self.messageId = EngineMessage.Id(peerId: fromId.peerId, namespace: Namespaces.Message.Cloud, id: giveawayMsgId)
            } else {
                self.messageId = nil
            }
            self.toPeerId = toId.flatMap { EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value($0)) }
            self.date = date
            self.months = months
            self.usedDate = usedDate
            self.isGiveaway = (flags & (1 << 2)) != 0
        }
    }
}

public extension PremiumGiftCodeInfo {
    var isUsed: Bool {
        return self.usedDate != nil
    }
}

extension PrepaidGiveaway {
    init(apiPrepaidGiveaway: Api.PrepaidGiveaway) {
        switch apiPrepaidGiveaway {
        case let .prepaidGiveaway(id, months, quantity, date):
            self.id = id
            self.prize = .premium(months: months)
            self.quantity = quantity
            self.date = date
        case let .prepaidStarsGiveaway(id, stars, quantity, boosts, date):
            self.id = id
            self.prize = .stars(stars: stars, boosts: boosts)
            self.quantity = quantity
            self.date = date
        }
    }
}
