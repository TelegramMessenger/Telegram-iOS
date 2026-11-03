//
//  PollVoteRestrictionReason.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Reason of vote restriction in the poll for the current user
public indirect enum PollVoteRestrictionReason: Codable, Equatable, Hashable {

    /// The poll is closed
    case pollVoteRestrictionReasonClosed

    /// The poll isn't sent yet
    case pollVoteRestrictionReasonYetUnsent

    /// The poll is from a scheduled message
    case pollVoteRestrictionReasonScheduled

    /// The user is from a country, users from which aren't allowed to vote
    case pollVoteRestrictionReasonCountryRestricted(PollVoteRestrictionReasonCountryRestricted)

    /// The user must be a member of the chat for at least a day to vote
    case pollVoteRestrictionReasonMembershipRequired(PollVoteRestrictionReasonMembershipRequired)

    /// The poll can't be voted by the user due to some other reason
    case pollVoteRestrictionReasonOther

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case pollVoteRestrictionReasonClosed
        case pollVoteRestrictionReasonYetUnsent
        case pollVoteRestrictionReasonScheduled
        case pollVoteRestrictionReasonCountryRestricted
        case pollVoteRestrictionReasonMembershipRequired
        case pollVoteRestrictionReasonOther
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .pollVoteRestrictionReasonClosed:
            self = .pollVoteRestrictionReasonClosed
        case .pollVoteRestrictionReasonYetUnsent:
            self = .pollVoteRestrictionReasonYetUnsent
        case .pollVoteRestrictionReasonScheduled:
            self = .pollVoteRestrictionReasonScheduled
        case .pollVoteRestrictionReasonCountryRestricted:
            let value = try PollVoteRestrictionReasonCountryRestricted(from: decoder)
            self = .pollVoteRestrictionReasonCountryRestricted(value)
        case .pollVoteRestrictionReasonMembershipRequired:
            let value = try PollVoteRestrictionReasonMembershipRequired(from: decoder)
            self = .pollVoteRestrictionReasonMembershipRequired(value)
        case .pollVoteRestrictionReasonOther:
            self = .pollVoteRestrictionReasonOther
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .pollVoteRestrictionReasonClosed:
            try container.encode(Kind.pollVoteRestrictionReasonClosed, forKey: .type)
        case .pollVoteRestrictionReasonYetUnsent:
            try container.encode(Kind.pollVoteRestrictionReasonYetUnsent, forKey: .type)
        case .pollVoteRestrictionReasonScheduled:
            try container.encode(Kind.pollVoteRestrictionReasonScheduled, forKey: .type)
        case .pollVoteRestrictionReasonCountryRestricted(let value):
            try container.encode(Kind.pollVoteRestrictionReasonCountryRestricted, forKey: .type)
            try value.encode(to: encoder)
        case .pollVoteRestrictionReasonMembershipRequired(let value):
            try container.encode(Kind.pollVoteRestrictionReasonMembershipRequired, forKey: .type)
            try value.encode(to: encoder)
        case .pollVoteRestrictionReasonOther:
            try container.encode(Kind.pollVoteRestrictionReasonOther, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The user is from a country, users from which aren't allowed to vote
public struct PollVoteRestrictionReasonCountryRestricted: Codable, Equatable, Hashable {

    /// Two-letter ISO 3166-1 alpha-2 code of the current user's country
    public let countryCode: String


    public init(countryCode: String) {
        self.countryCode = countryCode
    }
}

/// The user must be a member of the chat for at least a day to vote
public struct PollVoteRestrictionReasonMembershipRequired: Codable, Equatable, Hashable {

    /// Identifier of the chat which must be joined for at least a day before the user can vote
    public let chatId: Int64


    public init(chatId: Int64) {
        self.chatId = chatId
    }
}

