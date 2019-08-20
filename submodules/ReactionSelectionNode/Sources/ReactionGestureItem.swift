import Foundation
import Postbox
import TelegramCore

public enum ReactionGestureItem {
    case reaction(value: String, text: String, file: TelegramMediaFile)
    case reply
}
