import Foundation
import UIKit

/// A transition's progress running on the render server, sampled once: what the bar layer, its renderer and the
/// container bake their own keyframes from, on the transition's clock.
public struct NavigationTransitionTimeline {
    public let timing: NavigationKeyframeTiming
    /// At each of `timing.sampleTimes`: the bars' fraction (0: the bottom bar, 1: the top one) and the two screens'
    /// frames in the container.
    public let fractions: [CGFloat]
    public let topFrames: [CGRect]
    public let bottomFrames: [CGRect]
    /// Animation time now on the transition's clock.
    public let animationTime: () -> Double
    /// The timing to re-install a part with mid-transition (nil once it has ended).
    public let reinstallTiming: () -> NavigationKeyframeTiming?
    /// Runs an action at an animation time on the transition's clock, unless the transition is retargeted or ends.
    public let schedule: (_ animationTime: Double, _ action: @escaping () -> Void) -> Void

    public init(timing: NavigationKeyframeTiming, fractions: [CGFloat], topFrames: [CGRect], bottomFrames: [CGRect], animationTime: @escaping () -> Double, reinstallTiming: @escaping () -> NavigationKeyframeTiming?, schedule: @escaping (Double, @escaping () -> Void) -> Void) {
        self.timing = timing
        self.fractions = fractions
        self.topFrames = topFrames
        self.bottomFrames = bottomFrames
        self.animationTime = animationTime
        self.reinstallTiming = reinstallTiming
        self.schedule = schedule
    }

    /// The same samples installed with another timing (a part re-installed on the running phase).
    public func withTiming(_ timing: NavigationKeyframeTiming) -> NavigationTransitionTimeline {
        return NavigationTransitionTimeline(timing: timing, fractions: self.fractions, topFrames: self.topFrames, bottomFrames: self.bottomFrames, animationTime: self.animationTime, reinstallTiming: self.reinstallTiming, schedule: self.schedule)
    }

    /// The fraction at animation time `time`, linear between samples like the keyframes.
    public func fraction(at time: Double) -> CGFloat {
        return NavigationTransitionTimeline.interpolate(self.fractions, times: self.timing.sampleTimes, at: time)
    }

    public static func interpolate(_ values: [CGFloat], times: [Double], at time: Double) -> CGFloat {
        guard let first = values.first, let last = values.last, values.count == times.count else {
            return values.last ?? 0.0
        }
        if time <= times[0] {
            return first
        }
        guard let index = times.firstIndex(where: { $0 >= time }) else {
            return last
        }
        let t0 = times[index - 1]
        let t1 = times[index]
        let t = t1 > t0 ? CGFloat((time - t0) / (t1 - t0)) : 1.0
        return values[index - 1] + (values[index] - values[index - 1]) * t
    }
}
