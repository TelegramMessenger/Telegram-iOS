import XCTest
@testable import CoreListDemo

/// Core Animation does not run an animation whose `fromValue` equals its `toValue` — it changes
/// nothing, so the render server has nothing to schedule and never sends `animationDidStop`. With
/// `isRemovedOnCompletion = false` the animation simply sits on the layer forever.
///
/// Several CoreList tracks are equal-endpoint BY DESIGN and exist only to own a teardown deadline,
/// so a completion that never arrives strands stale rows on top of live content — the "old carousel
/// window stuck over the chat" report. These lock the contract that a model-owned completion does
/// not depend on whether Core Animation found the animation worth running.
///
/// `emitsAnimations: false` is exactly the production failure mode here: no Core Animation callback
/// will ever arrive for these tracks. The scheduler is injected, so the deadline is asserted rather
/// than waited on.
final class NoOpAnimationCompletionTests: XCTestCase {
    private func makeController(
        time: @escaping () -> CFTimeInterval,
        scheduled: @escaping (TimeInterval, @escaping () -> Void) -> Void
    ) -> ListAnimationController {
        ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: time,
            durationFactor: { 1 },
            scheduleAfter: scheduled
        )
    }

    /// Every departing row of a full-replace carousel takes this path: `fadesOut: false` keeps the
    /// row at the opacity it had, and the track exists purely to carry the teardown deadline.
    func testNonFadingExitTearsDownWithoutACoreAnimationCallback() throws {
        var time: CFTimeInterval = 10
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = makeController(time: { time },
                                        scheduled: { scheduled.append(($0, $1)) })
        let layer = CALayer()
        controller.seedLive(identity: "row", layer: layer)

        var tornDown = false
        controller.makeExit(identity: "row",
                            layer: layer,
                            contentY: 0,
                            transition: .easeInOut(duration: 0.3),
                            transactionTime: time,
                            fadesOut: false) { tornDown = true }

        XCTAssertFalse(tornDown, "teardown must wait for the pass duration, not fire immediately")
        let backstop = try XCTUnwrap(scheduled.first,
                                     "an equal-endpoint track must schedule its own completion")
        XCTAssertEqual(backstop.delay, 0.3, accuracy: 1e-9)

        time = 10.3
        backstop.work()
        XCTAssertTrue(tornDown,
                      "a non-fading exit must tear down; Core Animation never calls back for it")
    }

    /// A fading exit gets a real animation, so Core Animation WILL call back and no timer is armed.
    /// This is the non-vacuity guard: without it the test above would pass under a blanket timer for
    /// every track, which would cost dozens of timers per pass.
    func testFadingExitRidesItsCoreAnimationCallbackAndArmsNoTimer() {
        var time: CFTimeInterval = 10
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = makeController(time: { time },
                                        scheduled: { scheduled.append(($0, $1)) })
        let layer = CALayer()
        controller.seedLive(identity: "row", layer: layer)

        controller.makeExit(identity: "row",
                            layer: layer,
                            contentY: 0,
                            transition: .easeInOut(duration: 0.3),
                            transactionTime: time,
                            fadesOut: true) {}

        XCTAssertTrue(scheduled.isEmpty,
                      "opacity 1 -> 0 is a real animation and reports its own stop")
    }

    /// Re-targeting the viewport onto the displacement already in flight yields
    /// `viewportOffset: 0 -> 0` while still being a genuine re-target (the settled endpoints differ,
    /// so the model does not report `.unchanged`). Its completion is what releases the pass's
    /// viewport carries and every crossing carry migrated onto that generation.
    func testViewportRetargetOntoTheInFlightDisplacementStillReleasesItsGeneration() throws {
        var time: CFTimeInterval = 10
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = makeController(time: { time },
                                        scheduled: { scheduled.append(($0, $1)) })
        let layer = CALayer()
        controller.seedViewport(layer: layer)

        // A 50pt viewport move: correction starts at -50 and eases to 0.
        controller.transitionViewport(layer: layer,
                                      oldSettledOffset: 0,
                                      newSettledOffset: 50,
                                      transition: .easeInOut(duration: 0.5),
                                      transactionTime: time)
        XCTAssertTrue(scheduled.isEmpty, "a moving viewport track reports its own stop")

        // At phase 0 the correction is exactly -50, so re-targeting from 50 back to 0 asks for a
        // displacement the in-flight animation is already showing: from == to == 0.
        var released: UInt64?
        let mutation = controller.transitionViewport(layer: layer,
                                                     oldSettledOffset: 50,
                                                     newSettledOffset: 0,
                                                     transition: .easeInOut(duration: 0.5),
                                                     transactionTime: time) { generation in
            released = generation
        }
        let track = try XCTUnwrap(mutation.startedTrackForTests,
                                  "differing settled endpoints must still start a track")
        XCTAssertEqual(track.from, 0, accuracy: 1e-9)
        XCTAssertEqual(track.to, 0, accuracy: 1e-9)

        let backstop = try XCTUnwrap(scheduled.first,
                                     "an equal-endpoint viewport track must schedule its completion")
        XCTAssertEqual(backstop.delay, 0.5, accuracy: 1e-9)

        time = 10.5
        backstop.work()
        XCTAssertEqual(released, track.generation,
                       "the viewport generation must be released so its carries are reaped")
    }

    /// The timer and a (hypothetical) Core Animation callback must not both run the cleanup.
    func testAnalyticCompletionAndACoreAnimationCallbackCannotDoubleFire() throws {
        var time: CFTimeInterval = 10
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        var installed: [(track: ListAnimationTrack, completion: () -> Void)] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            scheduleAfter: { scheduled.append(($0, $1)) },
            animationInstaller: { track, _, _, _, completion in
                installed.append((track, completion))
            }
        )
        let layer = CALayer()
        controller.seedLive(identity: "row", layer: layer)

        var teardowns = 0
        controller.makeExit(identity: "row",
                            layer: layer,
                            contentY: 0,
                            transition: .easeInOut(duration: 0.3),
                            transactionTime: time,
                            fadesOut: false) { teardowns += 1 }

        time = 10.3
        try XCTUnwrap(scheduled.first).work()
        XCTAssertEqual(teardowns, 1)

        try XCTUnwrap(installed.first).completion()
        XCTAssertEqual(teardowns, 1, "a late Core Animation callback must be an exact no-op")
    }
}

private extension ListAnimationMutation {
    var startedTrackForTests: ListAnimationTrack? {
        guard case let .started(track) = self else { return nil }
        return track
    }
}
