import XCTest
import UIKit
import UIKit.UIGestureRecognizerSubclass
@testable import CoreListDemo

/// A finger on the list when its scene stops being active is the system's from then on: a swipe Home starts at the
/// bottom edge, on the list. The engine lets go of that touch sequence when the scene deactivates and again when it
/// activates, so a pan left holding it cannot keep the list from scrolling after the app comes back (#127).
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

    func test_aSceneDeactivatingCancelsAPanStillRecognizing() throws {
        let f = try makeFixture()
        f.pan.state = .began
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: f.scene)
        self.turnRunLoop()
        XCTAssertEqual(f.pan.state, .possible, "the pan is reset, ready for the next finger")
        XCTAssertTrue(f.pan.isEnabled, "and still enabled")
    }

    func test_aSceneActivatingCancelsAPanLeftRecognizing() throws {
        // A pan still holding a touch the app never saw end when it came back: until that touch ends it takes no
        // other finger.
        let f = try makeFixture()
        f.pan.state = .began
        f.pan.state = .changed
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: f.scene)
        self.turnRunLoop()
        XCTAssertEqual(f.pan.state, .possible)
        XCTAssertTrue(f.pan.isEnabled)
    }

    func test_aPanTheHostDisabledStaysDisabled() throws {
        // MediaGrid turns the scroll off for its pinch; a scene change must not turn it back on.
        let f = try makeFixture()
        f.engine.isScrollEnabled = false
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: f.scene)
        XCTAssertFalse(f.pan.isEnabled)
        XCTAssertFalse(f.engine.isScrollEnabled)
    }

    func test_anotherScenesActivationLeavesThePanAlone() throws {
        let f = try makeFixture()
        f.pan.state = .began
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: nil)
        self.turnRunLoop()
        XCTAssertEqual(f.pan.state, .began, "only the scene the list is shown in counts")
    }
}
