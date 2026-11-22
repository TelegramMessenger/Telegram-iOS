import XCTest
import UIKit
import Display
import ChatMessageItemCommon

// The pressed message without bubbles lifts on a card sized to its content (spec 5.9); its menu adds when it was sent
// and by whom, without changing the "Edited" row.
final class ChatMessageBubblelessLiftTests: XCTestCase {
    func testTextLinesTakeTheirPadding() {
        let lift = chatMessageBubblelessLift(parts: [.textLines(CGRect(x: 51.0, y: 30.0, width: 200.0, height: 40.0))])
        XCTAssertEqual(lift, ChatMessageBubblelessLift(rect: CGRect(x: 40.0, y: 24.0 - UIScreenPixel, width: 222.0, height: 52.0), hasCard: true))
    }

    // A caption under files is laid out across the whole column; the card hugs its lines, wherever they start.
    func testTextLinesHugTheirLines() {
        let node = CGRect(x: 51.0, y: 52.0, width: 332.0, height: 30.0)
        let insets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 3.0, right: 0.0)
        XCTAssertEqual(chatMessageBubblelessTextLinesFrame(nodeFrame: node, insets: insets, lineRects: [CGRect(x: 0.0, y: 18.0, width: 320.0, height: 22.0)]), CGRect(x: 51.0, y: 56.0, width: 320.0, height: 23.0))
        let indented = chatMessageBubblelessTextLinesFrame(nodeFrame: node, insets: insets, lineRects: [CGRect(x: 100.0, y: 18.0, width: 200.0, height: 22.0), CGRect(x: 40.0, y: 40.0, width: 100.0, height: 22.0)])
        XCTAssertEqual(indented.minX, 91.0)
        XCTAssertEqual(indented.maxX, 351.0)
        XCTAssertEqual(chatMessageBubblelessTextLinesFrame(nodeFrame: node, insets: insets, lineRects: []), node.inset(by: insets))
    }

    func testBlocksTakeElevenEverywhere() {
        let lift = chatMessageBubblelessLift(parts: [.block(CGRect(x: 51.0, y: 80.0, width: 300.0, height: 200.0))])
        XCTAssertEqual(lift?.rect, CGRect(x: 40.0, y: 69.0, width: 322.0, height: 222.0))
    }

    // The author's name counts as a line of text; the time beside it only widens the card.
    func testTheNameIsTextAndTheDateOnlyWidens() {
        let lift = chatMessageBubblelessLift(parts: [
            .textLines(CGRect(x: 51.0, y: 10.0, width: 80.0, height: 18.0)),
            .widthOnly(CGRect(x: 300.0, y: 0.0, width: 40.0, height: 50.0)),
            .textLines(CGRect(x: 51.0, y: 30.0, width: 200.0, height: 40.0))
        ])
        XCTAssertEqual(lift?.rect.minX, 40.0)
        XCTAssertEqual(lift?.rect.maxX, 351.0)
        XCTAssertEqual(lift?.rect.minY ?? 0.0, 4.0 - UIScreenPixel, accuracy: 0.0001)
        XCTAssertEqual(lift?.rect.maxY ?? 0.0, 76.0 - UIScreenPixel, accuracy: 0.0001)
    }

    func testAnOutlineIsTheCard() {
        let outline = CGRect(x: 51.0, y: 20.0, width: 300.0, height: 160.0)
        let lift = chatMessageBubblelessLift(parts: [.textLines(CGRect(x: 51.0, y: 0.0, width: 80.0, height: 18.0)), .outline(outline)])
        XCTAssertEqual(lift, ChatMessageBubblelessLift(rect: outline.insetBy(dx: -(1.0 + UIScreenPixel * 2.0), dy: -(1.0 + UIScreenPixel * 2.0)), hasCard: true))
    }

    func testRoundVideosAndServiceLiftAlone() {
        let circle = CGRect(x: 51.0, y: 30.0, width: 240.0, height: 240.0)
        let lift = chatMessageBubblelessLift(parts: [.textLines(CGRect(x: 51.0, y: 0.0, width: 80.0, height: 18.0)), .standalone(circle)])
        XCTAssertEqual(lift, ChatMessageBubblelessLift(rect: circle, hasCard: false))
        XCTAssertNil(chatMessageBubblelessLift(parts: []))
    }

    // What lifts without its name and time: round videos and torn strips (spec 5.9), and cards, which lift by their
    // outline alone, so their header would sit under the reaction picker.
    func testWhatLiftsWithoutItsHeader() {
        XCTAssertTrue(chatMessageBubblelessLiftHidesHeader(isTornStrip: true, isRoundVideo: false, hasCardOutline: false))
        XCTAssertTrue(chatMessageBubblelessLiftHidesHeader(isTornStrip: false, isRoundVideo: true, hasCardOutline: false))
        XCTAssertTrue(chatMessageBubblelessLiftHidesHeader(isTornStrip: false, isRoundVideo: false, hasCardOutline: true))
        XCTAssertFalse(chatMessageBubblelessLiftHidesHeader(isTornStrip: false, isRoundVideo: false, hasCardOutline: false))
    }

    func testPartsMoveWithTheirNode() {
        XCTAssertEqual(ChatMessageBubblelessLiftPart.block(CGRect(x: 0.0, y: 0.0, width: 10.0, height: 10.0)).offsetBy(CGPoint(x: 51.0, y: 20.0)), .block(CGRect(x: 51.0, y: 20.0, width: 10.0, height: 10.0)))
    }

    func testLiftColourAndRadius() {
        let page = UIColor(rgb: 0xffffff)
        XCTAssertEqual(chatMessageBubblelessLiftColor(dark: false, pageColor: page).rgb, 0xffffff)
        XCTAssertEqual(chatMessageBubblelessLiftColor(dark: true, pageColor: UIColor(rgb: 0x000000)).rgb, 0x1c1c1e)
        XCTAssertEqual(chatMessageBubblelessLiftCornerRadius(mainRadius: 16.0, height: 20.0), 10.0)
        XCTAssertEqual(chatMessageBubblelessLiftCornerRadius(mainRadius: 16.0, height: 200.0), 16.0)
    }

    func testInfoRowsOnlyForIncomingWithoutBubbles() {
        XCTAssertTrue(chatMessageBubblelessMenuShowsInfoRows(bubbleMode: false, isMessageOptions: false, incoming: true, isAd: false, isService: false))
        XCTAssertFalse(chatMessageBubblelessMenuShowsInfoRows(bubbleMode: true, isMessageOptions: false, incoming: true, isAd: false, isService: false))
        XCTAssertFalse(chatMessageBubblelessMenuShowsInfoRows(bubbleMode: false, isMessageOptions: true, incoming: true, isAd: false, isService: false))
        XCTAssertFalse(chatMessageBubblelessMenuShowsInfoRows(bubbleMode: false, isMessageOptions: false, incoming: false, isAd: false, isService: false))
        XCTAssertFalse(chatMessageBubblelessMenuShowsInfoRows(bubbleMode: false, isMessageOptions: false, incoming: true, isAd: true, isService: false))
        XCTAssertFalse(chatMessageBubblelessMenuShowsInfoRows(bubbleMode: false, isMessageOptions: false, incoming: true, isAd: false, isService: true))
    }

    // Where the server shows an edited message's send time in its "Edited" row (`message_primary_edited_date`), the menu
    // has no second "Sent" row; the author follows that row.
    func testNoSecondSentRow() {
        XCTAssertEqual(chatMessageBubblelessMenuInfoRows(hasAuthor: true, editedRowShowsSentTime: false), [.sent, .author])
        XCTAssertEqual(chatMessageBubblelessMenuInfoRows(hasAuthor: false, editedRowShowsSentTime: false), [.sent])
        XCTAssertEqual(chatMessageBubblelessMenuInfoRows(hasAuthor: true, editedRowShowsSentTime: true), [.author])
        XCTAssertEqual(chatMessageBubblelessMenuInfoRows(hasAuthor: false, editedRowShowsSentTime: true), [])
    }

    // Groups and channels keep master's "Edited" row (11pt vertical, 54pt right inset); private chats and the new info rows
    // use the compact one.
    func testTheEditedRowKeepsMastersMetrics() {
        XCTAssertFalse(chatReadReportRowUsesCompactMetrics(isCloudUserChat: false, isBubblelessInfoRow: false))
        XCTAssertTrue(chatReadReportRowUsesCompactMetrics(isCloudUserChat: true, isBubblelessInfoRow: false))
        XCTAssertTrue(chatReadReportRowUsesCompactMetrics(isCloudUserChat: false, isBubblelessInfoRow: true))
    }
}
