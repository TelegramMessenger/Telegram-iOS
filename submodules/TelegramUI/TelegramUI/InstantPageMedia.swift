import Foundation
import Postbox
import TelegramCore

struct InstantPageMedia: Equatable {
    let index: Int
    let media: Media
    let url: InstantPageUrlItem?
    let caption: RichText?
    let credit: RichText?
    
    static func ==(lhs: InstantPageMedia, rhs: InstantPageMedia) -> Bool {
        return lhs.index == rhs.index && lhs.media.isEqual(to: rhs.media) && lhs.url == rhs.url && lhs.caption == rhs.caption && lhs.credit == rhs.credit
    }
}
