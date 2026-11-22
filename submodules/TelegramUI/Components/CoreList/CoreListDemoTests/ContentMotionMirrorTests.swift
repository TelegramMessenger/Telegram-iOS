import XCTest
import UIKit
@testable import CoreListDemo

/// `CoreVirtualListView.addContentMotionMirror`: a view outside the list rides the content exactly, through every model
/// write of the content host's `bounds.origin.y` and every animation of it (`ContentMotionMirroringLayer`). The chat's
/// inline results panel puts its glass on such a mirror: placed from per-frame callbacks, it trailed a render-server
/// flight by up to 60 pt (measured on the simulator, 2026-10-29).
final class ContentMotionMirrorTests: XCTestCase {
    private func engine() -> (PhysicsScrollEngine, ContentMotionMirroringLayer) {
        let engine = PhysicsScrollEngine()
        engine.contentHost.bounds.size = CGSize(width: 390, height: 844)
        engine.decelerationMode = .keyframe
        engine.setEdges(min: nil, max: nil)
        let layer = (engine.contentHost as? ContentMotionHostView)?.mirroringLayer
        XCTAssertNotNil(layer, "the engine's content host does not mirror")
        return (engine, layer ?? ContentMotionMirroringLayer())
    }

    private func mirror() -> UIView {
        return UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    }

    /// A flick, as `FlightLaunchContinuityTests` drives one: the engine launches a `.keyframe` flight.
    private func flick(_ engine: PhysicsScrollEngine) {
        func pan(_ state: UIGestureRecognizer.State, translation: CGFloat, velocity: CGFloat) {
            engine.applyPanUpdate(state: state,
                                  translation: CGPoint(x: 0, y: translation),
                                  velocity: CGPoint(x: 0, y: velocity),
                                  forced: false, isIndirect: false)
        }
        pan(.began, translation: -20, velocity: -3000)
        pan(.changed, translation: -60, velocity: -3000)
        pan(.ended, translation: -60, velocity: -3000)
    }

    private func assertSameAnimations(_ host: CALayer, _ mirror: CALayer, file: StaticString = #filePath, line: UInt = #line) {
        let keys = host.animationKeys() ?? []
        XCTAssertEqual(Set(mirror.animationKeys() ?? []), Set(keys), file: file, line: line)
        for key in keys {
            guard let a = host.animation(forKey: key) as? CAKeyframeAnimation, let b = mirror.animation(forKey: key) as? CAKeyframeAnimation else {
                XCTFail("\(key) is not a keyframe animation on both", file: file, line: line)
                continue
            }
            XCTAssertEqual(a.keyPath, b.keyPath, file: file, line: line)
            XCTAssertEqual(a.beginTime, b.beginTime, "out of phase", file: file, line: line)
            XCTAssertEqual(a.duration, b.duration, file: file, line: line)
            XCTAssertEqual(a.isAdditive, b.isAdditive, file: file, line: line)
            XCTAssertEqual(a.values as? [NSNumber], b.values as? [NSNumber], file: file, line: line)
            XCTAssertEqual(a.keyTimes, b.keyTimes, file: file, line: line)
        }
    }

    func testAMirrorStartsWhereTheContentIsAndFollowsItsWrites() {
        let (engine, layer) = self.engine()
        let mirror = self.mirror()
        engine.setOffset(120)
        layer.addMirror(mirror.layer)
        XCTAssertEqual(mirror.bounds.origin.y, 120)
        engine.setOffset(200)
        XCTAssertEqual(mirror.bounds.origin.y, 200)
        engine.applyShift(15)
        XCTAssertEqual(mirror.bounds.origin.y, 215)
        XCTAssertEqual(mirror.bounds.size, CGSize(width: 390, height: 844), "the mirror keeps its own size")
    }

    /// The flight plays on the render server: the mirror gets the same animation, in phase, and the same base; the catch
    /// removes it from both.
    func testAMirrorRidesAFlightAndItsCatch() {
        let (engine, layer) = self.engine()
        let mirror = self.mirror()
        layer.addMirror(mirror.layer)
        self.flick(engine)
        XCTAssertFalse((engine.contentHost.layer.animationKeys() ?? []).isEmpty, "non-vacuity: a flight was launched")
        self.assertSameAnimations(engine.contentHost.layer, mirror.layer)
        XCTAssertEqual(mirror.bounds.origin.y, engine.contentHost.bounds.origin.y, "a different base")

        engine.tearDown()
        XCTAssertTrue((engine.contentHost.layer.animationKeys() ?? []).isEmpty, "precondition: the catch removed the flight")
        XCTAssertTrue((mirror.layer.animationKeys() ?? []).isEmpty, "the mirror kept the flight")
        XCTAssertEqual(mirror.bounds.origin.y, engine.contentHost.bounds.origin.y)
    }

    func testAMirrorAddedDuringAFlightJoinsIt() {
        let (engine, layer) = self.engine()
        self.flick(engine)
        let mirror = self.mirror()
        layer.addMirror(mirror.layer)
        self.assertSameAnimations(engine.contentHost.layer, mirror.layer)
        XCTAssertEqual(mirror.bounds.origin.y, engine.contentHost.bounds.origin.y)
        engine.tearDown()
    }

    /// Only the content's motion: another property's animation stays the host's, and a removal that names no key
    /// leaves the mirror's own animations.
    func testOnlyTheOriginsAnimationsAreMirrored() {
        let (_, layer) = self.engine()
        let mirror = self.mirror()
        layer.addMirror(mirror.layer)
        mirror.layer.add(CABasicAnimation(keyPath: "opacity"), forKey: "own")

        layer.add(CABasicAnimation(keyPath: "position.x"), forKey: "other")
        XCTAssertNil(mirror.layer.animation(forKey: "other"))
        layer.add(CABasicAnimation(keyPath: "bounds.origin.y"), forKey: "motion")
        XCTAssertNotNil(mirror.layer.animation(forKey: "motion"))
        layer.removeAnimation(forKey: "motion")
        XCTAssertNil(mirror.layer.animation(forKey: "motion"))

        layer.add(CABasicAnimation(keyPath: "bounds.origin.y"), forKey: "motion")
        layer.removeAllAnimations()
        XCTAssertNil(mirror.layer.animation(forKey: "motion"))
        XCTAssertNotNil(mirror.layer.animation(forKey: "own"), "the host's removal took the mirror's own animation")
    }

    /// A copy on a mirror carries no completion: CoreList's completions are one-shot delegates, and a mirror's copy
    /// stopping first (a mirror removed mid-flight) would spend the host's, finalizing a flight early.
    func testAMirrorsCopyCarriesNoCompletion() {
        final class Probe: NSObject, CAAnimationDelegate {}
        let probe = Probe()
        let (_, layer) = self.engine()
        let early = self.mirror()
        layer.addMirror(early.layer)
        let animation = CABasicAnimation(keyPath: "bounds.origin.y")
        animation.delegate = probe
        layer.add(animation, forKey: "motion")
        let late = self.mirror()
        layer.addMirror(late.layer)
        XCTAssertNotNil(layer.animation(forKey: "motion")?.delegate, "precondition: the host's animation has its completion")
        XCTAssertNotNil(early.layer.animation(forKey: "motion"), "precondition: mirrored")
        XCTAssertNil(early.layer.animation(forKey: "motion")?.delegate, "a mirror's copy carries the host's completion")
        XCTAssertNil(late.layer.animation(forKey: "motion")?.delegate, "a late mirror's copy carries the host's completion")
    }

    /// A touch that lands on a flight stops it and is the scroll's; the next touch, on still content, is not.
    func testTheLatestTouchSaysWhetherItCaughtMovingContent() {
        let (engine, _) = self.engine()
        self.flick(engine)
        XCTAssertTrue(engine.isDecelerating, "precondition: a flight runs")
        engine.noteTouchDown(at: CACurrentMediaTime())
        XCTAssertTrue(engine.lastTouchCaughtMovingContent)
        // The catch stopped the motion (`CatchWithoutDragTests`); still this touch's answer at its lift: captured at
        // touch-down, not live.
        XCTAssertFalse(engine.isDecelerating, "precondition: the content rests")
        XCTAssertTrue(engine.lastTouchCaughtMovingContent, "the flag follows the live motion, not the touch")
        engine.noteTouchDown(at: CACurrentMediaTime())
        XCTAssertFalse(engine.lastTouchCaughtMovingContent, "still content was caught")
        engine.tearDown()
    }

    func testARemovedMirrorStopsFollowing() {
        let (engine, layer) = self.engine()
        let mirror = self.mirror()
        layer.addMirror(mirror.layer)
        engine.setOffset(50)
        layer.removeMirror(mirror.layer)
        engine.setOffset(90)
        XCTAssertEqual(mirror.bounds.origin.y, 50)
    }

    /// Through the list: a mirror follows a programmatic scroll, and a row's content frame does not move with it, so a
    /// view placed there on the mirror stays on the row.
    func testThroughTheListARowsContentFrameStaysOnItsRow() throws {
        let list = CoreVirtualListView(forEmbedding: CGRect(x: 0, y: 0, width: 390, height: 400))
        let items = (0 ..< 30).map { _ in IdentifiableFixedHeightItem(id: UUID(), height: 50) }
        list.applyChanges(items: items, newSize: CGSize(width: 390, height: 400), newInsets: .zero, transition: .immediate)
        let mirror = self.mirror()
        XCTAssertTrue(list.addContentMotionMirror(mirror))
        let row = try XCTUnwrap(list.loadedItemView(at: 2))
        let contentFrame = list.contentFrame(of: row)

        list.applyChanges(scrollTo: CoreListScrollTarget(index: 6, pointOffset: 0), transition: .immediate)
        let movedRow = try XCTUnwrap(list.loadedItemView(at: 6))
        XCTAssertEqual(list.settledFrame(of: movedRow).minY, 0, accuracy: 1e-6, "precondition: the list scrolled")
        XCTAssertEqual(mirror.bounds.origin.y, list.engine.contentHost.bounds.origin.y, "the mirror did not follow")
        let after = try XCTUnwrap(list.loadedItemView(at: 2))
        XCTAssertEqual(list.contentFrame(of: after).minY - mirror.bounds.origin.y, list.settledFrame(of: after).minY, accuracy: 1e-6,
                       "a view at the row's content frame on the mirror is not on the row")
        XCTAssertEqual(list.contentFrame(of: after).height, contentFrame.height)
    }

    /// The UIKit engine has no such host: nothing is registered.
    func testAnotherEngineRegistersNothing() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 400), items: [])
        XCTAssertFalse(fixture.listView.addContentMotionMirror(self.mirror()))
    }
}
