import Foundation
import UIKit

/// A bar holding its own glass hidden while a navigation transition's glass finishes above it (UIKit's capsules run on
/// their own clock and outlive the screens' transition). The hold ends when the transition says so, or here: when the
/// bar is touched, laid out with other content, another row frame or a title pill the glass cannot follow, leaves the
/// screen, or after a cap. A title pill that only moves is followed by the glass instead. Main thread.
public final class NavigationBarGlassHold {
    private let schedule: (Double, @escaping () -> Void) -> Void
    private var interrupted: (() -> Void)?
    private var titlePillMoved: (() -> Void)?
    private var heldContent: NavigationBarComponent.Content?
    private var heldRowFrame = CGRect()
    private var heldTitlePill: (frame: CGRect, signature: AnyHashable)?
    private var generation = 0
    private var hasLeftHierarchy = false

    public private(set) var isHeld = false {
        didSet {
            if self.isHeld != oldValue {
                self.changed?()
            }
        }
    }
    /// Called whenever `isHeld` changes.
    public var changed: (() -> Void)?
    /// The animation duration factor (Slow Animations) the cap stretches with.
    public var durationFactor: () -> Double = {
        return UIView.animationDurationFactor()
    }

    /// `schedule` runs an action after a delay in seconds; tests replace it. The cap stays a timer: a completion on the
    /// bar's layer would end the hold whenever the bar leaves and re-enters the window.
    public init(schedule: @escaping (Double, @escaping () -> Void) -> Void = { delay, action in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }) {
        self.schedule = schedule
    }

    /// `titlePill`: the bar's title pill (the chat header), which the transition's glass draws; `titlePillMoved` asks the
    /// glass to follow it when a layout moves it.
    public func hold(_ held: Bool, interrupted: (() -> Void)?, titlePillMoved: (() -> Void)? = nil, content: NavigationBarComponent.Content?, rowFrame: CGRect, titlePill: NavigationBarTransitionTitlePill? = nil) {
        self.generation += 1
        self.interrupted = held ? interrupted : nil
        self.titlePillMoved = held ? titlePillMoved : nil
        self.heldContent = content
        self.heldRowFrame = rowFrame
        self.heldTitlePill = titlePill.flatMap { ($0.frame, $0.signature) }
        self.isHeld = held
        if held {
            // The transition ends its linger within 1.5 s of animation time (stretched by Slow Animations, as the glass
            // is); this covers a transition that is gone.
            let generation = self.generation
            self.schedule(1.6 * self.durationFactor(), { [weak self] in
                guard let self, self.generation == generation else {
                    return
                }
                self.interrupt()
            })
        }
    }

    /// The bar laid out: other content or another row frame under the transition's glass hands over now rather than
    /// settle on the old bar.
    public func barLaidOut(content: NavigationBarComponent.Content?, rowFrame: CGRect) {
        if self.isHeld, self.heldContent != content || self.heldRowFrame != rowFrame {
            self.interrupt()
        }
    }

    /// The bar laid out its title: a pill that moved (the chat header re-centred after the push) is followed by the glass,
    /// which otherwise settles where the bar no longer draws it and the pill snaps sideways at the hand-over. One the
    /// glass cannot follow hands over now: a pill appearing or going, another title view's, or any change with nobody
    /// to follow it.
    public func titlePillLaidOut(_ pill: NavigationBarTransitionTitlePill?) {
        guard self.isHeld, pill?.frame != self.heldTitlePill?.frame || pill?.signature != self.heldTitlePill?.signature else {
            return
        }
        guard let pill, let held = self.heldTitlePill, pill.signature == held.signature, let titlePillMoved = self.titlePillMoved else {
            self.interrupt()
            return
        }
        self.heldTitlePill = (pill.frame, pill.signature)
        titlePillMoved()
    }

    /// Asks the transition's glass to hand over (once), and ends the hold if it did not.
    public func interrupt() {
        guard self.isHeld else {
            return
        }
        if let interrupted = self.interrupted {
            self.interrupted = nil
            interrupted()
        }
        if self.isHeld {
            self.hold(false, interrupted: nil, content: nil, rowFrame: CGRect())
        }
    }

    /// The bar left the screen without a stack change (another tab selected): the glass hands over. Checked a turn
    /// later, since a finished swipe re-adds the screen beneath, leaving and entering at once.
    public func barLeftHierarchy() {
        guard self.isHeld else {
            return
        }
        self.hasLeftHierarchy = true
        self.schedule(0.0, { [weak self] in
            guard let self, self.hasLeftHierarchy else {
                return
            }
            self.hasLeftHierarchy = false
            self.interrupt()
        })
    }

    public func barEnteredHierarchy() {
        self.hasLeftHierarchy = false
    }
}
