import Foundation
import UIKit

/// The springs UIKit runs a navigation push or pop on, in units of transition progress
/// (`_UIFluidParallaxTransitionSettings`, UIKitCore 26.0 through 27.0; see
/// docs/superpowers/specs/2026-10-13-native-navigation-screen-transition-re.md). UIKit runs them in process and sets
/// the screens' frames every frame, and so does the navigation container.
public struct NavigationTransitionSpring: Equatable {
    public let dampingRatio: CGFloat
    public let response: CGFloat

    public init(dampingRatio: CGFloat, response: CGFloat) {
        self.dampingRatio = dampingRatio
        self.response = response
    }

    /// SwiftUI's `Spring(duration:bounce:)` (SwiftUICore 27 `Spring.init` 0x1c71909ac): response = duration,
    /// dampingRatio = 1 - bounce for a bounce in 0...1 (exactly 1 for 0), 1 / (1 + bounce) below 0.
    public init(duration: CGFloat, bounce: CGFloat) {
        self.response = duration
        if bounce >= 0.0 {
            self.dampingRatio = bounce == 0.0 ? 1.0 : 1.0 - bounce
        } else {
            self.dampingRatio = 1.0 / (1.0 + bounce)
        }
    }

    /// A tap push or pop: critically damped, 99% there after about 0.32 s.
    public static let noninteractive = NavigationTransitionSpring(dampingRatio: 1.0, response: 0.3)
    /// A released swipe finishing or cancelling; it carries the finger's velocity.
    public static let interactive = NavigationTransitionSpring(dampingRatio: 0.85, response: 0.3)
    /// Follows the finger while it drags.
    public static let tracking = NavigationTransitionSpring(dampingRatio: 0.85, response: 0.08)

    /// As UIKit hands it to Core Animation, with mass 1.
    public var stiffness: CGFloat {
        let omega = 2.0 * CGFloat.pi / self.response
        return omega * omega
    }

    public var damping: CGFloat {
        return 2.0 * self.dampingRatio * self.stiffness.squareRoot()
    }

    /// The state `time` seconds later, moving toward `target`: the exact solution of the damped oscillator, so the
    /// result does not depend on how the time is split into frames.
    public func advance(value: CGFloat, velocity: CGFloat, target: CGFloat, time: CGFloat) -> (value: CGFloat, velocity: CGFloat) {
        let omega = 2.0 * CGFloat.pi / self.response
        let x0 = value - target
        if self.dampingRatio < 1.0 {
            let zeta = self.dampingRatio
            let omegaD = omega * (1.0 - zeta * zeta).squareRoot()
            let decay = exp(-zeta * omega * time)
            let a = x0
            let b = (velocity + zeta * omega * x0) / omegaD
            let cosine = cos(omegaD * time)
            let sine = sin(omegaD * time)
            let x = decay * (a * cosine + b * sine)
            let v = decay * ((b * omegaD - zeta * omega * a) * cosine - (a * omegaD + zeta * omega * b) * sine)
            return (target + x, v)
        } else {
            // Critically damped. UIKit uses exactly 1.0, and Core Animation renders anything above 1 the same way.
            let decay = exp(-omega * time)
            let a = x0
            let b = velocity + omega * x0
            return (target + (a + b * time) * decay, (b - omega * (a + b * time)) * decay)
        }
    }
}

/// Runs a navigation transition's progress on a `NavigationTransitionSpring`, frame by frame. The spring can be
/// re-aimed at any time (the finger moved, it was released) and keeps its velocity.
final class NavigationTransitionProgressDriver {
    private(set) var value: CGFloat
    private(set) var velocity: CGFloat = 0.0
    private(set) var target: CGFloat
    private(set) var spring: NavigationTransitionSpring = .noninteractive
    private let update: (CGFloat) -> Void
    private var settled: (() -> Void)?
    private var overshoots = true
    private var link: SharedDisplayLinkDriver.Link?
    private var lastTime: Double?
    /// The animation duration factor (Slow Animations): animation time runs this many times slower than real time, as
    /// it does for every Core Animation animation Display makes.
    var durationFactor: () -> Double = {
        return UIView.animationDurationFactor()
    }

    init(value: CGFloat, update: @escaping (CGFloat) -> Void) {
        self.value = value
        self.target = value
        self.update = update
    }

    deinit {
        self.link?.invalidate()
    }

    /// Aims the spring at `target`. `velocity` (progress per second) replaces the current one when given.
    /// `settled` runs once the spring comes to rest there. With `overshoots` false the progress stops on reaching the
    /// target instead of carrying past it.
    func animate(to target: CGFloat, spring: NavigationTransitionSpring, velocity: CGFloat? = nil, overshoots: Bool = true, settled: (() -> Void)?) {
        self.target = target
        self.spring = spring
        self.overshoots = overshoots
        if let velocity {
            self.velocity = velocity
        }
        self.settled = settled
        if self.link == nil {
            // The first frame advances nothing: the transition starts on screen where it starts, as a Core Animation
            // animation starts its clock at the commit.
            self.lastTime = nil
            self.link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                self?.displayLinkFrame(at: CACurrentMediaTime())
            })
        }
    }

    private var holdUntil: Double?

    /// The driver takes over at media time `time`: frames before it change nothing (keyframes still show the motion up
    /// to then), and the first after it advances from it.
    func begin(atMediaTime time: Double) {
        self.holdUntil = time
        self.lastTime = time
    }


    /// A display link frame at `time`.
    func displayLinkFrame(at time: Double) {
        if let holdUntil = self.holdUntil {
            if time < holdUntil {
                return
            }
            self.holdUntil = nil
        }

        let dt = self.lastTime.map { CGFloat(time - $0) } ?? 0.0
        self.lastTime = time
        self.advance(realTime: dt)
    }

    /// One frame, `dt` seconds of real time.
    func advance(realTime dt: CGFloat) {
        let factor = self.durationFactor()
        self.tick(dt: factor > 0.0 ? dt / CGFloat(factor) : dt)
    }

    /// One frame, `dt` seconds of animation time.
    func tick(dt: CGFloat) {
        let previousOffset = self.value - self.target
        let state = self.spring.advance(value: self.value, velocity: self.velocity, target: self.target, time: max(0.0, dt))
        self.value = state.value
        self.velocity = state.velocity
        if !self.overshoots && previousOffset != 0.0 && (self.value - self.target) * previousOffset <= 0.0 {
            // Reached the target: stop there.
            self.value = self.target
            self.velocity = 0.0
        }
        // At rest: within a fifth of a point and a couple of points per second on a phone-width screen.
        if abs(self.value - self.target) < 0.0005 && abs(self.velocity) < 0.005, let settled = self.settled {
            self.value = self.target
            self.velocity = 0.0
            self.stop()
            self.update(self.value)
            settled()
        } else {
            self.update(self.value)
        }
    }

    func stop() {
        self.settled = nil
        self.link?.invalidate()
        self.link = nil
        self.lastTime = nil
    }
}
