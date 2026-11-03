//
//  Animation.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes an animation file. The animation must be encoded in GIF or MPEG4 format
public struct Animation: Codable, Equatable, Hashable {

    /// File containing the animation
    public let animation: File

    /// Duration of the animation, in seconds; as defined by the sender
    public let duration: Int

    /// Original name of the file; as defined by the sender
    public let fileName: String

    /// True, if stickers were added to the animation. The list of corresponding sticker set can be received using getAttachedStickerSets
    public let hasStickers: Bool

    /// Height of the animation
    public let height: Int

    /// MIME type of the file, usually "image/gif" or "video/mp4"
    public let mimeType: String

    /// Animation minithumbnail; may be null
    public let minithumbnail: Minithumbnail?

    /// Animation thumbnail in JPEG or MPEG4 format; may be null
    public let thumbnail: Thumbnail?

    /// Width of the animation
    public let width: Int


    public init(
        animation: File,
        duration: Int,
        fileName: String,
        hasStickers: Bool,
        height: Int,
        mimeType: String,
        minithumbnail: Minithumbnail?,
        thumbnail: Thumbnail?,
        width: Int
    ) {
        self.animation = animation
        self.duration = duration
        self.fileName = fileName
        self.hasStickers = hasStickers
        self.height = height
        self.mimeType = mimeType
        self.minithumbnail = minithumbnail
        self.thumbnail = thumbnail
        self.width = width
    }
}

