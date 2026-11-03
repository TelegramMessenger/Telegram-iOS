//
//  ChatPhotoStickerType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes type of sticker, which was used to create a chat photo
public indirect enum ChatPhotoStickerType: Codable, Equatable, Hashable {

    /// Information about the sticker, which was used to create the chat photo
    case chatPhotoStickerTypeRegularOrMask(ChatPhotoStickerTypeRegularOrMask)

    /// Information about the custom emoji, which was used to create the chat photo
    case chatPhotoStickerTypeCustomEmoji(ChatPhotoStickerTypeCustomEmoji)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case chatPhotoStickerTypeRegularOrMask
        case chatPhotoStickerTypeCustomEmoji
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .chatPhotoStickerTypeRegularOrMask:
            let value = try ChatPhotoStickerTypeRegularOrMask(from: decoder)
            self = .chatPhotoStickerTypeRegularOrMask(value)
        case .chatPhotoStickerTypeCustomEmoji:
            let value = try ChatPhotoStickerTypeCustomEmoji(from: decoder)
            self = .chatPhotoStickerTypeCustomEmoji(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .chatPhotoStickerTypeRegularOrMask(let value):
            try container.encode(Kind.chatPhotoStickerTypeRegularOrMask, forKey: .type)
            try value.encode(to: encoder)
        case .chatPhotoStickerTypeCustomEmoji(let value):
            try container.encode(Kind.chatPhotoStickerTypeCustomEmoji, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// Information about the sticker, which was used to create the chat photo
public struct ChatPhotoStickerTypeRegularOrMask: Codable, Equatable, Hashable {

    /// Identifier of the sticker in the set
    public let stickerId: TdInt64

    /// Sticker set identifier
    public let stickerSetId: TdInt64


    public init(
        stickerId: TdInt64,
        stickerSetId: TdInt64
    ) {
        self.stickerId = stickerId
        self.stickerSetId = stickerSetId
    }
}

/// Information about the custom emoji, which was used to create the chat photo
public struct ChatPhotoStickerTypeCustomEmoji: Codable, Equatable, Hashable {

    /// Identifier of the custom emoji
    public let customEmojiId: TdInt64


    public init(customEmojiId: TdInt64) {
        self.customEmojiId = customEmojiId
    }
}

