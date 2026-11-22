//
//  ThemeSettings.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes theme settings
public struct ThemeSettings: Codable, Equatable, Hashable {

    /// Theme accent color in ARGB format
    public let accentColor: Int

    /// If true, the freeform gradient fill needs to be animated on every sent message
    public let animateOutgoingMessageFill: Bool

    /// The background to be used in chats; may be null
    public let background: Background?

    /// Base theme for this theme
    public let baseTheme: BuiltInTheme

    /// Accent color of outgoing messages in ARGB format
    public let outgoingMessageAccentColor: Int

    /// The fill to be used as a background for outgoing messages; may be null if the fill from the base theme must be used instead
    public let outgoingMessageFill: BackgroundFill?


    public init(
        accentColor: Int,
        animateOutgoingMessageFill: Bool,
        background: Background?,
        baseTheme: BuiltInTheme,
        outgoingMessageAccentColor: Int,
        outgoingMessageFill: BackgroundFill?
    ) {
        self.accentColor = accentColor
        self.animateOutgoingMessageFill = animateOutgoingMessageFill
        self.background = background
        self.baseTheme = baseTheme
        self.outgoingMessageAccentColor = outgoingMessageAccentColor
        self.outgoingMessageFill = outgoingMessageFill
    }
}

