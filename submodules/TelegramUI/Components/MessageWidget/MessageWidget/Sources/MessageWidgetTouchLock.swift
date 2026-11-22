import UIKit
import UIKit.UIGestureRecognizerSubclass

/// While a widget control is held, the rest of the chat is inert (the user, 2026-10-23; multitouch design §2): a finger
/// that lands anywhere else in the chat does nothing, no scroll, tap, long press, menu or back swipe, until it lifts. A
/// widget view holds the lock while one of its presses claims its hold (`MessageWidgetTouchRecognizer`); the chat's
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

    /// The chat's view a widget view is in: the nearest ancestor the chat's lock recognizer is on (`ChatControllerNode`'s),
    /// else its window.
    static func chatView(of view: UIView?) -> UIView? {
        var current = view?.superview
        while let candidate = current {
            if candidate.gestureRecognizers?.contains(where: { $0 is MessageWidgetChatLockRecognizer }) ?? false {
                return candidate
            }
            current = candidate.superview
        }
        return view?.window
    }

    /// The chat under `root` scrolls: every widget view holding the lock there ends its fingers.
    fileprivate static func releaseHolders(under root: UIView) {
        let held = self.holders.compactMap(\.view).filter { $0.isDescendant(of: root) }
        for view in held {
            for recognizer in view.gestureRecognizers ?? [] {
                (recognizer as? MessageWidgetTouchRecognizer)?.cancelTrackedTouches()
            }
        }
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
            recognizer.delaysTouchesBegan = self.isHeld(under: recognizer.view)
            recognizer.updateIsEnabled()
        }
    }

    fileprivate static func isHeld(under root: UIView?) -> Bool {
        guard let root else {
            return false
        }
        return self.holders.contains { $0.view?.isDescendant(of: root) ?? false }
    }

    /// Tests only.
    static func resetForTesting() {
        self.holders.removeAll()
        self.holdersChanged()
    }
}

/// The chat's side of the lock (`MessageWidgetTouchLock`), on the chat's root view (`ChatControllerNode`): a finger
/// that lands while a widget under it holds a control, anywhere but on that widget, begins this recognizer, which fails
/// or cancels every recognizer the finger reaches and cancels the finger in its view, and stays locked until the finger
/// lifts, whatever the widget does meanwhile. The chat's scroll is the exception: a pan inside this view is left to the
/// finger's first movement, failed when it goes sideways and left to begin when it goes vertically
/// (`MessageWidgetTouchRecognizer.failsAbove`), and a scroll that begins lets go of the held controls. Every other
/// finger is ignored, never failing the recognizer, so later fingers still reach it.
public final class MessageWidgetChatLockRecognizer: UIGestureRecognizer {
    private struct Locked {
        let touch: UITouch
        let down: CGPoint
        var directionDecided = false
    }

    /// Tests: whether a touch is locked; nil asks `MessageWidgetTouchLock` about the touch's view under this view.
    var locks: ((UITouch) -> Bool)?
    private var locked: [Locked] = []
    /// A locked finger went sideways: UIKit's exclusion keeps the pans out too (`canPrevent`).
    private var preventsPans = false

    var lockedTouchCount: Int {
        return self.locked.count
    }

    public init() {
        super.init(target: nil, action: nil)
        self.cancelsTouchesInView = true
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
        self.isEnabled = false
        MessageWidgetTouchLock.register(self)
    }

    fileprivate func updateIsEnabled() {
        let isEnabled = !self.locked.isEmpty || MessageWidgetTouchLock.isHeld(under: self.view)
        if self.isEnabled != isEnabled {
            self.isEnabled = isEnabled
        }
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
            self.locked.append(Locked(touch: touch, down: touch.location(in: nil)))
            self.lockRecognizers(of: touch, pans: false)
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

    /// What a locked finger does to a recognizer it reaches: one still deciding fails, one already running (a pan that
    /// began as content moved under the finger) is cancelled, one that has ended is left as it is.
    static func lockedState(from state: UIGestureRecognizer.State) -> UIGestureRecognizer.State? {
        switch state {
        case .possible:
            return .failed
        case .began, .changed:
            return .cancelled
        default:
            return nil
        }
    }

    /// Fails or cancels what a locked finger reaches (`lockedState`), but the widgets' recognizers and the window's own
    /// (the system's, which a widget's claimed drag leaves alone too); `pans`: the finger went sideways, so the pans
    /// inside this view go too.
    private func lockRecognizers(of touch: UITouch, pans: Bool) {
        for recognizer in touch.gestureRecognizers ?? [] where recognizer !== self && !(recognizer is MessageWidgetTouchRecognizer) && !(recognizer.view is UIWindow) && MessageWidgetTouchRecognizer.failsAbove(recognizer, pans: pans, chat: self.view) {
            if let state = MessageWidgetChatLockRecognizer.lockedState(from: recognizer.state) {
                recognizer.state = state
            }
        }
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        var scrolls = false
        for index in self.locked.indices where touches.contains(self.locked[index].touch) {
            let touch = self.locked[index].touch
            // Its first `claimDistance`: sideways, the chat's pans go as everything else did; vertically, its scroll may
            // begin.
            if !self.locked[index].directionDecided {
                let location = touch.location(in: nil)
                let dx = abs(location.x - self.locked[index].down.x)
                let dy = abs(location.y - self.locked[index].down.y)
                if max(dx, dy) >= MessageWidgetTouchRecognizer.claimDistance {
                    self.locked[index].directionDecided = true
                    if dx >= dy {
                        self.preventsPans = true
                        self.lockRecognizers(of: touch, pans: true)
                    }
                }
            }
            scrolls = scrolls || (touch.gestureRecognizers ?? []).contains { MessageWidgetTouchRecognizer.isChatDrag($0, state: $0.state) }
        }
        // A locked finger scrolls the chat: the controls held under this view let go, as the chat's scroll ends every
        // widget's fingers (a held control may not move, so its own recognizer would not see the scroll).
        if scrolls, let root = self.view {
            MessageWidgetTouchLock.releaseHolders(under: root)
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
        self.locked.removeAll { touches.contains($0.touch) }
        if before > 0 && self.locked.isEmpty {
            self.state = ending
        }
    }

    override public func reset() {
        super.reset()
        self.locked = []
        self.preventsPans = false
        DispatchQueue.main.async { [weak self] in
            self?.updateIsEnabled()
        }
    }

    override public func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        // It fails what a locked finger reaches itself, and never a widget's fingers; a pan once a locked finger went
        // sideways, never before (the chat's scroll).
        if preventedGestureRecognizer is UIPanGestureRecognizer {
            return self.preventsPans
        }
        return false
    }

    override public func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Nothing may stop it hearing later fingers: a widget's claimed drag, or the list's pan before the lock.
        return false
    }
}
