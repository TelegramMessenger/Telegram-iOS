import Foundation
import XCTest
import Intents
import Postbox
import TelegramCore
@testable import IntentsExtensionLib

/// Where a Siri "reply" (`INSendMessageIntent`) goes.
///
/// Once Siri reads group messages, its reply arrives with the group's `conversationIdentifier`
/// and the author as recipient. Sending to the recipient would put a group reply into the
/// author's private chat, so the conversation wins; and a broadcast channel is never a target,
/// even though Siri can read its posts.
final class SiriSendMessageTargetTests: XCTestCase {
    private func peerId(_ namespace: PeerId.Namespace, _ id: Int64) -> PeerId {
        return PeerId(namespace: namespace, id: PeerId.Id._internalFromInt64Value(id))
    }

    func testConversationIdentifierWinsOverTheRecipient() {
        let group = peerId(Namespaces.Peer.CloudGroup, 2001)
        let author = peerId(Namespaces.Peer.CloudUser, 1001)

        let target = siriSendMessageTarget(conversationIdentifier: "\(group.toInt64())", recipientCustomIdentifier: "tg\(author.toInt64())")

        XCTAssertEqual(target, group)
    }

    func testRecipientIsUsedWithoutAConversation() {
        let author = peerId(Namespaces.Peer.CloudUser, 1001)

        XCTAssertEqual(siriSendMessageTarget(conversationIdentifier: nil, recipientCustomIdentifier: "tg\(author.toInt64())"), author)
    }

    func testUnparsableIdentifiersNameNoTarget() {
        XCTAssertNil(siriSendMessageTarget(conversationIdentifier: "not-a-peer", recipientCustomIdentifier: nil))
        XCTAssertNil(siriSendMessageTarget(conversationIdentifier: nil, recipientCustomIdentifier: "device-contact-42"))
        XCTAssertNil(siriSendMessageTarget(conversationIdentifier: nil, recipientCustomIdentifier: nil))
    }

    /// The standalone send swallows the server's refusal, so a peer the user cannot write to
    /// must be refused up front or Siri reports the reply as sent.
    func testChatsTheUserCannotWriteToAreRefused() {
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.group(2001, title: "Left", membership: .Left)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.group(2002, title: "Removed", membership: .Removed)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.group(2003, title: "Read-only", defaultBannedRights: IntentMessageFixtures.noTextAllowed)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3001, title: "Left", participationStatus: .left)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3002, title: "Kicked", participationStatus: .kicked)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3003, title: "Restricted", bannedRights: IntentMessageFixtures.noTextAllowed)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3004, title: "Read-only", defaultBannedRights: IntentMessageFixtures.noTextAllowed)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3005, title: "Paid", sendPaidMessageStars: StarsAmount(value: 10, nanos: 0))))
    }

    func testUsersTheUserCannotWriteToAreRefused() {
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(1002, firstName: nil)), "deleted account")
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(777000, firstName: "Telegram")), "service notifications")
        let paid = CachedUserData().withUpdatedSendPaidMessageStars(StarsAmount(value: 5, nanos: 0))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(1003, firstName: "Paid"), cachedData: paid, accountIsPremium: true), "paid messages, whatever the account")
        let premiumOnly = CachedUserData().withUpdatedFlags([.premiumRequired])
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(1004, firstName: "Premium"), cachedData: premiumOnly, accountIsPremium: false), "premium required, account is not")
        XCTAssertTrue(peerAcceptsSiriMessages(IntentMessageFixtures.user(1004, firstName: "Premium"), cachedData: premiumOnly, accountIsPremium: true), "premium required, account is premium")
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(1005, firstName: "Gated", flags: [.requirePremium]), cachedData: nil, accountIsPremium: false), "no cached data, user flag says premium required")
        XCTAssertTrue(peerAcceptsSiriMessages(IntentMessageFixtures.user(1006, firstName: "Friend", flags: [.requirePremium, .mutualContact]), cachedData: nil, accountIsPremium: false), "mutual contacts are exempt")
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(1007, firstName: "Stars", flags: [.requireStars]), cachedData: nil, accountIsPremium: true), "no cached data, user flag says stars required")
    }

    func testBlockedUserIsRefused() {
        let blocked = CachedUserData().withUpdatedIsBlocked(true)

        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(1008, firstName: "Blocked"), cachedData: blocked, accountIsPremium: true))
    }

    /// Cached data is refreshed only when the chat is opened; the user's own flags arrive
    /// with every update. Either source saying the chat is gated is enough to refuse.
    func testFreshUserFlagsOverrideStaleCachedData() {
        let staleNoFee = CachedUserData()

        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(1009, firstName: "Stars", flags: [.requireStars]), cachedData: staleNoFee, accountIsPremium: true))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(1010, firstName: "Premium", flags: [.requirePremium]), cachedData: staleNoFee, accountIsPremium: false))
    }

    func testEveryServicePeerIsRefused() {
        for id: Int64 in [777000, 333000, 1271266957, 489000, 708513] {
            XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.user(id, firstName: "Service")), "\(id)")
        }
    }

    /// Messaging yourself (Saved Messages) is always allowed, whatever gates the account has
    /// set for others.
    func testTheAccountItselfIsNeverGated() {
        let me = IntentMessageFixtures.user(1011, firstName: "Me", flags: [.requirePremium, .requireStars])

        XCTAssertTrue(peerAcceptsSiriMessages(me, cachedData: nil, accountIsPremium: false, isAccountPeer: true))
        XCTAssertFalse(peerAcceptsSiriMessages(me, cachedData: nil, accountIsPremium: false, isAccountPeer: false))
    }

    func testMigratedOrDeactivatedLegacyGroupsAreRefused() {
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.group(2004, title: "Upgraded", migratedTo: peerId(Namespaces.Peer.CloudChannel, 3001))))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.group(2005, title: "Deactivated", flags: [.deactivated])))
    }

    func testPaidUserRecipientIsRefusedAtResolution() {
        let paid = CachedUserData().withUpdatedSendPaidMessageStars(StarsAmount(value: 5, nanos: 0))

        XCTAssertTrue(decisionIsRefused(siriRecipientDecision(for: IntentMessageFixtures.user(1003, firstName: "Paid"), cachedData: paid, accountIsPremium: true)))
    }

    /// `INMessage.conversationIdentifier` names the chat only, so a reply into a forum would
    /// land in the wrong topic; until the topic travels with it, forums are not a target.
    func testForumsAndMonoforumsAreNotATarget() {
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3006, title: "Forum", flags: [.isForum])))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3007, title: "Monoforum", flags: [.isMonoforum])))
    }

    func testUsersAndGroupsAcceptSiriMessagesButBroadcastChannelsDoNot() {
        XCTAssertTrue(peerAcceptsSiriMessages(IntentMessageFixtures.user(1001, firstName: "Alice")))
        XCTAssertTrue(peerAcceptsSiriMessages(IntentMessageFixtures.group(2001, title: "Group")))
        XCTAssertTrue(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3001, title: "Supergroup")))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.broadcastChannel(4001, title: "Channel")))
    }

    // MARK: - Recipient resolution

    private func decisionIsRefused(_ decision: SiriRecipientDecision) -> Bool {
        if case .refused = decision {
            return true
        }
        return false
    }

    private func person(in decision: SiriRecipientDecision) -> INPerson? {
        if case let .person(person) = decision {
            return person
        }
        return nil
    }

    /// Both ways Siri names a recipient - the conversation of a message it read, and a person
    /// this extension handed it earlier - are decided here, so a channel is refused at
    /// resolution and never reaches the send.
    func testBroadcastChannelRecipientIsRefused() {
        let channel = IntentMessageFixtures.broadcastChannel(4001, title: "Daily News")

        XCTAssertTrue(decisionIsRefused(siriRecipientDecision(for: channel)))
    }

    func testForumRecipientIsRefused() {
        XCTAssertTrue(decisionIsRefused(siriRecipientDecision(for: IntentMessageFixtures.supergroup(3006, title: "Forum", flags: [.isForum]))))
    }

    func testUnknownPeerNeedsAValue() {
        if case .unknown = siriRecipientDecision(for: nil) {
        } else {
            XCTFail("a peer that is not in the store cannot be refused or accepted")
        }
    }

    func testUserRecipientResolvesToThatUser() {
        let user = IntentMessageFixtures.user(1001, firstName: "Alice", phone: "15551234567")

        let person = self.person(in: siriRecipientDecision(for: user))

        XCTAssertEqual(person?.customIdentifier, "tg\(user.id.toInt64())")
        XCTAssertEqual(person?.displayName, "Alice")
    }

    func testGroupRecipientResolvesToAPersonNamedAfterTheGroup() {
        let group = IntentMessageFixtures.supergroup(3001, title: "Big Group")

        let person = self.person(in: siriRecipientDecision(for: group))

        XCTAssertEqual(person?.customIdentifier, "tg\(group.id.toInt64())")
        XCTAssertEqual(person?.displayName, "Big Group")
    }
}
