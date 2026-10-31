import XCTest
import UIKit
@testable import Display

final class HardwareKeyboardBarTests: XCTestCase {
    func test_tablet_hardwareKeyboardBar_isTheBar() {
        // Posted on iPad Air 11" (iOS 27 simulator, hardware keyboard) when a text field becomes first responder:
        // the frame spans the width while only a small floating button is drawn in the corner.
        XCTAssertTrue(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 1111.5, width: 820.0, height: 68.5), deviceType: .tablet, responderHasInputViews: false))
    }

    func test_tablet_hardwareKeyboardBarInLandscape_isTheBar() {
        XCTAssertTrue(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 751.5, width: 1180.0, height: 68.5), deviceType: .tablet, responderHasInputViews: false))
    }

    func test_tablet_softwareKeyboard_isNotTheBar() {
        // Posted on the same iPad without a hardware keyboard.
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 843.0, width: 820.0, height: 337.0), deviceType: .tablet, responderHasInputViews: false))
    }

    func test_tablet_hiddenKeyboard_isNotTheBar() {
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 1180.0, width: 820.0, height: 0.0), deviceType: .tablet, responderHasInputViews: false))
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(), deviceType: .tablet, responderHasInputViews: false))
    }

    func test_tablet_shortFrameBelowTheThreshold_isTheBar() {
        XCTAssertTrue(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 1080.5, width: 820.0, height: 99.5), deviceType: .tablet, responderHasInputViews: false))
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 1080.0, width: 820.0, height: 100.0), deviceType: .tablet, responderHasInputViews: false))
    }

    func test_tablet_inputAccessoryWithHardwareKeyboard_isNotTheBar() {
        // With a hardware keyboard a responder's input accessory view (the drawing editor's 44pt text bar) is drawn
        // across the bottom of the screen, and the posted frame is just as short as the bar's.
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 1136.0, width: 820.0, height: 44.0), deviceType: .tablet, responderHasInputViews: true))
    }

    func test_phone_shortFrame_isNotTheBar() {
        // An iPhone with a hardware keyboard posts a zero-height frame; a phone's layout is left as it was.
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 874.0, width: 402.0, height: 0.0), deviceType: .phone, responderHasInputViews: false))
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 805.5, width: 402.0, height: 68.5), deviceType: .phone, responderHasInputViews: false))
    }
}
