import UIKit
import XCTest
@testable import MessageWidget

/// A widget runs its frames and timers only while its bubble is visible, its view is in a window, and the app is
/// active: a chat covered by a pushed screen is removed from the window but keeps its list visibility, and an app in
/// the background stays alive during a call or audio playback.
class VisibilityTests: MessageWidgetTestCase {
    /// Counts the frames it gets, asking for the next one each time.
    static let frameCounter = "<p>frames</p><script>window.n = 0; requestAnimationFrame(function f() { window.n++; requestAnimationFrame(f); })</script>"

    /// One window for the whole process, shared by every test and never freed. A freed window's screen-based
    /// scene is invalidated on a later run-loop turn, and in a test process launched standalone (the Bazel runner's
    /// logic tests; `simctl spawn -s`) that invalidation traps in BackBoardServices
    /// (`+[BKSHIDEventDeliveryManager sharedInstance]`), killing xctest after its last test.
    private static let window = UIWindow(frame: CGRect(x: 0.0, y: 0.0, width: 400.0, height: 400.0))

    override func tearDown() {
        MessageWidgetApplicationState.shared.isActive = true
        super.tearDown()
    }

    private func frames(_ instance: MessageWidgetInstance) -> String? {
        return instance.evaluateForTesting("String(window.n)")
    }

    private func hidden(_ instance: MessageWidgetInstance) -> String? {
        return instance.evaluateForTesting("String(document.hidden)")
    }

    func testViewOutOfItsWindowHidesTheWidget() throws {
        let window = VisibilityTests.window
        let (instance, view) = self.booted(VisibilityTests.frameCounter)
        defer {
            view.removeFromSuperview()
        }
        withExtendedLifetime(instance) {
            window.addSubview(view)
            instance.deliverFrameForTesting()
            XCTAssertEqual(self.frames(instance), "1")
            XCTAssertEqual(self.hidden(instance), "false")
            // A screen pushed over the chat removes the chat from the window; its list visibility stays.
            view.removeFromSuperview()
            XCTAssertFalse(instance.visible)
            XCTAssertEqual(self.hidden(instance), "true")
            instance.deliverFrameForTesting()
            XCTAssertEqual(self.frames(instance), "1")
            window.addSubview(view)
            XCTAssertTrue(instance.visible)
            XCTAssertEqual(self.hidden(instance), "false")
            instance.deliverFrameForTesting()
            XCTAssertEqual(self.frames(instance), "2")
        }
    }

    func testInactiveAppHidesTheWidget() throws {
        let (instance, _) = self.booted(VisibilityTests.frameCounter)
        withExtendedLifetime(instance) {
            instance.deliverFrameForTesting()
            XCTAssertEqual(self.frames(instance), "1")
            MessageWidgetApplicationState.shared.isActive = false
            XCTAssertFalse(instance.visible)
            XCTAssertEqual(self.hidden(instance), "true")
            instance.deliverFrameForTesting()
            XCTAssertEqual(self.frames(instance), "1")
            MessageWidgetApplicationState.shared.isActive = true
            XCTAssertTrue(instance.visible)
            instance.deliverFrameForTesting()
            XCTAssertEqual(self.frames(instance), "2")
        }
    }

    /// Each of the three hides the widget alone; it shows again only when all three allow it.
    func testVisibleOnlyWhenTheBubbleTheWindowAndTheAppAllAllowIt() throws {
        let window = VisibilityTests.window
        let (instance, view) = self.booted("<!doctype html><p>x</p>")
        defer {
            view.removeFromSuperview()
        }
        withExtendedLifetime(instance) {
            window.addSubview(view)
            XCTAssertTrue(instance.visible)
            instance.setVisible(false)
            MessageWidgetApplicationState.shared.isActive = false
            view.removeFromSuperview()
            XCTAssertFalse(instance.visible)
            instance.setVisible(true)
            XCTAssertFalse(instance.visible)
            MessageWidgetApplicationState.shared.isActive = true
            XCTAssertFalse(instance.visible)
            window.addSubview(view)
            XCTAssertTrue(instance.visible)
        }
    }

    /// A widget booted while the app is inactive starts hidden, so it boots with `document.hidden` and no frames.
    func testWidgetBootedWhileTheAppIsInactiveStartsHidden() throws {
        MessageWidgetApplicationState.shared.isActive = false
        let instance = self.make(VisibilityTests.frameCounter)
        _ = instance.layout(width: 360.0)
        XCTAssertFalse(instance.visible)
        XCTAssertEqual(self.hidden(instance), "true")
        instance.deliverFrameForTesting()
        XCTAssertEqual(self.frames(instance), "0")
        instance.destroy()
    }
}
