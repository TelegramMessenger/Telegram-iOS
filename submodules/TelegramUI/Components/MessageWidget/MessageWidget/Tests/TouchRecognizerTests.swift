import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest
@testable import MessageWidget

/// A widget takes its touches through its own recognizer. In a chat a recognizer above the bubble (likely the
/// history's keyboard-dismissing tap) recognizes every tap and so cancels the touched view's touches: a widget that read
/// `touchesEnded` got `touchesCancelled` instead and never clicked (measured on K3, 2026-10-15).
final class TouchRecognizerTests: MessageWidgetTestCase {
    private func recognizer() -> (MessageWidgetTouchRecognizer, () -> [MessageWidgetView.TouchPhase]) {
        let recognizer = MessageWidgetTouchRecognizer()
        var phases: [MessageWidgetView.TouchPhase] = []
        recognizer.onTouch = { phase, _ in
            phases.append(phase)
        }
        return (recognizer, { phases })
    }

    func testATapsEndReachesTheWidget() {
        // That the recognizer then recognizes (and so owns the tap) is not observable here: the hostless test process
        // has no gesture environment, and UIKit ignores the state change. It is checked in the simulator.
        let (recognizer, phases) = self.recognizer()
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        recognizer.touchesMoved([touch], with: UIEvent())
        recognizer.touchesEnded([touch], with: UIEvent())
        XCTAssertEqual(phases(), [.began, .moved, .ended])
    }

    func testATouchTakenByAnotherGestureIsCancelledOnReset() {
        // The chat's scroll pan prevents the recognizer (a drag that starts on a widget scrolls the chat); UIKit then
        // resets it without a touchesCancelled.
        let (recognizer, phases) = self.recognizer()
        recognizer.touchesBegan([UITouch()], with: UIEvent())
        recognizer.reset()
        XCTAssertEqual(phases(), [.began, .cancelled])
        recognizer.reset()
        XCTAssertEqual(phases(), [.began, .cancelled])
    }

    func testACancelledTouchIsCancelledOnce() {
        let (recognizer, phases) = self.recognizer()
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        recognizer.touchesCancelled([touch], with: UIEvent())
        recognizer.reset()
        XCTAssertEqual(phases(), [.began, .cancelled])
    }

    /// A long press opens the bubble's context menu (simultaneously with this recognizer, which the menu's gesture does
    /// not cancel): the widget's touch is cancelled there, so lifting the finger after the menu opened clicks nothing
    /// (sdk-v1 §5.5; fix-wave review N2).
    func testATouchTheContextMenuTookDoesNotEndAsATap() {
        let (recognizer, phases) = self.recognizer()
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        recognizer.cancelTrackedTouch()
        recognizer.touchesEnded([touch], with: UIEvent())
        recognizer.cancelTrackedTouch()
        XCTAssertEqual(phases(), [.began, .cancelled])
    }

    func testItLeavesOtherViewsTouchesAlone() {
        let (recognizer, _) = self.recognizer()
        XCTAssertFalse(recognizer.cancelsTouchesInView)
        XCTAssertFalse(recognizer.delaysTouchesBegan)
        XCTAssertFalse(recognizer.delaysTouchesEnded)
    }

    func testAnAncestorsTapCannotPreventItButAPanCan() {
        let (recognizer, _) = self.recognizer()
        XCTAssertFalse(recognizer.canBePrevented(by: UITapGestureRecognizer()))
        XCTAssertTrue(recognizer.canBePrevented(by: UIPanGestureRecognizer()))
    }

    /// Review Focus 2: a drag that starts on a widget scrolls the chat. The chat's pan prevents the recognizer, which
    /// UIKit then resets: the widget sees its touch begin, move and end cancelled (the two tests above), and clicks
    /// nothing. A tap at the same place does click, so the widget can.
    func testPanOverAWidgetScrollsAndDoesNotClick() {
        let (recognizer, phases) = self.recognizer()
        XCTAssertTrue(recognizer.canBePrevented(by: UIPanGestureRecognizer()))
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        recognizer.touchesMoved([touch], with: UIEvent())
        recognizer.reset()
        XCTAssertEqual(phases(), [.began, .moved, .cancelled])

        let (instance, view) = self.booted("<!doctype html><html><head><style>body{margin:0}</style></head><body>"
            + "<button id=\"b\" style=\"display:block;width:200px;height:100px\">b</button><script>window.clicks = 0;"
            + " document.getElementById('b').addEventListener('click', () => { window.clicks++; });</script></body></html>")
        view.handleTouch(phase: .began, at: CGPoint(x: 100.0, y: 30.0))
        view.handleTouch(phase: .moved, at: CGPoint(x: 100.0, y: 70.0))
        view.handleTouch(phase: .cancelled, at: CGPoint(x: 100.0, y: 70.0))
        self.pump(0.05)
        XCTAssertEqual(instance.evaluateForTesting("String(window.clicks)"), "0")
        view.handleTouch(phase: .began, at: CGPoint(x: 100.0, y: 30.0))
        view.handleTouch(phase: .ended, at: CGPoint(x: 100.0, y: 30.0))
        self.pump(0.05)
        XCTAssertEqual(instance.evaluateForTesting("String(window.clicks)"), "1")
    }
}
