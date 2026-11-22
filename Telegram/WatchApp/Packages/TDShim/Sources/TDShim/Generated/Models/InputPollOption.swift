//
//  InputPollOption.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes one answer option of a poll to be created
public struct InputPollOption: Codable, Equatable, Hashable {

    /// Option media; pass null if none; ignored in addPollOption. Must be one of the following types: inputMessageAnimation, non-live inputMessageLocation, inputMessagePhoto, inputMessageSticker, inputMessageVenue, or inputMessageVideo without caption
    public let media: InputMessageContent?

    /// Option text; 1-100 characters. Only custom emoji entities are allowed to be added and only by Premium users
    public let text: FormattedText


    public init(
        media: InputMessageContent?,
        text: FormattedText
    ) {
        self.media = media
        self.text = text
    }
}

