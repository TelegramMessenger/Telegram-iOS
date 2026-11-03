//
//  Sticker.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a sticker
public struct Sticker: Codable, Equatable, Hashable, Identifiable {

    /// Emoji corresponding to the sticker; may be empty if unknown
    public let emoji: String

    /// Sticker format
    public let format: StickerFormat

    /// Sticker's full type
    public let fullType: StickerFullType

    /// Sticker height; as defined by the sender
    public let height: Int

    /// Unique sticker identifier within the set; 0 if none
    public let id: TdInt64

    /// Identifier of the sticker set to which the sticker belongs; 0 if none
    public let setId: TdInt64

    /// File containing the sticker
    public let sticker: File

    /// Sticker thumbnail in WEBP or JPEG format; may be null
    public let thumbnail: Thumbnail?

    /// Sticker width; as defined by the sender
    public let width: Int


    public init(
        emoji: String,
        format: StickerFormat,
        fullType: StickerFullType,
        height: Int,
        id: TdInt64,
        setId: TdInt64,
        sticker: File,
        thumbnail: Thumbnail?,
        width: Int
    ) {
        self.emoji = emoji
        self.format = format
        self.fullType = fullType
        self.height = height
        self.id = id
        self.setId = setId
        self.sticker = sticker
        self.thumbnail = thumbnail
        self.width = width
    }
}

