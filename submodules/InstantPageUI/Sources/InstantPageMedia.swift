import Foundation
import Postbox
import TelegramCore

public struct InstantPageMedia: Equatable {
    public let index: Int
    public let media: Media
    public let url: InstantPageUrlItem?
    public let caption: RichText?
    public let credit: RichText?
    
    public init(index: Int, media: Media, url: InstantPageUrlItem?, caption: RichText?, credit: RichText?) {
        self.index = index
        self.media = media
        self.url = url
        self.caption = caption
        self.credit = credit
    }
    
    public static func ==(lhs: InstantPageMedia, rhs: InstantPageMedia) -> Bool {
        return lhs.index == rhs.index && lhs.media.isEqual(to: rhs.media) && lhs.url == rhs.url && lhs.caption == rhs.caption && lhs.credit == rhs.credit
    }
}
