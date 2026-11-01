import XCTest
import UIKit
import UIKit.UIGestureRecognizerSubclass
import ObjectiveC
@testable import CoreListDemo

/// Defensive, for #127: a swipe Home starts on the list and the system takes the touch, so the engine lets go of the
/// pan's touch sequence when the scene deactivates, and again when it activates if no finger came down meanwhile, so a
/// pan left holding that touch cannot keep the list from scrolling after the app comes back. The test host has no
/// `UITouch`es: a pan "holding a touch" is one set to a recognizing state, which UIKit does not reset by itself.
final class SceneActivationTouchResetTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        self.window?.isHidden = true
        self.window = nil
        super.tearDown()
    }

    /// An engine whose host is in a window of the test host's scene, and the engine's own pan.
    private func makeFixture() throws -> (engine: PhysicsScrollEngine, pan: UIGestureRecognizer, scene: UIWindowScene) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        self.window = window
        let engine = PhysicsScrollEngine()
        engine.contentHost.frame = window.bounds
        window.addSubview(engine.contentHost)
        let pan = try XCTUnwrap(engine.contentHost.gestureRecognizers?.first { $0 is PhysicsPanGestureRecognizer })
        return (engine, pan, scene)
    }

    /// UIKit resets a recognizer it took out of a gesture after the current turn, not inside `isEnabled = false`.
    private func turnRunLoop() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    private func post(_ name: Notification.Name, _ scene: UIScene?) {
        NotificationCenter.default.post(name: name, object: scene)
    }

    func test_aSceneDeactivatingCancelsAPanStillRecognizing() throws {
        let f = try makeFixture()
        var begins = 0
        var ends = 0
        f.engine.onWillBeginDragging = { begins += 1 }
        f.engine.onDidEndDragging = { ends += 1 }
        f.pan.state = .began
        self.turnRunLoop()
        self.post(UIScene.willDeactivateNotification, f.scene)
        XCTAssertEqual(ends, 1, "UIKit delivers the .cancelled inside isEnabled = false, which the at-rest flag relies on")
        self.turnRunLoop()
        XCTAssertEqual(f.pan.state, .possible, "the pan is reset, ready for the next finger")
        XCTAssertTrue(f.pan.isEnabled, "and still enabled")
        XCTAssertEqual(begins, 1)
        XCTAssertEqual(ends, 1, "the drag ends once, as .cancelled")
    }

    func test_aSceneActivatingCancelsAPanStillHoldingTheTouchItHadWhenTheAppLeft() throws {
        let f = try makeFixture()
        self.post(UIScene.willDeactivateNotification, f.scene)
        f.pan.state = .began
        f.pan.state = .changed
        self.post(UIScene.didActivateNotification, f.scene)
        self.turnRunLoop()
        XCTAssertEqual(f.pan.state, .possible)
        XCTAssertTrue(f.pan.isEnabled)
    }

    func test_aSceneActivatingLeavesADragBegunOnTheWayBack() throws {
        // A finger that lands while the app comes back, before the scene is active, is the user scrolling.
        let f = try makeFixture()
        self.post(UIScene.willDeactivateNotification, f.scene)
        f.engine.noteTouchDown(at: CACurrentMediaTime())
        f.pan.state = .began
        self.post(UIScene.didActivateNotification, f.scene)
        self.turnRunLoop()
        XCTAssertEqual(f.pan.state, .began)
    }

    func test_aPanTheHostDisabledStaysDisabled() throws {
        // MediaGrid turns the scroll off for its pinch; a scene change must not turn it back on.
        let f = try makeFixture()
        f.pan.state = .began
        f.engine.isScrollEnabled = false
        self.post(UIScene.willDeactivateNotification, f.scene)
        XCTAssertFalse(f.pan.isEnabled)
        XCTAssertFalse(f.engine.isScrollEnabled)
    }

    /// Makes this pan (only) report a finger moving at 3000 pt/s, which a test host's recognizer, with no touches, never
    /// does: a dynamic subclass, as KVO makes, overriding `velocity(in:)`. For the pan's whole life: only a fixture's own.
    private func giveVelocity(to pan: UIGestureRecognizer) {
        let base: AnyClass = PhysicsPanGestureRecognizer.self
        precondition(object_getClass(pan) == base, "the subclass is made on, and swapped in for, the plain pan only")
        let name = "SceneActivationTouchResetTests_FlingingPan"
        let subclass: AnyClass
        if let existing = NSClassFromString(name) {
            subclass = existing
        } else {
            subclass = objc_allocateClassPair(base, name, 0)!
            let selector = #selector(UIPanGestureRecognizer.velocity(in:))
            let block: @convention(block) (AnyObject, UIView?) -> CGPoint = { _, _ in CGPoint(x: 0, y: 3000) }
            class_addMethod(subclass, selector, imp_implementationWithBlock(block),
                            method_getTypeEncoding(class_getInstanceMethod(base, selector)!))
            objc_registerClassPair(subclass)
        }
        object_setClass(pan, subclass)
    }

    /// A drag under way at 3000 pt/s on open content.
    private func startFastDrag(_ f: (engine: PhysicsScrollEngine, pan: UIGestureRecognizer, scene: UIWindowScene)) {
        f.engine.setEdges(min: 0, max: 100_000)
        f.engine.setOffset(50_000)
        self.giveVelocity(to: f.pan)
        f.pan.state = .began
        self.turnRunLoop()
    }

    func test_aFastDragReleasedAsUsualDecelerates() throws {
        // The control for the next test: the same drag, cancelled with no scene change, flings.
        let f = try makeFixture()
        self.startFastDrag(f)
        f.pan.state = .cancelled
        self.turnRunLoop()
        XCTAssertTrue(f.engine.isDecelerating)
    }

    func test_aDragTheSceneCancelsReleasesAtRest() throws {
        // The system took the finger: flinging the content as the app leaves would move what the user comes back to.
        let f = try makeFixture()
        var ends = 0
        f.engine.onDidEndDragging = { ends += 1 }
        self.startFastDrag(f)
        self.post(UIScene.willDeactivateNotification, f.scene)
        self.turnRunLoop()
        XCTAssertEqual(ends, 1, "the scene cancel released the drag")
        XCTAssertFalse(f.engine.isDecelerating)
    }

    func test_aListMovedToASceneLessWindowIgnoresItsOldScene() throws {
        let f = try makeFixture()
        let otherWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        otherWindow.addSubview(f.engine.contentHost)
        f.pan.state = .began
        self.post(UIScene.willDeactivateNotification, f.scene)
        self.turnRunLoop()
        XCTAssertEqual(f.pan.state, .began, "a window with no scene is not the one that deactivated")
    }

    func test_aNotificationForNoSceneLeavesThePanAlone() throws {
        // The test host has one scene, so "another scene" is a notification that names none.
        let f = try makeFixture()
        f.pan.state = .began
        self.post(UIScene.willDeactivateNotification, nil)
        self.turnRunLoop()
        XCTAssertEqual(f.pan.state, .began, "only the scene the list is shown in counts")
    }
}
