import Foundation
import UIKit

/// When a bake's animations begin.
public enum NavigationKeyframeOrigin: Equatable {
    /// At the commit that carries them: `beginTime` is left for Core Animation to resolve, on the same origin as every
    /// other animation added in that turn.
    case atCommit
    /// At this media time (`CACurrentMediaTime()`'s clock).
    case explicit(Double)
}

/// The samples one bake takes and how its animations are timed. Sample times are seconds of animation time from the
/// origin. Under Slow Animations each animation keeps that logical duration and runs at `speed = 1 / factor`, as
/// `CAAnimationUtils` does (and CoreList: CLAUDE.md, "Slow Animations reaches the emitted animation as speed").
public struct NavigationKeyframeTiming: Equatable {
    public static let samplesPerSecond: Double = 120.0

    public let origin: NavigationKeyframeOrigin
    public let duration: Double
    public let factor: Double
    public let sampleTimes: [Double]

    public init(origin: NavigationKeyframeOrigin, duration: Double, factor: Double) {
        self.origin = origin
        self.duration = max(0.0, duration)
        self.factor = factor > 0.0 ? factor : 1.0
        var sampleTimes: [Double] = []
        let count = Int((self.duration * NavigationKeyframeTiming.samplesPerSecond).rounded(.up))
        for i in 0 ..< count {
            sampleTimes.append(Double(i) / NavigationKeyframeTiming.samplesPerSecond)
        }
        sampleTimes.append(self.duration)
        self.sampleTimes = sampleTimes
    }

    public func withOrigin(_ origin: NavigationKeyframeOrigin) -> NavigationKeyframeTiming {
        return NavigationKeyframeTiming(origin: origin, duration: self.duration, factor: self.factor)
    }

    /// The same origin and factor, cut (or extended) to `duration`.
    public func withDuration(_ duration: Double) -> NavigationKeyframeTiming {
        return NavigationKeyframeTiming(origin: self.origin, duration: duration, factor: self.factor)
    }
}

/// One property's keyframes: `values[i]` at `timing.sampleTimes[i]`, linear between them.
public func makeNavigationKeyframeAnimation(keyPath: String, values: [Any], timing: NavigationKeyframeTiming, layer: CALayer) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: keyPath)
    let duration = max(timing.duration, 1.0 / NavigationKeyframeTiming.samplesPerSecond)
    animation.values = values
    animation.keyTimes = timing.sampleTimes.map { NSNumber(value: min(1.0, $0 / duration)) }
    animation.calculationMode = .linear
    animation.duration = duration
    animation.speed = Float(1.0 / timing.factor)
    animation.fillMode = .both
    animation.isRemovedOnCompletion = true
    if case let .explicit(time) = timing.origin {
        animation.beginTime = layer.convertTime(time, from: nil)
    }
    if #available(iOS 15.0, *), UIScreen.main.maximumFramesPerSecond > 61 {
        // UIKit's push/pop runs at this range (screen RE notes §4); ProMotion caps app-driven refresh otherwise.
        animation.preferredFrameRateRange = CAFrameRateRange(minimum: 80.0, maximum: 120.0, preferred: 0.0)
    }
    return animation
}

/// Adds `values` on `layer` under `key`. Core Animation never runs an animation whose values are all equal, so then
/// nothing is added and an old animation under `key` is removed. The model value is the caller's to set. `owner` stamps
/// the animation for `removeNavigationKeyframes(from:key:owner:)`.
public func addNavigationKeyframes(to layer: CALayer, key: String, keyPath: String, values: [Any], timing: NavigationKeyframeTiming, owner: Int? = nil) {
    guard let first = values.first as AnyObject?, values.contains(where: { !($0 as AnyObject).isEqual(first) }) else {
        layer.removeAnimation(forKey: key)
        return
    }
    let animation = makeNavigationKeyframeAnimation(keyPath: keyPath, values: values, timing: timing, layer: layer)
    if let owner {
        animation.setValue(NSNumber(value: owner), forKey: navigationKeyframeOwnerKey)
    }
    layer.add(animation, forKey: key)
}

private let navigationKeyframeOwnerKey = "navigationKeyframeOwner"

/// Removes the animation under `key` only if `owner` added it: a layer can pass from one transition to the next, and the
/// next one's keyframes are not the old one's to remove.
public func removeNavigationKeyframes(from layer: CALayer, key: String, owner: Int) {
    if let stamp = layer.animation(forKey: key)?.value(forKey: navigationKeyframeOwnerKey) as? NSNumber, stamp.intValue == owner {
        layer.removeAnimation(forKey: key)
    }
}

/// The clock of one group of keyframe animations (a transition's screens, the glass capsules), like UIKit's dummy view
/// in its fluid transition: one animation on a layer of its own records where the group's animation time starts.
///
/// - A group's first bake begins at the commit; the model's origin is the bake's now until the commit resolves one,
///   which the clock then adopts (read back off the layer). A layer outside the render tree never resolves one.
/// - A bake that continues motion already on screen (a retarget, a release) begins explicitly at now, unless the
///   group's first commit is still pending, in which case it joins that commit.
/// - The group ends when Core Animation completes the clock animation. It also completes it, unfinished and at once,
///   for a layer that is not on screen or leaves it (measured in the app, spec §6 results), so a stop the group did
///   not cause ends it at once. Tests replace this with `schedule` (no render server runs in their process); the
///   group then ends at its analytic deadline, re-armed once the origin is adopted.
public final class NavigationAnimationClock {
    public static let animationKey = "navigationClock"
    /// Tests install a manual clock on every clock made.
    public static var configureForTesting: ((NavigationAnimationClock) -> Void)?

    public var now: () -> Double = {
        return CACurrentMediaTime()
    }
    public var durationFactor: () -> Double = {
        return UIView.animationDurationFactor()
    }
    /// Nil: the group's end and its marks come from Core Animation's completions. Tests set a manual scheduler.
    public var schedule: ((_ delay: Double, _ action: @escaping () -> Void) -> Void)?
    /// Nil: the host is on screen while it is in a window, where a commit resolves the origin. Tests standing in for the
    /// commit set it (no window can be made in their process).
    public var isHostOnScreen: (() -> Bool)?

    /// An empty 1×1 layer in the host view: it draws nothing, so its moving position shows nothing.
    public let layer: CALayer
    private weak var hostView: UIView?
    /// Called once when a group's deadline has passed on both the model's clock and Core Animation's.
    public var ended: (() -> Void)?

    public private(set) var timing: NavigationKeyframeTiming?
    /// Media time of animation time 0: the bake's now, then the commit's once it resolves.
    public private(set) var originTime: Double = 0.0
    private var isOriginResolved = false
    private var generation = 0
    private var markCount = 0

    public init(hostView: UIView) {
        self.layer = CALayer()
        self.layer.frame = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        self.hostView = hostView
        hostView.layer.addSublayer(self.layer)
        NavigationAnimationClock.configureForTesting?(self)
    }

    deinit {
        self.layer.removeFromSuperlayer()
    }

    public var isRunning: Bool {
        return self.timing != nil
    }

    /// Starts a group lasting `duration` seconds of animation time; returns the timing to bake it with. `continuing`:
    /// the bake continues motion already on screen, so it begins now rather than at the commit.
    public func start(duration: Double, continuing: Bool) -> NavigationKeyframeTiming {
        let now = self.now()
        let origin: NavigationKeyframeOrigin = (continuing && !self.isAwaitingCommit) ? .explicit(now) : .atCommit
        let timing = NavigationKeyframeTiming(origin: origin, duration: duration, factor: self.durationFactor())
        self.generation += 1
        self.timing = timing
        self.originTime = now
        self.isOriginResolved = origin != .atCommit

        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = NSValue(cgPoint: CGPoint(x: 0.0, y: 0.0))
        animation.toValue = NSValue(cgPoint: CGPoint(x: 1.0, y: 1.0))
        animation.duration = max(timing.duration, 1.0 / NavigationKeyframeTiming.samplesPerSecond)
        animation.speed = Float(1.0 / timing.factor)
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        if case let .explicit(time) = origin {
            animation.beginTime = self.layer.convertTime(time, from: nil)
        }
        let generation = self.generation
        if let schedule = self.schedule {
            self.layer.add(animation, forKey: NavigationAnimationClock.animationKey)
            schedule(timing.duration * timing.factor, { [weak self] in
                self?.deadlineReached(generation)
            })
        } else {
            animation.delegate = NavigationAnimationCompletion({ [weak self] _ in
                self?.clockAnimationStopped(generation)
            })
            self.layer.add(animation, forKey: NavigationAnimationClock.animationKey)
        }
        return timing
    }

    /// Takes the origin Core Animation resolved at the commit, once there is one.
    public func adoptResolvedOrigin() {
        guard self.timing != nil, !self.isOriginResolved, let animation = self.layer.animation(forKey: NavigationAnimationClock.animationKey), animation.beginTime > 0.0 else {
            return
        }
        self.originTime = self.layer.convertTime(animation.beginTime, to: nil)
        self.isOriginResolved = true
    }

    /// The first bake's commit has not happened yet (and will: the host is on screen).
    private var isAwaitingCommit: Bool {
        self.adoptResolvedOrigin()
        return self.timing != nil && !self.isOriginResolved && (self.isHostOnScreen?() ?? (self.hostView?.window != nil))
    }

    /// Seconds of animation time since the origin at media time `time` (now by default), after adopting a resolved
    /// origin. 0 when no group runs, and while the first commit is pending: nothing the group times has begun on screen
    /// then, and the origin the commit resolves is later than the bake's now by the rest of the turn (tens of ms in a
    /// heavy one), so a time read from the bake's now would step back when it resolves.
    public func animationTime(at time: Double? = nil) -> Double {
        guard let timing = self.timing, !self.isAwaitingCommit else {
            return 0.0
        }
        return max(0.0, ((time ?? self.now()) - self.originTime) / timing.factor)
    }

    /// The timing to re-install part of the running group with, on its phase: explicit at its origin, or at the commit
    /// while the first commit is still pending.
    public var reinstallTiming: NavigationKeyframeTiming? {
        guard let timing = self.timing else {
            return nil
        }
        if self.isAwaitingCommit {
            return timing.withOrigin(.atCommit)
        }
        return timing.withOrigin(.explicit(self.originTime))
    }

    /// Runs `action` when the group's animation time reaches `time`, unless the group is stopped or restarted first: at
    /// the completion of a marker animation on the group's own origin (at once if its layer is off screen).
    public func schedule(atAnimationTime time: Double, _ action: @escaping () -> Void) {
        guard let timing = self.timing, let reinstallTiming = self.reinstallTiming else {
            return
        }
        let generation = self.generation
        let guarded: () -> Void = { [weak self] in
            guard let self, self.generation == generation else {
                return
            }
            action()
        }
        if let schedule = self.schedule {
            schedule(max(0.0, (time - self.animationTime()) * timing.factor), guarded)
            return
        }
        let marker = CABasicAnimation(keyPath: "opacity")
        marker.fromValue = 1.0 as NSNumber
        marker.toValue = 0.5 as NSNumber
        marker.duration = max(time, 1.0 / NavigationKeyframeTiming.samplesPerSecond)
        marker.speed = Float(1.0 / timing.factor)
        marker.isRemovedOnCompletion = true
        if case let .explicit(origin) = reinstallTiming.origin {
            marker.beginTime = self.layer.convertTime(origin, from: nil)
        }
        marker.delegate = NavigationAnimationCompletion({ _ in
            guarded()
        })
        self.markCount += 1
        self.layer.add(marker, forKey: "\(NavigationAnimationClock.animationKey).mark\(self.markCount)")
    }

    public func stop() {
        self.generation += 1
        self.finish()
    }

    private func clockAnimationStopped(_ generation: Int) {
        // Finished, or stopped because the layer is off screen or left it; the group's own replacements and stops have
        // moved the generation on.
        guard generation == self.generation, self.timing != nil else {
            return
        }
        self.finish()
        self.ended?()
    }

    private func deadlineReached(_ generation: Int) {
        guard generation == self.generation, let timing = self.timing else {
            return
        }
        self.adoptResolvedOrigin()
        let remaining = self.originTime + timing.duration * timing.factor - self.now()
        if remaining > 0.0005, let schedule = self.schedule {
            schedule(remaining, { [weak self] in
                self?.deadlineReached(generation)
            })
            return
        }
        self.finish()
        self.ended?()
    }

    private func finish() {
        self.timing = nil
        self.isOriginResolved = false
        self.layer.removeAllAnimations()
    }
}

/// A Core Animation completion as a closure (the delegate is retained by its animation).
private final class NavigationAnimationCompletion: NSObject, CAAnimationDelegate {
    private var completion: ((Bool) -> Void)?

    init(_ completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        let completion = self.completion
        self.completion = nil
        completion?(flag)
    }
}
