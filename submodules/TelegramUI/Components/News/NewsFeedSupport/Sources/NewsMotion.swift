import Foundation
import CoreGraphics
import QuartzCore

/// A spring from the Feed2 mockup. SwiftUI's `.spring(duration: d, bounce: b)` (and `.smooth(duration: d)`, bounce
/// 0) is a mass-1 oscillator with ω₀ = 2π / d, stiffness ω₀² and damping ratio 1 − b.
///
/// It runs for its own settling time. Display's `makeAnimation` time-scales a `.customSpring` to whatever duration it
/// is given, which would play these about 1.5x too fast.
public struct NewsSpring: Equatable {
    public let mass: CGFloat
    public let stiffness: CGFloat
    public let damping: CGFloat

    public init(duration: Double, bounce: Double) {
        let omega = 2.0 * Double.pi / duration
        self.mass = 1.0
        self.stiffness = CGFloat(omega * omega)
        self.damping = CGFloat(2.0 * (1.0 - bounce) * omega)
    }

    public var dampingRatio: CGFloat {
        return self.damping / (2.0 * (self.stiffness * self.mass).squareRoot())
    }

    /// How long Core Animation runs it from rest.
    public var settlingDuration: Double {
        return self.makeAnimation(keyPath: "opacity").settlingDuration
    }

    /// An animation of `keyPath` on this spring, starting `delay` seconds from now and holding `from` until then.
    public func makeAnimation(keyPath: String, from: Any? = nil, to: Any? = nil, delay: Double = 0.0) -> CASpringAnimation {
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.mass = self.mass
        animation.stiffness = self.stiffness
        animation.damping = self.damping
        animation.initialVelocity = 0.0
        animation.fromValue = from
        animation.toValue = to
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = animation.settlingDuration
        if delay > 0.0 {
            animation.beginTime = CACurrentMediaTime() + delay
            animation.fillMode = .backwards
        }
        return animation
    }
}

public extension NewsSpring {
    /// `Motion.appear` (`.smooth(duration: 0.45)`): rows cascading in after a load.
    static let appear = NewsSpring(duration: 0.45, bounce: 0.0)

    /// `Motion.spread` (`.smooth(duration: 0.5)`): the old posts sliding down as the refreshed ones go in.
    static let spread = NewsSpring(duration: 0.5, bounce: 0.0)
}
