//
//  InlineKeyboardButtonType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the type of inline keyboard button
public indirect enum InlineKeyboardButtonType: Codable, Equatable, Hashable {

    /// A button that opens a specified URL
    case inlineKeyboardButtonTypeUrl(InlineKeyboardButtonTypeUrl)

    /// A button that opens a specified URL and automatically authorize the current user by calling getLoginUrlInfo
    case inlineKeyboardButtonTypeLoginUrl(InlineKeyboardButtonTypeLoginUrl)

    /// A button that opens a Web App by calling openWebApp
    case inlineKeyboardButtonTypeWebApp(InlineKeyboardButtonTypeWebApp)

    /// A button that sends a callback query to a bot
    case inlineKeyboardButtonTypeCallback(InlineKeyboardButtonTypeCallback)

    /// A button that asks for the 2-step verification password of the current user and then sends a callback query to a bot
    case inlineKeyboardButtonTypeCallbackWithPassword(InlineKeyboardButtonTypeCallbackWithPassword)

    /// A button with a game that sends a callback query to a bot. This button must be in the first column and row of the keyboard and can be attached only to a message with content of the type messageGame
    case inlineKeyboardButtonTypeCallbackGame

    /// A button that forces an inline query to the bot to be inserted in the input field
    case inlineKeyboardButtonTypeSwitchInline(InlineKeyboardButtonTypeSwitchInline)

    /// A button to buy something. This button must be in the first column and row of the keyboard and can be attached only to a message with content of the type messageInvoice
    case inlineKeyboardButtonTypeBuy

    /// A button with a user reference to be handled in the same way as textEntityTypeMentionName entities
    case inlineKeyboardButtonTypeUser(InlineKeyboardButtonTypeUser)

    /// A button that copies specified text to clipboard
    case inlineKeyboardButtonTypeCopyText(InlineKeyboardButtonTypeCopyText)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case inlineKeyboardButtonTypeUrl
        case inlineKeyboardButtonTypeLoginUrl
        case inlineKeyboardButtonTypeWebApp
        case inlineKeyboardButtonTypeCallback
        case inlineKeyboardButtonTypeCallbackWithPassword
        case inlineKeyboardButtonTypeCallbackGame
        case inlineKeyboardButtonTypeSwitchInline
        case inlineKeyboardButtonTypeBuy
        case inlineKeyboardButtonTypeUser
        case inlineKeyboardButtonTypeCopyText
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .inlineKeyboardButtonTypeUrl:
            let value = try InlineKeyboardButtonTypeUrl(from: decoder)
            self = .inlineKeyboardButtonTypeUrl(value)
        case .inlineKeyboardButtonTypeLoginUrl:
            let value = try InlineKeyboardButtonTypeLoginUrl(from: decoder)
            self = .inlineKeyboardButtonTypeLoginUrl(value)
        case .inlineKeyboardButtonTypeWebApp:
            let value = try InlineKeyboardButtonTypeWebApp(from: decoder)
            self = .inlineKeyboardButtonTypeWebApp(value)
        case .inlineKeyboardButtonTypeCallback:
            let value = try InlineKeyboardButtonTypeCallback(from: decoder)
            self = .inlineKeyboardButtonTypeCallback(value)
        case .inlineKeyboardButtonTypeCallbackWithPassword:
            let value = try InlineKeyboardButtonTypeCallbackWithPassword(from: decoder)
            self = .inlineKeyboardButtonTypeCallbackWithPassword(value)
        case .inlineKeyboardButtonTypeCallbackGame:
            self = .inlineKeyboardButtonTypeCallbackGame
        case .inlineKeyboardButtonTypeSwitchInline:
            let value = try InlineKeyboardButtonTypeSwitchInline(from: decoder)
            self = .inlineKeyboardButtonTypeSwitchInline(value)
        case .inlineKeyboardButtonTypeBuy:
            self = .inlineKeyboardButtonTypeBuy
        case .inlineKeyboardButtonTypeUser:
            let value = try InlineKeyboardButtonTypeUser(from: decoder)
            self = .inlineKeyboardButtonTypeUser(value)
        case .inlineKeyboardButtonTypeCopyText:
            let value = try InlineKeyboardButtonTypeCopyText(from: decoder)
            self = .inlineKeyboardButtonTypeCopyText(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .inlineKeyboardButtonTypeUrl(let value):
            try container.encode(Kind.inlineKeyboardButtonTypeUrl, forKey: .type)
            try value.encode(to: encoder)
        case .inlineKeyboardButtonTypeLoginUrl(let value):
            try container.encode(Kind.inlineKeyboardButtonTypeLoginUrl, forKey: .type)
            try value.encode(to: encoder)
        case .inlineKeyboardButtonTypeWebApp(let value):
            try container.encode(Kind.inlineKeyboardButtonTypeWebApp, forKey: .type)
            try value.encode(to: encoder)
        case .inlineKeyboardButtonTypeCallback(let value):
            try container.encode(Kind.inlineKeyboardButtonTypeCallback, forKey: .type)
            try value.encode(to: encoder)
        case .inlineKeyboardButtonTypeCallbackWithPassword(let value):
            try container.encode(Kind.inlineKeyboardButtonTypeCallbackWithPassword, forKey: .type)
            try value.encode(to: encoder)
        case .inlineKeyboardButtonTypeCallbackGame:
            try container.encode(Kind.inlineKeyboardButtonTypeCallbackGame, forKey: .type)
        case .inlineKeyboardButtonTypeSwitchInline(let value):
            try container.encode(Kind.inlineKeyboardButtonTypeSwitchInline, forKey: .type)
            try value.encode(to: encoder)
        case .inlineKeyboardButtonTypeBuy:
            try container.encode(Kind.inlineKeyboardButtonTypeBuy, forKey: .type)
        case .inlineKeyboardButtonTypeUser(let value):
            try container.encode(Kind.inlineKeyboardButtonTypeUser, forKey: .type)
            try value.encode(to: encoder)
        case .inlineKeyboardButtonTypeCopyText(let value):
            try container.encode(Kind.inlineKeyboardButtonTypeCopyText, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A button that opens a specified URL
public struct InlineKeyboardButtonTypeUrl: Codable, Equatable, Hashable {

    /// HTTP or tg:// URL to open. If the link is of the type internalLinkTypeWebApp, then the button must be marked as a Web App button
    public let url: String


    public init(url: String) {
        self.url = url
    }
}

/// A button that opens a specified URL and automatically authorize the current user by calling getLoginUrlInfo
public struct InlineKeyboardButtonTypeLoginUrl: Codable, Equatable, Hashable, Identifiable {

    /// If non-empty, new text of the button in forwarded messages
    public let forwardText: String

    /// Unique button identifier
    public let id: Int64

    /// An HTTP URL to pass to getLoginUrlInfo
    public let url: String


    public init(
        forwardText: String,
        id: Int64,
        url: String
    ) {
        self.forwardText = forwardText
        self.id = id
        self.url = url
    }
}

/// A button that opens a Web App by calling openWebApp
public struct InlineKeyboardButtonTypeWebApp: Codable, Equatable, Hashable {

    /// An HTTP URL to pass to openWebApp
    public let url: String


    public init(url: String) {
        self.url = url
    }
}

/// A button that sends a callback query to a bot
public struct InlineKeyboardButtonTypeCallback: Codable, Equatable, Hashable {

    /// Data to be sent to the bot via a callback query
    public let data: Data


    public init(data: Data) {
        self.data = data
    }
}

/// A button that asks for the 2-step verification password of the current user and then sends a callback query to a bot
public struct InlineKeyboardButtonTypeCallbackWithPassword: Codable, Equatable, Hashable {

    /// Data to be sent to the bot via a callback query
    public let data: Data


    public init(data: Data) {
        self.data = data
    }
}

/// A button that forces an inline query to the bot to be inserted in the input field
public struct InlineKeyboardButtonTypeSwitchInline: Codable, Equatable, Hashable {

    /// Inline query to be sent to the bot
    public let query: String

    /// Target chat from which to send the inline query
    public let targetChat: TargetChat


    public init(
        query: String,
        targetChat: TargetChat
    ) {
        self.query = query
        self.targetChat = targetChat
    }
}

/// A button with a user reference to be handled in the same way as textEntityTypeMentionName entities
public struct InlineKeyboardButtonTypeUser: Codable, Equatable, Hashable {

    /// User identifier
    public let userId: Int64


    public init(userId: Int64) {
        self.userId = userId
    }
}

/// A button that copies specified text to clipboard
public struct InlineKeyboardButtonTypeCopyText: Codable, Equatable, Hashable {

    /// The text to copy to clipboard
    public let text: String


    public init(text: String) {
        self.text = text
    }
}

