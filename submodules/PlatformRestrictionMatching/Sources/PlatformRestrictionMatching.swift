import Foundation
import TelegramCore

public extension RestrictedContentMessageAttribute {
    // MARK: Nicegram (extractReason)
    func platformText(platform: String, contentSettings: ContentSettings, extractReason: Bool = false) -> String? {
        for rule in self.rules {
            if rule.platform == "all" || rule.platform == "ios" {
                if !contentSettings.ignoreContentRestrictionReasons.contains(rule.reason) {
                    // MARK: Nicegram
                    if extractReason {
                        return rule.reason
                    }
                    //
                    return rule.text
                }
            }
        }
        return nil
    }
}
