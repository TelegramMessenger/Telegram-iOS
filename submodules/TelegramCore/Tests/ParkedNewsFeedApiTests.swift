import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

/// Layer 232 parks the feed API (`TELEGRAM_NEWS_FEED_API` is undefined): its `channel` constructor has no `in_news`,
/// so `flags2` bit 21 means nothing and must not put a channel in News.
final class ParkedNewsFeedApiTests: XCTestCase {
    func testInNewsBitIsIgnoredWhileTheFeedApiIsParked() throws {
        try XCTSkipIf(newsFeedApiIsAvailable, "the feed API is compiled in; ChannelInNewsFlagTests covers bit 21")
        let chat = Api.Chat.channel(.init(flags: 1 << 5, flags2: 1 << 21, id: 1234, accessHash: 5678, title: "News", username: nil, photo: .chatPhotoEmpty, date: 0, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: nil))
        guard let channel = parseTelegramGroupOrChannel(chat: chat) as? TelegramChannel else {
            XCTFail("not a channel")
            return
        }
        XCTAssertFalse(channel.flags.contains(.isInNews))
    }
}
