import Foundation
import UIKit

/// UIKit's swipe-back gesture rules for a Liquid Glass navigation controller (`_UINavigationInteractiveTransition`,
/// UIKitCore 26.0 through 27.0, unchanged across them; see
/// docs/superpowers/specs/2026-10-13-native-navigation-screen-transition-re.md §1–§3): the velocity statistics, the
/// edge-flick phase, and the finish/cancel decision with its hand-off velocity. Unlike UIKit, the target progress stops at
/// either end rather than rubber-banding past it.
/// Left-to-right only, as the container's swipe is.
struct NavigationInteractivePopTracker {
    /// `edgeFlickBoostThreshold`, in widths per second.
    static let edgeFlickThreshold: CGFloat = 1.5
    /// `edgeFlickVelocityBoostFactor`.
    static let edgeFlickBoost: CGFloat = 4.25
    /// The transition's duration (`transitionDuration:`), the projection horizon.
    static let projectionTime: CGFloat = 0.35
    /// A finish needs the projected position past this many points, or half the width if that is less.
    static let finishPoints: CGFloat = 187.5

    /// The target progress for a raw one (translation over width). It stops at either end: UIKit rubber-bands it toward
    /// an extra half width (`rubberBandExtent` 0.5, finger coefficient 0.55), which this does not (a decision, 2026-10-14).
    static func targetProgress(_ x: CGFloat) -> CGFloat {
        return max(0.0, min(1.0, x))
    }

    /// The width when the swipe began.
    let totalDistance: CGFloat
    private(set) var sampleCount: Int = 0
    private(set) var isInEdgeFlickPhase = false
    private(set) var averageVelocity: CGFloat = 0.0
    private(set) var averageAcceleration: CGFloat = 0.0
    private(set) var lastAcceleration: CGFloat = 0.0
    private var sawChange = false
    private var previousTime: Double = 0.0
    private var skipTime: Double = 0.0
    private var previousDisplacement: CGFloat = 0.0
    private var previousVelocity: CGFloat = 0.0
    private var velocities: [CGFloat] = [0.0, 0.0, 0.0]
    private var accelerations: [CGFloat] = [0.0, 0.0, 0.0]

    init(totalDistance: CGFloat) {
        self.totalDistance = max(1.0, totalDistance)
    }

    /// One gesture event: `translation` and `velocity` along the pop, in points and points per second.
    mutating func addSample(time: Double, translation: CGFloat, velocity: CGFloat, isChange: Bool) {
        if isChange {
            self.sawChange = true
        }
        let displacement = translation < 0.0 ? 0.0 : translation / self.totalDistance
        let v = velocity / self.totalDistance
        if self.sampleCount == 0 {
            self.previousTime = time
            self.skipTime = time
            self.previousDisplacement = displacement
            self.previousVelocity = v
            self.averageVelocity = v
            self.lastAcceleration = 0.0
            self.averageAcceleration = 0.0
            self.velocities[0] = v
            self.accelerations[0] = 0.0
            self.sampleCount = 1
            self.isInEdgeFlickPhase = true
            return
        }
        let sinceLastEvent = time - self.skipTime
        self.skipTime = time
        guard sinceLastEvent >= 0.01 || (sinceLastEvent > 0.001 && displacement != self.previousDisplacement) else {
            return
        }
        let n = self.sampleCount
        let index = n % 3
        let dt = CGFloat(time - self.previousTime)

        self.averageVelocity = n <= 2 ? (self.averageVelocity * CGFloat(n) + v) / CGFloat(n + 1) : (3.0 * self.averageVelocity - self.velocities[index] + v) / 3.0
        self.velocities[index] = v
        if self.isInEdgeFlickPhase && abs(self.averageVelocity) < NavigationInteractivePopTracker.edgeFlickThreshold {
            self.isInEdgeFlickPhase = false
        }

        var a = dt > 0.0 ? (v - self.previousVelocity) / dt : self.lastAcceleration
        if abs(a - self.lastAcceleration) > 5.0 {
            a = self.lastAcceleration + (a > self.lastAcceleration ? 5.0 : -5.0)
        }
        self.averageAcceleration = n <= 2 ? (self.averageAcceleration * CGFloat(n) + a) / CGFloat(n + 1) : (3.0 * self.averageAcceleration - self.accelerations[index] + a) / 3.0
        self.accelerations[index] = a

        self.lastAcceleration = a
        self.previousVelocity = v
        self.previousDisplacement = displacement
        self.previousTime = time
        self.sampleCount += 1
    }

    /// On release, after the final event was sampled: whether the pop finishes, and the velocity (points per second)
    /// the release spring starts with. `percent` is the last target progress; `velocity` the gesture's raw velocity.
    func release(percent: CGFloat, velocity: CGFloat) -> (finish: Bool, velocity: CGFloat) {
        var finish: Bool
        var handOff: CGFloat
        if self.sampleCount >= 3 && self.sawChange {
            let t = NavigationInteractivePopTracker.projectionTime
            let projected = percent + self.averageVelocity * t + 0.5 * self.averageAcceleration * t * t
            finish = projected > min(NavigationInteractivePopTracker.finishPoints / self.totalDistance, 0.5)
            handOff = self.totalDistance * self.previousVelocity
        } else {
            finish = self.averageVelocity > 0.0 && self.sawChange
            handOff = velocity
        }
        if self.isInEdgeFlickPhase {
            handOff *= NavigationInteractivePopTracker.edgeFlickBoost
        }
        return (finish, handOff)
    }
}
