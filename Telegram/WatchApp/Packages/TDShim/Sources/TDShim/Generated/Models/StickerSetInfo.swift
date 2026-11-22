//
//  StickerSetInfo.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Represents short information about a sticker set
public struct StickerSetInfo: Codable, Equatable, Hashable, Identifiable {

    /// Up to the first 5 stickers from the set, depending on the context. If the application needs more stickers the full sticker set needs to be requested
    public let covers: [Sticker]

    /// Identifier of the sticker set
    public let id: TdInt64

    /// True, if stickers in the sticker set are custom emoji that can be used as chat emoji status; for custom emoji sticker sets only
    public let isAllowedAsChatEmojiStatus: Bool

    /// True, if the sticker set has been archived. A sticker set can't be installed and archived simultaneously
    public let isArchived: Bool

    /// True, if the sticker set has been installed by the current user
    public let isInstalled: Bool

    /// True, if the sticker set is official
    public let isOfficial: Bool

    /// True, if the sticker set is owned by the current user
    public let isOwned: Bool

    /// True for already viewed trending sticker sets
    public let isViewed: Bool

    /// Name of the sticker set
    public let name: String

    /// True, if stickers in the sticker set are custom emoji that must be repainted; for custom emoji sticker sets only
    public let needsRepainting: Bool

    /// Total number of stickers in the set
    public let size: Int

    /// Type of the stickers in the set
    public let stickerType: StickerType

    /// Sticker set thumbnail in WEBP, TGS, or WEBM format with width and height 100; may be null. The file can be downloaded only before the thumbnail is changed
    public let thumbnail: Thumbnail?

    /// Sticker set thumbnail's outline; may be null if unknown
    public let thumbnailOutline: Outline?

    /// Title of the sticker set
    public let title: String


    public init(
        covers: [Sticker],
        id: TdInt64,
        isAllowedAsChatEmojiStatus: Bool,
        isArchived: Bool,
        isInstalled: Bool,
        isOfficial: Bool,
        isOwned: Bool,
        isViewed: Bool,
        name: String,
        needsRepainting: Bool,
        size: Int,
        stickerType: StickerType,
        thumbnail: Thumbnail?,
        thumbnailOutline: Outline?,
        title: String
    ) {
        self.covers = covers
        self.id = id
        self.isAllowedAsChatEmojiStatus = isAllowedAsChatEmojiStatus
        self.isArchived = isArchived
        self.isInstalled = isInstalled
        self.isOfficial = isOfficial
        self.isOwned = isOwned
        self.isViewed = isViewed
        self.name = name
        self.needsRepainting = needsRepainting
        self.size = size
        self.stickerType = stickerType
        self.thumbnail = thumbnail
        self.thumbnailOutline = thumbnailOutline
        self.title = title
    }
}

