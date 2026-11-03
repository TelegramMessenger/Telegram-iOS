//
//  SuggestedPostState.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes state of a suggested post
public indirect enum SuggestedPostState: Codable, Equatable, Hashable {

    /// The post must be approved or declined
    case suggestedPostStatePending

    /// The post was approved
    case suggestedPostStateApproved

    /// The post was declined
    case suggestedPostStateDeclined

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case suggestedPostStatePending
        case suggestedPostStateApproved
        case suggestedPostStateDeclined
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .suggestedPostStatePending:
            self = .suggestedPostStatePending
        case .suggestedPostStateApproved:
            self = .suggestedPostStateApproved
        case .suggestedPostStateDeclined:
            self = .suggestedPostStateDeclined
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .suggestedPostStatePending:
            try container.encode(Kind.suggestedPostStatePending, forKey: .type)
        case .suggestedPostStateApproved:
            try container.encode(Kind.suggestedPostStateApproved, forKey: .type)
        case .suggestedPostStateDeclined:
            try container.encode(Kind.suggestedPostStateDeclined, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

