import XCTest
import UIKit
@testable import LegacyMediaPickerUI

final class DocumentPickerPresentationTests: XCTestCase {
    // Before the picker is asked for, the host is still animating in and is legitimately alone on screen.
    func testNotLostBeforePresentationIsRequested() {
        let presentation = DocumentPickerPresentation()
        XCTAssertFalse(presentation.isLost)
    }

    // The system can drop the picker without telling its delegate (Files locked with Face ID, #40): the
    // picker is then neither presented nor in a window, and the invisible host would block the app.
    func testLostWhenRequestedPickerIsNotOnScreen() {
        let picker = UIViewController()
        let presentation = DocumentPickerPresentation()
        presentation.presentationRequested(picker: picker)
        XCTAssertTrue(presentation.isLost)
    }

    func testLostWhenRequestedPickerWasReleased() {
        let presentation = DocumentPickerPresentation()
        autoreleasepool {
            let picker = UIViewController()
            presentation.presentationRequested(picker: picker)
        }
        XCTAssertTrue(presentation.isLost)
    }

    // No test puts the picker in a window: a `UIWindow` in this hostless test process traps at exit, when
    // UIKit invalidates its screen-based scene.

    func testNotLostOnceFinished() {
        let picker = UIViewController()
        let presentation = DocumentPickerPresentation()
        presentation.presentationRequested(picker: picker)
        XCTAssertTrue(presentation.finish())
        XCTAssertFalse(presentation.isLost)
    }

    // Delivering the outcome a second time (a late delegate call after the host gave up) must be refused.
    func testFinishesOnlyOnce() {
        let presentation = DocumentPickerPresentation()
        XCTAssertTrue(presentation.finish())
        XCTAssertFalse(presentation.finish())
    }
}
