import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore

enum ChatEditInterfaceMessageStateContent: Equatable {
    case plaintext
    case media(mediaOptions: MessageMediaEditingOptions)
}

final class ChatEditInterfaceMessageState: Equatable {
    let content: ChatEditInterfaceMessageStateContent
    let mediaReference: AnyMediaReference?
    
    init(content: ChatEditInterfaceMessageStateContent, mediaReference: AnyMediaReference?) {
        self.content = content
        self.mediaReference = mediaReference
    }
    
    static func ==(lhs: ChatEditInterfaceMessageState, rhs: ChatEditInterfaceMessageState) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if let lhsMedia = lhs.mediaReference, let rhsMedia = rhs.mediaReference {
            if !lhsMedia.media.isEqual(to: rhsMedia.media) {
                return false
            }
        } else if (lhs.mediaReference != nil) != (rhs.mediaReference != nil) {
            return false
        }
        return true
    }
}
