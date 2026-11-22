//
//  KeyboardButton.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Represents a single button in a bot keyboard
public struct KeyboardButton: Codable, Equatable, Hashable {

    /// Identifier of the custom emoji that must be shown on the button; 0 if none
    public let iconCustomEmojiId: TdInt64

    /// Style of the button
    public let style: ButtonStyle

    /// Text of the button
    public let text: String

    /// Type of the button
    public let type: KeyboardButtonType


    public init(
        iconCustomEmojiId: TdInt64,
        style: ButtonStyle,
        text: String,
        type: KeyboardButtonType
    ) {
        self.iconCustomEmojiId = iconCustomEmojiId
        self.style = style
        self.text = text
        self.type = type
    }
}

