import Foundation
import TelegramCore

public extension RestrictedContentMessageAttribute {
    func platformText(platform: String, contentSettings: ContentSettings) -> String? {
        for rule in self.rules {
            if rule.platform == "all" || rule.platform == "ios" {
                if !contentSettings.ignoreContentRestrictionReasons.contains(rule.reason) {
                    return rule.text
                }
            }
        }
        return nil
    }
}
