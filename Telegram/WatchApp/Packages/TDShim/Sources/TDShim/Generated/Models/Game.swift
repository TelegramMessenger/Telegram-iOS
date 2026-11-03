//
//  Game.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a game. Use getInternalLink with internalLinkTypeGame to share the game
public struct Game: Codable, Equatable, Hashable, Identifiable {

    /// Game animation; may be null
    public let animation: Animation?

    public let description: String

    /// Unique game identifier
    public let id: TdInt64

    /// Game photo
    public let photo: Photo

    /// Game short name
    public let shortName: String

    /// Game text, usually containing scoreboards for a game
    public let text: FormattedText

    /// Game title
    public let title: String


    public init(
        animation: Animation?,
        description: String,
        id: TdInt64,
        photo: Photo,
        shortName: String,
        text: FormattedText,
        title: String
    ) {
        self.animation = animation
        self.description = description
        self.id = id
        self.photo = photo
        self.shortName = shortName
        self.text = text
        self.title = title
    }
}

