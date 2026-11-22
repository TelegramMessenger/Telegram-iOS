import XCTest
import QuartzCore
@testable import CoreListDemo

final class ListAnimationModelTests: XCTestCase {
    private let owner = ListAnimationOwner.live(AnyHashable("row"))

    func testTrackUsesItsOwnCurve() {
        let smooth = ListAnimationTrack(generation: 1, from: 0, to: 100,
                                        startTime: 0, duration: 4, curve: .easeInOut)
        let easeOut = ListAnimationTrack(generation: 2, from: 0, to: 100,
                                         startTime: 0, duration: 4, curve: .linear)

        XCTAssertEqual(smooth.value(at: 1), 12.916193104731983, accuracy: 1e-9)
        XCTAssertEqual(easeOut.value(at: 1), 25.0, accuracy: 1e-9)
    }

    func testReplacementSamplesOldCurveAndAdoptsNewCurve() throws {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1)
        _ = model.transitionPosition(owner: owner, oldSettledY: 0, newSettledY: 100,
                                     at: 0, transition: .linear(duration: 4))
        let current = try XCTUnwrap(model.value(for: owner, property: .positionY, at: 1))

        guard case let .started(track) = model.transitionPosition(
            owner: owner, oldSettledY: 100, newSettledY: 200,
            at: 1, transition: .linear(duration: 2)
        ) else { return XCTFail("expected replacement") }

        XCTAssertEqual(200 + track.from, 100 + current, accuracy: 1e-9)
        XCTAssertEqual(track.curve, .linear)
    }

    func testControllerScalesSpecDurationOnceAndPreservesCurve() throws {
        let clock = SyntheticClock()
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { clock.now },
            durationFactor: { 3 }
        )
        let layer = CALayer()
        controller.seedLive(identity: "row", layer: layer)

        guard case let .started(track) = controller.transitionPosition(
            identity: "row", layer: layer,
            oldSettledY: 0, newSettledY: 100,
            transition: .linear(duration: 2), transactionTime: 0
        ) else { return XCTFail("expected track") }

        XCTAssertEqual(track.duration, 6)
        XCTAssertEqual(track.curve, .linear)
    }

    func testPositionXAndWidthRetargetIndependently() throws {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffsetX: 0, positionOffsetY: 0,
                       opacity: 1, width: 390, height: 75)
        _ = model.transitionPositionX(owner: owner, oldSettledX: 0, newSettledX: 40,
                                      at: 0, transition: .easeInOut(duration: 4))
        _ = model.transitionWidth(owner: owner, oldSettledWidth: 390, newSettledWidth: 310,
                                  at: 0, transition: .easeInOut(duration: 4))
        let xTrack = try XCTUnwrap(model.track(for: owner, property: .positionX))

        _ = model.transitionWidth(owner: owner, oldSettledWidth: 310, newSettledWidth: 280,
                                  at: 1, transition: .easeInOut(duration: 2))

        XCTAssertEqual(model.track(for: owner, property: .positionX), xTrack)
        XCTAssertEqual(try XCTUnwrap(model.value(for: owner, property: .width, at: 1)),
                       379.66704551621444, accuracy: 1e-9)
    }

    func testSmoothstepTrackSamplesBirthMiddleAndDeadline() {
        let track = ListAnimationTrack(generation: 7, from: 80, to: 0,
                                       startTime: 10, duration: 4)
        XCTAssertEqual(track.value(at: 10), 80, accuracy: 1e-12)
        XCTAssertEqual(track.value(at: 12), 40, accuracy: 1e-12)
        XCTAssertEqual(track.value(at: 14), 0, accuracy: 1e-12)
        XCTAssertTrue(track.isComplete(at: 14))
    }

    func testSamePositionTargetPreservesExactTrack() {
        let model = ListAnimationModel(positionEpsilon: 1e-6)
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1)
        _ = model.transitionPosition(owner: owner, oldSettledY: 100,
                                     newSettledY: 180, at: 1, transition: .easeInOut(duration: 3))
        let before = model.track(for: owner, property: .positionY)
        let result = model.transitionPosition(owner: owner, oldSettledY: 180,
                                              newSettledY: 180 + 5e-7,
                                              at: 2, transition: .easeInOut(duration: 9))
        XCTAssertEqual(result, .unchanged)
        XCTAssertEqual(model.track(for: owner, property: .positionY), before)
    }

    func testChangedPositionRetargetsFromAnalyticCurrentValue() {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1)
        _ = model.transitionPosition(owner: owner, oldSettledY: 100,
                                     newSettledY: 180, at: 0, transition: .easeInOut(duration: 4))
        XCTAssertEqual(model.value(for: owner, property: .positionY, at: 2)!, -40, accuracy: 1e-9)
        let mutation = model.transitionPosition(owner: owner, oldSettledY: 180,
                                                newSettledY: 220, at: 2, transition: .easeInOut(duration: 2))
        guard case let .started(track) = mutation else { return XCTFail("expected replacement") }
        XCTAssertEqual(track.from, -80, accuracy: 1e-9)
        XCTAssertEqual(track.to, 0)
        XCTAssertEqual(220 + track.value(at: 2), 140, accuracy: 1e-9)
    }

    func testSameHeightTargetPreservesExactTrack() {
        let model = ListAnimationModel(positionEpsilon: 1e-6)
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1, height: 75)
        _ = model.transitionHeight(owner: owner, oldSettledHeight: 75,
                                   newSettledHeight: 100, at: 1, transition: .easeInOut(duration: 3))
        let before = model.track(for: owner, property: .height)

        let result = model.transitionHeight(owner: owner, oldSettledHeight: 100,
                                            newSettledHeight: 100 + 5e-7,
                                            at: 2, transition: .easeInOut(duration: 9))

        XCTAssertEqual(result, .unchanged)
        XCTAssertEqual(model.track(for: owner, property: .height), before)
    }

    func testChangedHeightRetargetsFromAnalyticCurrentValue() {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1, height: 75)
        _ = model.transitionHeight(owner: owner, oldSettledHeight: 75,
                                   newSettledHeight: 100, at: 0, transition: .easeInOut(duration: 4))
        XCTAssertEqual(model.value(for: owner, property: .height, at: 1)!,
                       78.229048276183, accuracy: 1e-9)

        let mutation = model.transitionHeight(owner: owner, oldSettledHeight: 100,
                                              newSettledHeight: 125,
                                              at: 1, transition: .easeInOut(duration: 2))

        guard case let .started(track) = mutation else { return XCTFail("expected replacement") }
        XCTAssertEqual(track.from, 78.229048276183, accuracy: 1e-9)
        XCTAssertEqual(track.to, 125, accuracy: 1e-9)
        XCTAssertEqual(track.value(at: 1), 78.229048276183, accuracy: 1e-9)
    }

    func testHeightReplacementAdoptsIncomingCurve() {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1, height: 75)

        let mutation = model.transitionHeight(
            owner: owner,
            oldSettledHeight: 75,
            newSettledHeight: 125,
            at: 0,
            transition: .linear(duration: 2)
        )

        guard case let .started(track) = mutation else {
            return XCTFail("expected height track")
        }
        XCTAssertEqual(track.curve, .linear)
    }

    func testStaleCompletionCannotClearReplacement() {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1)
        guard case let .started(first) = model.transitionOpacity(owner: owner, to: 0.5, at: 0, transition: .easeInOut(duration: 1)),
              case let .started(second) = model.transitionOpacity(owner: owner, to: 1, at: 0.5, transition: .easeInOut(duration: 1))
        else { return XCTFail("expected tracks") }
        XCTAssertFalse(model.complete(owner: owner, property: .opacity,
                                      generation: first.generation, at: 1))
        XCTAssertEqual(model.track(for: owner, property: .opacity)?.generation, second.generation)
    }

    func testZeroDurationChangedPropertySettlesButSameTargetDoesNotClearOtherTrack() {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1)
        _ = model.transitionOpacity(owner: owner, to: 0, at: 0, transition: .easeInOut(duration: 3))
        let opacity = model.track(for: owner, property: .opacity)
        XCTAssertEqual(model.transitionPosition(owner: owner, oldSettledY: 10,
                                                newSettledY: 10, at: 1, transition: .easeInOut(duration: 0)), .unchanged)
        XCTAssertEqual(model.track(for: owner, property: .opacity), opacity)
    }

    func testZeroDurationChangedPositionSettlesOnlyPosition() {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1)
        _ = model.transitionOpacity(owner: owner, to: 0, at: 0, transition: .easeInOut(duration: 3))
        let opacity = model.track(for: owner, property: .opacity)

        let mutation = model.transitionPosition(owner: owner, oldSettledY: 10,
                                                newSettledY: 20, at: 1, transition: .easeInOut(duration: 0))

        XCTAssertEqual(mutation, .immediate(value: 0))
        XCTAssertNil(model.track(for: owner, property: .positionY))
        XCTAssertEqual(model.value(for: owner, property: .positionY, at: 1), 0)
        XCTAssertEqual(model.track(for: owner, property: .opacity), opacity)
    }

    func testViewportRetargetAndSameTargetNoOp() throws {
        let model = ListAnimationModel()
        model.seedViewport()
        guard case let .started(first) = model.transitionViewport(
            oldSettledOffset: 100, newSettledOffset: 300, at: 0, transition: .easeInOut(duration: 4)
        ) else { return XCTFail("expected viewport track") }

        XCTAssertEqual(model.transitionViewport(
            oldSettledOffset: 300, newSettledOffset: 300, at: 1, transition: .easeInOut(duration: 20)
        ), .unchanged)
        XCTAssertEqual(model.track(for: .viewport, property: .viewportOffset), first)

        guard case let .started(second) = model.transitionViewport(
            oldSettledOffset: 300, newSettledOffset: 500, at: 2, transition: .easeInOut(duration: 2)
        ) else { return XCTFail("expected replacement") }
        XCTAssertEqual(second.from, -300, accuracy: 1e-9)
        XCTAssertEqual(500 + second.from, 200, accuracy: 1e-9)
    }

    func testZeroDurationViewportTransitionSettlesAndAdvancesGeneration() throws {
        let model = ListAnimationModel()
        model.seedViewport()
        guard case let .started(first) = model.transitionViewport(
            oldSettledOffset: 100, newSettledOffset: 300, at: 0, transition: .easeInOut(duration: 4)
        ) else { return XCTFail("expected viewport track") }

        XCTAssertEqual(model.transitionViewport(
            oldSettledOffset: 300, newSettledOffset: 500, at: 1, transition: .easeInOut(duration: 0)
        ), .immediate(value: 0))
        XCTAssertNil(model.track(for: .viewport, property: .viewportOffset))
        XCTAssertEqual(model.value(for: .viewport, property: .viewportOffset, at: 1), 0)

        guard case let .started(next) = model.transitionViewport(
            oldSettledOffset: 500, newSettledOffset: 600, at: 2, transition: .easeInOut(duration: 1)
        ) else { return XCTFail("expected viewport track after settlement") }
        XCTAssertGreaterThan(next.generation, first.generation)
    }

    func testTransientClonesOneAnalyticSampleWithoutConsumingLiveOwnerOrTracks() throws {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1, height: 75)
        _ = model.transitionPosition(owner: owner, oldSettledY: 100,
                                     newSettledY: 180, at: 0, transition: .easeInOut(duration: 4))
        _ = model.transitionHeight(owner: owner, oldSettledHeight: 75,
                                   newSettledHeight: 100, at: 0, transition: .easeInOut(duration: 4))
        _ = model.transitionOpacity(owner: owner, to: 0.5, at: 0, transition: .easeInOut(duration: 4))
        let livePositionTrack = model.track(for: owner, property: .positionY)
        let liveHeightTrack = model.track(for: owner, property: .height)
        let liveOpacityTrack = model.track(for: owner, property: .opacity)

        let transient = model.beginTransient(from: owner, at: 1)

        guard case .transient = transient else { return XCTFail("expected transient owner") }
        XCTAssertTrue(model.contains(owner))
        XCTAssertEqual(model.track(for: owner, property: .positionY), livePositionTrack)
        XCTAssertEqual(model.track(for: owner, property: .height), liveHeightTrack)
        XCTAssertEqual(model.track(for: owner, property: .opacity), liveOpacityTrack)
        XCTAssertEqual(try XCTUnwrap(model.value(
            for: transient, property: .positionY, at: 3
        )), -69.66704551621442, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(model.value(
            for: transient, property: .height, at: 3
        )), 78.229048276183, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(model.value(
            for: transient, property: .opacity, at: 3
        )), 0.9354190344763401, accuracy: 1e-9)
        for property in [ListAnimatedProperty.viewportOffset, .positionY, .height, .opacity] {
            XCTAssertNil(model.track(for: transient, property: property))
        }
    }

    func testInsertionUsesFullGeometryAndFadesFromZeroToOne() {
        let model = ListAnimationModel()

        let mutation = model.beginInsertion(
            owner: owner,
            width: 320,
            height: 75,
            at: 3,
            transition: .easeInOut(duration: 2)
        )

        guard case let .started(track) = mutation else {
            return XCTFail("expected opacity track")
        }
        XCTAssertEqual(model.value(for: owner, property: .positionX, at: 3), 0)
        XCTAssertEqual(model.value(for: owner, property: .positionY, at: 3), 0)
        XCTAssertEqual(model.value(for: owner, property: .width, at: 3), 320)
        XCTAssertEqual(model.value(for: owner, property: .height, at: 3), 75)
        for property in [ListAnimatedProperty.positionX, .positionY, .width, .height] {
            XCTAssertNil(model.track(for: owner, property: property))
        }
        XCTAssertEqual(track.from, 0)
        XCTAssertEqual(track.to, 1)
        XCTAssertEqual(track.startTime, 3)
        XCTAssertEqual(track.duration, 2)
    }

    func testExitSamplesLivePresentationAndUsesUniqueOwnerAfterReinsertion() {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1, height: 75)
        _ = model.transitionPosition(owner: owner, oldSettledY: 100,
                                     newSettledY: 180, at: 0, transition: .easeInOut(duration: 4))
        _ = model.transitionOpacity(owner: owner, to: 0.5, at: 0, transition: .easeInOut(duration: 4))
        _ = model.transitionHeight(owner: owner, oldSettledHeight: 75,
                                   newSettledHeight: 100, at: 0, transition: .easeInOut(duration: 4))

        let first = model.beginExit(from: owner, at: 1, transition: .easeInOut(duration: 2))

        XCTAssertEqual(first.positionY, -69.66704551621442, accuracy: 1e-9)
        XCTAssertEqual(first.height, 78.229048276183, accuracy: 1e-9)
        XCTAssertNil(model.value(for: owner, property: .opacity, at: 1))
        // accuracy, not exact equality: these are bezier-solver outputs, and the two assertions
        // directly above already compare the same values with 1e-9. Exact comparison was accidental
        // and broke on a 2e-14 change of convergence path.
        XCTAssertEqual(model.value(for: first.owner, property: .positionY, at: 1) ?? .nan,
                       -69.66704551621442, accuracy: 1e-9)
        XCTAssertEqual(model.value(for: first.owner, property: .height, at: 1) ?? .nan,
                       78.229048276183, accuracy: 1e-9)
        XCTAssertNil(model.track(for: first.owner, property: .height),
                     "an exit freezes analytic height and remains fade-only")
        guard case let .started(firstFade) = first.opacityMutation else {
            return XCTFail("expected exit opacity track")
        }
        XCTAssertEqual(firstFade.from, 0.9354190344763401, accuracy: 1e-9)
        XCTAssertEqual(firstFade.to, 0)

        _ = model.beginInsertion(owner: owner,
                                 width: 240,
                                 height: 100,
                                 at: 1,
                                 transition: .easeInOut(duration: 2))
        let second = model.beginExit(from: owner, at: 1, transition: .easeInOut(duration: 2))
        XCTAssertNotEqual(first.owner, second.owner)
        XCTAssertNotNil(model.track(for: first.owner, property: .opacity))
    }

    func testActiveTrackIsRetainedWithoutAnyLayerBinding() {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1)
        _ = model.transitionOpacity(owner: owner, to: 0, at: 0, transition: .easeInOut(duration: 4))
        let track = model.track(for: owner, property: .opacity)

        XCTAssertEqual(model.value(for: owner, property: .opacity, at: 2), 0.5)
        XCTAssertEqual(model.track(for: owner, property: .opacity), track)
    }

    func testCompleteAndReapOnlyClearTracksAtTheirDeadlines() {
        let model = ListAnimationModel()
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1)
        guard case let .started(position) = model.transitionPosition(
            owner: owner, oldSettledY: 0, newSettledY: 40, at: 0, transition: .easeInOut(duration: 1)
        ), case let .started(opacity) = model.transitionOpacity(
            owner: owner, to: 0, at: 0, transition: .easeInOut(duration: 2)
        ) else { return XCTFail("expected tracks") }

        XCTAssertFalse(model.complete(owner: owner, property: .positionY,
                                      generation: position.generation, at: 0.5))
        model.reap(at: 1)
        XCTAssertNil(model.track(for: owner, property: .positionY))
        XCTAssertEqual(model.track(for: owner, property: .opacity), opacity)
        model.reap(at: 2)
        XCTAssertNil(model.track(for: owner, property: .opacity))
        XCTAssertEqual(model.value(for: owner, property: .opacity, at: 2), 0)
    }

    func testRemoveAndResetDiscardEveryOwner() {
        let model = ListAnimationModel()
        let other = ListAnimationOwner.live(AnyHashable("other"))
        model.seedLive(owner: owner, positionOffset: 0, opacity: 1)
        model.seedLive(owner: other, positionOffset: 12, opacity: 0.5)
        let exit = model.beginExit(from: owner, at: 0, transition: .easeInOut(duration: 1))

        model.remove(other)
        XCTAssertNil(model.value(for: other, property: .positionY, at: 0))
        model.reset()

        XCTAssertNil(model.value(for: owner, property: .opacity, at: 0))
        XCTAssertNil(model.value(for: exit.owner, property: .opacity, at: 0))
    }

    func testControllerUnbindKeepsAnalyticTrackAndRebindKeepsOriginalDeadline() throws {
        var time: CFTimeInterval = 10
        let compiler = CoreAnimationCompiler(emitsAnimations: false)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let firstLayer = CALayer()
        let reboundLayer = CALayer()

        controller.seedLive(identity: "row", layer: firstLayer)
        controller.transitionPosition(identity: "row", layer: firstLayer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 4))
        let original = try XCTUnwrap(
            controller.model.track(for: owner, property: .positionY)
        )

        controller.unbind(identity: "row", layer: firstLayer)
        XCTAssertEqual(controller.model.track(for: owner, property: .positionY), original)

        time = 11
        controller.rebind(identity: "row", layer: reboundLayer)
        XCTAssertEqual(controller.model.track(for: owner, property: .positionY), original)
        XCTAssertTrue(controller.hasActiveAnimations(at: 13.999))
        XCTAssertFalse(controller.hasActiveAnimations(at: 14))

        time = 14
        controller.reapSettledTracks()
        XCTAssertNil(controller.model.track(for: owner, property: .positionY))
        XCTAssertEqual(try XCTUnwrap(controller.positionOffset(identity: "row", at: 14)),
                       0, accuracy: 1e-9)
    }

    func testStaleExitCompletionCannotCleanUpReusedLayerOrNewerExit() throws {
        var time: CFTimeInterval = 0
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let layer = CALayer()
        var staleCleanupCount = 0
        var currentCleanupCount = 0

        controller.seedLive(identity: "row", layer: layer)
        let staleOwner = controller.makeExit(
            identity: "row", layer: layer, contentY: 240,
            transition: .easeInOut(duration: 4),
            completion: { staleCleanupCount += 1 }
        )
        XCTAssertEqual(layer.position.y, 240)

        controller.seedLive(identity: "row", layer: layer)
        let currentOwner = controller.makeExit(
            identity: "row", layer: layer, contentY: 260,
            transition: .easeInOut(duration: 8),
            completion: { currentCleanupCount += 1 }
        )
        XCTAssertNotEqual(staleOwner, currentOwner)

        time = 4
        controller.reapSettledTracks()

        XCTAssertEqual(staleCleanupCount, 0)
        XCTAssertEqual(currentCleanupCount, 0)
        XCTAssertNil(controller.opacity(owner: staleOwner, at: time))
        XCTAssertNotNil(controller.model.track(for: currentOwner, property: .opacity))
        XCTAssertEqual(try XCTUnwrap(controller.opacity(owner: currentOwner, at: time)),
                       0.5, accuracy: 1e-9)
    }

    func testControllerTransientFreezesSampleAndRemovalPreservesLiveOwner() throws {
        var time: CFTimeInterval = 0
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let layer = CALayer()
        layer.bounds.size.height = 75
        controller.seedLive(identity: "row", layer: layer)
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 4))
        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4))
        time = 1

        let transient = controller.makeTransient(
            identity: "row", layer: layer, contentY: 240,
            transactionTime: time
        )

        XCTAssertEqual(layer.position.y, 240)
        XCTAssertEqual(layer.bounds.height, 78.229048276183, accuracy: 1e-9)
        XCTAssertEqual(CGFloat(layer.opacity), 1, accuracy: 1e-9)
        XCTAssertTrue(controller.model.contains(.live(AnyHashable("row"))))
        XCTAssertTrue(controller.model.contains(transient))

        controller.removeTransient(owner: transient, layer: layer)

        XCTAssertTrue(controller.model.contains(.live(AnyHashable("row"))))
        XCTAssertFalse(controller.model.contains(transient))
    }

    func testGhostBlockPositionRetargetsFromAnalyticCurrentAbsoluteRoot() throws {
        let model = ListAnimationModel()
        let owner = ListAnimationOwner.ghostBlock(7)
        model.seedGhostBlock(owner: owner)
        _ = model.transitionGhostBlock(owner: owner,
                                       oldSettledY: 100,
                                       newSettledY: 180,
                                       at: 0,
                                       transition: .easeInOut(duration: 4))

        XCTAssertEqual(try XCTUnwrap(model.value(
            for: owner, property: .positionY, at: 1
        )), -69.66704551621442, accuracy: 1e-9)

        let mutation = model.transitionGhostBlock(owner: owner,
                                                  oldSettledY: 180,
                                                  newSettledY: 240,
                                                  at: 1,
                                                  transition: .easeInOut(duration: 2))
        guard case let .started(track) = mutation else {
            return XCTFail("expected ghost replacement")
        }
        XCTAssertEqual(track.from, -129.66704551621442, accuracy: 1e-9)
        XCTAssertEqual(240 + track.from, 110.33295448378558, accuracy: 1e-9)
    }

    func testGhostBlockSameTargetIsExactNoOpAndZeroDurationSettles() throws {
        let model = ListAnimationModel()
        let owner = ListAnimationOwner.ghostBlock(8)
        model.seedGhostBlock(owner: owner)
        guard case let .started(original) = model.transitionGhostBlock(
            owner: owner, oldSettledY: 40, newSettledY: 90, at: 0, transition: .easeInOut(duration: 5)
        ) else { return XCTFail("expected ghost track") }

        XCTAssertEqual(model.transitionGhostBlock(
            owner: owner, oldSettledY: 90, newSettledY: 90,
            at: 1, transition: .easeInOut(duration: 20)
        ), .unchanged)
        XCTAssertEqual(model.track(for: owner, property: .positionY), original)

        XCTAssertEqual(model.transitionGhostBlock(
            owner: owner, oldSettledY: 90, newSettledY: 120,
            at: 1, transition: .easeInOut(duration: 0)
        ), .immediate(value: 0))
        XCTAssertNil(model.track(for: owner, property: .positionY))
    }

    func testControllerGhostBlockUsesStablePositionKeyAndExactTransactionClock() throws {
        var time: CFTimeInterval = 10
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(),
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let layer = CALayer()
        let owner = ListAnimationOwner.ghostBlock(9)
        controller.seedGhostBlock(owner: owner, layer: layer, settledRootY: 100)

        let mutation = controller.transitionGhostBlock(
            owner: owner, layer: layer,
            oldSettledY: 100, newSettledY: 180,
            transition: .easeInOut(duration: 4), transactionTime: time
        )
        guard case let .started(track) = mutation else {
            return XCTFail("expected installed ghost track")
        }
        XCTAssertEqual(layer.position.y, 180, accuracy: 1e-9)
        XCTAssertEqual(track.startTime, 10, accuracy: 1e-9)
        XCTAssertNotNil(layer.animation(
            forKey: controller.compiler.animationKey(for: .positionY)
        ))

        time = 11
        XCTAssertEqual(try XCTUnwrap(controller.ghostBlockOffset(
            owner: owner, at: time
        )), -69.66704551621442, accuracy: 1e-9)
    }

    func testControllerPositionCompletionReportsOnlyCurrentGeneration() throws {
        var time: CFTimeInterval = 0
        var installed: [(ListAnimationTrack, () -> Void)] = []
        var completed: [UInt64] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            animationInstaller: { track, property, _, _, completion in
                guard property == .positionY else { return }
                installed.append((track, completion))
            }
        )
        let layer = CALayer()
        controller.seedLive(identity: "row", layer: layer)

        controller.transitionPosition(
            identity: "row", layer: layer,
            oldSettledY: 0, newSettledY: 100,
            transition: .easeInOut(duration: 4),
            completion: { completed.append($0) }
        )
        let stale = try XCTUnwrap(installed.first)

        time = 1
        controller.transitionPosition(
            identity: "row", layer: layer,
            oldSettledY: 100, newSettledY: 200,
            transition: .easeInOut(duration: 4),
            completion: { completed.append($0) }
        )
        let current = try XCTUnwrap(installed.last)

        time = 4
        stale.1()
        XCTAssertEqual(completed, [])

        time = 5
        current.1()
        XCTAssertEqual(completed, [current.0.generation])
    }

    func testControllerUnchangedPositionDoesNotReplaceOriginalCompletion() throws {
        var installed: [(ListAnimationTrack, () -> Void)] = []
        var completed: [UInt64] = []
        var time: CFTimeInterval = 0
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            animationInstaller: { track, property, _, _, completion in
                if property == .positionY { installed.append((track, completion)) }
            }
        )
        let layer = CALayer()
        controller.seedLive(identity: "row", layer: layer)
        let first = controller.transitionPosition(
            identity: "row", layer: layer,
            oldSettledY: 0, newSettledY: 100,
            transition: .easeInOut(duration: 4),
            completion: { completed.append($0) }
        )
        let unchanged = controller.transitionPosition(
            identity: "row", layer: layer,
            oldSettledY: 100, newSettledY: 100,
            transition: .easeInOut(duration: 1),
            completion: { _ in XCTFail("unchanged call installed a replacement completion") }
        )

        guard case let .started(firstTrack) = first else {
            return XCTFail("expected a started position track")
        }
        XCTAssertEqual(unchanged, .unchanged)
        XCTAssertEqual(installed.count, 1)
        time = 4
        installed[0].1()
        XCTAssertEqual(completed, [firstTrack.generation])
    }
}
