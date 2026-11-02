import XCTest
import UIKit
import UIKit.UIGestureRecognizerSubclass
@testable import Display

/// #127: the main window's recognizers let go of the touches they hold as its scene deactivates, and again as it
/// activates unless a finger came down on the way back. The test process has no `UITouch`es and ignores state writes,
/// so a recognizer "holding" a touch is one whose `numberOfTouches` says so, and the release is seen through its
/// `isEnabled` writes (the state, in `WindowTouchReleaseStateTests`, hosted). What it does to UIKit's own touch
/// bookkeeping (the touch's other recognizers reset with it) is checked on the simulator, by withholding a touch's end
/// from the window.
final class WindowTouchReleaseTests: XCTestCase {
    /// Records every `isEnabled` write, so a toggle of a recognizer still `.possible` (which UIKit fails, with no
    /// visible state in a test process) is seen too.
    private final class RecordingRecognizer: UIPanGestureRecognizer {
        var touches = 0
        var enabledWrites: [Bool] = []
        var enabledWritten: ((Bool) -> Void)?

        override var numberOfTouches: Int {
            return self.touches
        }

        override var isEnabled: Bool {
            didSet {
                self.enabledWrites.append(self.isEnabled)
                self.enabledWritten?(self.isEnabled)
            }
        }
    }

    private var views: [UIView] = []

    override func tearDown() {
        self.views = []
        WindowTouchRelease.trace = nil
        super.tearDown()
    }

    private func makeRecognizer(touches: Int = 1, on view: UIView? = nil) -> RecordingRecognizer {
        let recognizer = RecordingRecognizer(target: nil, action: nil)
        recognizer.touches = touches
        let view = view ?? UIView()
        self.views.append(view)
        view.addGestureRecognizer(recognizer)
        recognizer.enabledWrites = []
        return recognizer
    }

    func testADeactivationLetsGoOfTheTouchesHeld() {
        let recognizer = self.makeRecognizer()
        let release = WindowTouchRelease(holders: { [recognizer] })

        release.sceneWillDeactivate()

        XCTAssertEqual(recognizer.enabledWrites, [false, true], "the recognizer holding a touch is toggled off and back on")
        XCTAssertTrue(recognizer.isEnabled)
    }

    func testAnActivationLetsGoAgainWhenNoFingerCameDownSince() {
        let recognizer = self.makeRecognizer()
        let release = WindowTouchRelease(holders: { [recognizer] })
        release.sceneWillDeactivate()
        recognizer.enabledWrites = []

        release.sceneDidActivate()

        XCTAssertEqual(recognizer.enabledWrites, [false, true])
    }

    func testAnActivationKeepsAGestureBegunOnTheWayBack() {
        let recognizer = self.makeRecognizer()
        let release = WindowTouchRelease(holders: { [recognizer] })
        release.sceneWillDeactivate()
        recognizer.enabledWrites = []
        release.touchBegan()

        release.sceneDidActivate()

        XCTAssertEqual(recognizer.enabledWrites, [], "a finger that came down on the way back keeps its gesture")
    }

    func testAFingerBeforeTheDeactivationDoesNotSpareTheActivation() {
        let recognizer = self.makeRecognizer()
        let release = WindowTouchRelease(holders: { [recognizer] })
        release.touchBegan()
        release.sceneWillDeactivate()
        recognizer.enabledWrites = []

        release.sceneDidActivate()

        XCTAssertEqual(recognizer.enabledWrites, [false, true], "the touch the app had when it left is let go of")
    }

    func testAnActivationWithoutADeactivationReleasesNothing() {
        let recognizer = self.makeRecognizer()
        let release = WindowTouchRelease(holders: { [recognizer] })

        release.sceneDidActivate()
        release.sceneWillDeactivate()
        release.sceneDidActivate()
        recognizer.enabledWrites = []
        release.sceneDidActivate()

        XCTAssertEqual(recognizer.enabledWrites, [], "the scene's first activation, or a second one, finds nothing to let go of")
    }

    func testEveryRecognizerIsOffBeforeAnyIsBackOn() {
        let first = self.makeRecognizer()
        let second = self.makeRecognizer()
        var firstEnabledWhenSecondTurnedOff: Bool?
        second.enabledWritten = { isEnabled in
            if !isEnabled {
                firstEnabledWhenSecondTurnedOff = first.isEnabled
            }
        }
        let release = WindowTouchRelease(holders: { [first, second] })

        release.sceneWillDeactivate()

        XCTAssertEqual(firstEnabledWhenSecondTurnedOff, false, "UIKit can reset a touch's recognizers only once none still holds it")
        XCTAssertTrue(first.isEnabled)
        XCTAssertTrue(second.isEnabled)
    }

    func testTheHoldersAreTheEnabledRecognizersHoldingTouches() {
        let root = UIView()
        let child = UIView()
        let grandchild = UIView()
        root.addSubview(child)
        child.addSubview(grandchild)
        let onRoot = self.makeRecognizer(on: root)
        let deep = self.makeRecognizer(on: grandchild)
        let idle = self.makeRecognizer(touches: 0, on: child)
        let off = self.makeRecognizer(on: child)
        off.isEnabled = false

        let holders = WindowTouchRelease.holders(in: root)

        XCTAssertEqual(holders.count, 2)
        XCTAssertTrue(holders.contains { $0 === onRoot })
        XCTAssertTrue(holders.contains { $0 === deep })
        XCTAssertFalse(holders.contains { $0 === idle }, "a recognizer holding no touch is left alone")
        XCTAssertFalse(holders.contains { $0 === off }, "a recognizer the app turned off stays off")
    }

    func testTheTraceNamesWhatHeldTheTouch() {
        let recognizer = self.makeRecognizer()
        let release = WindowTouchRelease(holders: { [recognizer] })
        var lines: [String] = []
        WindowTouchRelease.trace = { lines.append($0) }

        release.sceneWillDeactivate()

        XCTAssertEqual(lines, ["TOUCH-RELEASE deactivate recognizers=1 RecordingRecognizer:possible/1"])
    }

    func testTheTraceRecordsEverySceneChange() {
        let release = WindowTouchRelease(holders: { [] })
        var lines: [String] = []
        WindowTouchRelease.trace = { lines.append($0) }

        release.sceneWillDeactivate()
        release.sceneDidActivate()
        release.sceneWillDeactivate()
        release.touchBegan()
        release.sceneDidActivate()

        XCTAssertEqual(lines, [
            "TOUCH-RELEASE deactivate recognizers=0",
            "TOUCH-RELEASE activate recognizers=0",
            "TOUCH-RELEASE deactivate recognizers=0",
            "TOUCH-RELEASE activate kept: a finger came down since",
        ])
    }
}
