import Foundation
import Postbox
import TelegramCore

final class ChatEditInterfaceMessageState: Equatable {
    let hasOriginalMedia: Bool
    let media: Media?
    
    init(hasOriginalMedia: Bool, media: Media?) {
        self.hasOriginalMedia = hasOriginalMedia
        self.media = media
    }
    
    static func ==(lhs: ChatEditInterfaceMessageState, rhs: ChatEditInterfaceMessageState) -> Bool {
        if lhs.hasOriginalMedia != rhs.hasOriginalMedia {
            return false
        }
        if let lhsMedia = lhs.media, let rhsMedia = rhs.media {
            if !lhsMedia.isEqual(rhsMedia) {
                return false
            }
        } else if (lhs.media != nil) != (rhs.media != nil) {
            return false
        }
        return true
    }
}
