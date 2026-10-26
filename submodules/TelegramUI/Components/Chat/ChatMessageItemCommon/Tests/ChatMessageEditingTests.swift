import XCTest
import Postbox
import TelegramCore
import ChatMessageItemCommon

/// A message an anonymous admin sends has the group itself as its author. Only the sender's own
/// copy arrives with the server's `out` bit, which the store keeps as the absence of `.Incoming`,
/// so that bit is the one thing that tells the sender's copy apart from everybody else's.
final class ChatMessageEditingTests: XCTestCase {
    private let limits = EngineConfiguration.Limits(LimitsConfiguration.defaultValue)
    private let groupId: Int64 = 500

    private var now: Int32 {
        return Int32(Date().timeIntervalSince1970)
    }

    private var recentTimestamp: Int32 {
        return self.now - 60
    }

    private var expiredTimestamp: Int32 {
        return self.now - self.limits.maxMessageEditingInterval - 60
    }

    /// Nobody may pin by default, so pinning comes only from `adminRights`.
    private func makeGroup(adminRights: TelegramChatAdminRightsFlags?) -> TelegramChannel {
        return makeChannel(
            id: self.groupId,
            info: .group(TelegramChannelGroupInfo(flags: TelegramChannelGroupFlags())),
            adminRights: adminRights.flatMap { TelegramChatAdminRights(rights: $0) },
            defaultBannedRights: TelegramChatBannedRights(flags: [.banPinMessages], untilDate: Int32.max)
        )
    }

    private func makeAnonymousMessage(in group: TelegramChannel, timestamp: Int32, isOutgoing: Bool) -> Message {
        return makeMessage(peer: group, author: group, timestamp: timestamp, isOutgoing: isOutgoing)
    }

    private func canEdit(_ message: Message) -> Bool {
        return canEditMessage(accountPeerId: accountPeerIdForTests, limitsConfiguration: self.limits, message: message)
    }

    // bugs.telegram.org/c/17782
    func testAnonymousAdminWithoutPinRightCanEditOwnRecentMessage() {
        let group = self.makeGroup(adminRights: [.canDeleteMessages, .canBeAnonymous])
        let message = self.makeAnonymousMessage(in: group, timestamp: self.recentTimestamp, isOutgoing: true)

        XCTAssertTrue(self.canEdit(message))
    }

    func testAnonymousAdminWithoutPinRightCannotEditOwnMessagePastTimeLimit() {
        let group = self.makeGroup(adminRights: [.canDeleteMessages, .canBeAnonymous])
        let message = self.makeAnonymousMessage(in: group, timestamp: self.expiredTimestamp, isOutgoing: true)

        XCTAssertFalse(self.canEdit(message))
    }

    func testAnonymousAdminWithPinRightCanEditOwnMessagePastTimeLimit() {
        let group = self.makeGroup(adminRights: [.canPinMessages, .canBeAnonymous])
        let message = self.makeAnonymousMessage(in: group, timestamp: self.expiredTimestamp, isOutgoing: true)

        XCTAssertTrue(self.canEdit(message))
    }

    func testPinRightDoesNotAllowEditingAnotherAdminsAnonymousMessage() {
        let group = self.makeGroup(adminRights: [.canPinMessages, .canBeAnonymous])
        let message = self.makeAnonymousMessage(in: group, timestamp: self.recentTimestamp, isOutgoing: false)

        XCTAssertFalse(self.canEdit(message))
    }

    /// `hasPermission(.pinMessages)` also holds for a plain member when members may pin.
    func testMemberInGroupWhereEveryoneMayPinCannotEditAnonymousMessage() {
        let group = makeChannel(id: self.groupId, info: .group(TelegramChannelGroupInfo(flags: TelegramChannelGroupFlags())))
        XCTAssertTrue(group.hasPermission(.pinMessages))
        let message = self.makeAnonymousMessage(in: group, timestamp: self.recentTimestamp, isOutgoing: false)

        XCTAssertFalse(self.canEdit(message))
    }

    /// The hardware-keyboard up-arrow opens the newest message this accepts, with no action filter
    /// of its own.
    func testOwnServiceMessageIsNotEditable() {
        let group = self.makeGroup(adminRights: nil)
        let message = makeMessage(peer: group, author: makeUser(id: 1), timestamp: self.recentTimestamp, isOutgoing: true, media: [TelegramMediaAction(action: .pinnedMessageUpdated)])

        XCTAssertFalse(self.canEdit(message))
    }

    func testAnonymousAdminServiceMessageIsNotEditable() {
        let group = self.makeGroup(adminRights: [.canChangeInfo, .canBeAnonymous])
        let message = makeMessage(peer: group, author: group, timestamp: self.recentTimestamp, isOutgoing: true, media: [TelegramMediaAction(action: .titleUpdated(title: "Renamed"))])

        XCTAssertFalse(self.canEdit(message))
    }
}
