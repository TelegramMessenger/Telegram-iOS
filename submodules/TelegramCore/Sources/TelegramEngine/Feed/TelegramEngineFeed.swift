import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Feed {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func addedFeedContext(filterId: Int32) -> AddedFeedContext {
            return AddedFeedContext(account: self.account, filterId: filterId)
        }

        public func forYouFeedContext() -> ForYouFeedContext {
            return ForYouFeedContext(account: self.account)
        }

        public func interestCategories() -> Signal<EngineInterestCategories?, NoError> {
            return _internal_feedInterestCategories(account: self.account)
        }

        public func setInterestCategories(ids: [Int32]) -> Signal<Never, NoError> {
            return _internal_setFeedInterestCategories(account: self.account, ids: ids)
        }
    }
}
