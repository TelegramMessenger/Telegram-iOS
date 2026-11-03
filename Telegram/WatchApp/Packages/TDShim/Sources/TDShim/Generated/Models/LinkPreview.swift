//
//  LinkPreview.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a link preview
public struct LinkPreview: Codable, Equatable, Hashable {

    /// Author of the content
    public let author: String

    public let description: FormattedText

    /// URL to display
    public let displayUrl: String

    /// True, if size of media in the preview can be changed
    public let hasLargeMedia: Bool

    /// Version of instant view (currently, can be 1 or 2) for the web page; 0 if none
    public let instantViewVersion: Int

    /// True, if the link preview must be shown above message text; otherwise, the link preview must be shown below the message text
    public let showAboveText: Bool

    /// True, if large media preview must be shown; otherwise, the media preview must be shown small and only the first frame must be shown for videos
    public let showLargeMedia: Bool

    /// True, if media must be shown above link preview description; otherwise, the media must be shown below the description
    public let showMediaAboveDescription: Bool

    /// Short name of the site (e.g., Google Docs, App Store)
    public let siteName: String

    /// True, if there is no need to show an ordinary open URL confirmation, when opening the URL from the preview, because the URL is shown in the message text in clear
    public let skipConfirmation: Bool

    /// Title of the content
    public let title: String

    /// Type of the link preview
    public let type: LinkPreviewType

    /// Original URL of the link
    public let url: String


    public init(
        author: String,
        description: FormattedText,
        displayUrl: String,
        hasLargeMedia: Bool,
        instantViewVersion: Int,
        showAboveText: Bool,
        showLargeMedia: Bool,
        showMediaAboveDescription: Bool,
        siteName: String,
        skipConfirmation: Bool,
        title: String,
        type: LinkPreviewType,
        url: String
    ) {
        self.author = author
        self.description = description
        self.displayUrl = displayUrl
        self.hasLargeMedia = hasLargeMedia
        self.instantViewVersion = instantViewVersion
        self.showAboveText = showAboveText
        self.showLargeMedia = showLargeMedia
        self.showMediaAboveDescription = showMediaAboveDescription
        self.siteName = siteName
        self.skipConfirmation = skipConfirmation
        self.title = title
        self.type = type
        self.url = url
    }
}

