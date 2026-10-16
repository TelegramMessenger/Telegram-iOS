import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

final class ChannelInNewsFlagTests: XCTestCase {
    private func apiChannel(flags2: Int32, isMin: Bool = false, left: Bool = false) -> Api.Chat {
        var flags: Int32 = 1 << 5 // broadcast
        if isMin {
            flags |= 1 << 12
        }
        if left {
            flags |= 1 << 2
        }
        return Api.Chat.channel(.init(flags: flags, flags2: flags2, id: 1234, accessHash: isMin ? nil : 5678, title: "News", username: nil, photo: .chatPhotoEmpty, date: 0, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: nil))
    }

    // An in-News channel with the flag set directly: the parse of `in_news` is parked with the feed API (layer 232),
    // and the cases below test what the client does with the flag, not the parse.
    private func inNewsChannel(left: Bool = false) -> TelegramChannel {
        let channel = parseTelegramGroupOrChannel(chat: self.apiChannel(flags2: 0, left: left)) as! TelegramChannel
        var flags = channel.flags
        flags.insert(.isInNews)
        return channel.withUpdatedFlags(flags)
    }

    // Needs in_news parsed, which is parked with the feed API (layer 232).
#if TELEGRAM_NEWS_FEED_API
    func testInNewsBitMapsToFlag() {
        let channel = parseTelegramGroupOrChannel(chat: self.apiChannel(flags2: 1 << 21)) as? TelegramChannel
        XCTAssertEqual(channel?.flags.contains(.isInNews), true)
    }
#endif

    func testMissingBitLeavesFlagClear() {
        let channel = parseTelegramGroupOrChannel(chat: self.apiChannel(flags2: 0)) as? TelegramChannel
        XCTAssertEqual(channel?.flags.contains(.isInNews), false)
    }

    func testFlagSurvivesPostboxCoding() {
        let channel = self.inNewsChannel()
        let encoder = PostboxEncoder()
        channel.encode(encoder)
        let decoded = TelegramChannel(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertTrue(decoded.flags.contains(.isInNews))
    }

    // `in_news` is a light join: the channel is followed in News and stays out of Chats.
    func testLightJoinedChannelIsExcludedFromTheChatList() {
        let channel = self.inNewsChannel(left: true)
        XCTAssertEqual(channel.participationStatus, .left)
        XCTAssertTrue(channel.flags.contains(.isInNews), "an in-News channel")
        XCTAssertTrue(channelShouldBeExcludedFromChatList(channel, isHiddenByCollapsedCommunity: { false }))
    }

    // A joined channel appears everywhere, in News or not.
    func testJoinedChannelInNewsStaysInTheChatList() {
        let channel = self.inNewsChannel()
        XCTAssertEqual(channel.participationStatus, .member)
        XCTAssertTrue(channel.flags.contains(.isInNews), "an in-News channel")
        XCTAssertFalse(channelShouldBeExcludedFromChatList(channel, isHiddenByCollapsedCommunity: { false }))
    }

    func testJoinedChannelStaysInTheChatList() {
        guard let channel = parseTelegramGroupOrChannel(chat: self.apiChannel(flags2: 0)) as? TelegramChannel else {
            XCTFail("not a channel")
            return
        }
        XCTAssertFalse(channelShouldBeExcludedFromChatList(channel, isHiddenByCollapsedCommunity: { false }))
        XCTAssertTrue(channelShouldBeExcludedFromChatList(channel, isHiddenByCollapsedCommunity: { true }))
    }

    // `in_news` is per-user state that a min constructor does not carry: a min update keeps the stored value.
    func testMinUpdateKeepsStoredFlag() {
        let stored = self.inNewsChannel()
        let merged = mergeGroupOrChannel(lhs: stored, rhs: self.apiChannel(flags2: 0, isMin: true)) as? TelegramChannel
        XCTAssertEqual(merged?.flags.contains(.isInNews), true)
    }
}
