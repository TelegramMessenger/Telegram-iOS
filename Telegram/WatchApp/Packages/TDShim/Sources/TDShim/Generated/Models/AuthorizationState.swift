//
//  AuthorizationState.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Represents the current authorization state of the TDLib client
public indirect enum AuthorizationState: Codable, Equatable, Hashable {

    /// Initialization parameters are needed. Call setTdlibParameters to provide them
    case authorizationStateWaitTdlibParameters

    /// TDLib needs the user's phone number to authorize. Call setAuthenticationPhoneNumber to provide the phone number, or use requestQrCodeAuthentication, getAuthenticationPasskeyParameters, or checkAuthenticationBotToken for other authentication options
    case authorizationStateWaitPhoneNumber

    /// The user must buy Telegram Premium as an in-store purchase to log in. Call checkAuthenticationPremiumPurchase and then setAuthenticationPremiumPurchaseTransaction
    case authorizationStateWaitPremiumPurchase(AuthorizationStateWaitPremiumPurchase)

    /// TDLib needs the user's email address to authorize. Call setAuthenticationEmailAddress to provide the email address, or directly call checkAuthenticationEmailCode with Apple ID/Google ID token if allowed
    case authorizationStateWaitEmailAddress(AuthorizationStateWaitEmailAddress)

    /// TDLib needs the user's authentication code sent to an email address to authorize. Call checkAuthenticationEmailCode to provide the code
    case authorizationStateWaitEmailCode(AuthorizationStateWaitEmailCode)

    /// TDLib needs the user's authentication code to authorize. Call checkAuthenticationCode to check the code
    case authorizationStateWaitCode(AuthorizationStateWaitCode)

    /// The user needs to confirm authorization on another logged in device by scanning a QR code with the provided link
    case authorizationStateWaitOtherDeviceConfirmation(AuthorizationStateWaitOtherDeviceConfirmation)

    /// The user is unregistered and needs to accept terms of service and enter their first name and last name to finish registration. Call registerUser to accept the terms of service and provide the data
    case authorizationStateWaitRegistration(AuthorizationStateWaitRegistration)

    /// The user has been authorized, but needs to enter a 2-step verification password to start using the application. Call checkAuthenticationPassword to provide the password, or requestAuthenticationPasswordRecovery to recover the password, or deleteAccount to delete the account after a week
    case authorizationStateWaitPassword(AuthorizationStateWaitPassword)

    /// The user has been successfully authorized. TDLib is now ready to answer general requests
    case authorizationStateReady

    /// The user is currently logging out
    case authorizationStateLoggingOut

    /// TDLib is closing, all subsequent queries will be answered with the error 500. Note that closing TDLib can take a while. All resources will be freed only after authorizationStateClosed has been received
    case authorizationStateClosing

    /// TDLib client is in its final state. All databases are closed and all resources are released. No other updates will be received after this. All queries will be responded to with error code 500. To continue working, one must create a new instance of the TDLib client
    case authorizationStateClosed

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case authorizationStateWaitTdlibParameters
        case authorizationStateWaitPhoneNumber
        case authorizationStateWaitPremiumPurchase
        case authorizationStateWaitEmailAddress
        case authorizationStateWaitEmailCode
        case authorizationStateWaitCode
        case authorizationStateWaitOtherDeviceConfirmation
        case authorizationStateWaitRegistration
        case authorizationStateWaitPassword
        case authorizationStateReady
        case authorizationStateLoggingOut
        case authorizationStateClosing
        case authorizationStateClosed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .authorizationStateWaitTdlibParameters:
            self = .authorizationStateWaitTdlibParameters
        case .authorizationStateWaitPhoneNumber:
            self = .authorizationStateWaitPhoneNumber
        case .authorizationStateWaitPremiumPurchase:
            let value = try AuthorizationStateWaitPremiumPurchase(from: decoder)
            self = .authorizationStateWaitPremiumPurchase(value)
        case .authorizationStateWaitEmailAddress:
            let value = try AuthorizationStateWaitEmailAddress(from: decoder)
            self = .authorizationStateWaitEmailAddress(value)
        case .authorizationStateWaitEmailCode:
            let value = try AuthorizationStateWaitEmailCode(from: decoder)
            self = .authorizationStateWaitEmailCode(value)
        case .authorizationStateWaitCode:
            let value = try AuthorizationStateWaitCode(from: decoder)
            self = .authorizationStateWaitCode(value)
        case .authorizationStateWaitOtherDeviceConfirmation:
            let value = try AuthorizationStateWaitOtherDeviceConfirmation(from: decoder)
            self = .authorizationStateWaitOtherDeviceConfirmation(value)
        case .authorizationStateWaitRegistration:
            let value = try AuthorizationStateWaitRegistration(from: decoder)
            self = .authorizationStateWaitRegistration(value)
        case .authorizationStateWaitPassword:
            let value = try AuthorizationStateWaitPassword(from: decoder)
            self = .authorizationStateWaitPassword(value)
        case .authorizationStateReady:
            self = .authorizationStateReady
        case .authorizationStateLoggingOut:
            self = .authorizationStateLoggingOut
        case .authorizationStateClosing:
            self = .authorizationStateClosing
        case .authorizationStateClosed:
            self = .authorizationStateClosed
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .authorizationStateWaitTdlibParameters:
            try container.encode(Kind.authorizationStateWaitTdlibParameters, forKey: .type)
        case .authorizationStateWaitPhoneNumber:
            try container.encode(Kind.authorizationStateWaitPhoneNumber, forKey: .type)
        case .authorizationStateWaitPremiumPurchase(let value):
            try container.encode(Kind.authorizationStateWaitPremiumPurchase, forKey: .type)
            try value.encode(to: encoder)
        case .authorizationStateWaitEmailAddress(let value):
            try container.encode(Kind.authorizationStateWaitEmailAddress, forKey: .type)
            try value.encode(to: encoder)
        case .authorizationStateWaitEmailCode(let value):
            try container.encode(Kind.authorizationStateWaitEmailCode, forKey: .type)
            try value.encode(to: encoder)
        case .authorizationStateWaitCode(let value):
            try container.encode(Kind.authorizationStateWaitCode, forKey: .type)
            try value.encode(to: encoder)
        case .authorizationStateWaitOtherDeviceConfirmation(let value):
            try container.encode(Kind.authorizationStateWaitOtherDeviceConfirmation, forKey: .type)
            try value.encode(to: encoder)
        case .authorizationStateWaitRegistration(let value):
            try container.encode(Kind.authorizationStateWaitRegistration, forKey: .type)
            try value.encode(to: encoder)
        case .authorizationStateWaitPassword(let value):
            try container.encode(Kind.authorizationStateWaitPassword, forKey: .type)
            try value.encode(to: encoder)
        case .authorizationStateReady:
            try container.encode(Kind.authorizationStateReady, forKey: .type)
        case .authorizationStateLoggingOut:
            try container.encode(Kind.authorizationStateLoggingOut, forKey: .type)
        case .authorizationStateClosing:
            try container.encode(Kind.authorizationStateClosing, forKey: .type)
        case .authorizationStateClosed:
            try container.encode(Kind.authorizationStateClosed, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The user must buy Telegram Premium as an in-store purchase to log in. Call checkAuthenticationPremiumPurchase and then setAuthenticationPremiumPurchaseTransaction
public struct AuthorizationStateWaitPremiumPurchase: Codable, Equatable, Hashable {

    /// Duration of the Telegram Premium subscription after the purchase; may be 0 if Telegram Premium subscription will not be granted
    public let premiumDayCount: Int

    /// Identifier of the store product that must be bought
    public let storeProductId: String

    /// Email address to use for support if the user has issues with Telegram Premium purchase
    public let supportEmailAddress: String

    /// Subject for the email sent to the support email address
    public let supportEmailSubject: String


    public init(
        premiumDayCount: Int,
        storeProductId: String,
        supportEmailAddress: String,
        supportEmailSubject: String
    ) {
        self.premiumDayCount = premiumDayCount
        self.storeProductId = storeProductId
        self.supportEmailAddress = supportEmailAddress
        self.supportEmailSubject = supportEmailSubject
    }
}

/// TDLib needs the user's email address to authorize. Call setAuthenticationEmailAddress to provide the email address, or directly call checkAuthenticationEmailCode with Apple ID/Google ID token if allowed
public struct AuthorizationStateWaitEmailAddress: Codable, Equatable, Hashable {

    /// True, if authorization through Apple ID is allowed
    public let allowAppleId: Bool

    /// True, if authorization through Google ID is allowed
    public let allowGoogleId: Bool


    public init(
        allowAppleId: Bool,
        allowGoogleId: Bool
    ) {
        self.allowAppleId = allowAppleId
        self.allowGoogleId = allowGoogleId
    }
}

/// TDLib needs the user's authentication code sent to an email address to authorize. Call checkAuthenticationEmailCode to provide the code
public struct AuthorizationStateWaitEmailCode: Codable, Equatable, Hashable {

    /// True, if authorization through Apple ID is allowed
    public let allowAppleId: Bool

    /// True, if authorization through Google ID is allowed
    public let allowGoogleId: Bool

    /// Information about the sent authentication code
    public let codeInfo: EmailAddressAuthenticationCodeInfo

    /// Reset state of the email address; may be null if the email address can't be reset
    public let emailAddressResetState: EmailAddressResetState?


    public init(
        allowAppleId: Bool,
        allowGoogleId: Bool,
        codeInfo: EmailAddressAuthenticationCodeInfo,
        emailAddressResetState: EmailAddressResetState?
    ) {
        self.allowAppleId = allowAppleId
        self.allowGoogleId = allowGoogleId
        self.codeInfo = codeInfo
        self.emailAddressResetState = emailAddressResetState
    }
}

/// TDLib needs the user's authentication code to authorize. Call checkAuthenticationCode to check the code
public struct AuthorizationStateWaitCode: Codable, Equatable, Hashable {

    /// Information about the authorization code that was sent
    public let codeInfo: AuthenticationCodeInfo


    public init(codeInfo: AuthenticationCodeInfo) {
        self.codeInfo = codeInfo
    }
}

/// The user needs to confirm authorization on another logged in device by scanning a QR code with the provided link
public struct AuthorizationStateWaitOtherDeviceConfirmation: Codable, Equatable, Hashable {

    /// A tg:// URL for the QR code. The link will be updated frequently
    public let link: String


    public init(link: String) {
        self.link = link
    }
}

/// The user is unregistered and needs to accept terms of service and enter their first name and last name to finish registration. Call registerUser to accept the terms of service and provide the data
public struct AuthorizationStateWaitRegistration: Codable, Equatable, Hashable {

    /// Telegram terms of service
    public let termsOfService: TermsOfService


    public init(termsOfService: TermsOfService) {
        self.termsOfService = termsOfService
    }
}

/// The user has been authorized, but needs to enter a 2-step verification password to start using the application. Call checkAuthenticationPassword to provide the password, or requestAuthenticationPasswordRecovery to recover the password, or deleteAccount to delete the account after a week
public struct AuthorizationStateWaitPassword: Codable, Equatable, Hashable {

    /// True, if some Telegram Passport elements were saved
    public let hasPassportData: Bool

    /// True, if a recovery email address has been set up
    public let hasRecoveryEmailAddress: Bool

    /// Hint for the password; may be empty
    public let passwordHint: String

    /// Pattern of the email address to which the recovery email was sent; empty until a recovery email has been sent
    public let recoveryEmailAddressPattern: String


    public init(
        hasPassportData: Bool,
        hasRecoveryEmailAddress: Bool,
        passwordHint: String,
        recoveryEmailAddressPattern: String
    ) {
        self.hasPassportData = hasPassportData
        self.hasRecoveryEmailAddress = hasRecoveryEmailAddress
        self.passwordHint = passwordHint
        self.recoveryEmailAddressPattern = recoveryEmailAddressPattern
    }
}

