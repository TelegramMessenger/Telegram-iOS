import Foundation
import XCTest
import Intents
import Postbox
import TelegramCore
@testable import IntentsExtensionLib

/// How a Telegram message becomes the `INMessage` Siri reads out in CarPlay or over AirPods.
///
/// Group and channel messages used to be dropped or mis-described here: the unread search
/// looked at private chats only, so CarPlay's tap-to-read on a group notification produced
/// "You don't have new messages" (bugs.telegram.org/c/11135), and a group message carried no
/// group name, so Siri would have presented it as a private message from its author.
final class IntentMessageConversionTests: XCTestCase {
    func testGroupMessageIsAttributedToItsAuthorInsideTheGroup() {
        let author = IntentMessageFixtures.user(1001, firstName: "Alice")
        let group = IntentMessageFixtures.group(2001, title: "Weekend Ride")
        let message = IntentMessageFixtures.message(in: group, author: author, text: "leaving at 9")

        let intentMessage = messageWithTelegramMessage(message)

        XCTAssertNotNil(intentMessage)
        XCTAssertEqual(intentMessage?.sender?.displayName, "Alice")
        XCTAssertEqual(intentMessage?.groupName?.spokenPhrase, "Weekend Ride")
        XCTAssertEqual(intentMessage?.conversationIdentifier, "\(group.id.toInt64())")
        XCTAssertEqual(intentMessage?.content, "leaving at 9")
    }

    func testSupergroupMessageCarriesTheGroupName() {
        let author = IntentMessageFixtures.user(1001, firstName: "Alice")
        let group = IntentMessageFixtures.supergroup(3001, title: "Big Group")
        let message = IntentMessageFixtures.message(in: group, author: author)

        let intentMessage = messageWithTelegramMessage(message)

        XCTAssertEqual(intentMessage?.sender?.displayName, "Alice")
        XCTAssertEqual(intentMessage?.groupName?.spokenPhrase, "Big Group")
    }

    func testAnonymousAdminMessageIsSentByTheGroupWithoutRepeatingItsName() {
        let group = IntentMessageFixtures.supergroup(3001, title: "Big Group")
        let message = IntentMessageFixtures.message(in: group, author: group, text: "pinned rules")

        let intentMessage = messageWithTelegramMessage(message)

        XCTAssertNotNil(intentMessage)
        XCTAssertEqual(intentMessage?.sender?.displayName, "Big Group")
        XCTAssertNil(intentMessage?.groupName)
    }

    func testChannelPostIsSentByTheChannel() {
        let channel = IntentMessageFixtures.broadcastChannel(4001, title: "Daily News")
        let message = IntentMessageFixtures.message(in: channel, author: channel, text: "headline")

        let intentMessage = messageWithTelegramMessage(message)

        XCTAssertNotNil(intentMessage)
        XCTAssertEqual(intentMessage?.sender?.displayName, "Daily News")
        XCTAssertEqual(intentMessage?.sender?.customIdentifier, "tg\(channel.id.toInt64())")
        XCTAssertNil(intentMessage?.groupName)
        XCTAssertEqual(intentMessage?.conversationIdentifier, "\(channel.id.toInt64())")
    }

    func testPrivateMessageHasNoGroupName() {
        let author = IntentMessageFixtures.user(1001, firstName: "Alice", phone: "15551234567")
        let message = IntentMessageFixtures.message(in: author, author: author)

        let intentMessage = messageWithTelegramMessage(message)

        XCTAssertEqual(intentMessage?.sender?.displayName, "Alice")
        XCTAssertNil(intentMessage?.groupName)
    }

    /// Siri matches the sender it read a message from against the recipient it resolves for
    /// the reply by handle, so both must describe a user the same way.
    func testSenderIsDescribedLikeAResolvedRecipient() {
        let author = IntentMessageFixtures.user(1001, firstName: "Alice", phone: "15551234567")
        let message = IntentMessageFixtures.message(in: author, author: author)

        let sender = messageWithTelegramMessage(message)?.sender
        let recipient = personWithUser(stableId: "tg\(author.id.toInt64())", user: author)

        XCTAssertEqual(sender?.personHandle?.value, recipient.personHandle?.value)
        XCTAssertEqual(sender?.personHandle?.type, recipient.personHandle?.type)
        XCTAssertEqual(sender?.displayName, recipient.displayName)
        XCTAssertEqual(sender?.customIdentifier, recipient.customIdentifier)
    }

    func testServiceNotificationsAreNotReadOut() {
        let service = IntentMessageFixtures.user(777000, firstName: "Telegram")
        let message = IntentMessageFixtures.message(in: service, author: service, text: "Login code: 12345")

        XCTAssertNil(messageWithTelegramMessage(message))
    }

    func testUnreadSearchCoversUsersGroupsAndChannelsButNotSecretChats() {
        XCTAssertTrue(unreadMessagesIncludePeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))))
        XCTAssertTrue(unreadMessagesIncludePeer(PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(1))))
        XCTAssertTrue(unreadMessagesIncludePeer(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1))))
        XCTAssertFalse(unreadMessagesIncludePeer(PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(1))))
    }
}
