import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

/// The client's own Add to News / Remove from News own the stored `in_news` for a short while. Measured on K1: a
/// full-channel fetch sent when the chat opened landed after Add to News and stored the channel without `in_news`;
/// nothing fetched it again, so the channel read as not in News for minutes.
final class ChannelInNewsLocalChangeTests: XCTestCase {
    private let account = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
    private let otherAccount = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(2))
    private let channelId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1234))

    private func serverChannel(inNews: Bool, verified: Bool = false) -> TelegramChannel {
        var flags: Int32 = (1 << 5) | (1 << 2) // broadcast, left
        if verified {
            flags |= 1 << 7
        }
        let chat = Api.Chat.channel(.init(flags: flags, flags2: 0, id: 1234, accessHash: 5678, title: "News", username: nil, photo: .chatPhotoEmpty, date: 0, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: nil))
        let channel = parseTelegramGroupOrChannel(chat: chat) as! TelegramChannel
        guard inNews else {
            return channel
        }
        // Set directly: the parse of `in_news` is parked with the feed API (layer 232), and these cases test what the
        // client does with the flag, not the parse.
        var channelFlags = channel.flags
        channelFlags.insert(.isInNews)
        return channel.withUpdatedFlags(channelFlags)
    }

    func testARecordedChangeHoldsForTheWindow() {
        let changes = ChannelInNewsLocalChanges()
        changes.record(accountPeerId: self.account, channelId: self.channelId, isInNews: true, at: 100.0)
        XCTAssertEqual(changes.localInNews(accountPeerId: self.account, channelId: self.channelId, at: 100.0 + ChannelInNewsLocalChanges.window - 0.01), true)
        XCTAssertNil(changes.localInNews(accountPeerId: self.account, channelId: self.channelId, at: 100.0 + ChannelInNewsLocalChanges.window))
    }

    func testTheLatestChangeWins() {
        let changes = ChannelInNewsLocalChanges()
        changes.record(accountPeerId: self.account, channelId: self.channelId, isInNews: true, at: 100.0)
        changes.record(accountPeerId: self.account, channelId: self.channelId, isInNews: false, at: 102.0)
        XCTAssertEqual(changes.localInNews(accountPeerId: self.account, channelId: self.channelId, at: 103.0), false)
    }

    func testAnotherAccountIsUnaffected() {
        let changes = ChannelInNewsLocalChanges()
        changes.record(accountPeerId: self.account, channelId: self.channelId, isInNews: true, at: 100.0)
        XCTAssertNil(changes.localInNews(accountPeerId: self.otherAccount, channelId: self.channelId, at: 101.0))
    }

    // The stale response: a server channel without `in_news` after the client's own Add to News keeps the flag.
    func testAStaleServerChannelKeepsTheLocalAddToNews() {
        let stored = channelApplyingLocalInNews(self.serverChannel(inNews: false), localInNews: true)
        XCTAssertTrue(stored.flags.contains(.isInNews))
    }

    func testAStaleServerChannelKeepsTheLocalRemoveFromNews() {
        XCTAssertTrue(self.serverChannel(inNews: true).flags.contains(.isInNews), "an in-News server channel")
        let stored = channelApplyingLocalInNews(self.serverChannel(inNews: true), localInNews: false)
        XCTAssertFalse(stored.flags.contains(.isInNews))
    }

    func testWithoutALocalChangeTheServerDecides() {
        XCTAssertTrue(channelApplyingLocalInNews(self.serverChannel(inNews: true), localInNews: nil).flags.contains(.isInNews))
        XCTAssertFalse(channelApplyingLocalInNews(self.serverChannel(inNews: false), localInNews: nil).flags.contains(.isInNews))
    }

    func testOnlyInNewsChanges() {
        let server = self.serverChannel(inNews: false, verified: true)
        let stored = channelApplyingLocalInNews(server, localInNews: true)
        XCTAssertTrue(stored.flags.contains(.isVerified))
        XCTAssertEqual(stored.participationStatus, server.participationStatus)
        XCTAssertEqual(stored.title, server.title)
    }
}
