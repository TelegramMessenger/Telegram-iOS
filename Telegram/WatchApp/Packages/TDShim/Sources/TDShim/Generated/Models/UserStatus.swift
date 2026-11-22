//
//  UserStatus.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the last time the user was online
public indirect enum UserStatus: Codable, Equatable, Hashable {

    /// The user's status has never been changed
    case userStatusEmpty

    /// The user is online
    case userStatusOnline(UserStatusOnline)

    /// The user is offline
    case userStatusOffline(UserStatusOffline)

    /// The user was online recently
    case userStatusRecently(UserStatusRecently)

    /// The user is offline, but was online last week
    case userStatusLastWeek(UserStatusLastWeek)

    /// The user is offline, but was online last month
    case userStatusLastMonth(UserStatusLastMonth)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case userStatusEmpty
        case userStatusOnline
        case userStatusOffline
        case userStatusRecently
        case userStatusLastWeek
        case userStatusLastMonth
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .userStatusEmpty:
            self = .userStatusEmpty
        case .userStatusOnline:
            let value = try UserStatusOnline(from: decoder)
            self = .userStatusOnline(value)
        case .userStatusOffline:
            let value = try UserStatusOffline(from: decoder)
            self = .userStatusOffline(value)
        case .userStatusRecently:
            let value = try UserStatusRecently(from: decoder)
            self = .userStatusRecently(value)
        case .userStatusLastWeek:
            let value = try UserStatusLastWeek(from: decoder)
            self = .userStatusLastWeek(value)
        case .userStatusLastMonth:
            let value = try UserStatusLastMonth(from: decoder)
            self = .userStatusLastMonth(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .userStatusEmpty:
            try container.encode(Kind.userStatusEmpty, forKey: .type)
        case .userStatusOnline(let value):
            try container.encode(Kind.userStatusOnline, forKey: .type)
            try value.encode(to: encoder)
        case .userStatusOffline(let value):
            try container.encode(Kind.userStatusOffline, forKey: .type)
            try value.encode(to: encoder)
        case .userStatusRecently(let value):
            try container.encode(Kind.userStatusRecently, forKey: .type)
            try value.encode(to: encoder)
        case .userStatusLastWeek(let value):
            try container.encode(Kind.userStatusLastWeek, forKey: .type)
            try value.encode(to: encoder)
        case .userStatusLastMonth(let value):
            try container.encode(Kind.userStatusLastMonth, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The user is online
public struct UserStatusOnline: Codable, Equatable, Hashable {

    /// Point in time (Unix timestamp) when the user's online status will expire
    public let expires: Int


    public init(expires: Int) {
        self.expires = expires
    }
}

/// The user is offline
public struct UserStatusOffline: Codable, Equatable, Hashable {

    /// Point in time (Unix timestamp) when the user was last online
    public let wasOnline: Int


    public init(wasOnline: Int) {
        self.wasOnline = wasOnline
    }
}

/// The user was online recently
public struct UserStatusRecently: Codable, Equatable, Hashable {

    /// Exact user's status is hidden because the current user enabled userPrivacySettingShowStatus privacy setting for the user and has no Telegram Premium
    public let byMyPrivacySettings: Bool


    public init(byMyPrivacySettings: Bool) {
        self.byMyPrivacySettings = byMyPrivacySettings
    }
}

/// The user is offline, but was online last week
public struct UserStatusLastWeek: Codable, Equatable, Hashable {

    /// Exact user's status is hidden because the current user enabled userPrivacySettingShowStatus privacy setting for the user and has no Telegram Premium
    public let byMyPrivacySettings: Bool


    public init(byMyPrivacySettings: Bool) {
        self.byMyPrivacySettings = byMyPrivacySettings
    }
}

/// The user is offline, but was online last month
public struct UserStatusLastMonth: Codable, Equatable, Hashable {

    /// Exact user's status is hidden because the current user enabled userPrivacySettingShowStatus privacy setting for the user and has no Telegram Premium
    public let byMyPrivacySettings: Bool


    public init(byMyPrivacySettings: Bool) {
        self.byMyPrivacySettings = byMyPrivacySettings
    }
}

