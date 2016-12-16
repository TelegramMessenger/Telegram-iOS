import Foundation
import Postbox
import TelegramCore

struct InstantPageMedia: Equatable {
    let index: Int
    let media: Media
    let caption: String?
    
    static func ==(lhs: InstantPageMedia, rhs: InstantPageMedia) -> Bool {
        return lhs.index == rhs.index && lhs.media.isEqual(rhs.media) && lhs.caption == rhs.caption
    }
}
