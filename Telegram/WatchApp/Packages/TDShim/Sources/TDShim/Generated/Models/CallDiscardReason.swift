//
//  CallDiscardReason.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the reason why a call was discarded
public indirect enum CallDiscardReason: Codable, Equatable, Hashable {

    /// The call wasn't discarded, or the reason is unknown
    case callDiscardReasonEmpty

    /// The call was ended before the conversation started. It was canceled by the caller or missed by the other party
    case callDiscardReasonMissed

    /// The call was ended before the conversation started. It was declined by the other party
    case callDiscardReasonDeclined

    /// The call was ended during the conversation because the users were disconnected
    case callDiscardReasonDisconnected

    /// The call was ended because one of the parties hung up
    case callDiscardReasonHungUp

    /// The call was ended because it has been upgraded to a group call
    case callDiscardReasonUpgradeToGroupCall(CallDiscardReasonUpgradeToGroupCall)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case callDiscardReasonEmpty
        case callDiscardReasonMissed
        case callDiscardReasonDeclined
        case callDiscardReasonDisconnected
        case callDiscardReasonHungUp
        case callDiscardReasonUpgradeToGroupCall
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .callDiscardReasonEmpty:
            self = .callDiscardReasonEmpty
        case .callDiscardReasonMissed:
            self = .callDiscardReasonMissed
        case .callDiscardReasonDeclined:
            self = .callDiscardReasonDeclined
        case .callDiscardReasonDisconnected:
            self = .callDiscardReasonDisconnected
        case .callDiscardReasonHungUp:
            self = .callDiscardReasonHungUp
        case .callDiscardReasonUpgradeToGroupCall:
            let value = try CallDiscardReasonUpgradeToGroupCall(from: decoder)
            self = .callDiscardReasonUpgradeToGroupCall(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .callDiscardReasonEmpty:
            try container.encode(Kind.callDiscardReasonEmpty, forKey: .type)
        case .callDiscardReasonMissed:
            try container.encode(Kind.callDiscardReasonMissed, forKey: .type)
        case .callDiscardReasonDeclined:
            try container.encode(Kind.callDiscardReasonDeclined, forKey: .type)
        case .callDiscardReasonDisconnected:
            try container.encode(Kind.callDiscardReasonDisconnected, forKey: .type)
        case .callDiscardReasonHungUp:
            try container.encode(Kind.callDiscardReasonHungUp, forKey: .type)
        case .callDiscardReasonUpgradeToGroupCall(let value):
            try container.encode(Kind.callDiscardReasonUpgradeToGroupCall, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The call was ended because it has been upgraded to a group call
public struct CallDiscardReasonUpgradeToGroupCall: Codable, Equatable, Hashable {

    /// Invite link for the group call
    public let inviteLink: String


    public init(inviteLink: String) {
        self.inviteLink = inviteLink
    }
}

