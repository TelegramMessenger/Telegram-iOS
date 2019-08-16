import Foundation
import TelegramCore

public extension RestrictedContentMessageAttribute {
    func matchesPlatform() -> Bool {
        return self.platformSelector == "ios"
    }
}
