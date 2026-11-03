import XCTest
import UIKit
import QuartzCore
@testable import CoreListDemo

final class CoreAnimationCompilerParityTests: XCTestCase {
    private final class IntItem: CoreListItem {
        let id: Int
        let height: CGFloat
        var identity: AnyHashable { id }

        init(id: Int, height: CGFloat) {
            self.id = id
            self.height = height
        }

        func view() -> UIView & CoreListItemView {
            FixedHeightItemView(height: height)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? IntItem)?.id == id
        }
    }

    private final class AnimationSpyLayer: CALayer {
        var removedKeys: [String] = []

        override func removeAnimation(forKey key: String) {
            removedKeys.append(key)
            super.removeAnimation(forKey: key)
        }
    }

    private func visibleWindow() throws -> (UIWindow, UIViewController) {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        let root = UIViewController()
        root.view.backgroundColor = .white
        window.rootViewController = root
        window.makeKeyAndVisible()
        return (window, root)
    }

    private func flushCoreAnimation() {
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    /// The rendered-parity proofs below all pin `layer.timeOffset = track.startTime` before the first
    /// commit and then scrub. That pin is what makes the comparison against `track.value(at:)` valid
    /// now that `beginTime` is left implicit: a paused layer's local time AT THE COMMIT is its
    /// `timeOffset`, so Core Animation resolves the origin to exactly the track's clock.
    ///
    /// Asserting it here turns nine accidental passes into deliberate ones, and reads back the value
    /// Core Animation itself computed — strictly stronger evidence than the number the compiler used
    /// to stamp. Call this while the layer is still pinned, before any scrub.
    private func assertCommitResolvesOriginToTheTrackClock(
        layer: CALayer,
        property: ListAnimatedProperty,
        compiler: CoreAnimationCompiler,
        track: ListAnimationTrack,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(layer.timeOffset, track.startTime, accuracy: 1e-9,
                       "the layer must still be pinned at the track clock", file: file, line: line)
        flushCoreAnimation()   // this commit is what resolves the implicit origin
        guard let animation = layer.animation(forKey: compiler.animationKey(for: property)) else {
            XCTFail("no installed animation for \(property)", file: file, line: line)
            return
        }
        XCTAssertEqual(animation.beginTime, track.startTime, accuracy: 1e-9,
                       "the commit must resolve the implicit origin to the layer's paused local time",
                       file: file, line: line)
        XCTAssertFalse(animation.coreListPreservesPhase, file: file, line: line)
    }

    func testPositionKeyframeIsAdditiveDeclaresTheTrackClockAndLeavesTheOriginToTheCommit() throws {
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 1, from: -80, to: 0,
                                       startTime: 12, duration: 3)
        let animation = try XCTUnwrap(compiler.animation(for: track, property: .positionY)
                                      as? CABasicAnimation)
        XCTAssertEqual(animation.keyPath, "position.y")
        XCTAssertTrue(animation.isAdditive)
        // The animation has never been added to a layer, so `beginTime` is literally unset here —
        // this is a fact about the compiler, not about Core Animation.
        XCTAssertEqual(animation.beginTime, 0,
                       "a fresh install must leave the origin to the commit")
        XCTAssertEqual(try XCTUnwrap(animation.coreListDeclaredStartTime), 12, accuracy: 1e-9)
        XCTAssertFalse(animation.coreListPreservesPhase)
        XCTAssertEqual(animation.duration, 3)
        XCTAssertEqual(animation.fillMode, .both)
        XCTAssertFalse(animation.isRemovedOnCompletion)
    }

    func testExplicitOriginStampsTheGivenPhaseOrigin() throws {
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 92, from: 20, to: 0,
                                       startTime: 40, duration: 3)
        let animation = try XCTUnwrap(
            compiler.animation(for: track, property: .positionY,
                               origin: .explicit(track.startTime)) as? CABasicAnimation
        )
        XCTAssertEqual(animation.beginTime, 40)
        XCTAssertTrue(animation.coreListPreservesPhase)
        XCTAssertEqual(try XCTUnwrap(animation.coreListDeclaredStartTime), 40, accuracy: 1e-9)

        // The stamped origin is whatever the caller resolved — it is NOT required to be the track's
        // own clock, and on a real rebind it is not (see `phaseOrigin(for:…)`).
        let resolved = try XCTUnwrap(
            compiler.animation(for: track, property: .positionY,
                               origin: .explicit(41.5)) as? CABasicAnimation
        )
        XCTAssertEqual(resolved.beginTime, 41.5)
        XCTAssertEqual(try XCTUnwrap(resolved.coreListDeclaredStartTime), 40, accuracy: 1e-9)
    }

    func testOpacityKeyframeIsAbsolute() throws {
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 2, from: 0.25, to: 1,
                                       startTime: 4, duration: 2)
        let animation = try XCTUnwrap(compiler.animation(for: track, property: .opacity)
                                      as? CABasicAnimation)
        XCTAssertFalse(animation.isAdditive)
        XCTAssertEqual(animation.keyPath, "opacity")
    }

    func testHeightKeyframeIsAbsoluteAndIndependentlyKeyed() throws {
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 3, from: 75, to: 100,
                                       startTime: 4, duration: 2)

        let animation = try XCTUnwrap(compiler.animation(for: track, property: .height)
                                      as? CABasicAnimation)

        XCTAssertFalse(animation.isAdditive)
        XCTAssertEqual(animation.keyPath, "bounds.size.height")
        XCTAssertEqual(compiler.animationKey(for: .height), "CoreListAnimation.height")
        XCTAssertNotEqual(compiler.animationKey(for: .height),
                          compiler.animationKey(for: .positionY))
        XCTAssertNotEqual(compiler.animationKey(for: .height),
                          compiler.animationKey(for: .opacity))
    }

    func testHorizontalGeometryKeyframesHaveIndependentMappings() throws {
        let compiler = CoreAnimationCompiler()
        let position = ListAnimationTrack(generation: 31, from: -40, to: 0,
                                          startTime: 4, duration: 2)
        let width = ListAnimationTrack(generation: 32, from: 390, to: 310,
                                       startTime: 4, duration: 2)

        let positionAnimation = try XCTUnwrap(
            compiler.animation(for: position, property: .positionX) as? CABasicAnimation
        )
        let widthAnimation = try XCTUnwrap(
            compiler.animation(for: width, property: .width) as? CABasicAnimation
        )

        XCTAssertEqual(positionAnimation.keyPath, "position.x")
        XCTAssertTrue(positionAnimation.isAdditive)
        XCTAssertEqual(widthAnimation.keyPath, "bounds.size.width")
        XCTAssertFalse(widthAnimation.isAdditive)
        XCTAssertNotEqual(compiler.animationKey(for: .positionX),
                          compiler.animationKey(for: .width))
    }

    func testViewportKeyframeIsAdditiveBoundsOrigin() throws {
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 90, from: -500, to: 0,
                                       startTime: 10, duration: 4)
        let animation = try XCTUnwrap(compiler.animation(
            for: track, property: .viewportOffset
        ) as? CABasicAnimation)

        XCTAssertEqual(animation.keyPath, "bounds.origin.y")
        XCTAssertTrue(animation.isAdditive)
        XCTAssertEqual(compiler.animationKey(for: .viewportOffset),
                       "CoreListAnimation.viewportOffset")
    }

    func testCompilationPreservesGenerationAndDoesNotRescaleDuration() throws {
        let compiler = CoreAnimationCompiler()
        // The duration is already Slow-Animation-scaled before it reaches the compiler.
        let track = ListAnimationTrack(generation: 91, from: 20, to: 0,
                                       startTime: 40, duration: 3)
        let animation = try XCTUnwrap(compiler.animation(for: track, property: .positionY)
                                      as? CABasicAnimation)
        XCTAssertEqual(animation.beginTime, 0,
                       "a fresh install must leave the origin to the commit")
        XCTAssertEqual(try XCTUnwrap(animation.coreListDeclaredStartTime), 40, accuracy: 1e-9)
        XCTAssertEqual(animation.duration, 3, "the compiler must not apply Slow Animation scaling twice")
        XCTAssertEqual(animation.speed, 1.0)
        XCTAssertEqual((animation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
                       track.generation)
        XCTAssertEqual(animation.fromValue as? CGFloat, 20)
        XCTAssertEqual(animation.toValue as? CGFloat, 0)
    }

    func testInstallUsesStableKeysAndReplacementKeepsOtherProperty() throws {
        let compiler = CoreAnimationCompiler()
        let layer = CALayer()
        layer.speed = 0
        layer.timeOffset = 10
        let firstPosition = ListAnimationTrack(generation: 1, from: 80, to: 0,
                                               startTime: 10, duration: 2)
        let opacity = ListAnimationTrack(generation: 2, from: 0, to: 1,
                                         startTime: 10, duration: 2)
        let replacement = ListAnimationTrack(generation: 3, from: 40, to: 0,
                                              startTime: 10.5, duration: 1.5)
        let height = ListAnimationTrack(generation: 4, from: 75, to: 100,
                                        startTime: 10, duration: 2)
        let heightReplacement = ListAnimationTrack(generation: 5, from: 80, to: 110,
                                                   startTime: 10.5, duration: 1.5)

        compiler.install(firstPosition, property: .positionY, on: layer)
        compiler.install(opacity, property: .opacity, on: layer)
        compiler.install(height, property: .height, on: layer)
        compiler.install(replacement, property: .positionY, on: layer)
        compiler.install(heightReplacement, property: .height, on: layer)

        XCTAssertEqual(compiler.animationKey(for: .positionY), "CoreListAnimation.positionY")
        XCTAssertEqual(compiler.animationKey(for: .opacity), "CoreListAnimation.opacity")
        XCTAssertEqual(compiler.animationKey(for: .height), "CoreListAnimation.height")
        let installedPosition = try XCTUnwrap(
            layer.animation(forKey: compiler.animationKey(for: .positionY))
        )
        let installedOpacity = try XCTUnwrap(
            layer.animation(forKey: compiler.animationKey(for: .opacity))
        )
        let installedHeight = try XCTUnwrap(
            layer.animation(forKey: compiler.animationKey(for: .height))
        )
        XCTAssertEqual((installedPosition.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
                       replacement.generation)
        XCTAssertEqual((installedOpacity.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
                       opacity.generation)
        XCTAssertEqual((installedHeight.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
                       heightReplacement.generation)
    }

    func testDisabledCompilerDoesNotInstallAnimation() {
        let compiler = CoreAnimationCompiler(emitsAnimations: false)
        let layer = CALayer()
        let track = ListAnimationTrack(generation: 1, from: 1, to: 0,
                                       startTime: 0, duration: 1)

        compiler.install(track, property: .opacity, on: layer)

        XCTAssertNil(layer.animation(forKey: compiler.animationKey(for: .opacity)))
    }

    func testRemoveTargetsOnlyThePropertyStableKey() {
        let compiler = CoreAnimationCompiler()
        let layer = AnimationSpyLayer()

        compiler.remove(property: .positionY, from: layer)

        XCTAssertEqual(layer.removedKeys, ["CoreListAnimation.positionY"])
        XCTAssertFalse(layer.removedKeys.contains("CoreListAnimation.opacity"))
    }

    /// The 100%-match proof: install per curve on a REAL layer, pause it, step `timeOffset`, and
    /// compare what Core Animation actually renders against `track.value(at:)`. This measures the
    /// success criterion — rendered motion — rather than the sample array that used to approximate it.
    ///
    /// 0.5pt tolerance is well inside a pixel on a 3x display, so a pass means visually identical,
    /// while the class of error this work fixed (23% of travel on a mis-specified spring) would fail
    /// it by orders of magnitude.
    func testPausedLayerPresentationMatchesAnalyticTrackForEveryCurve() throws {
        let compiler = CoreAnimationCompiler()
        let cases: [(String, CoreListTransition.Animation.Curve, CoreListSpringKind, Double)] = [
            ("easeInOut", .easeInOut, .adjustedBezier, 3.0),
            ("easeIn", .easeIn, .adjustedBezier, 3.0),
            ("linear", .linear, .adjustedBezier, 3.0),
            ("custom", .custom(0.33, 0.52, 0.25, 0.99), .adjustedBezier, 3.0),
            ("spring@0.4", .spring, .adjustedBezier, 0.4),
            ("spring@0.5", .spring, .system05, 0.5)
        ]

        for (name, curve, springKind, duration) in cases {
            let track = ListAnimationTrack(generation: 44, from: -80, to: 0,
                                           startTime: 12, duration: duration,
                                           curve: curve, springKind: springKind)
            let (window, root) = try visibleWindow()
            defer { window.isHidden = true }

            let layer = CALayer()
            layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
            layer.position = CGPoint(x: 100, y: 200)
            layer.backgroundColor = UIColor.red.cgColor
            layer.speed = 0
            layer.timeOffset = track.startTime
            root.view.layer.addSublayer(layer)
            compiler.install(track, property: .positionY, on: layer)
            assertCommitResolvesOriginToTheTrackClock(layer: layer, property: .positionY,
                                                      compiler: compiler, track: track)

            // Do NOT reorder the phase loop ahead of the pin+flush above: the COMMIT chooses the
            // origin, so a scrub before it silently re-anchors the animation (measured).
            for phase in [0.0, 0.25, 0.5, 0.75, 1.0] {
                layer.timeOffset = track.startTime + phase * track.duration
                root.view.layoutIfNeeded()
                flushCoreAnimation()

                let presentation = try XCTUnwrap(layer.presentation())
                let rendered = presentation.position.y - layer.position.y
                let analytic = track.value(at: layer.timeOffset)
                XCTAssertEqual(rendered, analytic, accuracy: 0.5,
                               "\(name) diverged at phase \(phase)")
            }
        }
    }

    func testPausedWindowBackedLayerPresentationMatchesAnalyticOpacityTrack() throws {
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 45, from: 0.2, to: 1,
                                       startTime: 12, duration: 3)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        layer.position = CGPoint(x: 100, y: 200)
        layer.opacity = 1
        layer.backgroundColor = UIColor.red.cgColor
        layer.speed = 0
        layer.timeOffset = track.startTime
        root.view.layer.addSublayer(layer)
        compiler.install(track, property: .opacity, on: layer)
        assertCommitResolvesOriginToTheTrackClock(layer: layer, property: .opacity,
                                                  compiler: compiler, track: track)

        for phase in [0.0, 0.5, 1.0] {
            layer.timeOffset = track.startTime + phase * track.duration
            flushCoreAnimation()
            XCTAssertEqual(CGFloat(try XCTUnwrap(layer.presentation()).opacity),
                           track.value(at: layer.timeOffset), accuracy: 0.01)
        }
    }

    func testPausedWindowBackedLayerPresentationMatchesAnalyticHeightTrack() throws {
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 46, from: 75, to: 100,
                                       startTime: 12, duration: 3)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 100)
        layer.position = CGPoint(x: 100, y: 200)
        layer.backgroundColor = UIColor.red.cgColor
        layer.speed = 0
        layer.timeOffset = track.startTime
        root.view.layer.addSublayer(layer)
        compiler.install(track, property: .height, on: layer)
        assertCommitResolvesOriginToTheTrackClock(layer: layer, property: .height,
                                                  compiler: compiler, track: track)

        for phase in [0.0, 0.5, 1.0] {
            layer.timeOffset = track.startTime + phase * track.duration
            flushCoreAnimation()
            XCTAssertEqual(try XCTUnwrap(layer.presentation()).bounds.height,
                           track.value(at: layer.timeOffset), accuracy: 0.1)
        }
    }

    func testPausedViewportAddsToChangingBoundsAndPhysicsFlight() throws {
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 47, from: -200, to: 0,
                                       startTime: 12, duration: 4)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 500, width: 320, height: 640)
        layer.position = CGPoint(x: 160, y: 320)
        layer.speed = 0
        // Pinned at the track clock BEFORE the install, so the commit resolves the implicit origin
        // there and the analytic comparison below is on the model's own axis. The mid-phase scrub
        // that used to be this pin now happens after the origin is fixed.
        layer.timeOffset = track.startTime
        root.view.layer.addSublayer(layer)
        compiler.install(track, property: .viewportOffset, on: layer)
        assertCommitResolvesOriginToTheTrackClock(layer: layer, property: .viewportOffset,
                                                  compiler: compiler, track: track)

        layer.timeOffset = 14
        flushCoreAnimation()

        let correction = track.value(at: layer.timeOffset)
        XCTAssertEqual(try XCTUnwrap(layer.presentation()).bounds.origin.y,
                       500 + correction, accuracy: 0.1)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.bounds.origin.y = 575
        CATransaction.commit()
        flushCoreAnimation()
        XCTAssertEqual(try XCTUnwrap(layer.presentation()).bounds.origin.y,
                       575 + correction, accuracy: 0.1)

        let flight = CAKeyframeAnimation(keyPath: "bounds.origin.y")
        flight.isAdditive = true
        flight.values = [-50, -50]
        flight.keyTimes = [0, 1]
        flight.calculationMode = .linear
        flight.beginTime = track.startTime
        flight.duration = track.duration
        flight.fillMode = .both
        flight.isRemovedOnCompletion = false
        layer.add(flight, forKey: "listDecelerationFlight")
        flushCoreAnimation()

        XCTAssertEqual(try XCTUnwrap(layer.presentation()).bounds.origin.y,
                       575 + correction - 50, accuracy: 0.1)
    }

    func testControllerHeightRetargetPreservesPositionAndOpacityKeys() throws {
        var time: CFTimeInterval = 0
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 75)

        controller.insert(identity: "row", layer: layer, transition: .easeInOut(duration: 8))
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 8))
        let positionBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        let opacityBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))

        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4))
        time = 1
        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 100, newSettledHeight: 125,
                                    transition: .easeInOut(duration: 3))

        let positionAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        let opacityAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))
        // `beginTime` is no longer a same-object witness — it is commit-resolved, and identical for
        // any two emissions in one turn — so generation carries the "not replaced" claim here.
        XCTAssertEqual(positionAfter.coreListGeneration, positionBefore.coreListGeneration)
        XCTAssertEqual(positionAfter.duration, positionBefore.duration)
        XCTAssertEqual(opacityAfter.coreListGeneration, opacityBefore.coreListGeneration)
        XCTAssertEqual(opacityAfter.duration, opacityBefore.duration)
        XCTAssertNotNil(layer.animation(forKey: compiler.animationKey(for: .height)))
    }

    func testPausedWindowBackedReplacementMatchesControllerModel() throws {
        var time: CFTimeInterval = 10
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(),
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        layer.anchorPoint = .zero
        layer.position.y = 100
        layer.speed = 0
        layer.timeOffset = time
        root.view.layer.addSublayer(layer)
        controller.seedLive(identity: "row", layer: layer)
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 0, newSettledY: 100,
                                      transition: .easeInOut(duration: 4), transactionTime: time)

        time = 11
        layer.timeOffset = time
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.position.y = 150
        CATransaction.commit()
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 150,
                                      transition: .easeInOut(duration: 3), transactionTime: time)
        let replacement = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        layer.timeOffset = replacement.startTime
        assertCommitResolvesOriginToTheTrackClock(layer: layer, property: .positionY,
                                                  compiler: controller.compiler,
                                                  track: replacement)

        for phase in [0.0, 0.5, 1.0] {
            time = replacement.startTime + phase * replacement.duration
            layer.timeOffset = time
            flushCoreAnimation()
            let presentation = try XCTUnwrap(layer.presentation())
            XCTAssertEqual(presentation.position.y - layer.position.y,
                           replacement.value(at: time), accuracy: 0.1)
        }
    }

    func testPausedWindowBackedCrossingCarriesMatchAnalyticModel() throws {
        func items(_ ids: [Int]) -> [CoreListItem] {
            ids.map { IntItem(id: $0, height: 75) }
        }
        let original = Array(0..<30)
        let expanded = Array(0..<5) + Array(100..<105) + Array(5..<30)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }

        let outgoingFixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: items(original), preloadMargin: 200, emitsCA: true
        )
        root.view.addSubview(outgoingFixture.listView)
        outgoingFixture.apply(items(expanded), duration: 8)
        let outgoingIdentity = AnyHashable(8)
        let outgoingView = try XCTUnwrap(
            outgoingFixture.crossingCarryView(identity: outgoingIdentity)
        )
        // Pause BEFORE the first commit and at the pass clock (0): the commit is what resolves an
        // implicit origin, so pausing after one would anchor the curve at a wall-clock media time and
        // every comparison below would be against Core Animation's fill value. Nothing between
        // `apply` and here flushes — keep it that way.
        outgoingView.layer.speed = 0
        outgoingView.layer.timeOffset = 0
        let outgoingAnimation = try XCTUnwrap(outgoingView.layer.animation(
            forKey: "CoreListAnimation.positionY"
        ) as? CABasicAnimation)
        XCTAssertTrue(outgoingAnimation.isAdditive)

        for time in [0.0, 4.0, 8.0] {
            outgoingFixture.clock.now = time
            outgoingView.layer.timeOffset = time
            flushCoreAnimation()
            let snapshot = try XCTUnwrap(
                outgoingFixture.listView.crossingCarrySnapshots.first {
                    $0.identity == outgoingIdentity
                }
            )
            let analytic = snapshot.settledContentY
                + (outgoingFixture.animationController.positionOffset(
                    identity: outgoingIdentity,
                    at: time
                ) ?? 0)
            XCTAssertEqual(try XCTUnwrap(outgoingView.layer.presentation()).position.y,
                           analytic, accuracy: 0.1)
        }

        let incomingFixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: items(expanded), preloadMargin: 200, emitsCA: true
        )
        root.view.addSubview(incomingFixture.listView)
        incomingFixture.apply(items(original), duration: 8)
        let incomingIdentity = AnyHashable(8)
        let incomingView = try XCTUnwrap(incomingFixture.view(identity: incomingIdentity))
        // Pause before the first commit, at the pass clock — see the outgoing half above.
        incomingView.layer.speed = 0
        incomingView.layer.timeOffset = 0
        let incomingAnimation = try XCTUnwrap(incomingView.layer.animation(
            forKey: "CoreListAnimation.positionY"
        ) as? CABasicAnimation)
        XCTAssertTrue(incomingAnimation.isAdditive)

        for time in [0.0, 4.0, 8.0] {
            incomingFixture.clock.now = time
            incomingView.layer.timeOffset = time
            flushCoreAnimation()
            let settled = try XCTUnwrap(
                incomingFixture.driver.settledContentY(identity: incomingIdentity)
            )
            let analytic = settled + (incomingFixture.animationController.positionOffset(
                identity: incomingIdentity,
                at: time
            ) ?? 0)
            XCTAssertEqual(try XCTUnwrap(incomingView.layer.presentation()).position.y,
                           analytic, accuracy: 0.1)
        }
    }

    func testPausedUnwitnessedCrossingRunMatchesAnalyticModel() throws {
        func items(_ ids: [Int]) -> [CoreListItem] {
            ids.map { IntItem(id: $0, height: 75) }
        }
        let expanded = Array(0..<5) + Array(1000..<1100) + Array(5..<40)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: items(Array(0..<40)),
            preloadMargin: 200,
            emitsCA: true
        )
        root.view.addSubview(fixture.listView)
        fixture.apply(items(expanded), duration: 8)
        let identities = [AnyHashable(5), AnyHashable(6)]
        let views = try identities.map {
            try XCTUnwrap(fixture.crossingCarryView(identity: $0))
        }
        for view in views {
            // Pause before the first commit, at the pass clock (0) — the commit resolves the
            // implicit origin, so pausing afterwards would anchor these curves at a media time.
            view.layer.speed = 0
            view.layer.timeOffset = 0
            XCTAssertNotNil(view.layer.animation(forKey: "CoreListAnimation.positionY"))
        }

        for time in [0.0, 4.0, 8.0] {
            fixture.clock.now = time
            views.forEach { $0.layer.timeOffset = time }
            flushCoreAnimation()
            var presentationY: [CGFloat] = []
            for (identity, view) in zip(identities, views) {
                let snapshot = try XCTUnwrap(
                    fixture.listView.crossingCarrySnapshots.first {
                        $0.identity == identity
                    }
                )
                let analytic = snapshot.settledContentY
                    + (fixture.animationController.positionOffset(
                        identity: identity,
                        at: time
                    ) ?? 0)
                let y = try XCTUnwrap(view.layer.presentation()).position.y
                XCTAssertEqual(y, analytic, accuracy: 0.1)
                presentationY.append(y)
            }
            XCTAssertEqual(presentationY[1] - presentationY[0], 75, accuracy: 0.1)
        }
    }

    func testPausedWindowBackedReboundMatchesOriginalTrackPhaseAndDeadline() throws {
        var time: CFTimeInterval = 10
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(),
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let first = CALayer()
        first.position.y = 100
        controller.seedLive(identity: "row", layer: first)
        controller.transitionPosition(identity: "row", layer: first,
                                      oldSettledY: 0, newSettledY: 100,
                                      transition: .easeInOut(duration: 4), transactionTime: time)
        let original = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        controller.unbind(identity: "row", layer: first)

        time = 11
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let rebound = CALayer()
        rebound.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        rebound.anchorPoint = .zero
        rebound.position.y = 100
        rebound.speed = 0
        rebound.timeOffset = time
        root.view.layer.addSublayer(rebound)
        controller.rebind(identity: "row", layer: rebound)
        // The 10-vs-11 gap is load-bearing: the track starts at 10 while the layer is pinned at 11,
        // so an `.atCommit` emission here would resolve to 11 and render phase 0 where the model
        // says 0.25. This is the one case that must NOT take the commit's clock.
        XCTAssertTrue(try XCTUnwrap(rebound.animation(forKey: "CoreListAnimation.positionY"))
            .coreListPreservesPhase)

        for phase in [0.25, 0.5, 1.0] {
            time = original.startTime + phase * original.duration
            rebound.timeOffset = time
            flushCoreAnimation()
            let presentation = try XCTUnwrap(rebound.presentation())
            XCTAssertEqual(presentation.position.y - rebound.position.y,
                           original.value(at: time), accuracy: 0.1)
        }
    }

    func testControllerAppliesSlowModeOnceAsScaledTrackAndAnimationSpeed() throws {
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { 40 },
            durationFactor: { 10 }
        )
        let layer = CALayer()
        layer.position.y = 180

        controller.seedLive(identity: "row", layer: layer)
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 0.3))

        let track = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        let animation = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        // The MODEL is on the scaled clock (its deadlines and reaping depend on it); the emitted
        // animation keeps a logical duration and carries the factor as `speed`, matching
        // CAAnimationUtils. Both describe the same 3s of wall time.
        XCTAssertEqual(track.duration, 3)
        XCTAssertEqual(animation.duration, 0.3, accuracy: 1e-9,
                       "the emitted duration must stay logical")
        XCTAssertEqual(animation.speed, 0.1, accuracy: 1e-6,
                       "Slow Animations must appear as speed, not a longer duration")
        XCTAssertEqual(animation.duration / Double(animation.speed), 3, accuracy: 1e-6)
    }

    func testControllerViewportSlowDurationAndSameTargetPreserveExactTrackAndCA() throws {
        var time: CFTimeInterval = 40
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 10 }
        )
        let layer = CALayer()
        layer.bounds.origin.y = 300
        controller.seedViewport(layer: layer)
        controller.transitionViewport(
            layer: layer, oldSettledOffset: 100, newSettledOffset: 300,
            transition: .easeInOut(duration: 0.3), transactionTime: time,
            completion: { _ in }
        )
        let beforeTrack = try XCTUnwrap(controller.model.track(
            for: .viewport, property: .viewportOffset
        ))
        let key = compiler.animationKey(for: .viewportOffset)
        let beforeAnimation = try XCTUnwrap(layer.animation(forKey: key))
        XCTAssertEqual(beforeTrack.duration, 3)
        XCTAssertEqual(beforeAnimation.duration, 0.3, accuracy: 1e-9)
        XCTAssertEqual(beforeAnimation.speed, 0.1, accuracy: 1e-6)

        time = 41
        let mutation = controller.transitionViewport(
            layer: layer, oldSettledOffset: 300, newSettledOffset: 300,
            transition: .easeInOut(duration: 20), transactionTime: time,
            completion: { _ in }
        )
        let afterTrack = try XCTUnwrap(controller.model.track(
            for: .viewport, property: .viewportOffset
        ))
        let afterAnimation = try XCTUnwrap(layer.animation(forKey: key))
        XCTAssertEqual(mutation, .unchanged)
        XCTAssertEqual(afterTrack, beforeTrack)
        // `beginTime` no longer witnesses non-replacement (it is commit-resolved); the exact
        // generation equality below does.
        XCTAssertEqual(afterAnimation.duration, beforeAnimation.duration)
        XCTAssertEqual(
            (afterAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (beforeAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )
    }

    func testControllerSamePositionTargetLeavesInstalledGenerationAndClockUntouched() throws {
        var time: CFTimeInterval = 10
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let layer = CALayer()
        layer.position.y = 180

        controller.seedLive(identity: "row", layer: layer)
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 4))
        let beforeTrack = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        let beforeAnimation = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))

        time = 11
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 180,
                                      newSettledY: 180 + 5e-7,
                                      transition: .easeInOut(duration: 20))

        let afterTrack = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        let afterAnimation = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        XCTAssertEqual(afterTrack, beforeTrack)
        // `beginTime` no longer witnesses non-replacement (it is commit-resolved); the exact
        // generation equality below does.
        XCTAssertEqual(afterAnimation.duration, beforeAnimation.duration)
        XCTAssertEqual(
            (afterAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (beforeAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )
    }

    func testControllerSameHeightTargetLeavesModelAndInstalledCAKeyExactlyUntouched() throws {
        var time: CFTimeInterval = 10
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let layer = CALayer()
        layer.bounds.size.height = 75

        controller.seedLive(identity: "row", layer: layer)
        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4))
        let beforeTrack = try XCTUnwrap(
            controller.model.track(for: owner, property: .height)
        )
        let key = compiler.animationKey(for: .height)
        let installed = try XCTUnwrap(layer.animation(forKey: key))
        installed.setValue("preserve-height-install", forKey: "HeightRebind.installSentinel")
        // Re-adding a RETRIEVED animation under the same key is safe only because this layer is a
        // bare `CALayer` that never enters a render tree: an `.atCommit` origin stays unresolved, so
        // the re-add cannot re-zero a phase. Window-host this layer and the technique breaks
        // silently — the sentinel assertion would still pass while the curve restarted.
        layer.add(installed, forKey: key)

        time = 11
        let mutation = controller.transitionHeight(
            identity: "row", layer: layer,
            oldSettledHeight: 100, newSettledHeight: 100 + 5e-7,
            transition: .easeInOut(duration: 20)
        )

        XCTAssertEqual(mutation, .unchanged)
        XCTAssertEqual(controller.model.track(for: owner, property: .height), beforeTrack)
        XCTAssertEqual(layer.animation(forKey: key)?.value(
            forKey: "HeightRebind.installSentinel"
        ) as? String, "preserve-height-install")
    }

    func testControllerResetRemovesHeightModelStateAndInstalledCAKey() throws {
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { 0 },
            durationFactor: { 1 }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let layer = CALayer()
        layer.bounds.size.height = 75
        controller.seedLive(identity: "row", layer: layer)
        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4))
        XCTAssertNotNil(controller.model.track(for: owner, property: .height))
        XCTAssertNotNil(layer.animation(forKey: compiler.animationKey(for: .height)))

        controller.reset()

        XCTAssertNil(controller.model.value(for: owner, property: .height, at: 0))
        XCTAssertNil(controller.model.track(for: owner, property: .height))
        XCTAssertNil(layer.animation(forKey: compiler.animationKey(for: .height)))
    }

    func testControllerPositionRetargetPreservesInFlightOpacityKey() throws {
        var time: CFTimeInterval = 0
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let layer = CALayer()

        controller.insert(identity: "row", layer: layer, transition: .easeInOut(duration: 8))
        let opacityBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 4))

        time = 1
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 180, newSettledY: 220,
                                      transition: .easeInOut(duration: 3))

        let opacityAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))
        let position = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        XCTAssertEqual(
            (opacityAfter.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (opacityBefore.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )
        // `beginTime` no longer witnesses non-replacement (it is commit-resolved); the exact
        // generation equality above does.
        XCTAssertEqual(opacityAfter.duration, opacityBefore.duration)
        XCTAssertEqual(
            (position.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            controller.model.track(for: .live(AnyHashable("row")), property: .positionY)?.generation
        )
    }

    func testControllerStaleUnbindDoesNotClearRecycledLayersCurrentOwnerKeys() throws {
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { 0 },
            durationFactor: { 1 }
        )
        let layer = CALayer()

        controller.insert(identity: "A", layer: layer, transition: .easeInOut(duration: 8))
        controller.transitionPosition(identity: "A", layer: layer,
                                      oldSettledY: 0, newSettledY: 80,
                                      transition: .easeInOut(duration: 8))
        controller.insert(identity: "B", layer: layer, transition: .easeInOut(duration: 8))
        controller.transitionPosition(identity: "B", layer: layer,
                                      oldSettledY: 0, newSettledY: 120,
                                      transition: .easeInOut(duration: 8))

        let positionBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        let opacityBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))

        controller.unbind(identity: "A", layer: layer)

        let positionAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        let opacityAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))
        XCTAssertEqual(
            (positionAfter.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (positionBefore.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )
        XCTAssertEqual(
            (opacityAfter.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (opacityBefore.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )

        let unchanged = controller.transitionPosition(
            identity: "B", layer: layer,
            oldSettledY: 120, newSettledY: 120,
            transition: .easeInOut(duration: 20)
        )
        XCTAssertEqual(unchanged, .unchanged)
        XCTAssertNotNil(layer.animation(forKey: compiler.animationKey(for: .positionY)))
        XCTAssertNotNil(layer.animation(forKey: compiler.animationKey(for: .opacity)))
    }

    func testControllerRebindEmitsOriginalTrackClockAndCurrentBindingFinalizesIt() throws {
        var time: CFTimeInterval = 10
        let compiler = CoreAnimationCompiler()
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
        let original = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        controller.unbind(identity: "row", layer: firstLayer)

        time = 11
        controller.rebind(identity: "row", layer: reboundLayer)
        let rebound = try XCTUnwrap(reboundLayer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        // Both layers are bare `CALayer`s that never enter a render tree, so the original never
        // resolved an origin and `rebind` correctly falls back to the model's clock. Non-vacuous:
        // `original.startTime` is 10, and an `.atCommit` emission would read 0 here.
        XCTAssertEqual(rebound.beginTime, original.startTime)
        XCTAssertTrue(rebound.coreListPreservesPhase)
        XCTAssertEqual(try XCTUnwrap(rebound.coreListDeclaredStartTime),
                       original.startTime, accuracy: 1e-9)
        XCTAssertEqual(rebound.duration, original.duration)
        XCTAssertEqual(
            (rebound.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            original.generation
        )

        time = 14
        controller.reapSettledTracks()
        XCTAssertNil(reboundLayer.animation(forKey: compiler.animationKey(for: .positionY)),
                     "the stale first binding must not consume the generation before the rebound binding")
    }

    func testControllerAutonomouslyPrunesCompletedUnboundOwnerAtAnalyticDeadline() throws {
        var time: CFTimeInterval = 10
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            scheduleAfter: { delay, work in
                scheduled.append((delay, work))
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let layer = CALayer()

        controller.seedLive(identity: "row", layer: layer)
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 0, newSettledY: 100,
                                      transition: .easeInOut(duration: 4),
                                      transactionTime: time)
        controller.unbind(identity: "row", layer: layer, at: time)

        XCTAssertTrue(controller.model.contains(owner))
        XCTAssertEqual(try XCTUnwrap(scheduled.first?.delay), 4, accuracy: 1e-9)

        let early = scheduled.removeFirst().work
        early()
        XCTAssertTrue(controller.model.contains(owner),
                      "an early callback must retain active analytic state")
        XCTAssertEqual(try XCTUnwrap(scheduled.first?.delay), 4, accuracy: 1e-9)

        time = 14
        XCTAssertTrue(controller.model.contains(owner))
        scheduled.removeFirst().work()
        XCTAssertFalse(controller.model.contains(owner),
                       "deadline cleanup must not depend on a test driver or display link")
    }

    func testControllerAutonomouslyPrunesHeightOnlyUnboundOwnerAtAnalyticDeadline() throws {
        var time: CFTimeInterval = 10
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            scheduleAfter: { delay, work in
                scheduled.append((delay, work))
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let layer = CALayer()
        layer.bounds.size.height = 75
        controller.seedLive(identity: "row", layer: layer)
        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4),
                                    transactionTime: time)
        XCTAssertNil(controller.model.track(for: owner, property: .positionY))
        XCTAssertNil(controller.model.track(for: owner, property: .opacity))

        controller.unbind(identity: "row", layer: layer, at: time)

        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(try XCTUnwrap(scheduled.first?.delay), 4, accuracy: 1e-9)
        time = 14
        scheduled.removeFirst().work()
        XCTAssertFalse(controller.model.contains(owner))
    }

    func testStaleHeightReapCannotConsumeReboundReplacementGeneration() throws {
        var time: CFTimeInterval = 0
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            scheduleAfter: { delay, work in
                scheduled.append((delay, work))
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let firstLayer = CALayer()
        firstLayer.bounds.size.height = 75
        controller.seedLive(identity: "row", layer: firstLayer)
        controller.transitionHeight(identity: "row", layer: firstLayer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4),
                                    transactionTime: time)
        controller.unbind(identity: "row", layer: firstLayer, at: time)

        time = 1
        let reboundLayer = CALayer()
        reboundLayer.bounds.size.height = 100
        controller.rebind(identity: "row", layer: reboundLayer)
        controller.transitionHeight(identity: "row", layer: reboundLayer,
                                    oldSettledHeight: 100, newSettledHeight: 200,
                                    transition: .easeInOut(duration: 8),
                                    transactionTime: time)
        let replacement = try XCTUnwrap(
            controller.model.track(for: owner, property: .height)
        )
        controller.unbind(identity: "row", layer: reboundLayer, at: time)

        time = 4
        scheduled.removeFirst().work()
        XCTAssertEqual(controller.model.track(for: owner, property: .height), replacement,
                       "the original height deadline must not consume the replacement generation")

        time = 9
        scheduled.removeFirst().work()
        XCTAssertFalse(controller.model.contains(owner))
    }

    func testStaleHeightCACompletionCannotClearReboundReplacementOrInstalledKey() throws {
        var time: CFTimeInterval = 0
        var installedCompletions: [() -> Void] = []
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 },
            // A forwarding installer MUST pass the origin through: dropping it would emit `.atCommit`
            // for the rebind install below, restarting a curve that has to resume mid-phase.
            animationInstaller: { track, property, layer, origin, completion in
                compiler.install(track, property: property, on: layer, origin: origin)
                installedCompletions.append(completion)
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let firstLayer = CALayer()
        firstLayer.bounds.size.height = 75
        controller.seedLive(identity: "row", layer: firstLayer)
        controller.transitionHeight(identity: "row", layer: firstLayer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4),
                                    transactionTime: time)
        XCTAssertEqual(installedCompletions.count, 1)
        controller.unbind(identity: "row", layer: firstLayer, at: time)

        time = 1
        let reboundLayer = CALayer()
        reboundLayer.bounds.size.height = 100
        controller.rebind(identity: "row", layer: reboundLayer)
        XCTAssertEqual(installedCompletions.count, 2)
        controller.transitionHeight(identity: "row", layer: reboundLayer,
                                    oldSettledHeight: 100, newSettledHeight: 200,
                                    transition: .easeInOut(duration: 8),
                                    transactionTime: time)
        XCTAssertEqual(installedCompletions.count, 3)
        let replacement = try XCTUnwrap(
            controller.model.track(for: owner, property: .height)
        )
        let key = compiler.animationKey(for: .height)
        let installedReplacement = try XCTUnwrap(reboundLayer.animation(forKey: key))

        time = 4
        installedCompletions[0]()
        installedCompletions[1]()

        XCTAssertEqual(controller.model.track(for: owner, property: .height), replacement)
        let afterStaleCompletions = try XCTUnwrap(reboundLayer.animation(forKey: key))
        XCTAssertEqual(
            (afterStaleCompletions.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            replacement.generation
        )
        // `beginTime` no longer witnesses non-replacement (it is commit-resolved); the exact
        // generation equality above does.
        XCTAssertEqual(afterStaleCompletions.duration, installedReplacement.duration)
    }

    func testStaleAutonomousUnboundReapCannotConsumeReplacementGeneration() throws {
        var time: CFTimeInterval = 0
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            scheduleAfter: { delay, work in
                scheduled.append((delay, work))
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let firstLayer = CALayer()
        let secondLayer = CALayer()

        controller.seedLive(identity: "row", layer: firstLayer)
        controller.transitionPosition(identity: "row", layer: firstLayer,
                                      oldSettledY: 0, newSettledY: 100,
                                      transition: .easeInOut(duration: 4),
                                      transactionTime: time)
        controller.unbind(identity: "row", layer: firstLayer, at: time)

        time = 1
        controller.rebind(identity: "row", layer: secondLayer)
        controller.transitionPosition(identity: "row", layer: secondLayer,
                                      oldSettledY: 100, newSettledY: 200,
                                      transition: .easeInOut(duration: 8),
                                      transactionTime: time)
        let replacement = try XCTUnwrap(controller.model.track(
            for: owner, property: .positionY
        ))
        controller.unbind(identity: "row", layer: secondLayer, at: time)

        time = 4
        scheduled.removeFirst().work()
        XCTAssertEqual(controller.model.track(for: owner, property: .positionY), replacement,
                       "an old analytic deadline must not consume a replacement generation")

        time = 9
        scheduled.removeFirst().work()
        XCTAssertFalse(controller.model.contains(owner))
    }

    func testGhostBlockControllerTrackMatchesPausedWrapperLayer() throws {
        var time: CFTimeInterval = 12
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(),
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let wrapper = UIView(frame: CGRect(x: 0, y: 100, width: 320, height: 1))
        wrapper.layer.anchorPoint = CGPoint(x: 0, y: 0)
        wrapper.layer.speed = 0
        wrapper.layer.timeOffset = time
        root.view.addSubview(wrapper)
        let owner = ListAnimationOwner.ghostBlock(71)
        controller.seedGhostBlock(owner: owner,
                                  layer: wrapper.layer,
                                  settledRootY: 100)
        controller.transitionGhostBlock(owner: owner,
                                        layer: wrapper.layer,
                                        oldSettledY: 100,
                                        newSettledY: 180,
                                        transition: .easeInOut(duration: 4),
                                        transactionTime: time)
        assertCommitResolvesOriginToTheTrackClock(
            layer: wrapper.layer, property: .positionY, compiler: controller.compiler,
            track: try XCTUnwrap(controller.model.track(for: owner, property: .positionY))
        )

        for phase in [0.0, 0.5, 1.0] {
            time = 12 + phase * 4
            wrapper.layer.timeOffset = time
            flushCoreAnimation()
            let renderedRoot = try XCTUnwrap(wrapper.layer.presentation()).position.y
            let analyticRoot = wrapper.layer.position.y
                + (controller.ghostBlockOffset(owner: owner, at: time) ?? 0)
            XCTAssertEqual(renderedRoot, analyticRoot, accuracy: 0.1)
        }
    }

    // MARK: - The feature: one commit-resolved origin

    /// The detector for a regression back to the unconditional stamp. The layer is paused at 14 while
    /// the track's own clock is 12, so the two conventions render different values: an implicit origin
    /// resolves to 14 and renders phase 0.5 at local 16, an explicit `startTime` stamp would resolve
    /// to 12 and render phase 1.0 (the settled endpoint, 0).
    func testImplicitOriginResolvesAtTheCommitNotAtTheTrackClock() throws {
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 61, from: -80, to: 0,
                                       startTime: 12, duration: 4, curve: .linear)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        layer.position = CGPoint(x: 100, y: 200)
        layer.backgroundColor = UIColor.red.cgColor
        layer.speed = 0
        layer.timeOffset = 14
        root.view.layer.addSublayer(layer)

        compiler.install(track, property: .positionY, on: layer)
        flushCoreAnimation()
        XCTAssertEqual(
            try XCTUnwrap(layer.animation(forKey: compiler.animationKey(for: .positionY))).beginTime,
            14, accuracy: 1e-9,
            "the commit, not the track, chooses the origin"
        )

        layer.timeOffset = 16
        flushCoreAnimation()
        let rendered = try XCTUnwrap(layer.presentation()).position.y - layer.position.y
        XCTAssertEqual(rendered, track.value(at: 14), accuracy: 0.5,
                       "phase must be measured from the commit-resolved origin")
        XCTAssertEqual(rendered, -40, accuracy: 0.5)
        XCTAssertNotEqual(rendered, track.value(at: 16), accuracy: 1.0,
                          "non-vacuity: an explicit `startTime` stamp would render this instead")
    }

    /// The feature's own proof: a CoreList model track and a `CALayer.animate` executor animation,
    /// committed in one runloop turn on two layers paused at the same local time, start on ONE clock
    /// and render identically. This is what lets a host animation compose with a CoreList track.
    func testModelPathAndExecutorPathShareOneResolvedOrigin() throws {
        try XCTSkipUnless(UIView.animationDurationFactor == 1,
                          "CALayer.animate applies the Slow Animations factor itself")
        let compiler = CoreAnimationCompiler()
        let track = ListAnimationTrack(generation: 62, from: -80, to: 0,
                                       startTime: 12, duration: 4, curve: .linear)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }

        var layers: [CALayer] = []
        for index in 0..<2 {
            let layer = CALayer()
            layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
            layer.position = CGPoint(x: 100, y: 200 + CGFloat(index) * 60)
            layer.backgroundColor = UIColor.red.cgColor
            layer.speed = 0
            layer.timeOffset = 30
            root.view.layer.addSublayer(layer)
            layers.append(layer)
        }

        compiler.install(track, property: .positionY, on: layers[0])
        layers[1].animate(from: track.from, to: track.to, keyPath: "position.y",
                          duration: track.duration, curve: track.curve,
                          removeOnCompletion: false, additive: true, key: "executor")
        flushCoreAnimation()

        let modelOrigin = try XCTUnwrap(
            layers[0].animation(forKey: compiler.animationKey(for: .positionY))
        ).beginTime
        let executorOrigin = try XCTUnwrap(layers[1].animation(forKey: "executor")).beginTime
        XCTAssertEqual(modelOrigin, executorOrigin, accuracy: 1e-9,
                       "the model path and the executor path must start on one clock")
        XCTAssertEqual(modelOrigin, 30, accuracy: 1e-9)

        for phase in [0.25, 0.5, 0.75] {
            layers.forEach { $0.timeOffset = 30 + phase * track.duration }
            flushCoreAnimation()
            let model = try XCTUnwrap(layers[0].presentation()).position.y - layers[0].position.y
            let executor = try XCTUnwrap(layers[1].presentation()).position.y - layers[1].position.y
            XCTAssertEqual(model, executor, accuracy: 0.5,
                           "diverged at phase \(phase)")
            XCTAssertNotEqual(model, track.from, accuracy: 1.0,
                              "non-vacuity: neither is parked at `from` at phase \(phase)")
        }
    }

    /// One pass, one clock — on the CA side, as a fact Core Animation computed rather than one the
    /// compiler stamped. This is the only test anywhere that reads real resolved `beginTime`s
    /// produced by a full `applyChanges`; every other fixture in the suite is windowless, where an
    /// `.atCommit` emission reads 0 and per-emission origin skew is structurally invisible.
    func testOnePassCommitsEveryEmittedAnimationOnOneResolvedClock() throws {
        func items(_ ids: [Int]) -> [CoreListItem] {
            ids.map { IntItem(id: $0, height: 75) }
        }
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let clock = SyntheticClock()
        clock.now = 5
        let fixture = VirtualListFixture(viewport: CGSize(width: 320, height: 600),
                                         items: items(Array(0..<12)),
                                         preloadMargin: 100,
                                         clock: clock,
                                         emitsCA: true)
        root.view.addSubview(fixture.listView)

        // One insert among survivors: an insertion fade on the new row plus position tracks on every
        // row below it, so the pass emits on several distinct layers.
        fixture.apply(items([0, 1, 99, 2, 3, 4, 5, 6, 7, 8, 9, 10]), duration: 3)
        flushCoreAnimation()

        var origins: [Double] = []
        var layers: [ObjectIdentifier] = []
        for entry in fixture.listView.loadedItemEntries {
            for property in [ListAnimatedProperty.positionY, .opacity] {
                let key = fixture.animationController.compiler.animationKey(for: property)
                guard let animation = entry.view.layer.animation(forKey: key) else { continue }
                origins.append(animation.beginTime)
                layers.append(ObjectIdentifier(entry.view.layer))
                XCTAssertEqual(try XCTUnwrap(animation.coreListDeclaredStartTime), 5,
                               accuracy: 1e-9,
                               "the declared phase axis is still the pass clock")
                XCTAssertFalse(animation.coreListPreservesPhase)
            }
        }

        XCTAssertGreaterThanOrEqual(origins.count, 3, "non-vacuity: the pass emitted too little")
        XCTAssertGreaterThanOrEqual(Set(layers).count, 2,
                                    "non-vacuity: all emissions landed on one layer")
        XCTAssertEqual(Set(origins).count, 1,
                       "one pass must resolve to one origin, not one per emission: \(origins)")
        let origin = try XCTUnwrap(origins.first)
        XCTAssertNotEqual(origin, 0,
                          "non-vacuity: the window-hosted commit must actually have resolved one")
        XCTAssertGreaterThanOrEqual(origin, 5,
                                    "the CA origin is at or after the pass clock — the direction the "
                                        + "analytic-completion deadline depends on")
    }

    /// The rebind exception, measured where it is observable: the original resolved its origin at a
    /// commit, so re-emitting the track must reproduce THAT origin. Stamping `track.startTime`
    /// instead — which is earlier by the producing pass's commit delay, here a deliberate 2 — jumps
    /// the curve forward by exactly that much and desyncs the row from its still-bound neighbours.
    func testWindowBackedRebindResumesTheOriginalResolvedPhase() throws {
        var time: CFTimeInterval = 10
        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }

        let first = CALayer()
        first.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        first.anchorPoint = .zero
        first.position.y = 100
        first.backgroundColor = UIColor.red.cgColor
        first.speed = 0
        first.timeOffset = 14           // the commit delay, made observable
        root.view.layer.addSublayer(first)
        controller.seedLive(identity: "row", layer: first)
        controller.transitionPosition(identity: "row", layer: first,
                                      oldSettledY: 0, newSettledY: 100,
                                      transition: .linear(duration: 4), transactionTime: time)
        let original = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        XCTAssertEqual(original.startTime, 10, accuracy: 1e-9)
        flushCoreAnimation()
        let resolved = try XCTUnwrap(
            first.animation(forKey: compiler.animationKey(for: .positionY))
        ).beginTime
        XCTAssertEqual(resolved, 14, accuracy: 1e-9,
                       "non-vacuity: the original's origin must differ from its track clock")

        controller.unbind(identity: "row", layer: first)

        time = 11
        let rebound = CALayer()
        rebound.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        rebound.anchorPoint = .zero
        rebound.position.y = 100
        rebound.backgroundColor = UIColor.red.cgColor
        rebound.speed = 0
        rebound.timeOffset = 20
        root.view.layer.addSublayer(rebound)
        controller.rebind(identity: "row", layer: rebound)

        let reboundAnimation = try XCTUnwrap(
            rebound.animation(forKey: compiler.animationKey(for: .positionY))
        )
        XCTAssertTrue(reboundAnimation.coreListPreservesPhase)
        XCTAssertEqual(reboundAnimation.beginTime, resolved, accuracy: 1e-9,
                       "a rebind must reproduce the origin Core Animation resolved, not the "
                           + "model's clock")
        XCTAssertEqual(try XCTUnwrap(reboundAnimation.coreListDeclaredStartTime),
                       original.startTime, accuracy: 1e-9,
                       "the declared phase axis stays the model's")

        // ...and it renders where the original was rendering: at local 16 the original was at phase
        // (16 - 14)/4 = 0.5. Under a `track.startTime` stamp this would be phase (16 - 10)/4 > 1.
        rebound.timeOffset = 16
        flushCoreAnimation()
        let rendered = try XCTUnwrap(rebound.presentation()).position.y - rebound.position.y
        XCTAssertEqual(rendered, original.value(at: original.startTime + 0.5 * original.duration),
                       accuracy: 0.5)
        XCTAssertNotEqual(rendered, original.to, accuracy: 1.0,
                          "non-vacuity: a `startTime` stamp would render the settled endpoint")
    }
}
