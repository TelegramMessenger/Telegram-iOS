//
//  ChatTheme.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a chat theme
public indirect enum ChatTheme: Codable, Equatable, Hashable {

    /// A chat theme based on an emoji
    case chatThemeEmoji(ChatThemeEmoji)

    /// A chat theme based on an upgraded gift
    case chatThemeGift(ChatThemeGift)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case chatThemeEmoji
        case chatThemeGift
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .chatThemeEmoji:
            let value = try ChatThemeEmoji(from: decoder)
            self = .chatThemeEmoji(value)
        case .chatThemeGift:
            let value = try ChatThemeGift(from: decoder)
            self = .chatThemeGift(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .chatThemeEmoji(let value):
            try container.encode(Kind.chatThemeEmoji, forKey: .type)
            try value.encode(to: encoder)
        case .chatThemeGift(let value):
            try container.encode(Kind.chatThemeGift, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A chat theme based on an emoji
public struct ChatThemeEmoji: Codable, Equatable, Hashable {

    /// Name of the theme; full theme description is received through updateEmojiChatThemes
    public let name: String


    public init(name: String) {
        self.name = name
    }
}

/// A chat theme based on an upgraded gift
public struct ChatThemeGift: Codable, Equatable, Hashable {

    /// The chat theme
    public let giftTheme: GiftChatTheme


    public init(giftTheme: GiftChatTheme) {
        self.giftTheme = giftTheme
    }
}

