import XCTest
import UIKit
import Postbox
import TelegramCore
import ChatMessageItemCommon

// Where things go without bubbles when a status, a header or a strip moves (step 3's final review): reactions a hidden
// status held, the strip the chat tears around content this build cannot show, the header a run starts with, a contact
// block's text.
final class ChatMessageBubblelessPlacementTests: XCTestCase {
    private func placement(style: ChatMessageBubbleStyle = .bubbleless, hasReactions: Bool = true, statusHeldReactions: Bool = true, hasReactionsFooter: Bool = false, endsWithComments: Bool = false, hasSeparateContainers: Bool = false) -> ChatMessageBubblelessReactionsPlacement {
        return chatMessageBubblelessReactionsPlacement(style: style, hasReactions: hasReactions, statusHeldReactions: statusHeldReactions, hasReactionsFooter: hasReactionsFooter, endsWithComments: endsWithComments, hasSeparateContainers: hasSeparateContainers)
    }

    func testReactionsAStatusHeldGetARow() {
        XCTAssertEqual(self.placement(), .row)
    }

    // A widget with a caption is a card whose text hides its status.
    func testACaptionedCardKeepsItsReactions() {
        XCTAssertEqual(self.placement(style: .bubblelessCard), .row)
    }

    // A game or an invoice under a comments row.
    func testReactionsStandAboveACommentsRow() {
        XCTAssertEqual(self.placement(style: .bubblelessCard, endsWithComments: true), .footer)
        XCTAssertEqual(self.placement(endsWithComments: true), .footer)
    }

    // An album of documents or tracks: each file in its own container, the last one's status held the reactions.
    func testAFileAlbumTakesAReactionsFooter() {
        XCTAssertEqual(self.placement(hasSeparateContainers: true), .footer)
        XCTAssertEqual(self.placement(endsWithComments: true, hasSeparateContainers: true), .footer)
    }

    func testMastersPlacementStandsOtherwise() {
        XCTAssertEqual(self.placement(style: .bubble), .unchanged)
        XCTAssertEqual(self.placement(style: .bubblelessService), .unchanged)
        XCTAssertEqual(self.placement(hasReactions: false), .unchanged)
        XCTAssertEqual(self.placement(hasReactionsFooter: true), .unchanged)
        XCTAssertEqual(self.placement(statusHeldReactions: false), .unchanged)
    }

    func testOnlyAMessageThisBuildCannotShowTearsTheChat() {
        let zones = [CGRect(x: 0.0, y: 10.0, width: 300.0, height: 80.0)]
        XCTAssertEqual(chatMessageBubblelessTornStripZones(style: .bubbleless, isUnsupportedMessage: true, zones: zones), zones)
        // A rich page's unsupported blocks keep their pill.
        XCTAssertEqual(chatMessageBubblelessTornStripZones(style: .bubbleless, isUnsupportedMessage: false, zones: zones), [])
        XCTAssertEqual(chatMessageBubblelessTornStripZones(style: .bubble, isUnsupportedMessage: true, zones: zones), [])
    }

    // Stickers and large emoji are headed by the rule text is (spec 3.2, 5.4).
    func testRunsAreHeadedOutsideSecretChats() {
        let group = makeGroupChannel(id: 100).id
        XCTAssertTrue(chatMessageBubblelessHeadsRow(isMergedWithPrevious: false, isChannelPostWithoutProfiles: false, chatPeerId: group))
        XCTAssertFalse(chatMessageBubblelessHeadsRow(isMergedWithPrevious: true, isChannelPostWithoutProfiles: false, chatPeerId: group))
        XCTAssertFalse(chatMessageBubblelessHeadsRow(isMergedWithPrevious: false, isChannelPostWithoutProfiles: false, chatPeerId: makeSecretChat(id: 4, with: 2).id))
    }

    func testChannelPostsWithoutProfilesAreHeadedEveryTime() {
        let channel = makeBroadcastChannel(id: 9, messagesShouldHaveProfiles: false)
        XCTAssertTrue(chatMessageBubblelessIsChannelPostWithoutProfiles(chatPeer: EnginePeer(channel)))
        XCTAssertTrue(chatMessageBubblelessHeadsRow(isMergedWithPrevious: true, isChannelPostWithoutProfiles: true, chatPeerId: channel.id))
        XCTAssertFalse(chatMessageBubblelessIsChannelPostWithoutProfiles(chatPeer: EnginePeer(makeBroadcastChannel(id: 10, messagesShouldHaveProfiles: true))))
        XCTAssertFalse(chatMessageBubblelessIsChannelPostWithoutProfiles(chatPeer: EnginePeer(makeGroupChannel(id: 11))))
        XCTAssertFalse(chatMessageBubblelessIsChannelPostWithoutProfiles(chatPeer: nil))
    }

    // The name and number start past the accent line, the avatar and their padding, and keep the same padding from the
    // block's right edge.
    func testContactTextKeepsTheBlocksPaddingOnBothSides() {
        let insets = chatMessageBubblelessContactTextInsets(lineWidth: 3.0, avatarWidth: 40.0)
        XCTAssertEqual(insets.leading, 63.0)
        XCTAssertEqual(insets.trailing, 10.0)
    }
}
