//
//  EmojiStatusType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes type of emoji status
public indirect enum EmojiStatusType: Codable, Equatable, Hashable {

    /// A custom emoji set as emoji status
    case emojiStatusTypeCustomEmoji(EmojiStatusTypeCustomEmoji)

    /// An upgraded gift set as emoji status
    case emojiStatusTypeUpgradedGift(EmojiStatusTypeUpgradedGift)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case emojiStatusTypeCustomEmoji
        case emojiStatusTypeUpgradedGift
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .emojiStatusTypeCustomEmoji:
            let value = try EmojiStatusTypeCustomEmoji(from: decoder)
            self = .emojiStatusTypeCustomEmoji(value)
        case .emojiStatusTypeUpgradedGift:
            let value = try EmojiStatusTypeUpgradedGift(from: decoder)
            self = .emojiStatusTypeUpgradedGift(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .emojiStatusTypeCustomEmoji(let value):
            try container.encode(Kind.emojiStatusTypeCustomEmoji, forKey: .type)
            try value.encode(to: encoder)
        case .emojiStatusTypeUpgradedGift(let value):
            try container.encode(Kind.emojiStatusTypeUpgradedGift, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A custom emoji set as emoji status
public struct EmojiStatusTypeCustomEmoji: Codable, Equatable, Hashable {

    /// Identifier of the custom emoji in stickerFormatTgs format
    public let customEmojiId: TdInt64


    public init(customEmojiId: TdInt64) {
        self.customEmojiId = customEmojiId
    }
}

/// An upgraded gift set as emoji status
public struct EmojiStatusTypeUpgradedGift: Codable, Equatable, Hashable {

    /// Colors of the backdrop of the upgraded gift
    public let backdropColors: UpgradedGiftBackdropColors

    /// Unique name of the upgraded gift that can be used with internalLinkTypeUpgradedGift
    public let giftName: String

    /// The title of the upgraded gift
    public let giftTitle: String

    /// Custom emoji identifier of the model of the upgraded gift
    public let modelCustomEmojiId: TdInt64

    /// Custom emoji identifier of the symbol of the upgraded gift
    public let symbolCustomEmojiId: TdInt64

    /// Identifier of the upgraded gift
    public let upgradedGiftId: TdInt64


    public init(
        backdropColors: UpgradedGiftBackdropColors,
        giftName: String,
        giftTitle: String,
        modelCustomEmojiId: TdInt64,
        symbolCustomEmojiId: TdInt64,
        upgradedGiftId: TdInt64
    ) {
        self.backdropColors = backdropColors
        self.giftName = giftName
        self.giftTitle = giftTitle
        self.modelCustomEmojiId = modelCustomEmojiId
        self.symbolCustomEmojiId = symbolCustomEmojiId
        self.upgradedGiftId = upgradedGiftId
    }
}

