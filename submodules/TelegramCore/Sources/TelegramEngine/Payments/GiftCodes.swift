import Foundation
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public struct PremiumGiftCodeInfo: Equatable {
    public let slug: String
    public let fromPeerId: EnginePeer.Id
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
    }
    
    public let users: Int32
    public let months: Int32
    public let storeProductId: String?
    
    public init(users: Int32, months: Int32, storeProductId: String?) {
        self.users = users
        self.months = months
        self.storeProductId = storeProductId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.users = try container.decode(Int32.self, forKey: .users)
        self.months = try container.decode(Int32.self, forKey: .months)
        self.storeProductId = try container.decodeIfPresent(String.self, forKey: .storeProductId)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.users, forKey: .users)
        try container.encode(self.months, forKey: .months)
        try container.encodeIfPresent(self.storeProductId, forKey: .storeProductId)
    }
}

func _internal_premiumGiftCodeOptions(account: Account, peerId: EnginePeer.Id) -> Signal<[PremiumGiftCodeOption], NoError> {
    let flags: Int32 = 1 << 0
    return account.postbox.loadedPeerWithId(peerId)
    |> mapToSignal { peer in
        guard let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
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

func _internal_applyPremiumGiftCode(account: Account, slug: String) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.payments.applyGiftCode(slug: slug))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { updates -> Signal<Never, NoError> in
        if let updates = updates {
            account.stateManager.addUpdates(updates)
        }
        
        return .complete()
    }
}

extension PremiumGiftCodeOption {
    init(apiGiftCodeOption: Api.PremiumGiftCodeOption) {
        switch apiGiftCodeOption {
        case let .premiumGiftCodeOption(_, users, months, storeProduct, _, _, _):
            self.init(users: users, months: months, storeProductId: storeProduct)
        }
    }
}

extension PremiumGiftCodeInfo {
    init(apiCheckedGiftCode: Api.payments.CheckedGiftCode, slug: String) {
        switch apiCheckedGiftCode {
        case let .checkedGiftCode(flags, fromId, _, toId, date, months, usedDate, _, _):
            self.slug = slug
            self.fromPeerId = fromId.peerId
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
