import Foundation
import SwiftSignalKit
import Postbox

/// Whether this build talks the feed API (`TELEGRAM_NEWS_FEED_API`). Layer 233 as the server serves it has none: while
/// this is false nothing is sent, and the app hides News (`isNewsFeedEnabled`; `submodules/TelegramApi/CLAUDE.md`,
/// "Parked APIs").
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

        public func addedFeedContext(filterId: Int32, source: AddedFeedSource) -> AddedFeedContext {
            return AddedFeedContext(account: self.account, filterId: filterId, source: source)
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

        /// Server-side search over the For you feed (`feed.getForYou` with a query): one page of posts, nil on a
        /// network error.
        public func searchForYouPosts(query: String, limit: Int32) -> Signal<[EngineFeedEntry]?, NoError> {
            return _internal_searchForYouPosts(account: self.account, query: query, limit: limit)
        }

        /// `feed.likePost`. Completes when the server answered or the request failed.
        public func likePost(id: EngineMessage.Id) -> Signal<Never, NoError> {
            return _internal_voteFeedPost(account: self.account, id: id, like: true)
        }

        /// `feed.dislikePost`. Completes when the server answered or the request failed.
        public func dislikePost(id: EngineMessage.Id) -> Signal<Never, NoError> {
            return _internal_voteFeedPost(account: self.account, id: id, like: false)
        }
    }
}
