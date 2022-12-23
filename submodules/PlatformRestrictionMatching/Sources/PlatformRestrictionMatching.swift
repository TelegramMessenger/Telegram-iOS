import Foundation
import TelegramCore
import Postbox

public extension Message {
    func isRestricted(platform: String, contentSettings: ContentSettings) -> Bool {
        return self.restrictionReason(platform: platform, contentSettings: contentSettings) != nil
    }
    
    func restrictionReason(platform: String, contentSettings: ContentSettings) -> String? {
        if let attribute = self.restrictedContentAttribute {
            if let value = attribute.platformText(platform: platform, contentSettings: contentSettings) {
                return value
            }
        }
        return nil
    }
}

public extension RestrictedContentMessageAttribute {
    // MARK: Nicegram (extractReason)
    func platformText(platform: String, contentSettings: ContentSettings, extractReason: Bool = false) -> String? {
        for rule in self.rules {
            if rule.platform == "all" || rule.platform == "ios" || contentSettings.addContentRestrictionReasons.contains(rule.platform) {
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
