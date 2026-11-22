//
//  PhotoSize.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes an image in JPEG format
public struct PhotoSize: Codable, Equatable, Hashable {

    /// Image height
    public let height: Int

    /// Information about the image file
    public let photo: File

    /// Sizes of progressive JPEG file prefixes, which can be used to preliminarily show the image; in bytes
    public let progressiveSizes: [Int]

    /// Image type (see https://core.telegram.org/constructor/photoSize)
    public let type: String

    /// Image width
    public let width: Int


    public init(
        height: Int,
        photo: File,
        progressiveSizes: [Int],
        type: String,
        width: Int
    ) {
        self.height = height
        self.photo = photo
        self.progressiveSizes = progressiveSizes
        self.type = type
        self.width = width
    }
}

