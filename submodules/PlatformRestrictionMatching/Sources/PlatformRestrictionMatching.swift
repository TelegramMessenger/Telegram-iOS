import Foundation
import TelegramCore

public extension RestrictedContentMessageAttribute {
    func platformText(platform: String) -> String? {
        for rule in self.rules {
            if rule.platform == "all" || rule.platform == "ios" {
                return rule.text
            }
        }
        return nil
    }
}
