import XCTest
import ChatTextInputPanelNode

// The composer shows the bot's Start button in place of its input in a bot chat with no messages yet (outside a
// thread) and in a blocked bot's chat, never among scheduled messages. The chat shows no input node (the bot's reply
// keyboard, the emoji keyboard) while it does: blocking a bot that has a reply keyboard up left the keyboard below Start.
final class BotStartButtonTests: XCTestCase {
    func testABlockedBotShowsStart() {
        XCTAssertTrue(chatDisplaysBotStartButton(isBot: true, isScheduledMessages: false, historyIsEmpty: false, isThread: false, peerIsBlocked: true))
        XCTAssertTrue(chatDisplaysBotStartButton(isBot: true, isScheduledMessages: false, historyIsEmpty: false, isThread: true, peerIsBlocked: true))
    }

    func testAnUnblockedBotWithMessagesShowsTheInput() {
        XCTAssertFalse(chatDisplaysBotStartButton(isBot: true, isScheduledMessages: false, historyIsEmpty: false, isThread: false, peerIsBlocked: false))
    }

    func testABotWithNoMessagesShowsStartOutsideAThread() {
        XCTAssertTrue(chatDisplaysBotStartButton(isBot: true, isScheduledMessages: false, historyIsEmpty: true, isThread: false, peerIsBlocked: false))
        XCTAssertFalse(chatDisplaysBotStartButton(isBot: true, isScheduledMessages: false, historyIsEmpty: true, isThread: true, peerIsBlocked: false))
    }

    func testScheduledMessagesAndOtherPeersNeverShowStart() {
        XCTAssertFalse(chatDisplaysBotStartButton(isBot: true, isScheduledMessages: true, historyIsEmpty: true, isThread: false, peerIsBlocked: true))
        XCTAssertFalse(chatDisplaysBotStartButton(isBot: false, isScheduledMessages: false, historyIsEmpty: true, isThread: false, peerIsBlocked: true))
    }
}
