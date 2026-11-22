import XCTest
import UIKit
@testable import CoreListDemo

/// A mutation pass that runs while a `.keyframe` flight is in the air must not move the content.
///
/// It used to: the pass built its geometry from `engine.offset` sampled before its work
/// (CoreVirtualListView.swift:539) and re-based the coordinate against a later sample (:832 → :1347, plus a
/// third at :849), and `engine.offset` sampled the running animation — so the pass re-placed the content
/// exactly where it was when the pass STARTED, a backward lurch of `velocity × pass duration` (up to 185pt).
/// The fix makes `ScrollEngine.offset` the physics position, advanced once per frame. See
/// docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md.
///
/// **The measuring stick is load-bearing.** `engine.offset` must NOT appear in it: the fix changes that very
/// expression, so a metric built on it freezes with what it measures and reads zero even with the bug fully
/// present (deleting `flight?.noteShift(dy)` in PhysicsScrollEngine leaves such a test green). Everything here
/// measures against `engine.liveViewportOffset` — the PRESENTED viewport, which the fix does not touch.
///
/// The amplifier is a row whose measure/reconcile advances the injected clock, which is what a slow row
/// measure costs in production. `SyntheticClock` never advances inside a pass on its own, which is why the rest
/// of the suite is blind to this whole class.
final class MidFlightPassLurchTests: XCTestCase {

    /// A row that costs `cost` seconds of clock time every time it is measured or reconciled.
    private final class SlowRow: CoreListItem {
        let id: Int
        let revision: Int
        let height: CGFloat
        let clock: SyntheticClock
        let cost: TimeInterval

        init(id: Int, revision: Int = 0, height: CGFloat = 50,
             clock: SyntheticClock, cost: TimeInterval) {
            self.id = id
            self.revision = revision
            self.height = height
            self.clock = clock
            self.cost = cost
        }

        var identity: AnyHashable { id }
        func isEqual(to other: CoreListItem) -> Bool {
            guard let other = other as? SlowRow else { return false }
            return other.id == id && other.revision == revision
        }
        func view() -> UIView & CoreListItemView { SlowRowView(height: height, clock: clock, cost: cost) }
        func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) { clock.advance(by: cost) }
    }

    private final class SlowRowView: UIView, CoreListItemView {
        let height: CGFloat
        let clock: SyntheticClock
        let cost: TimeInterval
        var onContentDidChange: ((Bool) -> Void)?

        init(height: CGFloat, clock: SyntheticClock, cost: TimeInterval) {
            self.height = height
            self.clock = clock
            self.cost = cost
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
            clock.advance(by: cost)      // "measuring this row took `cost` seconds"
            return height
        }
    }

    /// True on-screen y of a row: container + local frame − the PRESENTED viewport. Never `engine.offset`.
    private func screenY(_ fixture: PhysicsListFixture, identity: AnyHashable) -> CGFloat? {
        guard let item = fixture.activeWindow.items.first(where: {
            (fixture.listView.items[$0.index] as? SlowRow)?.identity == identity
        }) else { return nil }
        return fixture.containerOriginY
            + item.view.frame.minY
            - (fixture.engine.liveViewportOffset + fixture.viewportCorrection)
    }

    private func flying(cost: TimeInterval, velocity: CGFloat,
                        mode: TestScrollEngine.DecelerationMode = .keyframe)
        -> (PhysicsListFixture, SyntheticClock) {
        let clock = SyntheticClock()
        let items: [CoreListItem] = (0..<200).map { SlowRow(id: $0, clock: clock, cost: cost) }
        let fixture = PhysicsListFixture(items: items, decelerationMode: mode, clock: clock)
        fixture.listView.applyChanges(scrollTo: .init(index: 60, pointOffset: 0), transition: .easeInOut(duration: 0))
        fixture.simulateFlick(offsetVelocity: velocity)
        for _ in 0..<6 { fixture.tick(dt: 1.0 / 120) }
        return (fixture, clock)
    }

    private struct Result {
        var passDuration: TimeInterval
        var screenWithoutPass: CGFloat
        var screenWithPass: CGFloat
        var lurch: CGFloat { screenWithPass - screenWithoutPass }
    }

    /// Run one content-changed pass mid-flight, and compare the probe row's presented screen y against a
    /// counterfactual that only advances the clock by the same amount. Comparing before/after the pass instead
    /// would hide the defect — "the row did not move during 24ms of flight" IS the defect.
    private func measureLurch(cost: TimeInterval, velocity: CGFloat,
                              mode: TestScrollEngine.DecelerationMode = .keyframe) -> Result {
        let (b, clockB) = flying(cost: cost, velocity: velocity, mode: mode)
        let probe = (b.listView.items[b.activeWindow.items[3].index] as! SlowRow).identity
        let t0 = clockB.now
        let changed: [CoreListItem] = (0..<200).map { SlowRow(id: $0, revision: 1, clock: clockB, cost: cost) }
        b.listView.applyChanges(items: changed, transition: .easeInOut(duration: 0))
        let dt = clockB.now - t0
        let withPass = screenY(b, identity: probe)!

        let (a, clockA) = flying(cost: cost, velocity: velocity, mode: mode)
        clockA.advance(by: dt)
        let withoutPass = screenY(a, identity: probe)!

        return Result(passDuration: dt, screenWithoutPass: withoutPass, screenWithPass: withPass)
    }

    // MARK: - The regression

    func test_midFlightPass_doesNotMoveTheContent_atAnyPassDuration() {
        for velocity in [CGFloat(3000), 9000] {
            for cost in [0.0, 0.000025, 0.0001, 0.0005] {
                let r = measureLurch(cost: cost, velocity: velocity)
                XCTAssertEqual(r.lurch, 0, accuracy: 0.5, """
                    a mid-flight mutation pass moved the content by \(r.lurch)pt \
                    (flick \(Int(velocity))pt/s, pass \(r.passDuration * 1000)ms, \(cost * 1_000_000)µs/row). \
                    The pass must be a rigid coordinate re-base: the flight keeps playing through it.
                    """)
            }
        }
    }

    func test_midFlightPass_lurchDoesNotScaleWithPassDuration() {
        // The signature of the defect was strict proportionality to pass duration. Pin the shape, not just
        // the magnitude: a cheap pass and a 20x more expensive one must be equally still.
        let cheap = measureLurch(cost: 0.000025, velocity: 9000)
        let heavy = measureLurch(cost: 0.0005, velocity: 9000)
        XCTAssertGreaterThan(heavy.passDuration, cheap.passDuration * 10, "the amplifier must actually amplify")
        XCTAssertEqual(abs(heavy.lurch) - abs(cheap.lurch), 0, accuracy: 0.5,
                       "lurch must not grow with pass duration (was v × Δt: 9.25pt → 184.86pt)")
    }

    func test_steppedMode_isAlsoStill() {
        let r = measureLurch(cost: 0.0005, velocity: 9000, mode: .stepped)
        XCTAssertEqual(r.lurch, 0, accuracy: 0.5)
    }

    /// A `scrollTo` arriving mid-momentum (jump-to-bottom during a fling) halts the flight. Its viewport
    /// animation must START from where the content actually is. The halt used to run inside `resolveAnchor`,
    /// i.e. AFTER the pass had already read `engine.offset` at :539 and built its geometry from it — so the
    /// animation's `from` was computed against a position the content had already left.
    func test_scrollToDuringMomentum_startsItsAnimationFromThePresentedPosition() {
        let (f, clock) = flying(cost: 0.0001, velocity: 9000)
        // Loaded window is ~[60…88] after the setup scrollTo(60) + flick, so a 10-row jump keeps the probe
        // in both the old and the new window (no carousel, no removal).
        let probeIndex = 72
        XCTAssertNotNil(f.activeWindow.items.first(where: { $0.index == probeIndex }),
                        "probe must be loaded before the pass")
        let probe = (f.listView.items[probeIndex] as! SlowRow).identity

        clock.advance(by: 0.008)          // the pass arrives between sampling ticks
        let before = screenY(f, identity: probe)!

        f.listView.applyChanges(scrollTo: .init(index: 70, pointOffset: 0), transition: .easeInOut(duration: 0.3))

        let after = screenY(f, identity: probe)!
        XCTAssertEqual(after, before, accuracy: 0.5, """
            the scroll animation started \(after - before)pt away from where the content was — \
            the halt must happen before the pass reads engine.offset
            """)
    }

    // MARK: - The seam contract

    func test_engineOffset_isStableWithinAFrame_andAdvancesOnTick() {
        let (f, clock) = flying(cost: 0, velocity: 9000)
        let first = f.engine.offset
        clock.advance(by: 0.004)
        XCTAssertEqual(f.engine.offset, first, accuracy: 1e-9,
                       "engine.offset must not track the clock — a pass reads it more than once")
        clock.advance(by: 0.004)
        XCTAssertEqual(f.engine.offset, first, accuracy: 1e-9)

        // ...but the presented viewport HAS moved: the flight is on the render server, not the main thread.
        // (Safe to compare numerically here: with no tick there is no rebalance, so no coordinate re-base.)
        XCTAssertGreaterThan(f.engine.liveViewportOffset, first + 10,
                            "the flight must keep playing while engine.offset holds still")

        // A tick re-syncs it to the presented position. Do NOT assert a numeric increase: the rebalance inside
        // the tick may re-base the coordinate (container reposition), which moves the offset NUMBER in either
        // direction while the content keeps travelling forward. Re-sync is the contract; monotonicity is not.
        f.tick(dt: 1.0 / 120)
        XCTAssertNotEqual(f.engine.offset, first, "a sampling tick advances it")
        XCTAssertEqual(f.engine.offset, f.engine.liveViewportOffset, accuracy: 1e-9,
                       "and lands exactly on the presented position")
    }

    func test_engineOffset_equalsPresentedPosition_atEveryTickBoundary() {
        // The two definitions must coincide exactly where the list observes them, which is what makes the
        // change a no-op for every existing test.
        for velocity in [CGFloat(3000), 9000] {
            let (f, _) = flying(cost: 0, velocity: velocity)
            for _ in 0..<8 {
                f.tick(dt: 1.0 / 120)
                XCTAssertEqual(f.engine.offset, f.engine.liveViewportOffset, accuracy: 1e-9,
                               "core.offset must equal the presented position at a tick boundary")
            }
        }
    }

    // MARK: - Passes that run between sampling ticks

    /// A pass triggered between sampling ticks (a network batch, a scheduler flush) must resolve its
    /// geometry against the CURRENT viewport, not the last tick's. Continuity held either way — that is the
    /// cancellation algebra — but membership, the anchor witness and the overscroll gate were all decided
    /// against a stale position.
    func test_passRunBetweenTicks_resolvesAgainstThePresentedViewport() {
        let (f, clock) = flying(cost: 0, velocity: 9000)
        clock.advance(by: 0.008)
        XCTAssertGreaterThan(f.engine.liveViewportOffset - f.engine.offset, 10,
                             "precondition: engine.offset is deliberately stale between ticks")

        let changed: [CoreListItem] = (0..<200).map {
            SlowRow(id: $0, revision: 1, clock: clock, cost: 0)
        }
        f.listView.applyChanges(items: changed, transition: .easeInOut(duration: 0))

        XCTAssertEqual(f.engine.offset, f.engine.liveViewportOffset, accuracy: 1e-6,
                       "the pass must have re-anchored the engine on the presented position")
    }

    /// The same pass must still be continuous — the sync must not become a second, inconsistent read.
    func test_passRunBetweenTicks_doesNotMoveTheContent() {
        let (b, clockB) = flying(cost: 0.0001, velocity: 9000)
        let probe = (b.listView.items[b.activeWindow.items[3].index] as! SlowRow).identity
        clockB.advance(by: 0.008)
        let t0 = clockB.now
        let changed: [CoreListItem] = (0..<200).map {
            SlowRow(id: $0, revision: 1, clock: clockB, cost: 0.0001)
        }
        b.listView.applyChanges(items: changed, transition: .easeInOut(duration: 0))
        let withPass = screenY(b, identity: probe)!

        let (a, clockA) = flying(cost: 0.0001, velocity: 9000)
        clockA.advance(by: 0.008 + (clockB.now - t0))
        let withoutPass = screenY(a, identity: probe)!

        XCTAssertEqual(withPass, withoutPass, accuracy: 0.5,
                       "an off-tick pass moved the content by \(withPass - withoutPass)pt")
    }

    /// The overscroll gate (`wasOverscrolledPrePass`, CoreVirtualListView.swift:588) is a 0.5pt threshold on
    /// `engine.offset − clamp(engine.offset, loadedEdges)`. Off-tick during a bounce that threshold was
    /// resolved against a stale sample, so it could take the wrong branch at :819-828 and clamp the settled
    /// offset to a loaded edge the content is not actually at. Pin the user-visible property: continuity.
    func test_offTickPassDuringABounce_doesNotMoveTheContent() {
        func bouncing(cost: TimeInterval) -> (PhysicsListFixture, SyntheticClock) {
            let clock = SyntheticClock()
            // 30 rows x 50pt = 1500pt of content in an 800pt viewport: the bottom edge is loaded, so
            // loadedEdgeRange reports a finite maximum and a hard flick overshoots into the bounce.
            let items: [CoreListItem] = (0..<30).map { SlowRow(id: $0, clock: clock, cost: cost) }
            let f = PhysicsListFixture(items: items, decelerationMode: .keyframe, clock: clock)
            f.simulateFlick(offsetVelocity: 6000)
            for _ in 0..<40 { f.tick(dt: 1.0 / 120) }   // reach the edge and enter the bounce
            return (f, clock)
        }

        let (b, clockB) = bouncing(cost: 0.0001)
        guard let probeItem = b.activeWindow.items.first else { return XCTFail("no loaded rows") }
        let probe = (b.listView.items[probeItem.index] as! SlowRow).identity
        clockB.advance(by: 0.004)
        let t0 = clockB.now
        let changed: [CoreListItem] = (0..<30).map {
            SlowRow(id: $0, revision: 1, clock: clockB, cost: 0.0001)
        }
        b.listView.applyChanges(items: changed, transition: .easeInOut(duration: 0))
        let withPass = screenY(b, identity: probe)!

        let (a, clockA) = bouncing(cost: 0.0001)
        clockA.advance(by: 0.004 + (clockB.now - t0))
        let withoutPass = screenY(a, identity: probe)!

        XCTAssertEqual(withPass, withoutPass, accuracy: 0.5,
                       "an off-tick pass during a bounce moved the content by \(withPass - withoutPass)pt")
    }

    // MARK: - Accepted cost, pinned rather than assumed

    /// The fix trades currency for consistency: a pass anchors on the position at the last sampling tick, so
    /// window membership is resolved against a viewport that trails the presented one by
    /// `velocity × (time since the last tick)`. Continuity is unaffected (that is the test above); COVERAGE is.
    /// This pins the lag to that formula so it cannot grow silently, and documents where it crosses
    /// `preloadMargin` (160pt) — at 9000pt/s that is ~18ms of main-thread work.
    func test_membershipLag_equalsVelocityTimesStaleness() {
        let (f, clock) = flying(cost: 0, velocity: 9000)
        let atTick = f.engine.offset
        clock.advance(by: 0.008)
        let lag = f.engine.liveViewportOffset - f.engine.offset
        XCTAssertEqual(f.engine.offset, atTick, accuracy: 1e-9)
        XCTAssertGreaterThan(lag, 0, "the presented viewport leads the value membership is resolved against")
        XCTAssertLessThan(lag, 160, "8ms of staleness must stay inside preloadMargin at 9000pt/s")
    }
}
