//
//  GiftPurchaseOfferState.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes state of a gift purchase offer
public indirect enum GiftPurchaseOfferState: Codable, Equatable, Hashable {

    /// The offer must be accepted or rejected
    case giftPurchaseOfferStatePending

    /// The offer was accepted
    case giftPurchaseOfferStateAccepted

    /// The offer was rejected
    case giftPurchaseOfferStateRejected

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case giftPurchaseOfferStatePending
        case giftPurchaseOfferStateAccepted
        case giftPurchaseOfferStateRejected
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .giftPurchaseOfferStatePending:
            self = .giftPurchaseOfferStatePending
        case .giftPurchaseOfferStateAccepted:
            self = .giftPurchaseOfferStateAccepted
        case .giftPurchaseOfferStateRejected:
            self = .giftPurchaseOfferStateRejected
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .giftPurchaseOfferStatePending:
            try container.encode(Kind.giftPurchaseOfferStatePending, forKey: .type)
        case .giftPurchaseOfferStateAccepted:
            try container.encode(Kind.giftPurchaseOfferStateAccepted, forKey: .type)
        case .giftPurchaseOfferStateRejected:
            try container.encode(Kind.giftPurchaseOfferStateRejected, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

