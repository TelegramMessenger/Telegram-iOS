import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getMessages = "messages.getMessages"

/// Api values only these tests need.
private enum PeerMergeApi {
    /// `user#b1b8cc83` as `StateSyncApi.user`, with `min` (flags.20): the copy the server sends where the
    /// account may not see the full user. `TelegramUser.merge` keeps the stored user's name and access hash
    /// for it.
    static func minUser(id: Int64, accessHash: Int64, firstName: String) -> Api.User {
        let flags: Int32 = (1 << 0) | (1 << 1) | (1 << 20)
        return .user(.init(flags: flags, flags2: 0, id: id, accessHash: accessHash, firstName: firstName, lastName: nil, username: nil, phone: nil, photo: nil, status: nil, botInfoVersion: nil, restrictionReason: nil, botInlinePlaceholder: nil, langCode: nil, emojiStatus: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, botActiveUsers: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedCommunityId: nil))
    }

    /// `channel#d49f34c6` as `StateSyncApi.broadcastChannel`, with `min` (flags.12). Parsed on its own
    /// (`parseTelegramGroupOrChannel`), its access hash is `.genericPublic`.
    static func minBroadcastChannel(id: Int64, accessHash: Int64, title: String) -> Api.Chat {
        let flags: Int32 = (1 << 5) | (1 << 12) | (1 << 13)
        return .channel(.init(flags: flags, flags2: 0, id: id, accessHash: accessHash, title: title, username: nil, photo: .chatPhotoEmpty, date: 1, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: nil))
    }
}

/// How a history fill merges the peers of its answer with those of its confirmation (owner decision D3,
/// 2026-10-15). The confirmation answered later, so its copy of a peer wins, except that a min copy never
/// replaces a full copy. The fills are driven directly, as ManagedMessageHistoryHoles starts them; no state
/// manager runs.
final class HistoryFillPeerMergeTests: StateSyncTestCase {
    /// The fill's answer carries user 500 and channel 900 in full; the confirmation of candidate 11 carries
    /// min copies of both. The full copies are stored. Before D3 the min copies won the merge: the user's was
    /// then merged with the stored "U500" (a min copy keeps the stored name and access hash) and the channel's
    /// replaced the full copy outright.
    func testMinCopiesInTheConfirmationNeverReplaceTheFillsFullCopies() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        let channelId = StateSyncFixture.channelPeerId(900)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11])
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ], chats: [StateSyncApi.broadcastChannel(id: 900, accessHash: 77, title: "From the fill")], users: [StateSyncApi.user(id: 500, accessHash: 77, firstName: "From the fill")])))
        self.server.on(getMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 11, peerUserId: 500, fromUserId: 500, date: self.baseDate + 11)
        ], chats: [PeerMergeApi.minBroadcastChannel(id: 900, accessHash: 99, title: "From the confirmation")], users: [PeerMergeApi.minUser(id: 500, accessHash: 99, firstName: "From the confirmation")])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        let user = self.fixture.peer(peerId) as? TelegramUser
        XCTAssertEqual(user?.firstName, "From the fill", "the confirmation's min copy of the user replaced the fill's full copy")
        XCTAssertEqual(user?.accessHash, .personal(77))
        let channel = self.fixture.peer(channelId) as? TelegramChannel
        XCTAssertEqual(channel?.title, "From the fill", "the confirmation's min copy of the channel replaced the fill's full copy")
        XCTAssertEqual(channel?.accessHash, .personal(77))
    }

    /// The confirmation of candidate 11 carries channel 900, which the account administers, only as a min copy (as
    /// an answer carries the source of a forward), and the fill's answer does not carry the channel at all. The
    /// stored channel keeps its admin rights: the min copy is merged with it when the answer is read
    /// (`mergeGroupOrChannel`), as the fill's own peers are, and updates only what a min copy carries. Before the fix
    /// the confirmation parsed its chats on their own; the write's own merge (`mergeChannel` in `updatePeersCustom`)
    /// kept the access hash and membership but took the min copy's empty admin rights.
    func testMinChannelInTheConfirmationIsMergedWithTheStoredChannel() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        let channelId = StateSyncFixture.channelPeerId(900)
        let adminRights = TelegramChatAdminRights(rights: [.canChangeInfo, .canPostMessages])
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: channelId, accessHash: 77, title: "C900", adminRights: adminRights), state: nil)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11])
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ])))
        self.server.on(getMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 11, peerUserId: 500, fromUserId: 500, date: self.baseDate + 11)
        ], chats: [PeerMergeApi.minBroadcastChannel(id: 900, accessHash: 99, title: "From the confirmation")])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        let channel = self.fixture.peer(channelId) as? TelegramChannel
        XCTAssertEqual(channel?.adminRights, adminRights, "the confirmation's min copy of the channel dropped the stored admin rights")
        XCTAssertEqual(channel?.accessHash, .personal(77))
        XCTAssertEqual(channel?.title, "From the confirmation", "a min copy still updates what it carries")
    }

    /// Pin: a full copy in the confirmation wins over the fill's min copy, as before D3 (the newer copy wins).
    func testFullCopyInTheConfirmationReplacesTheFillsMinCopy() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11])
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ], users: [PeerMergeApi.minUser(id: 500, accessHash: 77, firstName: "From the fill")])))
        self.server.on(getMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 11, peerUserId: 500, fromUserId: 500, date: self.baseDate + 11)
        ], users: [StateSyncApi.user(id: 500, accessHash: 99, firstName: "From the confirmation")])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        let user = self.fixture.peer(peerId) as? TelegramUser
        XCTAssertEqual(user?.firstName, "From the confirmation")
        XCTAssertEqual(user?.accessHash, .personal(99))
    }
}
