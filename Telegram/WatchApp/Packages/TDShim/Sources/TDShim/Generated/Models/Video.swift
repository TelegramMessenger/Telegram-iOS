//
//  Video.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a video file
public struct Video: Codable, Equatable, Hashable {

    /// Duration of the video, in seconds; as defined by the sender
    public let duration: Int

    /// Original name of the file; as defined by the sender
    public let fileName: String

    /// True, if stickers were added to the video. The list of corresponding sticker sets can be received using getAttachedStickerSets
    public let hasStickers: Bool

    /// Video height; as defined by the sender
    public let height: Int

    /// MIME type of the file; as defined by the sender
    public let mimeType: String

    /// Video minithumbnail; may be null
    public let minithumbnail: Minithumbnail?

    /// True, if the video is expected to be streamed
    public let supportsStreaming: Bool

    /// Video thumbnail in JPEG or MPEG4 format; as defined by the sender; may be null
    public let thumbnail: Thumbnail?

    /// File containing the video
    public let video: File

    /// Video width; as defined by the sender
    public let width: Int


    public init(
        duration: Int,
        fileName: String,
        hasStickers: Bool,
        height: Int,
        mimeType: String,
        minithumbnail: Minithumbnail?,
        supportsStreaming: Bool,
        thumbnail: Thumbnail?,
        video: File,
        width: Int
    ) {
        self.duration = duration
        self.fileName = fileName
        self.hasStickers = hasStickers
        self.height = height
        self.mimeType = mimeType
        self.minithumbnail = minithumbnail
        self.supportsStreaming = supportsStreaming
        self.thumbnail = thumbnail
        self.video = video
        self.width = width
    }
}

