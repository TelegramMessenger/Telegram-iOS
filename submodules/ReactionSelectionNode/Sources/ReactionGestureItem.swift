import Foundation
import Postbox
import TelegramCore

public enum ReactionGestureItem {
    case reaction(value: String, text: String, path: String)
    case reply
}
