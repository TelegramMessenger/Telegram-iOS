//
//  InputThumbnail.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// A thumbnail to be sent along with a file; must be in JPEG or WEBP format for stickers, and less than 200 KB in size
public struct InputThumbnail: Codable, Equatable, Hashable {

    /// Thumbnail height, usually shouldn't exceed 320. Use 0 if unknown
    public let height: Int

    /// Thumbnail file to send. Sending thumbnails by file_id is currently not supported
    public let thumbnail: InputFile

    /// Thumbnail width, usually shouldn't exceed 320. Use 0 if unknown
    public let width: Int


    public init(
        height: Int,
        thumbnail: InputFile,
        width: Int
    ) {
        self.height = height
        self.thumbnail = thumbnail
        self.width = width
    }
}

