import Foundation
import Postbox
import TelegramCore

enum ChatEditInterfaceMessageStateContent: Equatable {
    case plaintext
    case media(editable: Bool)
}

final class ChatEditInterfaceMessageState: Equatable {
    let content: ChatEditInterfaceMessageStateContent
    let media: Media?
    
    init(content: ChatEditInterfaceMessageStateContent, media: Media?) {
        self.content = content
        self.media = media
    }
    
    static func ==(lhs: ChatEditInterfaceMessageState, rhs: ChatEditInterfaceMessageState) -> Bool {
        if lhs.content != rhs.content {
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
