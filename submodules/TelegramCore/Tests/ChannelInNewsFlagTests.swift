import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

final class ChannelInNewsFlagTests: XCTestCase {
    private func apiChannel(flags2: Int32, isMin: Bool = false) -> Api.Chat {
        var flags: Int32 = 1 << 5 // broadcast
        if isMin {
            flags |= 1 << 12
        }
        return Api.Chat.channel(.init(flags: flags, flags2: flags2, id: 1234, accessHash: isMin ? nil : 5678, title: "News", username: nil, photo: .chatPhotoEmpty, date: 0, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil))
    }

    func testInNewsBitMapsToFlag() {
        let channel = parseTelegramGroupOrChannel(chat: self.apiChannel(flags2: 1 << 21)) as? TelegramChannel
        XCTAssertEqual(channel?.flags.contains(.isInNews), true)
    }

    func testMissingBitLeavesFlagClear() {
        let channel = parseTelegramGroupOrChannel(chat: self.apiChannel(flags2: 0)) as? TelegramChannel
        XCTAssertEqual(channel?.flags.contains(.isInNews), false)
    }

    func testFlagSurvivesPostboxCoding() {
        guard let channel = parseTelegramGroupOrChannel(chat: self.apiChannel(flags2: 1 << 21)) as? TelegramChannel else {
            XCTFail("not a channel")
            return
        }
        let encoder = PostboxEncoder()
        channel.encode(encoder)
        let decoded = TelegramChannel(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertTrue(decoded.flags.contains(.isInNews))
    }

    // `in_news` is per-user state that a min constructor does not carry: a min update keeps the stored value.
    func testMinUpdateKeepsStoredFlag() {
        guard let stored = parseTelegramGroupOrChannel(chat: self.apiChannel(flags2: 1 << 21)) as? TelegramChannel else {
            XCTFail("not a channel")
            return
        }
        let merged = mergeGroupOrChannel(lhs: stored, rhs: self.apiChannel(flags2: 0, isMin: true)) as? TelegramChannel
        XCTAssertEqual(merged?.flags.contains(.isInNews), true)
    }
}
