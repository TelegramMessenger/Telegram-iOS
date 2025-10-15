import Foundation
import Postbox
import TelegramApi


extension RestrictionRule {
    convenience init(apiReason: Api.RestrictionReason) {
        switch apiReason {
        case let .restrictionReason(platform, reason, text):
            self.init(platform: platform, reason: reason, text: text)
        }
    }
}

extension PeerAccessRestrictionInfo {
    convenience init(apiReasons: [Api.RestrictionReason]) {
        self.init(rules: apiReasons.map(RestrictionRule.init(apiReason:)))
    }
}
