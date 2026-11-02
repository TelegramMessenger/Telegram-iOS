import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

final class ChannelForumDisplayModeTests: XCTestCase {
    private func channel(flags2: Int32) -> TelegramChannel? {
        let flags: Int32 = (1 << 8) | (1 << 30)
        let chat = Api.Chat.channel(.init(flags: flags, flags2: flags2, id: 1234, accessHash: 5678, title: "Forum", username: nil, photo: .chatPhotoEmpty, date: 0, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: nil))
        return parseTelegramGroupOrChannel(chat: chat) as? TelegramChannel
    }

    func testNoFlagsIsList() {
        let channel = self.channel(flags2: 0)
        XCTAssertEqual(channel?.flags.contains(.displayForumAsTabs), false)
        XCTAssertEqual(channel?.flags.contains(.displayForumAsSidebar), false)
    }

    func testTabsWithoutSidebarIsTabs() {
        let channel = self.channel(flags2: 1 << 19)
        XCTAssertEqual(channel?.flags.contains(.displayForumAsTabs), true)
        XCTAssertEqual(channel?.flags.contains(.displayForumAsSidebar), false)
    }

    func testSidebarComesWithTabs() {
        let channel = self.channel(flags2: (1 << 19) | (1 << 23))
        XCTAssertEqual(channel?.flags.contains(.displayForumAsTabs), true)
        XCTAssertEqual(channel?.flags.contains(.displayForumAsSidebar), true)
    }

    func testSidebarFlagSurvivesPostboxCoding() {
        guard let channel = self.channel(flags2: (1 << 19) | (1 << 23)) else {
            XCTFail("not a channel")
            return
        }
        let encoder = PostboxEncoder()
        channel.encode(encoder)
        let decoded = TelegramChannel(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertTrue(decoded.flags.contains(.displayForumAsSidebar))
    }

    private func bot(flags2: Int32) -> TelegramUser {
        let flags: Int32 = (1 << 0) | (1 << 1) | (1 << 14)
        return TelegramUser(user: .user(.init(flags: flags, flags2: flags2, id: 1234, accessHash: 1, firstName: "Bot", lastName: nil, username: nil, phone: nil, photo: nil, status: nil, botInfoVersion: 1, restrictionReason: nil, botInlinePlaceholder: nil, langCode: nil, emojiStatus: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, botActiveUsers: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedCommunityId: nil)))
    }

    private func minBot() -> Api.User {
        let flags: Int32 = (1 << 0) | (1 << 1) | (1 << 14) | (1 << 20)
        return .user(.init(flags: flags, flags2: 0, id: 1234, accessHash: 1, firstName: "Bot", lastName: nil, username: nil, phone: nil, photo: nil, status: nil, botInfoVersion: 1, restrictionReason: nil, botInlinePlaceholder: nil, langCode: nil, emojiStatus: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, botActiveUsers: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedCommunityId: nil))
    }

    func testMinUpdateKeepsStoredBotForumFlags() {
        let stored = self.bot(flags2: (1 << 16) | (1 << 17) | (1 << 22))
        let flags = TelegramUser.merge(stored, rhs: self.minBot())?.botInfo?.flags
        XCTAssertEqual(flags?.contains(.hasForum), true)
        XCTAssertEqual(flags?.contains(.forumManagedByUser), true)
        XCTAssertEqual(flags?.contains(.displayForumAsSidebar), true)
    }

    func testMinPeerMergeKeepsStoredBotForumFlags() {
        let stored = self.bot(flags2: (1 << 16) | (1 << 17) | (1 << 22))
        let flags = TelegramUser.merge(lhs: stored, rhs: TelegramUser(user: self.minBot())).botInfo?.flags
        XCTAssertEqual(flags?.contains(.hasForum), true)
        XCTAssertEqual(flags?.contains(.forumManagedByUser), true)
        XCTAssertEqual(flags?.contains(.displayForumAsSidebar), true)
    }

    func testFullUpdateClearsBotSidebarFlag() {
        let stored = self.bot(flags2: (1 << 16) | (1 << 22))
        let flags = TelegramUser.merge(stored, rhs: Api.User.user(.init(flags: (1 << 0) | (1 << 1) | (1 << 14), flags2: 1 << 16, id: 1234, accessHash: 1, firstName: "Bot", lastName: nil, username: nil, phone: nil, photo: nil, status: nil, botInfoVersion: 1, restrictionReason: nil, botInlinePlaceholder: nil, langCode: nil, emojiStatus: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, botActiveUsers: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedCommunityId: nil)))?.botInfo?.flags
        XCTAssertEqual(flags?.contains(.hasForum), true)
        XCTAssertEqual(flags?.contains(.displayForumAsSidebar), false)
    }

    func testBotForumWithoutSidebar() {
        let botInfo = self.bot(flags2: 1 << 16).botInfo
        XCTAssertEqual(botInfo?.flags.contains(.hasForum), true)
        XCTAssertEqual(botInfo?.flags.contains(.displayForumAsSidebar), false)
    }

    func testBotForumWithSidebar() {
        let botInfo = self.bot(flags2: (1 << 16) | (1 << 22)).botInfo
        XCTAssertEqual(botInfo?.flags.contains(.hasForum), true)
        XCTAssertEqual(botInfo?.flags.contains(.displayForumAsSidebar), true)
    }
}
