//
//  AnimatedEmoji.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes an animated or custom representation of an emoji
public struct AnimatedEmoji: Codable, Equatable, Hashable {

    /// Emoji modifier fitzpatrick type; 0-6; 0 if none
    public let fitzpatrickType: Int

    /// File containing the sound to be played when the sticker is clicked; may be null. The sound is encoded with the Opus codec, and stored inside an OGG container
    public let sound: File?

    /// Sticker for the emoji; may be null if yet unknown for a custom emoji. If the sticker is a custom emoji, then it can have arbitrary format
    public let sticker: Sticker?

    /// Expected height of the sticker, which can be used if the sticker is null
    public let stickerHeight: Int

    /// Expected width of the sticker, which can be used if the sticker is null
    public let stickerWidth: Int


    public init(
        fitzpatrickType: Int,
        sound: File?,
        sticker: Sticker?,
        stickerHeight: Int,
        stickerWidth: Int
    ) {
        self.fitzpatrickType = fitzpatrickType
        self.sound = sound
        self.sticker = sticker
        self.stickerHeight = stickerHeight
        self.stickerWidth = stickerWidth
    }
}

