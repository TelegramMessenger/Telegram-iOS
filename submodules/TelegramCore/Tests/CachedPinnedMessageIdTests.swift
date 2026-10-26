import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

/// Every `channel` constructor carries `pinned_msg_id`. It is kept as a cache in `CachedChannelData.pinnedMessageId`,
/// which the chat shows as a pinned skeleton until its pinned list has loaded.
final class CachedPinnedMessageIdTests: XCTestCase {
    private let channelId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1234))

    private func apiChannel(pinnedMsgId: Int32?, isMin: Bool = false) -> Api.Chat {
        var flags: Int32 = 1 << 5 // broadcast
        if isMin {
            flags |= 1 << 12
        }
        let flags2: Int32 = pinnedMsgId != nil ? 1 << 22 : 0
        return Api.Chat.channel(.init(flags: flags, flags2: flags2, id: 1234, accessHash: isMin ? nil : 5678, title: "News", username: nil, photo: .chatPhotoEmpty, date: 0, restrictionReason: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, participantsCount: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, emojiStatus: nil, level: nil, subscriptionUntilDate: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedMonoforumId: nil, linkedCommunityId: nil, pinnedMsgId: pinnedMsgId))
    }

    private func messageId(_ id: Int32) -> MessageId {
        return MessageId(peerId: self.channelId, namespace: Namespaces.Message.Cloud, id: id)
    }

    func testFullConstructorWithThePinSetsIt() {
        XCTAssertEqual(cachedPinnedMessageIdUpdate(chat: self.apiChannel(pinnedMsgId: 42)), .set(42))
    }

    // The field is in every channel constructor: a full one without it says nothing is pinned.
    func testFullConstructorWithoutThePinClearsIt() {
        XCTAssertEqual(cachedPinnedMessageIdUpdate(chat: self.apiChannel(pinnedMsgId: nil)), .clear)
    }

    // A min constructor is partial: it neither sets nor clears.
    func testMinConstructorLeavesItAlone() {
        XCTAssertNil(cachedPinnedMessageIdUpdate(chat: self.apiChannel(pinnedMsgId: nil, isMin: true)))
        XCTAssertNil(cachedPinnedMessageIdUpdate(chat: self.apiChannel(pinnedMsgId: 42, isMin: true)))
    }

    func testOtherConstructorsLeaveItAlone() {
        let forbidden = Api.Chat.channelForbidden(.init(flags: 1 << 5, id: 1234, accessHash: 5678, title: "News", untilDate: nil))
        XCTAssertNil(cachedPinnedMessageIdUpdate(chat: forbidden))
    }

    func testSetCreatesMissingCachedData() {
        let updated = cachedChannelData(applying: .set(42), peerId: self.channelId, to: nil)
        XCTAssertEqual(updated?.pinnedMessageId, self.messageId(42))
        // The chat's cached-data view hands over the messages in `messageIds`: the stored pinned message among them.
        XCTAssertEqual(updated?.messageIds.contains(self.messageId(42)), true)
    }

    func testSetReplacesADifferentId() {
        let current = CachedChannelData().withUpdatedPinnedMessageId(self.messageId(7))
        XCTAssertEqual(cachedChannelData(applying: .set(42), peerId: self.channelId, to: current)?.pinnedMessageId, self.messageId(42))
    }

    // `updatePeerCachedData` writes and notifies for any non-nil return, so an unchanged value must return nil.
    func testSetWithTheSameIdWritesNothing() {
        let current = CachedChannelData().withUpdatedPinnedMessageId(self.messageId(42))
        XCTAssertNil(cachedChannelData(applying: .set(42), peerId: self.channelId, to: current))
    }

    func testClearWithoutCachedDataCreatesNothing() {
        XCTAssertNil(cachedChannelData(applying: .clear, peerId: self.channelId, to: nil))
    }

    func testClearEmptiesThePin() {
        let current = CachedChannelData().withUpdatedPinnedMessageId(self.messageId(42))
        let updated = cachedChannelData(applying: .clear, peerId: self.channelId, to: current)
        XCTAssertNotNil(updated)
        XCTAssertNil(updated?.pinnedMessageId)
    }

    func testClearWithNothingPinnedWritesNothing() {
        XCTAssertNil(cachedChannelData(applying: .clear, peerId: self.channelId, to: CachedChannelData()))
    }
}
