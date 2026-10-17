import XCTest
import UIKit
@testable import Display

final class NavigationKeyframesTests: XCTestCase {
    private let time = ManualAnimationTime()

    override func setUp() {
        super.setUp()
        self.time.attach()
    }

    override func tearDown() {
        self.time.detach()
        super.tearDown()
    }

    func test_timing_samplesAt120Hz_endingExactlyAtTheDuration() {
        let timing = NavigationKeyframeTiming(origin: .atCommit, duration: 0.5, factor: 1.0)
        XCTAssertEqual(timing.sampleTimes.count, 61)
        XCTAssertEqual(timing.sampleTimes.first, 0.0)
        XCTAssertEqual(timing.sampleTimes[12], 0.1, accuracy: 1e-12)
        XCTAssertEqual(timing.sampleTimes.last, 0.5)
        XCTAssertEqual(NavigationKeyframeTiming(origin: .atCommit, duration: 0.0, factor: 1.0).sampleTimes, [0.0])
        XCTAssertEqual(NavigationKeyframeTiming(origin: .atCommit, duration: 0.4123, factor: 1.0).sampleTimes.last, 0.4123)
    }

    // CoreList's rules (CLAUDE.md "Non-obvious gotchas"): Slow Animations as speed, an implicit origin at the commit,
    // an explicit one in the layer's own time.
    func test_animation_isLinearKeyframes_atSpeed_withItsOrigin() {
        let layer = CALayer()
        let timing = NavigationKeyframeTiming(origin: .atCommit, duration: 0.5, factor: 10.0)
        let values = timing.sampleTimes.map { NSNumber(value: $0) }
        let animation = makeNavigationKeyframeAnimation(keyPath: "opacity", values: values, timing: timing, layer: layer)
        XCTAssertEqual(animation.calculationMode, .linear)
        XCTAssertEqual(animation.duration, 0.5)
        XCTAssertEqual(animation.speed, 0.1, accuracy: 1e-6)
        XCTAssertEqual(animation.beginTime, 0.0)
        XCTAssertEqual(animation.fillMode, .both)
        XCTAssertEqual(animation.keyTimes?.first?.doubleValue, 0.0)
        XCTAssertEqual(animation.keyTimes?.last?.doubleValue, 1.0)
        XCTAssertEqual(animation.values?.count, 61)
        let explicit = makeNavigationKeyframeAnimation(keyPath: "opacity", values: values, timing: timing.withOrigin(.explicit(1234.5)), layer: layer)
        XCTAssertEqual(explicit.beginTime, layer.convertTime(1234.5, from: nil))
    }

    // Core Animation never runs a from == to animation, so equal values install nothing (and clear an old one).
    func test_add_equalValues_installNothing() {
        let layer = CALayer()
        let timing = NavigationKeyframeTiming(origin: .atCommit, duration: 0.2, factor: 1.0)
        addNavigationKeyframes(to: layer, key: "k", keyPath: "opacity", values: timing.sampleTimes.map { NSNumber(value: $0) }, timing: timing)
        XCTAssertNotNil(layer.animation(forKey: "k"))
        addNavigationKeyframes(to: layer, key: "k", keyPath: "opacity", values: timing.sampleTimes.map { _ in NSNumber(value: 0.5) }, timing: timing)
        XCTAssertNil(layer.animation(forKey: "k"))
    }

    func test_firstBake_beginsAtTheCommit_withAClockThatMoves() {
        let clock = NavigationAnimationClock(hostView: UIView())
        let timing = clock.start(duration: 0.4, continuing: false)
        XCTAssertEqual(timing.origin, .atCommit)
        guard let animation = clock.layer.animation(forKey: NavigationAnimationClock.animationKey) as? CABasicAnimation else {
            XCTFail("no clock animation")
            return
        }
        XCTAssertEqual(animation.beginTime, 0.0)
        XCTAssertNotEqual(animation.fromValue as? NSValue, animation.toValue as? NSValue)
        XCTAssertTrue(clock.isRunning)
    }

    // A windowless layer never resolves an origin: the bake's own now stands, and the group ends on that deadline.
    func test_windowless_neverResolves_endsOnTheBakesDeadline() {
        let clock = NavigationAnimationClock(hostView: UIView())
        var ended = 0
        clock.ended = {
            ended += 1
        }
        let _ = clock.start(duration: 0.4, continuing: false)
        self.time.advance(by: 0.2)
        XCTAssertEqual(clock.animationTime(), 0.2, accuracy: 1e-9)
        XCTAssertEqual(ended, 0)
        self.time.advance(by: 0.21)
        XCTAssertEqual(ended, 1)
        XCTAssertFalse(clock.isRunning)
    }

    // The commit resolves a later origin (the turn's cost): the model adopts it, and the deadline moves with it.
    func test_resolvedOrigin_isAdopted_andMovesTheDeadline() {
        let clock = NavigationAnimationClock(hostView: UIView())
        var ended = 0
        clock.ended = {
            ended += 1
        }
        let start = self.time.now
        let _ = clock.start(duration: 0.4, continuing: false)
        self.time.resolveOrigin(of: clock, at: start + 0.05)
        self.time.advance(by: 0.15)
        XCTAssertEqual(clock.animationTime(), 0.1, accuracy: 1e-9)
        self.time.advance(by: 0.26)
        XCTAssertEqual(ended, 0, "Core Animation's end is 0.05 s later than the bake's")
        self.time.advance(by: 0.05)
        XCTAssertEqual(ended, 1)
    }

    // On screen, nothing the group times has begun until the commit resolves its origin, and that origin is later than
    // the bake's own now by the rest of the turn. Read from the bake's now, the time would step back when the origin
    // resolves (a drop's tint, driven per frame, took that step for a stopped clock and froze); it reads 0 until then.
    func test_awaitingTheCommit_readsZero_soTheTimeNeverStepsBack() {
        let clock = NavigationAnimationClock(hostView: UIView())
        clock.isHostOnScreen = { true }
        let start = self.time.now
        let _ = clock.start(duration: 0.4, continuing: false)
        self.time.advance(by: 0.03)
        XCTAssertEqual(clock.animationTime(), 0.0)
        self.time.resolveOrigin(of: clock, at: start + 0.045)
        XCTAssertEqual(clock.animationTime(), 0.0)
        self.time.advance(by: 0.02)
        XCTAssertEqual(clock.animationTime(), 0.005, accuracy: 1e-9)
    }

    // A retarget or a release continues motion already on screen: it begins at now, explicitly.
    func test_continuingBake_beginsAtNow() {
        let clock = NavigationAnimationClock(hostView: UIView())
        let _ = clock.start(duration: 0.4, continuing: false)
        self.time.advance(by: 0.1)
        let timing = clock.start(duration: 0.3, continuing: true)
        XCTAssertEqual(timing.origin, .explicit(self.time.now))
        XCTAssertEqual(clock.animationTime(), 0.0, accuracy: 1e-9)
        XCTAssertEqual(clock.reinstallTiming?.origin, .explicit(self.time.now))
    }

    func test_slowAnimations_runAtSpeedAndStretchTheDeadline() {
        self.time.factor = 10.0
        let clock = NavigationAnimationClock(hostView: UIView())
        var ended = 0
        clock.ended = {
            ended += 1
        }
        let timing = clock.start(duration: 0.4, continuing: false)
        XCTAssertEqual(timing.factor, 10.0)
        XCTAssertEqual(clock.layer.animation(forKey: NavigationAnimationClock.animationKey)?.speed ?? 0.0, 0.1, accuracy: 1e-6)
        self.time.advance(by: 2.0)
        XCTAssertEqual(clock.animationTime(), 0.2, accuracy: 1e-9)
        self.time.advance(by: 1.9)
        XCTAssertEqual(ended, 0)
        self.time.advance(by: 0.2)
        XCTAssertEqual(ended, 1)
    }

    func test_stop_cancelsTheDeadline() {
        let clock = NavigationAnimationClock(hostView: UIView())
        var ended = 0
        clock.ended = {
            ended += 1
        }
        let _ = clock.start(duration: 0.4, continuing: false)
        clock.stop()
        self.time.advance(by: 1.0)
        XCTAssertEqual(ended, 0)
        XCTAssertNil(clock.layer.animation(forKey: NavigationAnimationClock.animationKey))
    }

    func test_scheduleAtAnimationTime_firesOnTheGroupsClock_andNotAfterAStop() {
        let clock = NavigationAnimationClock(hostView: UIView())
        let _ = clock.start(duration: 0.4, continuing: false)
        var fired: [Double] = []
        clock.schedule(atAnimationTime: 0.25, {
            fired.append(clock.animationTime())
        })
        self.time.advance(by: 0.3)
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first ?? 0.0, 0.25, accuracy: 1e-9)
        clock.schedule(atAnimationTime: 0.35, {
            fired.append(-1.0)
        })
        clock.stop()
        self.time.advance(by: 0.3)
        XCTAssertEqual(fired.count, 1)
    }
}

/// The clock without the manual time: its group ends through Core Animation's completion of the clock animation, which
/// Core Animation also calls (unfinished, at once) for a layer that is not on screen or leaves it, as a spike measured in
/// the app (spec §6 results). This test process has no screen, so every group here is off screen.
final class NavigationAnimationClockCompletionTests: XCTestCase {
    private func spin(_ seconds: Double = 0.1) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    func test_offScreenGroup_endsAtOnce_throughItsCompletion() {
        let clock = NavigationAnimationClock(hostView: UIView())
        var ended = 0
        clock.ended = {
            ended += 1
        }
        let _ = clock.start(duration: 5.0, continuing: false)
        XCTAssertNotNil(clock.layer.animation(forKey: NavigationAnimationClock.animationKey)?.delegate)
        self.spin()
        XCTAssertEqual(ended, 1)
        XCTAssertFalse(clock.isRunning)
    }

    // Replacing the clock animation (a retarget) or stopping it stops the old one; that stop is not the group's end.
    func test_restartAndStop_doNotEndTheGroup() {
        let clock = NavigationAnimationClock(hostView: UIView())
        var ended = 0
        clock.ended = {
            ended += 1
        }
        let _ = clock.start(duration: 5.0, continuing: false)
        let _ = clock.start(duration: 5.0, continuing: true)
        self.spin()
        XCTAssertEqual(ended, 1, "only the second group ends")
        let _ = clock.start(duration: 5.0, continuing: false)
        clock.stop()
        self.spin()
        XCTAssertEqual(ended, 1)
    }

    // A mark on the group's clock (the status bar's flip) fires through a marker animation's completion.
    func test_markOnTheClock_firesThroughItsCompletion() {
        let clock = NavigationAnimationClock(hostView: UIView())
        let _ = clock.start(duration: 5.0, continuing: false)
        var fired = 0
        clock.schedule(atAnimationTime: 2.0, {
            fired += 1
        })
        self.spin()
        XCTAssertEqual(fired, 1)
    }
}
