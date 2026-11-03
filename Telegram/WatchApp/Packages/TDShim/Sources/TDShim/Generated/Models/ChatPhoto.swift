//
//  ChatPhoto.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a chat or user profile photo
public struct ChatPhoto: Codable, Equatable, Hashable, Identifiable {

    /// Point in time (Unix timestamp) when the photo has been added
    public let addedDate: Int

    /// A big (up to 1280x1280) animated variant of the photo in MPEG4 format; may be null
    public let animation: AnimatedChatPhoto?

    /// Unique photo identifier
    public let id: TdInt64

    /// Photo minithumbnail; may be null
    public let minithumbnail: Minithumbnail?

    /// Available variants of the photo in JPEG format, in different size
    public let sizes: [PhotoSize]

    /// A small (160x160) animated variant of the photo in MPEG4 format; may be null even if the big animation is available
    public let smallAnimation: AnimatedChatPhoto?

    /// Sticker-based version of the chat photo; may be null
    public let sticker: ChatPhotoSticker?


    public init(
        addedDate: Int,
        animation: AnimatedChatPhoto?,
        id: TdInt64,
        minithumbnail: Minithumbnail?,
        sizes: [PhotoSize],
        smallAnimation: AnimatedChatPhoto?,
        sticker: ChatPhotoSticker?
    ) {
        self.addedDate = addedDate
        self.animation = animation
        self.id = id
        self.minithumbnail = minithumbnail
        self.sizes = sizes
        self.smallAnimation = smallAnimation
        self.sticker = sticker
    }
}

