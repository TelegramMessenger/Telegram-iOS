import XCTest
import UIKit
@testable import CoreListDemo

/// `additionalScrollDistance` is the analogue of `ListViewImpl.transaction`'s parameter of the same
/// name: a caller-chosen content displacement that rides the same addend as an inset change's
/// compensation (`Display/Source/ListView.swift:3275`), so one pass can re-inset AND scroll by a
/// delta as a single movement. Positive moves content DOWN, matching a growing top inset.
///
/// Assertions are on settled/rendered screen Y rather than the engine offset: mid-collection with both
/// edges unloaded the engine sits on `UIKitScrollEngine`'s private 10,000,000-point canvas, so its raw
/// offset carries a meaningless base.
final class AdditionalScrollDistanceTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 400)

    /// A row inside the loaded window at the scrolled position these tests use.
    private func probeIdentity(_ fixture: VirtualListFixture) throws -> AnyHashable {
        let index = 12
        XCTAssertTrue(fixture.loadedIndices.contains(index), "probe row must be loaded")
        return fixture.listView.items[index].identity
    }

    // MARK: - The displacement itself

    func testNegativeDistanceScrollsIntoContentByExactlyThatMuch() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.scroll(to: 500)
        let identity = try probeIdentity(fixture)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: identity))

        fixture.listView.applyChanges(additionalScrollDistance: -60,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                       before - 60, accuracy: 1e-6,
                       "content up 60 = scrolled 60 further into the collection")
    }

    func testPositiveDistanceMovesContentDownByExactlyThatMuch() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.scroll(to: 500)
        let identity = try probeIdentity(fixture)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: identity))

        fixture.listView.applyChanges(additionalScrollDistance: 60,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                       before + 60, accuracy: 1e-6)
    }

    /// The distance is an ADDEND on the inset compensation, not a replacement for it — which is what
    /// lets a keyboard-driven inset change plus a nudge be one movement rather than two.
    func testDistanceComposesWithInsetCompensationRatherThanReplacingIt() throws {
        func settledYAfterInsetChange(withDistance distance: CGFloat) throws -> CGFloat {
            let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
            fixture.scroll(to: 500)
            let identity = try probeIdentity(fixture)
            fixture.listView.applyChanges(
                newInsets: UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0),
                additionalScrollDistance: distance,
                transition: .easeInOut(duration: 0)
            )
            return try XCTUnwrap(fixture.settledScreenY(identity: identity))
        }

        let compensationOnly = try settledYAfterInsetChange(withDistance: 0)
        XCTAssertEqual(try settledYAfterInsetChange(withDistance: -60), compensationOnly - 60,
                       accuracy: 1e-6)
        XCTAssertEqual(try settledYAfterInsetChange(withDistance: 60), compensationOnly + 60,
                       accuracy: 1e-6)
    }

    func testZeroDistanceAloneIsNotEvenAPass() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.scroll(to: 500)
        let identity = try probeIdentity(fixture)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: identity))

        fixture.listView.applyChanges(additionalScrollDistance: 0,
                                      transition: .easeInOut(duration: 0.5))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: identity)),
                       before, accuracy: 1e-9)
        XCTAssertFalse(fixture.hasActiveAnimations)
    }

    // MARK: - Animation

    /// The displacement must animate through the ONE shared additive viewport track, exactly as an
    /// inset change does — that track is what carries ghost blocks, viewport carries and rows entering
    /// the window along with the loaded rows. Per-row position tracks would render the same rigid
    /// motion while leaving all three behind.
    func testDistanceAnimatesThroughTheSharedViewportTrackOnThePassCurve() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.scroll(to: 500)
        let identity = try probeIdentity(fixture)

        fixture.listView.applyChanges(additionalScrollDistance: -60,
                                      transition: .linear(duration: 3))

        let track = try XCTUnwrap(fixture.viewportTrack)
        XCTAssertEqual(track.from, -60, accuracy: 1e-6,
                       "the correction must start where the content already was")
        XCTAssertEqual(track.to, 0, accuracy: 1e-6)
        XCTAssertEqual(track.duration, 3, accuracy: 1e-9)
        XCTAssertEqual(track.curve, .linear)
        XCTAssertNil(fixture.positionTrack(identity: identity),
                     "a displaced row must not ALSO get its own correction, which would double it")
    }

    /// C0 continuity at the pass boundary, then arrival at the displaced position.
    func testDistanceIsContinuousAtThePassBoundaryAndArrivesDisplaced() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.scroll(to: 500)
        let identity = try probeIdentity(fixture)
        let renderedBefore = try XCTUnwrap(fixture.renderedY(identity: identity))

        fixture.listView.applyChanges(additionalScrollDistance: -60,
                                      transition: .linear(duration: 3))

        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                       renderedBefore, accuracy: 1e-6,
                       "the content must not jump at the boundary")
        fixture.advance(by: 1.5)
        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                       renderedBefore - 30, accuracy: 1e-6, "linear, so halfway at half time")
        fixture.advance(by: 1.5)
        XCTAssertEqual(try XCTUnwrap(fixture.renderedY(identity: identity)),
                       renderedBefore - 60, accuracy: 1e-6)
    }

    // MARK: - The loaded top edge

    /// At the loaded top the pass normally pins index 0 to point offset 0. That pin would swallow a
    /// displacement whole, so a caller asking for one opts out of it — matching ListViewImpl, whose
    /// equivalent (`snapToBounds`) only closes a GAP above the top item and therefore honours a
    /// displacement that scrolls DOWN into content.
    func testNegativeDistanceIsHonouredAtTheLoadedTopEdge() {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        XCTAssertEqual(fixture.boundsOriginY, 0, accuracy: 1e-9)

        fixture.listView.applyChanges(additionalScrollDistance: -60,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(fixture.boundsOriginY, 60, accuracy: 1e-6)
    }

    /// The other direction DOES get clipped, because it opens exactly the gap `snapToBounds` closes.
    func testPositiveDistanceIsClippedAtTheLoadedTopEdge() {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)

        fixture.listView.applyChanges(additionalScrollDistance: 60,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(fixture.boundsOriginY, 0, accuracy: 1e-6,
                       "a displacement past the loaded top edge is clipped, not overscrolled into")
    }

    // MARK: - Momentum

    func testNonZeroDistanceHaltsMomentum() {
        let fixture = PhysicsListFixture(itemCount: 200, itemHeight: 50, viewport: viewport)
        fixture.simulateFlick(offsetVelocity: 2_000)
        fixture.tick(dt: 1.0 / 60)
        XCTAssertTrue(fixture.engine.isDecelerating)

        fixture.listView.applyChanges(additionalScrollDistance: -60,
                                      transition: .easeInOut(duration: 0))

        XCTAssertFalse(fixture.engine.isDecelerating,
                       "a programmatic displacement halts the fling, as ListViewImpl's stopScrolling does")
    }

    /// `.preserveVisibleContent` is the stationary-item-range analogue, and ListViewImpl's stationary
    /// branch does NOT halt — the caller is asking to keep content where it is, not to jump.
    func testPreserveVisibleContentDoesNotHaltMomentum() {
        let fixture = PhysicsListFixture(itemCount: 200, itemHeight: 50, viewport: viewport)
        fixture.simulateFlick(offsetVelocity: 2_000)
        fixture.tick(dt: 1.0 / 60)
        XCTAssertTrue(fixture.engine.isDecelerating)

        fixture.listView.applyChanges(additionalScrollDistance: -60,
                                      anchorMode: .preserveVisibleContent,
                                      transition: .easeInOut(duration: 0))

        XCTAssertTrue(fixture.engine.isDecelerating)
    }
}
