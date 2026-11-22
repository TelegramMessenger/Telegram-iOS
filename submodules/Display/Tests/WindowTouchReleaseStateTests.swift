import XCTest
import UIKit
import UIKit.UIGestureRecognizerSubclass
@testable import Display

/// #127, `WindowTouchRelease` with what needs a running app: UIKit's recognizer state machine (a recognizer still
/// recognizing a touch that never ended, set to `.began`, which UIKit does not reset by itself, is cancelled and reset as
/// the scene deactivates) and a window.
final class WindowTouchReleaseStateTests: XCTestCase {
    private var view: UIView?

    override func tearDown() {
        self.view?.removeFromSuperview()
        self.view = nil
        super.tearDown()
    }

    private func hostWindow() throws -> UIWindow {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return try XCTUnwrap(scenes.flatMap(\.windows).first)
    }

    private func turnRunLoop() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    func testARecognizingRecognizerIsCancelledAndReset() throws {
        let window = try self.hostWindow()
        let view = UIView(frame: window.bounds)
        window.addSubview(view)
        self.view = view
        var states: [UIGestureRecognizer.State] = []
        let target = Target { states.append($0.state) }
        let recognizer = UIPanGestureRecognizer(target: target, action: #selector(Target.fire(_:)))
        view.addGestureRecognizer(recognizer)
        let release = WindowTouchRelease(holders: { [recognizer] })
        recognizer.state = .began
        self.turnRunLoop()
        XCTAssertEqual(recognizer.state, .began, "UIKit leaves a recognizing recognizer as it is")

        release.sceneWillDeactivate()
        self.turnRunLoop()

        XCTAssertEqual(states, [.began, .cancelled], "the gesture ends as cancelled")
        XCTAssertEqual(recognizer.state, .possible, "and the recognizer is reset, ready for the next finger")
        XCTAssertTrue(recognizer.isEnabled)
    }

    func testTheWindowsOwnRecognizersAreLeftAlone() throws {
        let window = try self.hostWindow()
        let windowRecognizer = HoldingRecognizer(target: nil, action: nil)
        window.addGestureRecognizer(windowRecognizer)
        defer {
            window.removeGestureRecognizer(windowRecognizer)
        }
        let view = UIView(frame: window.bounds)
        window.addSubview(view)
        self.view = view
        let recognizer = HoldingRecognizer(target: nil, action: nil)
        view.addGestureRecognizer(recognizer)

        let holders = WindowTouchRelease.holders(in: window)

        XCTAssertFalse(holders.contains { $0 === windowRecognizer }, "the system's gates on the window are not the app's to reset")
        XCTAssertTrue(holders.contains { $0 === recognizer })
    }

    /// Holds a touch, as far as `numberOfTouches` tells.
    private final class HoldingRecognizer: UIPanGestureRecognizer {
        override var numberOfTouches: Int {
            return 1
        }
    }

    private final class Target: NSObject {
        private let action: (UIGestureRecognizer) -> Void

        init(_ action: @escaping (UIGestureRecognizer) -> Void) {
            self.action = action
        }

        @objc func fire(_ recognizer: UIGestureRecognizer) {
            self.action(recognizer)
        }
    }
}
