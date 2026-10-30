import XCTest
import UIKit
import Display
import ChatMessageItemCommon

// The designer's second revision: blocks under the author header start as far under the name as in a bubble, and your
// own gray message comes out for its menu on a fill as light as the menu.
final class ChatMessageBubblelessRevisionTwoTests: XCTestCase {
    // A file or music under the name starts 15pt below the header, its voice button no higher; elsewhere a voice
    // message's button rides above the row; a contact starts 11pt (and a pixel) below the header.
    func testBlocksStartAsFarUnderTheNameAsInABubble() {
        XCTAssertEqual(chatMessageBubblelessFileTopInset(baseTop: 0.0, underHeader: true, voiceButtonOverhang: 3.0), 15.0)
        XCTAssertEqual(chatMessageBubblelessFileTopInset(baseTop: 0.0, underHeader: true, voiceButtonOverhang: 0.0), 15.0)
        XCTAssertEqual(chatMessageBubblelessFileTopInset(baseTop: 4.0, underHeader: false, voiceButtonOverhang: 3.0), 7.0)
        XCTAssertEqual(chatMessageBubblelessHeaderContactSpacing, 11.0 + UIScreenPixel)
        XCTAssertEqual(chatMessageBubblelessHeaderMediaSpacing, 10.0)
    }

    // A round video's duration stands on the dark media glass without bubbles: its text is the time-over-media colour,
    // not the service gray, which the dark glass would swallow on a light page. With bubbles the service colour stays.
    func testARoundVideosDurationOnTheDarkGlassIsLight() {
        let service = UIColor(rgb: 0x8e8e93)
        let media = UIColor(rgb: 0xffffff)
        XCTAssertEqual(chatMessageBubblelessRoundVideoDurationTextColor(onGlass: true, serviceTextColor: service, mediaTextColor: media).rgb, 0xffffff)
        XCTAssertEqual(chatMessageBubblelessRoundVideoDurationTextColor(onGlass: false, serviceTextColor: service, mediaTextColor: media).rgb, 0x8e8e93)
    }

    // A light theme's gray bubble is barely lighter than the dimmed chat: it comes out on the page's colour. A dark gray
    // bubble is lighter than the menu already, and a coloured one keeps its colour.
    func testGrayBubblesComeOutOnALightFill() {
        let page = UIColor(rgb: 0xf9f9fb)
        XCTAssertEqual(chatMessageBubblelessContextLiftColor(bubbleIsGray: true, dark: false, pageColor: page)?.rgb, 0xf9f9fb)
        XCTAssertNil(chatMessageBubblelessContextLiftColor(bubbleIsGray: true, dark: true, pageColor: page))
        XCTAssertNil(chatMessageBubblelessContextLiftColor(bubbleIsGray: false, dark: false, pageColor: page))
    }

    // The fill takes the bubble's shape: its body stands 1pt inside the frame and leaves the 6pt tail column on the
    // right; the corners toward the messages it runs on are the smaller radius.
    func testTheFillTakesTheBubblesShape() {
        let frame = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 40.0)
        func radii(_ merge: ChatMessageBubblelessBubbleMerge) -> ChatMessageBubblelessCornerRadii {
            let shape = chatMessageBubblelessOutgoingBubbleShape(backgroundFrame: frame, merge: merge, mainRadius: 16.0, smallRadius: 8.0)
            XCTAssertEqual(shape.frame, CGRect(x: 11.0, y: 21.0, width: 92.0, height: 38.0))
            return shape.radii
        }
        XCTAssertEqual(radii(.none), ChatMessageBubblelessCornerRadii(topLeft: 16.0, topRight: 16.0, bottomLeft: 16.0, bottomRight: 16.0))
        XCTAssertEqual(radii(.both), ChatMessageBubblelessCornerRadii(topLeft: 16.0, topRight: 8.0, bottomLeft: 16.0, bottomRight: 8.0))
        XCTAssertEqual(radii(.bottom), ChatMessageBubblelessCornerRadii(topLeft: 16.0, topRight: 8.0, bottomLeft: 16.0, bottomRight: 16.0))
        XCTAssertEqual(radii(.side), ChatMessageBubblelessCornerRadii(topLeft: 16.0, topRight: 16.0, bottomLeft: 8.0, bottomRight: 8.0))
        XCTAssertEqual(radii(.top(side: true)), ChatMessageBubblelessCornerRadii(topLeft: 16.0, topRight: 16.0, bottomLeft: 8.0, bottomRight: 8.0))
        XCTAssertEqual(radii(.top(side: false)), ChatMessageBubblelessCornerRadii(topLeft: 16.0, topRight: 16.0, bottomLeft: 16.0, bottomRight: 8.0))
    }
}
