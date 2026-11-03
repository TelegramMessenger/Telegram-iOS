//
//  UpgradedGiftColors.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about color scheme for user's name, background of empty chat photo, replies to messages and link previews
public struct UpgradedGiftColors: Codable, Equatable, Hashable, Identifiable {

    /// Accent color to use in dark themes in RGB format
    public let darkThemeAccentColor: Int

    /// The list of 1-3 colors in RGB format, describing the accent color, as expected to be shown in dark themes
    public let darkThemeColors: [Int]

    /// Unique identifier of the upgraded gift colors
    public let id: TdInt64

    /// Accent color to use in light themes in RGB format
    public let lightThemeAccentColor: Int

    /// The list of 1-3 colors in RGB format, describing the accent color, as expected to be shown in light themes
    public let lightThemeColors: [Int]

    /// Custom emoji identifier of the model of the upgraded gift
    public let modelCustomEmojiId: TdInt64

    /// Custom emoji identifier of the symbol of the upgraded gift
    public let symbolCustomEmojiId: TdInt64


    public init(
        darkThemeAccentColor: Int,
        darkThemeColors: [Int],
        id: TdInt64,
        lightThemeAccentColor: Int,
        lightThemeColors: [Int],
        modelCustomEmojiId: TdInt64,
        symbolCustomEmojiId: TdInt64
    ) {
        self.darkThemeAccentColor = darkThemeAccentColor
        self.darkThemeColors = darkThemeColors
        self.id = id
        self.lightThemeAccentColor = lightThemeAccentColor
        self.lightThemeColors = lightThemeColors
        self.modelCustomEmojiId = modelCustomEmojiId
        self.symbolCustomEmojiId = symbolCustomEmojiId
    }
}

