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
        recognizer.onTouch = { phase, _, _, _, _ in
            phases.append(phase)
            return phase == .began ? press : .none
        }
        return (recognizer, { phases })
    }

    private typealias Call = (phase: MessageWidgetView.TouchPhase, pointer: Int32, primary: Bool, kind: MessageWidgetPointerKind)

    /// A recognizer whose presses answer `answer(pointer)`, recording each call's phase, pointer, primary flag and kind.
    private func pointerRecognizer(_ answer: @escaping (Int32) -> MessageWidgetPress = { _ in .none }) -> (MessageWidgetTouchRecognizer, () -> [Call]) {
        let recognizer = MessageWidgetTouchRecognizer()
        var calls: [Call] = []
        recognizer.onTouch = { phase, _, pointer, primary, kind in
            calls.append((phase, pointer, primary, kind))
            return phase == .began ? answer(pointer) : .none
        }
        return (recognizer, { calls })
    }

    private func described(_ calls: [Call]) -> [String] {
        return calls.map { "\($0.phase):\($0.primary ? "P" : "S")" }
    }

    /// Multitouch (design §5.2): each finger is its own pointer, its moves included; the first down while none is
    /// tracked is primary.
    func testTwoTouchesAreTwoPointers() {
        let (recognizer, calls) = self.pointerRecognizer()
        let first = UITouch()
        let second = UITouch()
        recognizer.touchesBegan([first], with: UIEvent())
        recognizer.touchesBegan([second], with: UIEvent())
        recognizer.touchesMoved([second], with: UIEvent())
        recognizer.touchesEnded([second], with: UIEvent())
        recognizer.touchesMoved([first], with: UIEvent())
        let made = calls()
        XCTAssertEqual(self.described(made), ["began:P", "began:S", "moved:S", "ended:S", "moved:P"])
        XCTAssertNotEqual(made[0].pointer, made[1].pointer)
        XCTAssertEqual(made[2].pointer, made[1].pointer)
        XCTAssertEqual(made[3].pointer, made[1].pointer)
        XCTAssertEqual(made[4].pointer, made[0].pointer)
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

    /// Once the chat scrolls (a pan above the widget began, which nothing the widget does can stop), the touches the
    /// widget took end as cancelled, as a finger landing during a scroll starts nothing.
    func testAChatScrollEndsTheTouchesTheWidgetTook() {
        let (recognizer, calls) = self.pointerRecognizer { _ in MessageWidgetPress(claim: [], takesTaps: true, hold: true) }
        var dragging = false
        recognizer.chatIsDragging = { dragging }
        let first = UITouch()
        let second = UITouch()
        recognizer.touchesBegan([first], with: UIEvent())
        recognizer.touchesBegan([second], with: UIEvent())
        dragging = true
        recognizer.touchesMoved([first], with: UIEvent())
        XCTAssertEqual(self.described(calls()).filter { $0.hasPrefix("cancelled") }.count, 2)
    }

    /// A move the widget answers by ending every touch (the host's cancel, from inside the move's callback) leaves the
    /// recognizer no finger to go on with: the move ends there.
    func testAMoveThatCancelsTheTouchesEndsThere() {
        let recognizer = MessageWidgetTouchRecognizer()
        var phases: [MessageWidgetView.TouchPhase] = []
        recognizer.onTouch = { [unowned recognizer] phase, _, _, _, _ in
            phases.append(phase)
            if phase == .moved {
                recognizer.cancelTrackedTouches()
            }
            return phase == .began ? MessageWidgetPress(claim: [.horizontal], takesTaps: true) : .none
        }
        var at = CGPoint.zero
        recognizer.touchLocation = { _ in at }
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        at = CGPoint(x: 40.0, y: 0.0)
        recognizer.touchesMoved([touch], with: UIEvent())
        XCTAssertEqual(phases, [.began, .moved, .cancelled])
        XCTAssertEqual(recognizer.state, .possible)
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

    /// Once a second finger took the touches for the widget (a part that claims its hold under one of them), every
    /// question the bubble asks is the widget's until every finger has lifted: the bubble's long-tap timer survives the
    /// recognizer being failed from outside, fires, and asks about the finger on the other part (the harness opened the
    /// menu).
    func testWhileTheWidgetHoldsTheTouchesEveryQuestionIsTheWidgets() {
        let (recognizer, _) = self.pointerRecognizer { pointer in MessageWidgetPress(claim: [], takesTaps: true, hold: pointer == 2) }
        let pad = UITouch()
        let button = UITouch()
        let points = [ObjectIdentifier(pad): CGPoint(x: 10.0, y: 100.0), ObjectIdentifier(button): CGPoint(x: 10.0, y: 10.0)]
        recognizer.touchLocation = { points[ObjectIdentifier($0)] ?? .zero }
        recognizer.touchesBegan([pad], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.hold, false)
        recognizer.touchesBegan([button], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.hold, true)
        recognizer.touchesEnded([button], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.hold, true)
        recognizer.touchesEnded([pad], with: UIEvent())
        recognizer.reset()
        recognizer.touchesBegan([pad], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.hold, false)
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
        let (recognizer, _) = self.pointerRecognizer { pointer in MessageWidgetPress(claim: [], takesTaps: true, hold: pointer == 2) }
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
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 10.0, y: 100.0))?.hold, false)
    }

    /// The two-finger rules key on holds (decision 2): fingers on parts that handle taps but claim no hold (auto
    /// buttons) neither take the touches from the chat nor hold its lock, so a hold under them is still the menu.
    func testTwoFingersOnAutoPartsDoNotTakeTheTouches() {
        let (recognizer, _) = self.pointerRecognizer { _ in MessageWidgetPress(claim: [], takesTaps: true, hold: false) }
        let view = UIView()
        view.addGestureRecognizer(recognizer)
        let first = UITouch()
        let second = UITouch()
        recognizer.touchesBegan([first], with: UIEvent())
        XCTAssertFalse(MessageWidgetTouchLock.isHolding(view))
        recognizer.touchesBegan([second], with: UIEvent())
        XCTAssertFalse(recognizer.tookTouches)
        XCTAssertFalse(MessageWidgetTouchLock.isHolding(view))
        recognizer.touchesEnded([first, second], with: UIEvent())
    }

    /// With two fingers down on parts the widget does not handle, a question reads the press of the finger nearest its
    /// point (here told apart by their claims).
    func testAQuestionWithTwoTouchesReadsTheNearestPress() {
        let (recognizer, _) = self.pointerRecognizer { pointer in MessageWidgetPress(claim: pointer == 1 ? [.horizontal] : [], takesTaps: false) }
        let first = UITouch()
        let second = UITouch()
        let points = [ObjectIdentifier(first): CGPoint(x: 10.0, y: 10.0), ObjectIdentifier(second): CGPoint(x: 200.0, y: 10.0)]
        recognizer.touchLocation = { points[ObjectIdentifier($0)] ?? .zero }
        recognizer.touchesBegan([first], with: UIEvent())
        recognizer.touchesBegan([second], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: CGPoint(x: 11.0, y: 12.0))?.claim, [.horizontal])
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
    /// landed on something the widget handles (a button here). A vertical drag is never the widget's (the user,
    /// 2026-10-23: "widgets should not be able to prevent vertical scrolling, ever"): touch-action: none claims the
    /// horizontal one only.
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
            MessageWidgetPress(claim: [], takesTaps: false, hold: false),
            MessageWidgetPress(claim: [.horizontal], takesTaps: true, hold: true),
            MessageWidgetPress(claim: [.horizontal], takesTaps: true, hold: false),
            MessageWidgetPress(claim: [], takesTaps: true, hold: false)
        ])
    }

    /// A drag its press claims is the widget's well short of the chat's pans, which begin at about 10 pt (the list's
    /// pan took a claimed drag whose decision also came at 10 pt): taking it keeps the chat's pans off the touch (read
    /// here, as a recognizer outside a window keeps its state). The runtime still tells a tap from a drag by the
    /// gesture policy's 10 px slop.
    func testAClaimedDragIsTakenShortOfTheChatsPans() {
        let (recognizer, _) = self.recognizer(press: MessageWidgetPress(claim: [.horizontal], takesTaps: true, hold: false))
        var at = CGPoint.zero
        recognizer.touchLocation = { _ in at }
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        at = CGPoint(x: 2.0, y: 0.0)
        recognizer.touchesMoved([touch], with: UIEvent())
        XCTAssertFalse(recognizer.canPrevent(UIPanGestureRecognizer()))
        at = CGPoint(x: 6.0, y: 0.0)
        recognizer.touchesMoved([touch], with: UIEvent())
        XCTAssertTrue(recognizer.canPrevent(UIPanGestureRecognizer()))
        recognizer.touchesEnded([touch], with: UIEvent())
    }

    /// An iPad pointer (a trackpad, a mouse) presses as the policy's mouse, with its button: its down, moves and end
    /// carry both.
    func testAPointerTouchPressesAsAMouse() {
        let (recognizer, calls) = self.pointerRecognizer()
        let secondary = MessageWidgetPointerKind(mouse: true, button: 2)
        recognizer.touchKind = { _, _ in secondary }
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        recognizer.touchesMoved([touch], with: UIEvent())
        recognizer.touchesEnded([touch], with: UIEvent())
        XCTAssertEqual(calls().map(\.kind), [secondary, secondary, secondary])
    }

    /// The bubble's question starts a press before its touch reaches the recognizer, and cannot tell a pointer from a
    /// finger: a pointer's touch retracts that press (a cancel to the widget, never a press to its double tap) and presses
    /// again as a mouse.
    func testAPointerTouchRestartsAnEarlyPress() {
        let (recognizer, calls) = self.pointerRecognizer()
        recognizer.touchKind = { _, _ in MessageWidgetPointerKind(mouse: true, button: 0) }
        _ = recognizer.beginPressEarly(at: .zero)
        recognizer.touchesBegan([UITouch()], with: UIEvent())
        XCTAssertEqual(calls().map { "\($0.phase):\($0.kind.mouse ? "M" : "T"):\($0.primary ? "P" : "S")" }, ["began:T:P", "retracted:T:P", "began:M:P"])
    }

    /// A pointer hovers over the view before it clicks: a question the bubble asks where it hovers is answered as the
    /// policy's mouse answers (its holds and sideways drags are the widget's) and starts no press, so the press the widget
    /// gets is the one the pointer's touch starts, with its real button: a right click is never a primary press first
    /// (final review I1). Elsewhere, or once a finger touched, a question starts a touch's press as before.
    func testAHoveringPointersQuestionStartsNoPress() {
        let (recognizer, calls) = self.pointerRecognizer()
        var kind = MessageWidgetPointerKind(mouse: true, button: 2)
        recognizer.touchKind = { _, _ in kind }
        var at = CGPoint(x: 10.0, y: 10.0)
        recognizer.touchLocation = { _ in at }
        recognizer.pointerHovered(at: CGPoint(x: 10.0, y: 10.0))
        XCTAssertEqual(recognizer.beginPressEarly(at: CGPoint(x: 10.3, y: 9.8)), MessageWidgetPress(claim: [.horizontal], takesTaps: true, hold: true))
        XCTAssertTrue(calls().isEmpty)
        let pointer = UITouch()
        recognizer.touchesBegan([pointer], with: UIEvent())
        recognizer.touchesEnded([pointer], with: UIEvent())
        recognizer.reset()
        XCTAssertEqual(calls().map { "\($0.phase):\($0.kind.mouse ? "M" : "T")\($0.kind.button)" }, ["began:M2", "ended:M2"])
        _ = recognizer.beginPressEarly(at: CGPoint(x: 100.0, y: 100.0))
        self.pump(0.05)
        XCTAssertEqual(calls().last?.kind, .touch)
        kind = .touch
        at = CGPoint(x: 50.0, y: 50.0)
        let finger = UITouch()
        recognizer.touchesBegan([finger], with: UIEvent())
        recognizer.touchesEnded([finger], with: UIEvent())
        recognizer.reset()
        _ = recognizer.beginPressEarly(at: CGPoint(x: 10.0, y: 10.0))
        self.pump(0.05)
        XCTAssertEqual(calls().suffix(2).map(\.kind), [.touch, .touch])
    }

    /// A press the widget did not answer within the wait (a busy game) leans to the widget, as it did before holds were
    /// keyed on touch-action (final review I2): its hold opens no menu, it holds the chat's lock, and a second finger
    /// steps the chat back.
    func testAnUnansweredPressLeansToTheWidget() {
        let (recognizer, _) = self.pointerRecognizer { _ in .unanswered }
        let view = UIView()
        view.addGestureRecognizer(recognizer)
        let first = UITouch()
        let second = UITouch()
        recognizer.touchesBegan([first], with: UIEvent())
        XCTAssertEqual(recognizer.pressAnswer(near: .zero)?.hold, true)
        XCTAssertTrue(MessageWidgetTouchLock.isHolding(view))
        recognizer.touchesBegan([second], with: UIEvent())
        XCTAssertTrue(recognizer.tookTouches)
        recognizer.touchesEnded([first, second], with: UIEvent())
        XCTAssertFalse(MessageWidgetTouchLock.isHolding(view))
    }

    /// A pointer has no hold menu and no swipes (the policy's mouse): a pointer press that claims its hold takes the
    /// touches at its down, so the bubble's context gesture and the swipes above it fail; a finger's does not.
    func testAPointerPressThatClaimsHoldsTakesTheTouches() {
        for (kind, takes) in [(MessageWidgetPointerKind(mouse: true, button: 0), true), (MessageWidgetPointerKind.touch, false)] {
            let (recognizer, _) = self.recognizer(press: MessageWidgetPress(claim: [.horizontal], takesTaps: false, hold: true))
            recognizer.touchKind = { _, _ in kind }
            let touch = UITouch()
            recognizer.touchesBegan([touch], with: UIEvent())
            XCTAssertEqual(recognizer.tookTouches, takes, "\(kind)")
            recognizer.touchesEnded([touch], with: UIEvent())
        }
    }

    /// A secondary click on a part that claims no holds is the chat's: it opens the message's menu at the click's end,
    /// as a secondary click elsewhere in the chat does. On one that claims holds the widget had its contextmenu, and a
    /// primary click is the widget's.
    func testASecondaryClickOpensTheMenuUnlessThePressClaimsHolds() {
        for (button, hold, opens) in [(2, false, true), (2, true, false), (0, false, false)] {
            let (recognizer, _) = self.recognizer(press: MessageWidgetPress(claim: [.horizontal], takesTaps: true, hold: hold))
            recognizer.touchKind = { _, _ in MessageWidgetPointerKind(mouse: true, button: button) }
            recognizer.touchLocation = { _ in CGPoint(x: 30.0, y: 40.0) }
            var clicks: [CGPoint] = []
            recognizer.onSecondaryClick = { clicks.append($0) }
            let touch = UITouch()
            recognizer.touchesBegan([touch], with: UIEvent())
            recognizer.touchesEnded([touch], with: UIEvent())
            XCTAssertEqual(clicks, opens ? [CGPoint(x: 30.0, y: 40.0)] : [], "button \(button), hold \(hold)")
        }
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

    /// An early press no touch adopts is retracted on the next run-loop turn, and one at another point when the touch
    /// begins.
    func testAnEarlyPressNoTouchAdoptsIsRetracted() {
        let (recognizer, phases) = self.recognizer(press: MessageWidgetPress(claim: [.horizontal], takesTaps: true))
        _ = recognizer.beginPressEarly(at: .zero)
        self.pump(0.05)
        XCTAssertEqual(phases(), [.began, .retracted])
        _ = recognizer.beginPressEarly(at: CGPoint(x: 40.0, y: 40.0))
        recognizer.touchesBegan([UITouch()], with: UIEvent())
        self.pump(0.05)
        XCTAssertEqual(phases(), [.began, .retracted, .began, .retracted, .began])
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
