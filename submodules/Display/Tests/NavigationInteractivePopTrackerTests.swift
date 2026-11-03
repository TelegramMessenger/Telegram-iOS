import XCTest
import UIKit
@testable import Display

/// UIKit's swipe-back rules (`_UINavigationInteractiveTransition`, UIKitCore 26.0–27.0; see
/// docs/superpowers/specs/2026-10-13-native-navigation-screen-transition-re.md §1–§3).
final class NavigationInteractivePopTrackerTests: XCTestCase {
    private let width: CGFloat = 402.0

    /// A finger moving at a constant `pointsPerSecond`, sampled at 60 Hz for `count` samples.
    private func drag(pointsPerSecond: CGFloat, count: Int, start: CGFloat = 0.0) -> NavigationInteractivePopTracker {
        var tracker = NavigationInteractivePopTracker(totalDistance: self.width)
        for i in 0 ..< count {
            let time = Double(i) / 60.0
            tracker.addSample(time: time, translation: start + pointsPerSecond * CGFloat(time), velocity: pointsPerSecond, isChange: i > 0)
        }
        return tracker
    }

    // The target stops at either end: no rubber band past them (a decision, 2026-10-14: UIKit rubber-bands toward an
    // extra half width, which uncovers the container's background).
    func test_targetProgress_stopsAtBothEnds() {
        XCTAssertEqual(NavigationInteractivePopTracker.targetProgress(0.4), 0.4)
        XCTAssertEqual(NavigationInteractivePopTracker.targetProgress(1.2), 1.0)
        XCTAssertEqual(NavigationInteractivePopTracker.targetProgress(-0.2), 0.0)
    }

    // A slow drag that stops short: projected 0.3 + 0.249 * 0.35 = 0.39 < min(187.5 / 402, 0.5) = 0.466, so it cancels;
    // it left the edge-flick phase, so the hand-off velocity is the last sample's, unboosted.
    func test_slowShortDrag_cancels() {
        let tracker = self.drag(pointsPerSecond: 100.0, count: 73)
        XCTAssertFalse(tracker.isInEdgeFlickPhase)
        let decision = tracker.release(percent: 0.3, velocity: 100.0)
        XCTAssertFalse(decision.finish)
        XCTAssertEqual(decision.velocity, 100.0, accuracy: 0.01)
    }

    // The same drag carried past the threshold finishes.
    func test_slowDragPastThreshold_finishes() {
        let tracker = self.drag(pointsPerSecond: 100.0, count: 73)
        XCTAssertTrue(tracker.release(percent: 0.45, velocity: 100.0).finish)
    }

    // A flick: still in the edge-flick phase at release, so it finishes from 15% and hands off 4.25x its velocity.
    func test_flick_finishes_withBoostedVelocity() {
        let tracker = self.drag(pointsPerSecond: 2000.0, count: 4)
        XCTAssertTrue(tracker.isInEdgeFlickPhase)
        let decision = tracker.release(percent: 0.15, velocity: 2000.0)
        XCTAssertTrue(decision.finish)
        XCTAssertEqual(decision.velocity, 2000.0 * 4.25, accuracy: 0.5)
    }

    // Fewer than three samples: finish exactly when the average velocity points toward the pop.
    func test_fewSamples_followTheVelocity() {
        let forward = self.drag(pointsPerSecond: 50.0, count: 2)
        XCTAssertTrue(forward.release(percent: 0.05, velocity: 50.0).finish)
        let backward = self.drag(pointsPerSecond: -50.0, count: 2, start: 30.0)
        XCTAssertFalse(backward.release(percent: 0.05, velocity: -50.0).finish)
    }

    // Samples closer than 10 ms are dropped unless the finger moved (and never closer than 1 ms).
    func test_closeSamples_areDropped() {
        var tracker = NavigationInteractivePopTracker(totalDistance: self.width)
        tracker.addSample(time: 0.0, translation: 0.0, velocity: 100.0, isChange: false)
        tracker.addSample(time: 0.005, translation: 0.0, velocity: 100.0, isChange: true)
        XCTAssertEqual(tracker.sampleCount, 1)
        tracker.addSample(time: 0.0055, translation: 5.0, velocity: 100.0, isChange: true)
        XCTAssertEqual(tracker.sampleCount, 1)
        tracker.addSample(time: 0.008, translation: 6.0, velocity: 100.0, isChange: true)
        XCTAssertEqual(tracker.sampleCount, 2)
    }

    // The acceleration may change by at most 5 widths/s^2 per sample.
    func test_accelerationChange_isLimited() {
        var tracker = NavigationInteractivePopTracker(totalDistance: self.width)
        tracker.addSample(time: 0.0, translation: 0.0, velocity: 0.0, isChange: false)
        tracker.addSample(time: 0.02, translation: 10.0, velocity: 4020.0, isChange: true)
        XCTAssertEqual(tracker.lastAcceleration, 5.0, accuracy: 1e-9)
    }
}
