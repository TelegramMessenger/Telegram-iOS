import XCTest
import UIKit
import Display
import ChatTextInputActionButtonsNode

// Without bubbles the send button is glass in the accent the user picked, or in the system blue as iOS draws it when
// the accent is one of the built-in blues, or black or white.
final class SendButtonGlassColorTests: XCTestCase {
    func testBuiltInBluesAndNeutralAccentsTakeTheSystemBlue() {
        let lightBlue = UIColor.systemBlue.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let darkBlue = UIColor.systemBlue.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertEqual(bubblelessSendButtonGlassColor(accentColor: UIColor(rgb: 0x0088ff), dark: false).argb, lightBlue.argb)
        XCTAssertEqual(bubblelessSendButtonGlassColor(accentColor: UIColor(rgb: 0x3e88f7), dark: true).argb, darkBlue.argb)
        XCTAssertEqual(bubblelessSendButtonGlassColor(accentColor: UIColor(rgb: 0x2ea6ff), dark: true).argb, darkBlue.argb)
        XCTAssertEqual(bubblelessSendButtonGlassColor(accentColor: .white, dark: true).argb, darkBlue.argb)
        XCTAssertEqual(bubblelessSendButtonGlassColor(accentColor: .black, dark: false).argb, lightBlue.argb)
    }

    // In slow mode the countdown is a ring just inside the button's frame: the glass stands 4pt in, as master's disc
    // shrinks, so the ring shows on the page around it.
    func testTheGlassLeavesTheSlowModeRingRoom() {
        let frame = CGRect(x: 3.0, y: 3.0, width: 40.0, height: 40.0)
        XCTAssertEqual(bubblelessSendButtonGlassFrame(backgroundFrame: frame, hasSlowmodeTimer: false), frame)
        XCTAssertEqual(bubblelessSendButtonGlassFrame(backgroundFrame: frame, hasSlowmodeTimer: true), CGRect(x: 7.0, y: 7.0, width: 32.0, height: 32.0))
    }

    func testAPickedAccentIsKept() {
        let orange = UIColor(rgb: 0xff9500)
        XCTAssertEqual(bubblelessSendButtonGlassColor(accentColor: orange, dark: false).argb, orange.argb)
    }
}
