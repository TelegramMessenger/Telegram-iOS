//
//  EmailAddressResetState.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes reset state of an email address
public indirect enum EmailAddressResetState: Codable, Equatable, Hashable {

    /// Email address can be reset after the given period. Call resetAuthenticationEmailAddress to reset it and allow the user to authorize with a code sent to the user's phone number
    case emailAddressResetStateAvailable(EmailAddressResetStateAvailable)

    /// Email address reset has already been requested. Call resetAuthenticationEmailAddress to check whether immediate reset is possible
    case emailAddressResetStatePending(EmailAddressResetStatePending)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case emailAddressResetStateAvailable
        case emailAddressResetStatePending
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .emailAddressResetStateAvailable:
            let value = try EmailAddressResetStateAvailable(from: decoder)
            self = .emailAddressResetStateAvailable(value)
        case .emailAddressResetStatePending:
            let value = try EmailAddressResetStatePending(from: decoder)
            self = .emailAddressResetStatePending(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .emailAddressResetStateAvailable(let value):
            try container.encode(Kind.emailAddressResetStateAvailable, forKey: .type)
            try value.encode(to: encoder)
        case .emailAddressResetStatePending(let value):
            try container.encode(Kind.emailAddressResetStatePending, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// Email address can be reset after the given period. Call resetAuthenticationEmailAddress to reset it and allow the user to authorize with a code sent to the user's phone number
public struct EmailAddressResetStateAvailable: Codable, Equatable, Hashable {

    /// Time required to wait before the email address can be reset; 0 if the user is subscribed to Telegram Premium
    public let waitPeriod: Int


    public init(waitPeriod: Int) {
        self.waitPeriod = waitPeriod
    }
}

/// Email address reset has already been requested. Call resetAuthenticationEmailAddress to check whether immediate reset is possible
public struct EmailAddressResetStatePending: Codable, Equatable, Hashable {

    /// Left time before the email address will be reset, in seconds. updateAuthorizationState is not sent when this field changes
    public let resetIn: Int


    public init(resetIn: Int) {
        self.resetIn = resetIn
    }
}

