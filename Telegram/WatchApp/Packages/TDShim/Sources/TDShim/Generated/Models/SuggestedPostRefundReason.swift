//
//  SuggestedPostRefundReason.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes reason for refund of the payment for a suggested post
public indirect enum SuggestedPostRefundReason: Codable, Equatable, Hashable {

    /// The post was refunded, because it was deleted by channel administrators in less than getOption("suggested_post_lifetime_min") seconds
    case suggestedPostRefundReasonPostDeleted

    /// The post was refunded, because the payment for the post was refunded
    case suggestedPostRefundReasonPaymentRefunded

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case suggestedPostRefundReasonPostDeleted
        case suggestedPostRefundReasonPaymentRefunded
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .suggestedPostRefundReasonPostDeleted:
            self = .suggestedPostRefundReasonPostDeleted
        case .suggestedPostRefundReasonPaymentRefunded:
            self = .suggestedPostRefundReasonPaymentRefunded
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .suggestedPostRefundReasonPostDeleted:
            try container.encode(Kind.suggestedPostRefundReasonPostDeleted, forKey: .type)
        case .suggestedPostRefundReasonPaymentRefunded:
            try container.encode(Kind.suggestedPostRefundReasonPaymentRefunded, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

