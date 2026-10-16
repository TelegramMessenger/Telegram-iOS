import Foundation
import SwiftSignalKit
import Postbox

/// Whether this build talks the feed API (`TELEGRAM_NEWS_FEED_API`). The feed is parked at layer 232: while this is
/// false nothing is sent, and the app hides News (`isNewsFeedEnabled`). Bringing it back needs the define on the tests
/// module too: CLAUDE.md, "News feed: parked at layer 232".
#if TELEGRAM_NEWS_FEED_API
public let newsFeedApiIsAvailable = true
#else
public let newsFeedApiIsAvailable = false
#endif

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
