import XCTest
import UIKit
@testable import Display

final class HardwareKeyboardBarTests: XCTestCase {
    func test_tablet_hardwareKeyboardBar_isTheBar() {
        // Posted on iPad Air 11" (iOS 27 simulator, hardware keyboard) when a text field becomes first responder:
        // the frame spans the width while only a small floating button is drawn in the corner.
        XCTAssertTrue(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 1111.5, width: 820.0, height: 68.5), deviceType: .tablet))
    }

    func test_tablet_hardwareKeyboardBarInLandscape_isTheBar() {
        XCTAssertTrue(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 751.5, width: 1180.0, height: 68.5), deviceType: .tablet))
    }

    func test_tablet_softwareKeyboard_isNotTheBar() {
        // Posted on the same iPad without a hardware keyboard.
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 843.0, width: 820.0, height: 337.0), deviceType: .tablet))
    }

    func test_tablet_hiddenKeyboard_isNotTheBar() {
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 1180.0, width: 820.0, height: 0.0), deviceType: .tablet))
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(), deviceType: .tablet))
    }

    func test_phone_shortFrame_isNotTheBar() {
        // An iPhone with a hardware keyboard posts a zero-height frame; a phone's layout is left as it was.
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 874.0, width: 402.0, height: 0.0), deviceType: .phone))
        XCTAssertFalse(isHardwareKeyboardBar(keyboardFrame: CGRect(x: 0.0, y: 805.5, width: 402.0, height: 68.5), deviceType: .phone))
    }
}
