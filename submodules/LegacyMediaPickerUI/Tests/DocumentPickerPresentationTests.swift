import XCTest
import UIKit
@testable import LegacyMediaPickerUI

final class DocumentPickerPresentationTests: XCTestCase {
    private var time: Double = 100.0

    // Each test that holds a picker keeps it alive to its end (`withExtendedLifetime`): an optimized build may
    // release a local after its last use, and a released picker counts as lost at once.
    private func makePresentation() -> DocumentPickerPresentation {
        return DocumentPickerPresentation(now: { [unowned self] in self.time })
    }

    // Before the picker is asked for, the host is still animating in and is legitimately alone on screen.
    func testNotLostBeforePresentationIsRequested() {
        let presentation = self.makePresentation()
        self.time += 10.0
        XCTAssertFalse(presentation.isLost)
    }

    // UIKit holds a document picker's presentation back for up to 3 s, until its remote view is ready: the picker
    // is then neither presented nor in a window, yet it will appear. Cancelling it then would drop the user's pick.
    func testNotLostWhileUIKitMayStillPresentIt() {
        let picker = UIViewController()
        let presentation = self.makePresentation()
        presentation.presentationRequested(picker: picker)
        XCTAssertFalse(presentation.isLost)
        self.time += 3.0
        XCTAssertFalse(presentation.isLost)
        withExtendedLifetime(picker) {}
    }

    // Past that limit, a picker still neither presented nor in a window is not going to appear (#40), and the
    // invisible host would block the app.
    func testLostWhenNotOnScreenPastThePresentationLimit() {
        let picker = UIViewController()
        let presentation = self.makePresentation()
        presentation.presentationRequested(picker: picker)
        self.time += DocumentPickerPresentation.presentationDelayLimit
        XCTAssertTrue(presentation.isLost)
        withExtendedLifetime(picker) {}
    }

    // A cancelled presentation releases the picker (UIKit holds one it will still present), so it is lost at once:
    // this is the app lock dismissing what the root presents while the picker is held back.
    func testLostAtOnceWhenRequestedPickerWasReleased() {
        let presentation = self.makePresentation()
        autoreleasepool {
            let picker = UIViewController()
            presentation.presentationRequested(picker: picker)
        }
        XCTAssertTrue(presentation.isLost)
    }

    // No test puts the picker in a window: a `UIWindow` in this hostless test process traps at exit, when
    // UIKit invalidates its screen-based scene.

    // A picker closing normally leaves the window before its delegate reports the pick; the host leaves through
    // the picker's `viewDidDisappear` then, and must not turn the pick into a cancellation.
    func testNotLostOnceDisappeared() {
        let picker = UIViewController()
        let presentation = self.makePresentation()
        presentation.presentationRequested(picker: picker)
        presentation.pickerDidDisappear()
        self.time += 10.0
        XCTAssertFalse(presentation.isLost)
        XCTAssertTrue(presentation.finish())
        withExtendedLifetime(picker) {}
    }

    func testNotLostOnceFinished() {
        let picker = UIViewController()
        let presentation = self.makePresentation()
        presentation.presentationRequested(picker: picker)
        XCTAssertTrue(presentation.finish())
        self.time += 10.0
        XCTAssertFalse(presentation.isLost)
        withExtendedLifetime(picker) {}
    }

    // Delivering the outcome a second time (a late delegate call after the host gave up) must be refused.
    func testFinishesOnlyOnce() {
        let presentation = self.makePresentation()
        XCTAssertTrue(presentation.finish())
        XCTAssertFalse(presentation.finish())
    }
}
