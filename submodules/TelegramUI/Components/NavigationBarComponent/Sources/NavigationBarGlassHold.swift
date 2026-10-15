import Foundation
import UIKit

/// A bar holding its own glass hidden while a navigation transition's glass finishes above it (UIKit's capsules run on
/// their own clock and outlive the screens' transition). The hold ends when the transition says so, or here: when the
/// bar is touched, laid out with other content or another row frame, leaves the screen, or after a cap. Main thread.
public final class NavigationBarGlassHold {
    private let schedule: (Double, @escaping () -> Void) -> Void
    private var interrupted: (() -> Void)?
    private var heldContent: NavigationBarComponent.Content?
    private var heldRowFrame = CGRect()
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

    public func hold(_ held: Bool, interrupted: (() -> Void)?, content: NavigationBarComponent.Content?, rowFrame: CGRect) {
        self.generation += 1
        self.interrupted = held ? interrupted : nil
        self.heldContent = content
        self.heldRowFrame = rowFrame
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
