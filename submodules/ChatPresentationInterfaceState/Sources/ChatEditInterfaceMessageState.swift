import Foundation
import UIKit
import Postbox
import TelegramCore

public struct MessageMediaEditingOptions: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let imageOrVideo = MessageMediaEditingOptions(rawValue: 1 << 0)
    public static let file = MessageMediaEditingOptions(rawValue: 1 << 1)
}

public enum ChatEditInterfaceMessageStateContent: Equatable {
    case plaintext
    case media(mediaOptions: MessageMediaEditingOptions)
}

public final class ChatEditInterfaceMessageState: Equatable {
    public let content: ChatEditInterfaceMessageStateContent
    public let mediaReference: AnyMediaReference?
    
    public init(content: ChatEditInterfaceMessageStateContent, mediaReference: AnyMediaReference?) {
        self.content = content
        self.mediaReference = mediaReference
    }
    
    public static func ==(lhs: ChatEditInterfaceMessageState, rhs: ChatEditInterfaceMessageState) -> Bool {
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
