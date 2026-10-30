import XCTest
import UIKit
import Display
import TelegramCore
import ChatMessageItemCommon

// Selection and highlight without bubbles (spec 5.8): where the checkmark sits and stays, how far content shifts, and
// the rounded bands behind selected and highlighted rows.
final class ChatMessageBubblelessSelectionTests: XCTestCase {
    func testCheckX() {
        XCTAssertEqual(chatMessageBubblelessSelectionCheckX, 14.0)
        XCTAssertEqual(chatMessageSelectionCheckSize, 28.0)
    }

    func testContentOffsets() {
        XCTAssertEqual(chatMessageSelectionContentOffset(incoming: true, bubbleMode: true), 42.0)
        XCTAssertEqual(chatMessageSelectionContentOffset(incoming: true, bubbleMode: false), 42.0)
        XCTAssertEqual(chatMessageSelectionContentOffset(incoming: false, bubbleMode: true), 0.0)
        XCTAssertEqual(chatMessageSelectionContentOffset(incoming: false, bubbleMode: false), -6.0)
    }

    func testCheckCentres() {
        XCTAssertEqual(chatMessageBubblelessCheckCenterY(.lead(centerY: 30.0)), 30.0)
        XCTAssertEqual(chatMessageBubblelessCheckCenterY(.forwardHeader(top: 10.0, lineHeight: 18.0)), 19.0)
        XCTAssertEqual(chatMessageBubblelessCheckCenterY(.firstTextLine(top: 6.33, lineHeight: 20.4)), 6.33 + 10.5, accuracy: 0.0001)
        XCTAssertEqual(chatMessageBubblelessCheckCenterY(.block(top: 4.0)), 21.0)
        XCTAssertEqual(chatMessageBubblelessCheckCenterY(.bubble(CGRect(x: 100.0, y: 10.0, width: 200.0, height: 20.0))), 20.0)
        XCTAssertEqual(chatMessageBubblelessCheckCenterY(.bubble(CGRect(x: 100.0, y: 10.0, width: 200.0, height: 100.0))), 27.5)
        XCTAssertEqual(chatMessageBubblelessCheckCenterY(.strip(CGRect(x: 0.0, y: 0.0, width: 402.0, height: 120.0))), 60.0)
    }

    // The check of a message taller than the screen stays 17pt under the visible top, level with the parked avatar,
    // and never leaves its row.
    func testStickyCheckStaysBelowTheTopAndInsideTheRow() {
        XCTAssertEqual(chatMessageBubblelessStickyCheckY(checkY: 10.0, visibleTop: 100.0, rowHeight: 600.0), 103.0)
        XCTAssertEqual(chatMessageBubblelessStickyCheckY(checkY: 200.0, visibleTop: 100.0, rowHeight: 600.0), 200.0)
        XCTAssertEqual(chatMessageBubblelessStickyCheckY(checkY: 10.0, visibleTop: 100.0, rowHeight: 120.0), 88.0)
        XCTAssertEqual(chatMessageBubblelessStickyCheckY(checkY: 10.0, visibleTop: -CGFloat.greatestFiniteMagnitude, rowHeight: 600.0), 10.0)
    }

    func testBandFrameKeepsToTheSafeEdges() {
        XCTAssertEqual(chatMessageBubblelessRowBandFrame(rowSize: CGSize(width: 402.0, height: 80.0), leftSafeInset: 0.0, rightSafeInset: 0.0, top: 6.0), CGRect(x: 8.0, y: 6.0, width: 386.0, height: 74.0))
        let landscape = chatMessageBubblelessRowBandFrame(rowSize: CGSize(width: 402.0, height: 80.0), leftSafeInset: 59.0, rightSafeInset: 59.0, top: 0.0)
        XCTAssertEqual(landscape.minX, 67.0)
        XCTAssertEqual(landscape.width, 268.0)
    }

    // A band leaves out the date header; its first row starts 5.5pt above the name, or just under the spacing without one.
    func testBandTop() {
        XCTAssertEqual(chatMessageBubblelessRowBandTop(dateHeaderInset: 30.0, nameTop: 20.0, layoutTopInset: 8.0, joinsAbove: false), 30.0)
        XCTAssertEqual(chatMessageBubblelessRowBandTop(dateHeaderInset: 30.0, nameTop: 40.0, layoutTopInset: 8.0, joinsAbove: false), 34.5)
        XCTAssertEqual(chatMessageBubblelessRowBandTop(dateHeaderInset: 0.0, nameTop: nil, layoutTopInset: 8.0, joinsAbove: false), 7.34, accuracy: 0.0001)
        XCTAssertEqual(chatMessageBubblelessRowBandTop(dateHeaderInset: 0.0, nameTop: 40.0, layoutTopInset: 8.0, joinsAbove: true), 0.0)
    }

    func testBandRadius() {
        XCTAssertEqual(chatMessageBubblelessRowBandCornerRadius(mainRadius: 16.0, height: 100.0), 24.0)
        XCTAssertEqual(chatMessageBubblelessRowBandCornerRadius(mainRadius: 16.0, height: 30.0), 15.0)
    }

    func testJoins() {
        XCTAssertEqual(chatMessageBubblelessBandJoins(isSelected: true, aboveSelected: true, belowSelected: true, headerBetweenAbove: false, headerBetweenBelow: false), ChatMessageBubblelessBandJoins(above: true, below: true))
        XCTAssertEqual(chatMessageBubblelessBandJoins(isSelected: true, aboveSelected: true, belowSelected: true, headerBetweenAbove: false, headerBetweenBelow: true), ChatMessageBubblelessBandJoins(above: true, below: false))
        XCTAssertEqual(chatMessageBubblelessBandJoins(isSelected: false, aboveSelected: true, belowSelected: true, headerBetweenAbove: false, headerBetweenBelow: false), ChatMessageBubblelessBandJoins(above: false, below: false))
        XCTAssertEqual(chatMessageBubblelessBandJoins(isSelected: true, aboveSelected: false, belowSelected: true, headerBetweenAbove: false, headerBetweenBelow: false), ChatMessageBubblelessBandJoins(above: false, below: true))
    }

    func testRoundVideosAndStripsGetNoBand() {
        XCTAssertTrue(chatMessageBubblelessHasSelectionBand(bubbleMode: false, isRoundVideo: false, isTornStrip: false))
        XCTAssertFalse(chatMessageBubblelessHasSelectionBand(bubbleMode: false, isRoundVideo: true, isTornStrip: false))
        XCTAssertFalse(chatMessageBubblelessHasSelectionBand(bubbleMode: false, isRoundVideo: false, isTornStrip: true))
        XCTAssertFalse(chatMessageBubblelessHasHighlightBand(style: .bubbleless, isRoundVideo: true, isTornStrip: false, isQuoteOrTaskHighlight: false))
        XCTAssertFalse(chatMessageBubblelessHasHighlightBand(style: .bubbleless, isRoundVideo: false, isTornStrip: true, isQuoteOrTaskHighlight: false))
    }

    // Outgoing messages keep their bubble, and with it the bubble's flash.
    func testHighlightOnlyWithoutABubble() {
        XCTAssertTrue(chatMessageBubblelessHasHighlightBand(style: .bubbleless, isRoundVideo: false, isTornStrip: false, isQuoteOrTaskHighlight: false))
        XCTAssertTrue(chatMessageBubblelessHasHighlightBand(style: .bubblelessCard, isRoundVideo: false, isTornStrip: false, isQuoteOrTaskHighlight: false))
        XCTAssertFalse(chatMessageBubblelessHasHighlightBand(style: .bubble, isRoundVideo: false, isTornStrip: false, isQuoteOrTaskHighlight: false))
        XCTAssertFalse(chatMessageBubblelessHasHighlightBand(style: .bubblelessService, isRoundVideo: false, isTornStrip: false, isQuoteOrTaskHighlight: false))
        XCTAssertFalse(chatMessageBubblelessHasHighlightBand(style: .bubbleless, isRoundVideo: false, isTornStrip: false, isQuoteOrTaskHighlight: true))
    }

    func testWithBubblesNoBandAndMastersCheck() {
        XCTAssertFalse(chatMessageBubblelessHasSelectionBand(bubbleMode: true, isRoundVideo: false, isTornStrip: false))
        XCTAssertEqual(chatMessageSelectionContentOffset(incoming: false, bubbleMode: true), 0.0)
    }

    // What a row's neighbours learn about its band: a round video draws none, and an unsupported message only where it is
    // a torn strip — your own keeps its bubble, its tear and its band.
    func testWhichItemsDrawABand() {
        XCTAssertTrue(chatMessageBubblelessItemDrawsSelectionBand(style: .bubble, isRoundVideo: false, isUnsupportedMessage: true))
        XCTAssertFalse(chatMessageBubblelessItemDrawsSelectionBand(style: .bubbleless, isRoundVideo: false, isUnsupportedMessage: true))
        XCTAssertFalse(chatMessageBubblelessItemDrawsSelectionBand(style: .bubbleless, isRoundVideo: true, isUnsupportedMessage: false))
        XCTAssertTrue(chatMessageBubblelessItemDrawsSelectionBand(style: .bubbleless, isRoundVideo: false, isUnsupportedMessage: false))
    }

    // Leaving selection the rows are laid out without it (their neighbours no longer selected) a moment before their bands
    // fade out: a row out of selection keeps the joins it had, so the joined band fades as one.
    func testARowLeavingSelectionKeepsItsJoins() {
        let joined = ChatMessageBubblelessRowBandInputs(nameTop: 10.0, selectedAbove: true, selectedBelow: true, hasSelectionBand: true, hasHighlightBand: false)
        let leaving = chatMessageBubblelessBandSelectedNeighbors(inSelection: false, above: false, below: false, previous: joined)
        XCTAssertTrue(leaving.above)
        XCTAssertTrue(leaving.below)
        let inSelection = chatMessageBubblelessBandSelectedNeighbors(inSelection: true, above: false, below: true, previous: joined)
        XCTAssertFalse(inSelection.above)
        XCTAssertTrue(inSelection.below)
        let firstLayout = chatMessageBubblelessBandSelectedNeighbors(inSelection: false, above: false, below: false, previous: nil)
        XCTAssertFalse(firstLayout.above)
        XCTAssertFalse(firstLayout.below)
    }

    // Without bubbles the chat stands on the list's plain page in every theme, so the checkmark takes the list's plain
    // ring; with bubbles, master's: plain only on the theme's own colour wallpaper.
    func testTheCheckmarkIsPlainOnThePage() {
        let page = TelegramWallpaper.color(0xffffff)
        let classic = TelegramWallpaper.builtin(WallpaperSettings())
        XCTAssertTrue(chatMessageSelectionCheckIsPlain(wallpaper: page, defaultWallpaper: classic, bubbleMode: false))
        XCTAssertFalse(chatMessageSelectionCheckIsPlain(wallpaper: page, defaultWallpaper: classic, bubbleMode: true))
        XCTAssertTrue(chatMessageSelectionCheckIsPlain(wallpaper: page, defaultWallpaper: page, bubbleMode: true))
        XCTAssertFalse(chatMessageSelectionCheckIsPlain(wallpaper: classic, defaultWallpaper: classic, bubbleMode: true))
    }
}
