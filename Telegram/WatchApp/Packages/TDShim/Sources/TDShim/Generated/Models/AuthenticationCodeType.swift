//
//  AuthenticationCodeType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Provides information about the method by which an authentication code is delivered to the user
public indirect enum AuthenticationCodeType: Codable, Equatable, Hashable {

    /// A digit-only authentication code is delivered via a private Telegram message, which can be viewed from another active session
    case authenticationCodeTypeTelegramMessage(AuthenticationCodeTypeTelegramMessage)

    /// A digit-only authentication code is delivered via an SMS message to the specified phone number; non-official applications may not receive this type of code
    case authenticationCodeTypeSms(AuthenticationCodeTypeSms)

    /// An authentication code is a word delivered via an SMS message to the specified phone number; non-official applications may not receive this type of code
    case authenticationCodeTypeSmsWord(AuthenticationCodeTypeSmsWord)

    /// An authentication code is a phrase from multiple words delivered via an SMS message to the specified phone number; non-official applications may not receive this type of code
    case authenticationCodeTypeSmsPhrase(AuthenticationCodeTypeSmsPhrase)

    /// A digit-only authentication code is delivered via a phone call to the specified phone number
    case authenticationCodeTypeCall(AuthenticationCodeTypeCall)

    /// An authentication code is delivered by an immediately canceled call to the specified phone number. The phone number that calls is the code that must be entered automatically
    case authenticationCodeTypeFlashCall(AuthenticationCodeTypeFlashCall)

    /// An authentication code is delivered by an immediately canceled call to the specified phone number. The last digits of the phone number that calls are the code that must be entered manually by the user
    case authenticationCodeTypeMissedCall(AuthenticationCodeTypeMissedCall)

    /// A digit-only authentication code is delivered to https://fragment.com. The user must be logged in there via a wallet owning the phone number's NFT
    case authenticationCodeTypeFragment(AuthenticationCodeTypeFragment)

    /// A digit-only authentication code is delivered via Firebase Authentication to the official Android application
    case authenticationCodeTypeFirebaseAndroid(AuthenticationCodeTypeFirebaseAndroid)

    /// A digit-only authentication code is delivered via Firebase Authentication to the official iOS application
    case authenticationCodeTypeFirebaseIos(AuthenticationCodeTypeFirebaseIos)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case authenticationCodeTypeTelegramMessage
        case authenticationCodeTypeSms
        case authenticationCodeTypeSmsWord
        case authenticationCodeTypeSmsPhrase
        case authenticationCodeTypeCall
        case authenticationCodeTypeFlashCall
        case authenticationCodeTypeMissedCall
        case authenticationCodeTypeFragment
        case authenticationCodeTypeFirebaseAndroid
        case authenticationCodeTypeFirebaseIos
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .authenticationCodeTypeTelegramMessage:
            let value = try AuthenticationCodeTypeTelegramMessage(from: decoder)
            self = .authenticationCodeTypeTelegramMessage(value)
        case .authenticationCodeTypeSms:
            let value = try AuthenticationCodeTypeSms(from: decoder)
            self = .authenticationCodeTypeSms(value)
        case .authenticationCodeTypeSmsWord:
            let value = try AuthenticationCodeTypeSmsWord(from: decoder)
            self = .authenticationCodeTypeSmsWord(value)
        case .authenticationCodeTypeSmsPhrase:
            let value = try AuthenticationCodeTypeSmsPhrase(from: decoder)
            self = .authenticationCodeTypeSmsPhrase(value)
        case .authenticationCodeTypeCall:
            let value = try AuthenticationCodeTypeCall(from: decoder)
            self = .authenticationCodeTypeCall(value)
        case .authenticationCodeTypeFlashCall:
            let value = try AuthenticationCodeTypeFlashCall(from: decoder)
            self = .authenticationCodeTypeFlashCall(value)
        case .authenticationCodeTypeMissedCall:
            let value = try AuthenticationCodeTypeMissedCall(from: decoder)
            self = .authenticationCodeTypeMissedCall(value)
        case .authenticationCodeTypeFragment:
            let value = try AuthenticationCodeTypeFragment(from: decoder)
            self = .authenticationCodeTypeFragment(value)
        case .authenticationCodeTypeFirebaseAndroid:
            let value = try AuthenticationCodeTypeFirebaseAndroid(from: decoder)
            self = .authenticationCodeTypeFirebaseAndroid(value)
        case .authenticationCodeTypeFirebaseIos:
            let value = try AuthenticationCodeTypeFirebaseIos(from: decoder)
            self = .authenticationCodeTypeFirebaseIos(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .authenticationCodeTypeTelegramMessage(let value):
            try container.encode(Kind.authenticationCodeTypeTelegramMessage, forKey: .type)
            try value.encode(to: encoder)
        case .authenticationCodeTypeSms(let value):
            try container.encode(Kind.authenticationCodeTypeSms, forKey: .type)
            try value.encode(to: encoder)
        case .authenticationCodeTypeSmsWord(let value):
            try container.encode(Kind.authenticationCodeTypeSmsWord, forKey: .type)
            try value.encode(to: encoder)
        case .authenticationCodeTypeSmsPhrase(let value):
            try container.encode(Kind.authenticationCodeTypeSmsPhrase, forKey: .type)
            try value.encode(to: encoder)
        case .authenticationCodeTypeCall(let value):
            try container.encode(Kind.authenticationCodeTypeCall, forKey: .type)
            try value.encode(to: encoder)
        case .authenticationCodeTypeFlashCall(let value):
            try container.encode(Kind.authenticationCodeTypeFlashCall, forKey: .type)
            try value.encode(to: encoder)
        case .authenticationCodeTypeMissedCall(let value):
            try container.encode(Kind.authenticationCodeTypeMissedCall, forKey: .type)
            try value.encode(to: encoder)
        case .authenticationCodeTypeFragment(let value):
            try container.encode(Kind.authenticationCodeTypeFragment, forKey: .type)
            try value.encode(to: encoder)
        case .authenticationCodeTypeFirebaseAndroid(let value):
            try container.encode(Kind.authenticationCodeTypeFirebaseAndroid, forKey: .type)
            try value.encode(to: encoder)
        case .authenticationCodeTypeFirebaseIos(let value):
            try container.encode(Kind.authenticationCodeTypeFirebaseIos, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A digit-only authentication code is delivered via a private Telegram message, which can be viewed from another active session
public struct AuthenticationCodeTypeTelegramMessage: Codable, Equatable, Hashable {

    /// Length of the code
    public let length: Int


    public init(length: Int) {
        self.length = length
    }
}

/// A digit-only authentication code is delivered via an SMS message to the specified phone number; non-official applications may not receive this type of code
public struct AuthenticationCodeTypeSms: Codable, Equatable, Hashable {

    /// Length of the code
    public let length: Int


    public init(length: Int) {
        self.length = length
    }
}

/// An authentication code is a word delivered via an SMS message to the specified phone number; non-official applications may not receive this type of code
public struct AuthenticationCodeTypeSmsWord: Codable, Equatable, Hashable {

    /// The first letters of the word if known
    public let firstLetter: String


    public init(firstLetter: String) {
        self.firstLetter = firstLetter
    }
}

/// An authentication code is a phrase from multiple words delivered via an SMS message to the specified phone number; non-official applications may not receive this type of code
public struct AuthenticationCodeTypeSmsPhrase: Codable, Equatable, Hashable {

    /// The first word of the phrase if known
    public let firstWord: String


    public init(firstWord: String) {
        self.firstWord = firstWord
    }
}

/// A digit-only authentication code is delivered via a phone call to the specified phone number
public struct AuthenticationCodeTypeCall: Codable, Equatable, Hashable {

    /// Length of the code
    public let length: Int


    public init(length: Int) {
        self.length = length
    }
}

/// An authentication code is delivered by an immediately canceled call to the specified phone number. The phone number that calls is the code that must be entered automatically
public struct AuthenticationCodeTypeFlashCall: Codable, Equatable, Hashable {

    /// Pattern of the phone number from which the call will be made
    public let pattern: String


    public init(pattern: String) {
        self.pattern = pattern
    }
}

/// An authentication code is delivered by an immediately canceled call to the specified phone number. The last digits of the phone number that calls are the code that must be entered manually by the user
public struct AuthenticationCodeTypeMissedCall: Codable, Equatable, Hashable {

    /// Number of digits in the code, excluding the prefix
    public let length: Int

    /// Prefix of the phone number from which the call will be made
    public let phoneNumberPrefix: String


    public init(
        length: Int,
        phoneNumberPrefix: String
    ) {
        self.length = length
        self.phoneNumberPrefix = phoneNumberPrefix
    }
}

/// A digit-only authentication code is delivered to https://fragment.com. The user must be logged in there via a wallet owning the phone number's NFT
public struct AuthenticationCodeTypeFragment: Codable, Equatable, Hashable {

    /// Length of the code
    public let length: Int

    /// URL to open to receive the code
    public let url: String


    public init(
        length: Int,
        url: String
    ) {
        self.length = length
        self.url = url
    }
}

/// A digit-only authentication code is delivered via Firebase Authentication to the official Android application
public struct AuthenticationCodeTypeFirebaseAndroid: Codable, Equatable, Hashable {

    /// Parameters to be used for device verification
    public let deviceVerificationParameters: FirebaseDeviceVerificationParameters

    /// Length of the code
    public let length: Int


    public init(
        deviceVerificationParameters: FirebaseDeviceVerificationParameters,
        length: Int
    ) {
        self.deviceVerificationParameters = deviceVerificationParameters
        self.length = length
    }
}

/// A digit-only authentication code is delivered via Firebase Authentication to the official iOS application
public struct AuthenticationCodeTypeFirebaseIos: Codable, Equatable, Hashable {

    /// Length of the code
    public let length: Int

    /// Time after the next authentication method is expected to be used if verification push notification isn't received, in seconds
    public let pushTimeout: Int

    /// Receipt of successful application token validation to compare with receipt from push notification
    public let receipt: String


    public init(
        length: Int,
        pushTimeout: Int,
        receipt: String
    ) {
        self.length = length
        self.pushTimeout = pushTimeout
        self.receipt = receipt
    }
}

