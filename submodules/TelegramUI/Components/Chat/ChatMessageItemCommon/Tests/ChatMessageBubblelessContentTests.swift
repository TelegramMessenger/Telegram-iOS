import XCTest
import UIKit
import Display
import ChatMessageItemCommon

// The pure decisions the bubble-free content nodes read (spec 5.5, 5.12): what hides its time, where a caption starts,
// how far media may grow, how large emoji sit, where stickers and a failed message's icon go.
final class ChatMessageBubblelessContentTests: XCTestCase {
    func testStatusFollowsTheStyle() {
        XCTAssertTrue(ChatMessageBubbleStyle.bubbleless.hidesIncomingStatus)
        XCTAssertTrue(ChatMessageBubbleStyle.bubblelessCard.hidesIncomingStatus)
        XCTAssertFalse(ChatMessageBubbleStyle.bubble.hidesIncomingStatus)
        XCTAssertFalse(ChatMessageBubbleStyle.bubblelessService.hidesIncomingStatus)
    }

    func testCaptionCapLineSitsABlockGapUnderMedia() {
        XCTAssertEqual(chatMessageBubblelessCaptionTopInset(ascender: 16.0, capHeight: 12.0), 4.0, accuracy: 0.001)
        XCTAssertEqual(chatMessageBubblelessCaptionTopInset(ascender: 30.0, capHeight: 12.0), 0.0, accuracy: 0.001)
    }

    func testMediaGrowsToTheColumnOnPhones() {
        let size = chatMessageBubblelessMediaMaxDimensions(CGSize(width: 300.0, height: 380.0), columnWidth: 335.0, isChannelPost: false, bubbleMaxWidth: 366.0)
        XCTAssertEqual(size, CGSize(width: 335.0, height: 380.0))
    }

    func testChannelMediaScaleTheirHeight() {
        let size = chatMessageBubblelessMediaMaxDimensions(CGSize(width: 300.0, height: 380.0), columnWidth: 335.0, isChannelPost: true, bubbleMaxWidth: 366.0)
        XCTAssertEqual(size, CGSize(width: 335.0, height: 424.0))
    }

    // 5.12: a channel's media is never taller than a bubble at that width would allow.
    func testMediaStaysWithinTheBubbleCap() {
        let size = chatMessageBubblelessMediaMaxDimensions(CGSize(width: 300.0, height: 380.0), columnWidth: 370.0, isChannelPost: true, bubbleMaxWidth: 366.0)
        XCTAssertEqual(size, CGSize(width: 370.0, height: 463.0))
    }

    func testNarrowColumnsKeepMediaSize() {
        let size = chatMessageBubblelessMediaMaxDimensions(CGSize(width: 300.0, height: 380.0), columnWidth: 250.0, isChannelPost: true, bubbleMaxWidth: 366.0)
        XCTAssertEqual(size, CGSize(width: 300.0, height: 380.0))
    }

    func testLargeEmojiInsets() {
        let plain = chatMessageBubblelessLargeEmojiInsets(emojiHeight: 100.0, hasReactions: false, underHeader: false)
        XCTAssertEqual(plain.top, 0.0)
        XCTAssertEqual(plain.bottom, -11.0)
        XCTAssertEqual(plain.headerOverlap, 0.0)
        let reacted = chatMessageBubblelessLargeEmojiInsets(emojiHeight: 100.0, hasReactions: true, underHeader: false)
        XCTAssertEqual(reacted.bottom, 0.0)
        let headed = chatMessageBubblelessLargeEmojiInsets(emojiHeight: 100.0, hasReactions: false, underHeader: true)
        XCTAssertEqual(headed.headerOverlap, 10.0)
    }

    func testStickerInsetLandsOnTheColumn() {
        XCTAssertEqual(chatMessageBubblelessStickerInset(hasAvatarColumn: true, edgeInset: 3.0, contentInsetLeft: 6.0, transparentInset: 10.0), 32.0)
        XCTAssertEqual(chatMessageBubblelessStickerInset(hasAvatarColumn: false, edgeInset: 3.0, contentInsetLeft: 6.0, transparentInset: 10.0), -3.0)
    }

    func testDeliveryFailedIconTakesTheVisibleEdge() {
        let short = chatMessageBubblelessDeliveryFailedFrame(iconSize: CGSize(width: 22.0, height: 22.0), contentFrame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 20.0), inset: 28.0)
        XCTAssertEqual(short.minX, 206.0)
        XCTAssertEqual(short.minY, -1.0)
        let tall = chatMessageBubblelessDeliveryFailedFrame(iconSize: CGSize(width: 22.0, height: 22.0), contentFrame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 100.0), inset: 28.0)
        XCTAssertEqual(tall.minY, floorToScreenPixels(72.5))
        XCTAssertEqual(tall.size, CGSize(width: 22.0, height: 22.0))
    }
}
