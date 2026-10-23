import UIKit
import UIKit.UIGestureRecognizerSubclass

/// While a widget control is held, the rest of the chat is inert (the user, 2026-10-23; multitouch design §2): a finger
/// that lands anywhere else in the chat does nothing, no scroll, tap, long press, menu or back swipe, until it lifts. A
/// widget view holds the lock while one of its presses takes taps (`MessageWidgetTouchRecognizer`); the chat's
/// `MessageWidgetChatLockRecognizer` reads it. Main thread only.
enum MessageWidgetTouchLock {
    private struct Holder {
        weak var view: UIView?
    }

    private static var holders: [Holder] = []
    private static var recognizers: [WeakLockRecognizer] = []

    private struct WeakLockRecognizer {
        weak var recognizer: MessageWidgetChatLockRecognizer?
    }

    static func setHolding(_ view: UIView, _ holding: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        let was = self.isHolding(view)
        self.holders.removeAll { $0.view == nil || $0.view === view }
        if holding {
            self.holders.append(Holder(view: view))
        }
        if was != holding {
            self.holdersChanged()
        }
    }

    static func isHolding(_ view: UIView) -> Bool {
        return self.holders.contains { $0.view === view }
    }

    /// Whether another widget view in the same chat (under the same root) holds the lock: a finger on `view` then
    /// starts nothing.
    static func isHeld(elsewhereThan view: UIView) -> Bool {
        let root = self.root(of: view)
        return self.holders.contains { holder in
            guard let held = holder.view, held !== view, !held.isDescendant(of: view), !view.isDescendant(of: held) else {
                return false
            }
            return self.root(of: held) === root
        }
    }

    private static func root(of view: UIView) -> UIView {
        var root = view
        while let superview = root.superview {
            root = superview
        }
        return root
    }

    /// Whether a touch on `touchView` in the chat rooted at `root` is locked: a view under `root` holds the lock, and
    /// the touch is not on a holding view or inside one. A touch on no view is locked.
    static func locks(touchView: UIView?, under root: UIView) -> Bool {
        let held = self.holders.compactMap(\.view).filter { $0.isDescendant(of: root) }
        if held.isEmpty {
            return false
        }
        guard let touchView else {
            return true
        }
        return !held.contains { touchView.isDescendant(of: $0) }
    }

    fileprivate static func register(_ recognizer: MessageWidgetChatLockRecognizer) {
        self.recognizers.removeAll { $0.recognizer == nil }
        self.recognizers.append(WeakLockRecognizer(recognizer: recognizer))
    }

    /// A locked touch's view must never see it begin (a button would show its highlight): the lock recognizers delay
    /// touches while a widget under them holds the lock.
    private static func holdersChanged() {
        self.recognizers.removeAll { $0.recognizer == nil }
        for entry in self.recognizers {
            guard let recognizer = entry.recognizer else {
                continue
            }
            recognizer.delaysTouchesBegan = recognizer.view.map { root in self.holders.contains { $0.view?.isDescendant(of: root) ?? false } } ?? false
        }
    }

    /// Tests only.
    static func resetForTesting() {
        self.holders.removeAll()
        self.holdersChanged()
    }
}

/// The chat's side of the lock (`MessageWidgetTouchLock`), on the chat's root view (`ChatControllerNode`): a finger
/// that lands while a widget under it holds a control, anywhere but on that widget, begins this recognizer, which fails
/// every recognizer the finger reaches and cancels the finger in its view, and stays locked until the finger lifts,
/// whatever the widget does meanwhile. Every other finger is ignored, never failing the recognizer, so later fingers
/// still reach it.
public final class MessageWidgetChatLockRecognizer: UIGestureRecognizer {
    /// Tests: whether a touch is locked; nil asks `MessageWidgetTouchLock` about the touch's view under this view.
    var locks: ((UITouch) -> Bool)?
    private var locked: [UITouch] = []

    var lockedTouchCount: Int {
        return self.locked.count
    }

    public init() {
        super.init(target: nil, action: nil)
        self.cancelsTouchesInView = true
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
        MessageWidgetTouchLock.register(self)
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        for touch in touches {
            let locked: Bool
            if let locks = self.locks {
                locked = locks(touch)
            } else if let root = self.view {
                locked = MessageWidgetTouchLock.locks(touchView: touch.view, under: root)
            } else {
                locked = false
            }
            guard locked else {
                self.ignore(touch, for: event)
                continue
            }
            self.locked.append(touch)
            // The window's own recognizers are the system's and are left alone, as a widget's claimed drag leaves them.
            for recognizer in touch.gestureRecognizers ?? [] where recognizer !== self && !(recognizer is MessageWidgetTouchRecognizer) && !(recognizer.view is UIWindow) && recognizer.state == .possible {
                recognizer.state = .failed
            }
        }
        if !self.locked.isEmpty {
            switch self.state {
            case .possible:
                self.state = .began
            case .began, .changed:
                self.state = .changed
            default:
                break
            }
        }
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        self.release(touches, ending: .ended)
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        self.release(touches, ending: .cancelled)
    }

    private func release(_ touches: Set<UITouch>, ending: UIGestureRecognizer.State) {
        let before = self.locked.count
        self.locked.removeAll { touches.contains($0) }
        if before > 0 && self.locked.isEmpty {
            self.state = ending
        }
    }

    override public func reset() {
        super.reset()
        self.locked = []
    }

    override public func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        // It fails what a locked finger reaches itself, and never a widget's fingers.
        return false
    }

    override public func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Nothing may stop it hearing later fingers: a widget's claimed drag, or the list's pan before the lock.
        return false
    }
}
