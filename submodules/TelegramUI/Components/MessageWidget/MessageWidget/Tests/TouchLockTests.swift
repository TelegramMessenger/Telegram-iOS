import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest
@testable import MessageWidget

/// While a widget control is held, the rest of the chat is inert (the user, 2026-10-23): a finger that lands anywhere
/// else in the chat does nothing until it lifts (multitouch design §2).
final class TouchLockTests: MessageWidgetTestCase {
    /// For the life of the process: a freed UIWindow traps the hostless test process later, when UIKit invalidates its
    /// scene (as VisibilityTests keeps its own).
    private static let window = UIWindow(frame: CGRect(x: 0.0, y: 0.0, width: 400.0, height: 400.0))

    override func tearDown() {
        MessageWidgetTouchLock.resetForTesting()
        super.tearDown()
    }

    /// A recognizer on a plain view, answering every press: it takes taps, and claims its hold when `hold`.
    private func holder(hold: Bool = true) -> (UIView, MessageWidgetTouchRecognizer) {
        let view = UIView()
        let recognizer = MessageWidgetTouchRecognizer()
        recognizer.onTouch = { phase, _, _, _, _ in
            return phase == .began ? MessageWidgetPress(claim: [], takesTaps: true, hold: hold) : .none
        }
        view.addGestureRecognizer(recognizer)
        return (view, recognizer)
    }

    func testATouchOutsideAHolderUnderTheRootIsLocked() {
        let root = UIView()
        let holder = UIView()
        let inside = UIView()
        let other = UIView()
        root.addSubview(holder)
        holder.addSubview(inside)
        root.addSubview(other)
        MessageWidgetTouchLock.setHolding(holder, true)
        XCTAssertTrue(MessageWidgetTouchLock.locks(touchView: other, under: root))
        XCTAssertTrue(MessageWidgetTouchLock.locks(touchView: nil, under: root))
        XCTAssertFalse(MessageWidgetTouchLock.locks(touchView: holder, under: root))
        XCTAssertFalse(MessageWidgetTouchLock.locks(touchView: inside, under: root))
    }

    func testNoHolderNoLock() {
        let root = UIView()
        let holder = UIView()
        let other = UIView()
        root.addSubview(holder)
        root.addSubview(other)
        MessageWidgetTouchLock.setHolding(holder, true)
        MessageWidgetTouchLock.setHolding(holder, false)
        XCTAssertFalse(MessageWidgetTouchLock.locks(touchView: other, under: root))
    }

    /// A widget held in one chat locks nothing in another.
    func testAHolderUnderAnotherRootDoesNotLock() {
        let root = UIView()
        let holder = UIView()
        root.addSubview(holder)
        let otherRoot = UIView()
        let other = UIView()
        otherRoot.addSubview(other)
        MessageWidgetTouchLock.setHolding(holder, true)
        XCTAssertFalse(MessageWidgetTouchLock.locks(touchView: other, under: otherRoot))
    }

    /// A finger the lock holds is no chat drag (a finger then landing on the held widget is still the widget's), a
    /// claimed drag fails everything above it but the lock, and neither recognizer prevents the other.
    func testTheLockRecognizerIsNotAChatDrag() {
        let lock = MessageWidgetChatLockRecognizer()
        XCTAssertFalse(MessageWidgetTouchRecognizer.isChatDrag(lock, state: .began))
        XCTAssertTrue(MessageWidgetTouchRecognizer.isChatDrag(UIPanGestureRecognizer(), state: .changed))
        XCTAssertFalse(MessageWidgetTouchRecognizer.isChatDrag(UIPanGestureRecognizer(), state: .possible))
        XCTAssertFalse(MessageWidgetTouchRecognizer.failsAbove(lock, pans: true, chat: nil))
        XCTAssertTrue(MessageWidgetTouchRecognizer.failsAbove(UITapGestureRecognizer(), pans: false, chat: nil))
        XCTAssertFalse(MessageWidgetTouchRecognizer().canBePrevented(by: lock))
        XCTAssertFalse(lock.canBePrevented(by: UIPanGestureRecognizer()))
        XCTAssertFalse(lock.canPrevent(MessageWidgetTouchRecognizer()))
    }

    /// The chat's vertical scroll is never a widget's to stop (the user, 2026-10-23: "widgets should not be able to prevent
    /// vertical scrolling, ever"): a widget taking the touches, or the lock taking a finger, leaves a pan inside the
    /// chat's view (its scroll, a bubble's swipe to reply) until a finger moves sideways, and fails one on the chat's view
    /// or above it (the back swipe) at once; neither keeps a pan out by exclusion.
    func testNoWidgetStopsAVerticalPan() {
        let chat = UIView()
        let list = UIView()
        chat.addSubview(list)
        let scroll = UIPanGestureRecognizer()
        list.addGestureRecognizer(scroll)
        let back = UIPanGestureRecognizer()
        chat.addGestureRecognizer(back)
        let tap = UITapGestureRecognizer()
        list.addGestureRecognizer(tap)
        XCTAssertFalse(MessageWidgetTouchRecognizer.failsAbove(scroll, pans: false, chat: chat))
        XCTAssertTrue(MessageWidgetTouchRecognizer.failsAbove(scroll, pans: true, chat: chat))
        XCTAssertTrue(MessageWidgetTouchRecognizer.failsAbove(back, pans: false, chat: chat))
        XCTAssertTrue(MessageWidgetTouchRecognizer.failsAbove(tap, pans: false, chat: chat))
        for recognizer in [MessageWidgetTouchRecognizer(), MessageWidgetChatLockRecognizer()] as [UIGestureRecognizer] {
            XCTAssertFalse(recognizer.canPrevent(scroll), "\(recognizer)")
        }
        XCTAssertFalse(MessageWidgetChatLockRecognizer().canPrevent(MessageWidgetTouchRecognizer()))
    }

    /// The chat's view is the one its lock recognizer is on, else the window.
    func testTheChatViewIsTheLocksView() {
        let chat = UIView()
        let bubble = UIView()
        let widget = UIView()
        chat.addSubview(bubble)
        bubble.addSubview(widget)
        XCTAssertNil(MessageWidgetTouchLock.chatView(of: widget))
        chat.addGestureRecognizer(MessageWidgetChatLockRecognizer())
        XCTAssertTrue(MessageWidgetTouchLock.chatView(of: widget) === chat)
    }

    /// What a locked finger does to a recognizer it reaches: one still deciding fails, one already running (a pan that
    /// began as content moved under the finger) is cancelled, one that has ended is left as it is.
    func testALockedFingerFailsOrCancelsWhatItReaches() {
        XCTAssertEqual(MessageWidgetChatLockRecognizer.lockedState(from: .possible), .failed)
        XCTAssertEqual(MessageWidgetChatLockRecognizer.lockedState(from: .began), .cancelled)
        XCTAssertEqual(MessageWidgetChatLockRecognizer.lockedState(from: .changed), .cancelled)
        for state in [UIGestureRecognizer.State.ended, .cancelled, .failed] {
            XCTAssertNil(MessageWidgetChatLockRecognizer.lockedState(from: state))
        }
    }

    /// Only a drag is a chat drag: a recognizer that began otherwise (the bubble's tap waiting for a double tap) leaves a
    /// single finger on a control the widget's, as it always was.
    func testOnlyAPanIsAChatDrag() {
        XCTAssertFalse(MessageWidgetTouchRecognizer.isChatDrag(UITapGestureRecognizer(), state: .began))
        XCTAssertFalse(MessageWidgetTouchRecognizer.isChatDrag(UILongPressGestureRecognizer(), state: .changed))
        XCTAssertTrue(MessageWidgetTouchRecognizer.isChatDrag(UIPanGestureRecognizer(), state: .began))
    }

    /// Another widget in the same chat is "anywhere else in the chat" (multitouch design §2): while one widget holds a
    /// control, a finger on another starts nothing there, early questions included; in another chat it does.
    func testAnotherWidgetUnderAHeldLockStartsNothing() {
        let root = UIView()
        let (held, heldRecognizer) = self.holder()
        let (other, otherRecognizer) = self.holder()
        root.addSubview(held)
        root.addSubview(other)
        heldRecognizer.touchesBegan([UITouch()], with: UIEvent())
        XCTAssertTrue(MessageWidgetTouchLock.isHolding(held))
        var calls = 0
        otherRecognizer.onTouch = { phase, _, _, _, _ in
            calls += 1
            return phase == .began ? MessageWidgetPress(claim: [], takesTaps: true) : .none
        }
        otherRecognizer.touchesBegan([UITouch()], with: UIEvent())
        XCTAssertEqual(otherRecognizer.beginPressEarly(at: CGPoint(x: 5.0, y: 5.0)), .none)
        XCTAssertEqual(calls, 0)
        let elsewhere = UIView()
        let (third, thirdRecognizer) = self.holder()
        elsewhere.addSubview(third)
        var thirdCalls = 0
        thirdRecognizer.onTouch = { _, _, _, _, _ in
            thirdCalls += 1
            return .none
        }
        thirdRecognizer.touchesBegan([UITouch()], with: UIEvent())
        XCTAssertEqual(thirdCalls, 1)
    }

    /// The lock is held while a press claims its hold (touch-action: none), not while one only takes taps.
    func testTheWidgetHoldsWhileAPressClaimsItsHold() {
        let (view, recognizer) = self.holder()
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        XCTAssertTrue(MessageWidgetTouchLock.isHolding(view))
        recognizer.touchesEnded([touch], with: UIEvent())
        XCTAssertFalse(MessageWidgetTouchLock.isHolding(view))
        let (other, otherRecognizer) = self.holder(hold: false)
        otherRecognizer.touchesBegan([UITouch()], with: UIEvent())
        XCTAssertFalse(MessageWidgetTouchLock.isHolding(other))
    }

    func testALockEndsOnReset() {
        let (view, recognizer) = self.holder()
        recognizer.touchesBegan([UITouch()], with: UIEvent())
        recognizer.reset()
        XCTAssertFalse(MessageWidgetTouchLock.isHolding(view))
    }

    func testALockEndsWhenUIKitCancels() {
        let (view, recognizer) = self.holder()
        let touch = UITouch()
        recognizer.touchesBegan([touch], with: UIEvent())
        recognizer.touchesCancelled([touch], with: UIEvent())
        XCTAssertFalse(MessageWidgetTouchLock.isHolding(view))
    }

    /// A widget view leaving its window (a recycled bubble) ends its fingers, and the lock with them.
    func testALockEndsWhenTheHolderLeavesItsWindow() {
        let (instance, view) = self.booted("<!doctype html><html><head><style>body{margin:0}</style></head><body>"
            + "<button style=\"display:block;width:200px;height:100px;touch-action:none\">b</button></body></html>")
        withExtendedLifetime(instance) {
            TouchLockTests.window.addSubview(view)
            defer {
                view.removeFromSuperview()
            }
            let recognizer = view.gestureRecognizers?.compactMap { $0 as? MessageWidgetTouchRecognizer }.first
            // Past the widget's leading 20 pt, where a press claims nothing.
            recognizer?.touchLocation = { _ in CGPoint(x: 100.0, y: 50.0) }
            recognizer?.touchesBegan([UITouch()], with: UIEvent())
            XCTAssertTrue(MessageWidgetTouchLock.isHolding(view))
            view.removeFromSuperview()
            XCTAssertFalse(MessageWidgetTouchLock.isHolding(view))
        }
    }

    /// A finger that landed under the lock stays inert until it lifts, even after the control's finger lifts.
    func testALockedTouchStaysLockedAfterTheHolderLifts() {
        let lock = MessageWidgetChatLockRecognizer()
        lock.locks = { _ in true }
        let stray = UITouch()
        lock.touchesBegan([stray], with: UIEvent())
        XCTAssertEqual(lock.lockedTouchCount, 1)
        lock.locks = { _ in false }
        lock.touchesBegan([UITouch()], with: UIEvent())
        XCTAssertEqual(lock.lockedTouchCount, 1)
        lock.touchesEnded([stray], with: UIEvent())
        XCTAssertEqual(lock.lockedTouchCount, 0)
    }

    func testTheLockRecognizerIsOffWhileNoWidgetUnderItHolds() {
        let chat = UIView()
        let holder = UIView()
        chat.addSubview(holder)
        let otherChat = UIView()
        let otherHolder = UIView()
        otherChat.addSubview(otherHolder)
        let lock = MessageWidgetChatLockRecognizer()
        chat.addGestureRecognizer(lock)
        XCTAssertFalse(lock.isEnabled)
        MessageWidgetTouchLock.setHolding(otherHolder, true)
        XCTAssertFalse(lock.isEnabled)
        MessageWidgetTouchLock.setHolding(holder, true)
        XCTAssertTrue(lock.isEnabled)
        MessageWidgetTouchLock.setHolding(holder, false)
        XCTAssertFalse(lock.isEnabled)
    }
}
