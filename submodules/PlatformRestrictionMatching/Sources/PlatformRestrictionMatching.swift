import Foundation
import TelegramCore

public extension EngineRawMessage {
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
    func platformText(platform: String, contentSettings: ContentSettings) -> String? {
        for rule in self.rules {
            if rule.reason == "sensitive" {
                continue
            }
            if rule.appliesTo(platform: platform, contentSettings: contentSettings) {
                if !contentSettings.ignoreContentRestrictionReasons.contains(rule.reason) {
                    return rule.text
                }
            }
        }
        return nil
    }
}
