//
//  ReplyMarkup.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains a description of a custom keyboard and actions that can be done with it to quickly reply to bots
public indirect enum ReplyMarkup: Codable, Equatable, Hashable {

    /// Instructs application to remove the keyboard once this message has been received. This kind of keyboard can't be received in an incoming message; instead, updateChatReplyMarkup with reply_markup_message == null will be sent
    case replyMarkupRemoveKeyboard(ReplyMarkupRemoveKeyboard)

    /// Instructs application to force a reply to this message
    case replyMarkupForceReply(ReplyMarkupForceReply)

    /// Contains a custom keyboard layout to quickly reply to bots
    case replyMarkupShowKeyboard(ReplyMarkupShowKeyboard)

    /// Contains an inline keyboard layout
    case replyMarkupInlineKeyboard(ReplyMarkupInlineKeyboard)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case replyMarkupRemoveKeyboard
        case replyMarkupForceReply
        case replyMarkupShowKeyboard
        case replyMarkupInlineKeyboard
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .replyMarkupRemoveKeyboard:
            let value = try ReplyMarkupRemoveKeyboard(from: decoder)
            self = .replyMarkupRemoveKeyboard(value)
        case .replyMarkupForceReply:
            let value = try ReplyMarkupForceReply(from: decoder)
            self = .replyMarkupForceReply(value)
        case .replyMarkupShowKeyboard:
            let value = try ReplyMarkupShowKeyboard(from: decoder)
            self = .replyMarkupShowKeyboard(value)
        case .replyMarkupInlineKeyboard:
            let value = try ReplyMarkupInlineKeyboard(from: decoder)
            self = .replyMarkupInlineKeyboard(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .replyMarkupRemoveKeyboard(let value):
            try container.encode(Kind.replyMarkupRemoveKeyboard, forKey: .type)
            try value.encode(to: encoder)
        case .replyMarkupForceReply(let value):
            try container.encode(Kind.replyMarkupForceReply, forKey: .type)
            try value.encode(to: encoder)
        case .replyMarkupShowKeyboard(let value):
            try container.encode(Kind.replyMarkupShowKeyboard, forKey: .type)
            try value.encode(to: encoder)
        case .replyMarkupInlineKeyboard(let value):
            try container.encode(Kind.replyMarkupInlineKeyboard, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// Instructs application to remove the keyboard once this message has been received. This kind of keyboard can't be received in an incoming message; instead, updateChatReplyMarkup with reply_markup_message == null will be sent
public struct ReplyMarkupRemoveKeyboard: Codable, Equatable, Hashable {

    /// True, if the keyboard is removed only for the mentioned users or the target user of a reply
    public let isPersonal: Bool


    public init(isPersonal: Bool) {
        self.isPersonal = isPersonal
    }
}

/// Instructs application to force a reply to this message
public struct ReplyMarkupForceReply: Codable, Equatable, Hashable {

    /// If non-empty, the placeholder to be shown in the input field when the reply is active; 0-64 characters
    public let inputFieldPlaceholder: String

    /// True, if a forced reply must automatically be shown to the current user. For outgoing messages, specify true to show the forced reply only for the mentioned users and for the target user of a reply
    public let isPersonal: Bool


    public init(
        inputFieldPlaceholder: String,
        isPersonal: Bool
    ) {
        self.inputFieldPlaceholder = inputFieldPlaceholder
        self.isPersonal = isPersonal
    }
}

/// Contains a custom keyboard layout to quickly reply to bots
public struct ReplyMarkupShowKeyboard: Codable, Equatable, Hashable {

    /// If non-empty, the placeholder to be shown in the input field when the keyboard is active; 0-64 characters
    public let inputFieldPlaceholder: String

    /// True, if the keyboard is expected to always be shown when the ordinary keyboard is hidden
    public let isPersistent: Bool

    /// True, if the keyboard must automatically be shown to the current user. For outgoing messages, specify true to show the keyboard only for the mentioned users and for the target user of a reply
    public let isPersonal: Bool

    /// True, if the application needs to hide the keyboard after use
    public let oneTime: Bool

    /// True, if the application needs to resize the keyboard vertically
    public let resizeKeyboard: Bool

    /// A list of rows of bot keyboard buttons
    public let rows: [[KeyboardButton]]


    public init(
        inputFieldPlaceholder: String,
        isPersistent: Bool,
        isPersonal: Bool,
        oneTime: Bool,
        resizeKeyboard: Bool,
        rows: [[KeyboardButton]]
    ) {
        self.inputFieldPlaceholder = inputFieldPlaceholder
        self.isPersistent = isPersistent
        self.isPersonal = isPersonal
        self.oneTime = oneTime
        self.resizeKeyboard = resizeKeyboard
        self.rows = rows
    }
}

/// Contains an inline keyboard layout
public struct ReplyMarkupInlineKeyboard: Codable, Equatable, Hashable {

    /// A list of rows of inline keyboard buttons
    public let rows: [[InlineKeyboardButton]]


    public init(rows: [[InlineKeyboardButton]]) {
        self.rows = rows
    }
}

