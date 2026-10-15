import Foundation
import XCTest
import Postbox
import TelegramCore
@testable import IntentsExtensionLib

/// Which messages Siri may read out at all. The account's own messages are not news to the
/// user, except a reminder: a scheduled message delivered to Saved Messages, which notifies
/// like a received one (bugs.telegram.org/c/66638).
final class IntentMessageReadabilityTests: XCTestCase {
    private let me = IntentMessageFixtures.user(1000, firstName: "Me")
    private let alice = IntentMessageFixtures.user(1001, firstName: "Alice")
    private let ride = IntentMessageFixtures.group(2001, title: "Weekend Ride")

    func testIncomingMessageIsReadable() {
        let message = IntentMessageFixtures.message(in: self.alice, author: self.alice)

        XCTAssertTrue(intentMessageIsReadable(message, accountPeerId: self.me.id))
    }

    func testOwnMessageInAPrivateChatIsNotReadable() {
        let message = IntentMessageFixtures.message(in: self.alice, author: self.me, flags: [])

        XCTAssertFalse(intentMessageIsReadable(message, accountPeerId: self.me.id))
    }

    func testOwnMessageInAGroupIsNotReadable() {
        let message = IntentMessageFixtures.message(in: self.ride, author: self.me, flags: [])

        XCTAssertFalse(intentMessageIsReadable(message, accountPeerId: self.me.id))
    }

    func testReminderInSavedMessagesIsReadable() {
        let message = IntentMessageFixtures.message(in: self.me, author: self.me, text: "call mum", flags: [.WasScheduled, .CountedAsIncoming])

        XCTAssertTrue(intentMessageIsReadable(message, accountPeerId: self.me.id))
    }

    func testOrdinarySavedMessageIsNotReadable() {
        let message = IntentMessageFixtures.message(in: self.me, author: self.me, flags: [])

        XCTAssertFalse(intentMessageIsReadable(message, accountPeerId: self.me.id))
    }

    /// A scheduled message the account sent to someone else is still the account's own.
    func testScheduledMessageSentToAnotherChatIsNotReadable() {
        let message = IntentMessageFixtures.message(in: self.alice, author: self.me, flags: [.WasScheduled, .CountedAsIncoming])

        XCTAssertFalse(intentMessageIsReadable(message, accountPeerId: self.me.id))
    }
}
