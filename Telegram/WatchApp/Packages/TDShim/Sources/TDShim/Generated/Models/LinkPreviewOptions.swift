//
//  LinkPreviewOptions.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Options to be used for generation of a link preview
public struct LinkPreviewOptions: Codable, Equatable, Hashable {

    /// True, if shown media preview must be large; ignored in secret chats or if the URL isn't explicitly specified
    public let forceLargeMedia: Bool

    /// True, if shown media preview must be small; ignored in secret chats or if the URL isn't explicitly specified
    public let forceSmallMedia: Bool

    /// True, if link preview must be disabled
    public let isDisabled: Bool

    /// True, if link preview must be shown above message text; otherwise, the link preview will be shown below the message text; ignored in secret chats
    public let showAboveText: Bool

    /// URL to use for link preview. If empty, then the first URL found in the message text will be used
    public let url: String


    public init(
        forceLargeMedia: Bool,
        forceSmallMedia: Bool,
        isDisabled: Bool,
        showAboveText: Bool,
        url: String
    ) {
        self.forceLargeMedia = forceLargeMedia
        self.forceSmallMedia = forceSmallMedia
        self.isDisabled = isDisabled
        self.showAboveText = showAboveText
        self.url = url
    }
}

