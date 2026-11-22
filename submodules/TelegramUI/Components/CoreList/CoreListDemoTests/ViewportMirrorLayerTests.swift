import XCTest
import QuartzCore
@testable import CoreListDemo

/// The viewport correction is one model track with more than one output layer.
///
/// A carousel's departed strip is parked outside the scrolling content host so the user's finger
/// cannot reach it, but it still has to travel — and its travel IS the viewport travel. Rather than
/// give it a second track (two tracks describing one motion is the failure family this module keeps
/// re-learning), the single track is emitted to the overlay's layer as a second output. One
/// generation, one phase, one deadline, one completion, and nothing to desynchronise.
final class ViewportMirrorLayerTests: XCTestCase {
    private func makeController(clock: SyntheticClock)
        -> (ListAnimationController, CALayer, CALayer) {
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: true),
            mediaTime: { clock.now },
            durationFactor: { 1 }
        )
        let host = CALayer()
        let mirror = CALayer()
        controller.seedViewport(layer: host)
        controller.addViewportMirrorLayer(mirror)
        return (controller, host, mirror)
    }

    private func viewportAnimation(on layer: CALayer,
                                   _ controller: ListAnimationController) -> CAAnimation? {
        layer.animation(forKey: controller.compiler.animationKey(for: .viewportOffset))
    }

    func testViewportTrackIsEmittedToTheMirrorLayer() throws {
        let clock = SyntheticClock()
        let (controller, host, mirror) = makeController(clock: clock)

        controller.transitionViewport(layer: host,
                                      oldSettledOffset: 0,
                                      newSettledOffset: 300,
                                      transition: .linear(duration: 1))

        let hosted = try XCTUnwrap(viewportAnimation(on: host, controller))
        let mirrored = try XCTUnwrap(viewportAnimation(on: mirror, controller))
        XCTAssertEqual(mirrored.coreListGeneration, hosted.coreListGeneration)
        XCTAssertEqual(mirrored.coreListDeclaredStartTime, hosted.coreListDeclaredStartTime)
        XCTAssertEqual(mirrored.duration, hosted.duration, accuracy: 1e-9)
    }

    /// A replacement must move both ends together: a mirror still playing the previous generation
    /// would drift away from the content it is supposed to be travelling beside.
    func testReplacingTheViewportTrackReplacesTheMirrorEmission() throws {
        let clock = SyntheticClock()
        let (controller, host, mirror) = makeController(clock: clock)

        controller.transitionViewport(layer: host,
                                      oldSettledOffset: 0,
                                      newSettledOffset: 300,
                                      transition: .linear(duration: 1))
        let first = try XCTUnwrap(viewportAnimation(on: mirror, controller)?.coreListGeneration)

        clock.advance(by: 0.3)
        controller.transitionViewport(layer: host,
                                      oldSettledOffset: 300,
                                      newSettledOffset: 900,
                                      transition: .linear(duration: 1))

        let hosted = try XCTUnwrap(viewportAnimation(on: host, controller))
        let mirrored = try XCTUnwrap(viewportAnimation(on: mirror, controller))
        XCTAssertNotEqual(mirrored.coreListGeneration, first)
        XCTAssertEqual(mirrored.coreListGeneration, hosted.coreListGeneration)
    }

    /// An immediate viewport mutation writes no animation; a mirror left holding the previous one
    /// would keep travelling after the list had already landed.
    func testImmediateViewportMutationClearsTheMirrorEmission() throws {
        let clock = SyntheticClock()
        let (controller, host, mirror) = makeController(clock: clock)

        controller.transitionViewport(layer: host,
                                      oldSettledOffset: 0,
                                      newSettledOffset: 300,
                                      transition: .linear(duration: 1))
        XCTAssertNotNil(viewportAnimation(on: mirror, controller))

        controller.transitionViewport(layer: host,
                                      oldSettledOffset: 300,
                                      newSettledOffset: 900,
                                      transition: .immediate)

        XCTAssertNil(viewportAnimation(on: host, controller))
        XCTAssertNil(viewportAnimation(on: mirror, controller))
    }

    func testResetClearsTheMirrorEmissionAndKeepsTheRegistration() throws {
        let clock = SyntheticClock()
        let (controller, host, mirror) = makeController(clock: clock)

        controller.transitionViewport(layer: host,
                                      oldSettledOffset: 0,
                                      newSettledOffset: 300,
                                      transition: .linear(duration: 1))
        controller.reset()
        XCTAssertNil(viewportAnimation(on: mirror, controller))

        // The overlay outlives the reset, so its registration must too.
        controller.seedViewport(layer: host)
        controller.transitionViewport(layer: host,
                                      oldSettledOffset: 0,
                                      newSettledOffset: 300,
                                      transition: .linear(duration: 1))
        XCTAssertNotNil(viewportAnimation(on: mirror, controller))
    }
}
