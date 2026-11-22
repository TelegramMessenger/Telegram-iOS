//
//  InputPaidMedia.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a paid media to be sent
public struct InputPaidMedia: Codable, Equatable, Hashable {

    /// File identifiers of the stickers added to the media, if applicable
    public let addedStickerFileIds: [Int]

    /// Media height
    public let height: Int

    /// Photo or video to be sent
    public let media: InputFile

    /// Media thumbnail; pass null to skip thumbnail uploading
    public let thumbnail: InputThumbnail?

    /// Type of the media
    public let type: InputPaidMediaType

    /// Media width
    public let width: Int


    public init(
        addedStickerFileIds: [Int],
        height: Int,
        media: InputFile,
        thumbnail: InputThumbnail?,
        type: InputPaidMediaType,
        width: Int
    ) {
        self.addedStickerFileIds = addedStickerFileIds
        self.height = height
        self.media = media
        self.thumbnail = thumbnail
        self.type = type
        self.width = width
    }
}

