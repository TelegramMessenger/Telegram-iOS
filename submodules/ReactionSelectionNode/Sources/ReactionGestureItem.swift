import Foundation
import Postbox
import TelegramCore

public struct ReactionGestureItemValue {
    public var value: String
    public var text: String
    public var file: TelegramMediaFile
    
    public init(value: String, text: String, file: TelegramMediaFile) {
        self.value = value
        self.text = text
        self.file = file
    }
}

public final class ReactionGestureItem {
    public let value: ReactionGestureItemValue
    
    public init(value: ReactionGestureItemValue) {
        self.value = value
    }
}
