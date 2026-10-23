import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest
@testable import MessageWidget

/// A widget takes its touches through its own recognizer. In a chat a recognizer above the bubble (likely the
/// history's keyboard-dismissing tap) recognizes every tap and so cancels the touched view's touches: a widget that read
/// `touchesEnded` got `touchesCancelled` instead and never clicked (measured on K3, 2026-10-15).
final class TouchRecognizerTests: MessageWidgetTestCase {
    private func recognizer(press: MessageWidgetPress = .none) -> (MessageWidgetTouchRecognizer, () -> [MessageWidgetView.TouchPhase]) {
        let recognizer = MessageWidgetTouchRecognizer()
        var phases: [MessageWidgetView.TouchPhase] = []
        recognizer.onTouch = { phase, _, _, _ in
            phases.append(phase)
            return phase == .began ? press : .none
        }
        return (recognizer, { phases })
    }

    private typealias Call = (phase: MessageWidgetView.TouchPhase, pointer: Int32, primary: Bool)

    /// A recognizer whose presses answer `answer(pointer)`, recording each call's phase, pointer and primary flag.
    private func pointerRecognizer(_ answer: @escaping (Int32) -> MessageWidgetPress = { _ in .none }) -> (MessageWidgetTouchRecognizer, () -> [Call]) {
        let recognizer = MessageWidgetTouchRecognizer()
        var calls: [Call] = []
        recognizer.onTouch = { phase, _, pointer, primary in
            calls.append((phase, pointer, primary))
            return phase == .began ? answer(pointer) : .none
        }
        return (recognizer, { calls })
    }

    private func described(_ calls: [Call]) -> [String] {
        return calls.map { "\($0.phase):\($0.primary ? "P" : "S")" }
    }

    /// Multitouch (design §5.2): each finger is its own pointer; the first down while none is tracked is primary.
    func testTwoTouchesAreTwoPointers() {
        let (recognizer, calls) = self.pointerRecognizer()
        let first = UITouch()
        let second = UITouch()
        recognizer.touchesBegan([first], with: UIEvent())
        recognizer.touchesBegan([second], with: UIEvent())
        recognizer.touchesEnded([second], with: UIEvent())
        recognizer.touchesMoved([first], with: UIEvent())
        let made = calls()
        XCTAssertEqual(self.described(made), ["began:P", "began:S", "ended:S", "moved:P"])
        XCTAssertNotEqual(made[0].pointer, made[1].pointer)
        XCTAssertEqual(made[2].pointer, made[1].pointer)
        XCTAssertEqual(made[3].pointer, made[0].pointer)
    }

    /// Every end path ends every finger: UIKit's reset and the host's cancel cancel each tracked touch once.
    func testResetCancelsEveryTouch() {
        for end in [{ (r: MessageWidgetTouchRecognizer) in r.reset() }, { (r: MessageWidgetTouchRecognizer) in r.cancelTrackedTouches() }] {
            let (recognizer, calls) = self.pointerRecognizer()
            recognizer.touchesBegan([UITouch()], with: UIEvent())
            recognizer.touchesBegan([UITouch()], with: UIEvent())
            end(recognizer)
            recognizer.reset()
            let made = calls()
            XCTAssertEqual(self.described(made), ["began:P", "began:S", "cancelled:P", "cancelled:S"])
            XCTAssertEqual(Set(made.dropFirst(2).map(\.pointer)), Set(made.prefix(2).map(\.pointer)))
        }
    }

    /// The app going to the background or a system alert cancels every touch at once.
    func testUIKitsCancelCancelsEachTouch() {
        let (recognizer, calls) = self.pointerRecognizer()
        let first = UITouch()
        let second = UITouch()
        recognizer.touchesBegan([first], with: UIEvent())
        recognizer.touchesBegan([second], with: UIEvent())
        recognizer.touchesCancelled([first, second], with: UIEvent())
        recognizer.reset()
        XCTAssertEqual(self.described(calls()).filter { $0.hasPrefix("cancelled") }.count, 2)
    }

    /// At most `maximumTouches` fingers: another is ignored whole, its end too.
    func testASixthTouchIsIgnored() {
        let (recognizer, calls) = self.pointerRecognizer()
        let touches = (0 ..< 6).map { _ in UITouch() }
        for touch in touches {
            recognizer.touchesBegan([touch], with: UIEvent())
        }
        XCTAssertEqual(calls().count, 5)
        recognizer.touchesEnded([touches[5]], with: UIEvent())
        XCTAssertEqual(calls().count, 5)
    }

    /// While the chat drags (the list's pan, swipe-to-reply, the back swipe), a finger on the widget starts nothing,
    /// whether its touch or the bubble's early question comes first (the user, 2026-10-23).
    func testATouchDuringAChatDragStartsNoPress() {
        let (recognizer, calls) = self.pointerRecognizer { _ in MessageWidgetPress(claim: [], takesTaps: true) }
        recognizer.chatIsDragging = { true }
        recognizer.touchesBegan([UITouch()], with: UIEvent())
        XCTAssertEqual(recognizer.beginPressEarly(at: .zero), .none)
        self.pump(0.05)
        XCTAssertEqual(calls().count, 0)
    }

    /// Once a second finger took the touches for the widget (a part it handles under one of them), every question the
    /// bubble asks is the widget's until every finger has lifted: the bubble's long-tap timer survives the recognizer
    /// being failed from outside, fires, and asks about the finger on the empty part (the harness opened the menu).
    func testWhileTheWidgetHoldsTheTouchesEveryQuestionIsTheWidgets() {
        let (recognizer, _) = self.pointerRecognizer { pointer in MessageWidgetPress(claim: [], takesTaps: pointer == 2) }
        let pad = UITouch()
        let button = UITouch()
        let points = [ObjectIdentifier(pad): CGPoint(x: 10.0, y: 100.0), ObjectIdentifier(button): CGPoint(x: 10.0, y: 10.0)]
        recognizer.touchLocation = { points[ObjectIdentifier($0)] ?? .zero }
        recognizer.touchesBegan([pad], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.takesTaps, false)
        recognizer.touchesBegan([button], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.takesTaps, true)
        recognizer.touchesEnded([button], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.takesTaps, true)
        recognizer.touchesEnded([pad], with: UIEvent())
        recognizer.reset()
        recognizer.touchesBegan([pad], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.takesTaps, false)
    }

    /// Two fingers landing in one event: the bubble's question started the press of one of them (`touches.first`), and
    /// that finger adopts it whichever order the set iterates in, with no cancel (a game would see its press twice).
    func testTwoTouchesInOneEventAdoptTheEarlyPress() {
        for _ in 0 ..< 20 {
            let (recognizer, calls) = self.pointerRecognizer { _ in MessageWidgetPress(claim: [], takesTaps: true) }
            let first = UITouch()
            let second = UITouch()
            let points = [ObjectIdentifier(first): CGPoint(x: 10.0, y: 10.0), ObjectIdentifier(second): CGPoint(x: 200.0, y: 10.0)]
            recognizer.touchLocation = { points[ObjectIdentifier($0)] ?? .zero }
            _ = recognizer.beginPressEarly(at: CGPoint(x: 10.0, y: 10.0))
            recognizer.touchesBegan([first, second], with: UIEvent())
            let made = calls()
            XCTAssertEqual(self.described(made), ["began:P", "began:S"])
            XCTAssertEqual(made.first?.pointer, 1)
        }
    }

    /// The host taking the touches (the bubble lifted into its menu, the view leaving its window) also forgets that the
    /// widget took them: a later touch's questions read its own press again.
    func testCancellingTheTouchesForgetsThatTheWidgetTookThem() {
        let (recognizer, _) = self.pointerRecognizer { pointer in MessageWidgetPress(claim: [], takesTaps: pointer == 2) }
        let pad = UITouch()
        let button = UITouch()
        let later = UITouch()
        let points = [ObjectIdentifier(pad): CGPoint(x: 10.0, y: 100.0), ObjectIdentifier(button): CGPoint(x: 10.0, y: 10.0),
                      ObjectIdentifier(later): CGPoint(x: 10.0, y: 100.0)]
        recognizer.touchLocation = { points[ObjectIdentifier($0)] ?? .zero }
        recognizer.touchesBegan([pad], with: UIEvent())
        recognizer.touchesBegan([button], with: UIEvent())
        recognizer.cancelTrackedTouches()
        recognizer.touchesBegan([later], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.takesTaps, false)
    }

    /// With two fingers down on parts the widget does not handle, a question reads the press of the finger nearest its
    /// point (here told apart by their claims).
    func testAQuestionWithTwoTouchesReadsTheNearestPress() {
        let (recognizer, _) = self.pointerRecognizer { pointer in MessageWidgetPress(claim: pointer == 1 ? [.vertical] : [], takesTaps: false) }
        let first = UITouch()
        let second = UITouch()
        let points = [ObjectIdentifier(first): CGPoint(x: 10.0, y: 10.0), ObjectIdentifier(second): CGPoint(x: 200.0, y: 10.0)]
        recognizer.touchLocation = { points[ObjectIdentifier($0)] ?? .zero }
        recognizer.touchesBegan([first], with: UIEvent())
        recognizer.touchesBegan([second], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 11.0, y: 12.0))?.claim, [.vertical])
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 199.0, y: 9.0))?.claim, [])
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
        recognizer.cancelTrackedTouches()
        recognizer.touchesEnded([touch], with: UIEvent())
        recognizer.cancelTrackedTouches()
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

    /// sdk-v1 §5.5: a press answers the drags its widget claims, from the touch-action at its point, and whether it
    /// landed on something the widget handles (a button here).
    func testAPressAnswersItsClaimAndWhetherItTakesTaps() {
        let (instance, view) = self.booted("<!doctype html><html><head><style>body{margin:0} div,button{display:block;"
            + "width:100px;height:50px;margin:0;padding:0;border:0}</style></head><body><div></div>"
            + "<div style=\"touch-action:none\"></div><div style=\"touch-action:pan-y\"></div><button></button></body></html>")
        // The view holds its instance weakly: keep it for the presses.
        let presses = withExtendedLifetime(instance) {
            [25.0, 75.0, 125.0, 175.0].map { y -> MessageWidgetPress in
                let press = view.handleTouch(phase: .began, at: CGPoint(x: 50.0, y: y))
                view.handleTouch(phase: .ended, at: CGPoint(x: 50.0, y: y))
                return press
            }
        }
        XCTAssertEqual(presses, [
            MessageWidgetPress(claim: [], takesTaps: false),
            MessageWidgetPress(claim: [.horizontal, .vertical], takesTaps: true),
            MessageWidgetPress(claim: [.horizontal], takesTaps: true),
            MessageWidgetPress(claim: [], takesTaps: true)
        ])
    }

    /// The back swipe and the bubble's tap recognizer ask for a press before the touch reaches the recognizer: the press
    /// starts there, and the touch that begins at its point adopts it rather than starting a second one.
    func testAnEarlyPressIsAdoptedByItsTouch() {
        let answer = MessageWidgetPress(claim: [.horizontal], takesTaps: true)
        let (recognizer, phases) = self.recognizer(press: answer)
        XCTAssertEqual(recognizer.beginPressEarly(at: .zero), answer)
        XCTAssertEqual(recognizer.beginPressEarly(at: CGPoint(x: 0.4, y: -0.3)), answer)
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        self.pump(0.05)
        recognizer.touchesEnded([touch], with: UIEvent())
        XCTAssertEqual(phases(), [.began, .ended])
    }

    /// An early press no touch adopts ends as cancelled on the next run-loop turn, and one at another point when the
    /// touch begins.
    func testAnEarlyPressNoTouchAdoptsIsCancelled() {
        let (recognizer, phases) = self.recognizer(press: MessageWidgetPress(claim: [.horizontal], takesTaps: true))
        _ = recognizer.beginPressEarly(at: .zero)
        self.pump(0.05)
        XCTAssertEqual(phases(), [.began, .cancelled])
        _ = recognizer.beginPressEarly(at: CGPoint(x: 40.0, y: 40.0))
        recognizer.touchesBegan([UITouch()], with: UIEvent())
        self.pump(0.05)
        XCTAssertEqual(phases(), [.began, .cancelled, .began, .cancelled, .began])
    }

    /// While the touch is down, the bubble's questions are about it wherever they are asked from: its press animation
    /// scales the bubble during a long press, so the finger's point in the widget drifts (1.3 pt measured in the
    /// harness) and a question matched by point found no press, which read as the widget's, so no menu opened (K3).
    func testAQuestionDuringTheTouchReadsItsPressWhereverItIsAsked() {
        let answer = MessageWidgetPress(claim: [], takesTaps: false)
        let (recognizer, _) = self.recognizer(press: answer)
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 0.1, y: 1.3)), answer)
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 6.0, y: 12.0)), answer)
        recognizer.touchesEnded([touch], with: UIEvent())
    }

    /// UIKit tells a touch's recognizers about it in an order of its own: the bubble's context gesture can hear the touch
    /// first and ask before anything started its press (2 of 8 launches in the harness; always on K3). Its question
    /// starts the press there, as the tap recognizer's does, and the touch adopts it: no menu was ever allowed, since a
    /// question that found no press answered as the widget's.
    func testAQuestionBeforeAnyPressStartsIt() {
        let answer = MessageWidgetPress(claim: [], takesTaps: false)
        let (recognizer, phases) = self.recognizer(press: answer)
        XCTAssertEqual(recognizer.pressAnswerOrBegin(at: .zero), answer)
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswerOrBegin(at: CGPoint(x: 0.0, y: 2.0)), answer)
        recognizer.touchesEnded([touch], with: UIEvent())
        self.pump(0.05)
        XCTAssertEqual(phases(), [.began, .ended])
        // After the touch, a question where it went down reads its press and starts nothing.
        XCTAssertEqual(recognizer.pressAnswerOrBegin(at: CGPoint(x: 0.4, y: 0.0)), answer)
        self.pump(0.05)
        XCTAssertEqual(phases(), [.began, .ended])
    }

    /// The bubble acts on a tap or a double tap after the touch has ended and asks about it again: the answer is the
    /// press that went down there, and asking starts nothing.
    func testALateQuestionReadsThePressThatWentDownThere() {
        let (recognizer, phases) = self.recognizer(press: MessageWidgetPress(claim: [], takesTaps: false))
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        recognizer.touchesEnded([touch], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 0.5, y: 0.5)), MessageWidgetPress(claim: [], takesTaps: false))
        XCTAssertNil(recognizer.pressAnswer(near: CGPoint(x: 30.0, y: 0.0)))
        self.pump(0.05)
        XCTAssertEqual(phases(), [.began, .ended])
    }
}
