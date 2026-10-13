import XCTest
import UIKit
@testable import CoreListDemo

/// `presentedFrame(of:)` — the accessor a host must use instead of `UIView.convert`.
///
/// `convert` composes ancestor MODEL `bounds.origin`, and `contentHost`'s model origin is the additive base
/// of whatever animates the viewport: a `.keyframe` flight parks it at the flight's DESTINATION, and a
/// programmatic `scrollTo` leaves the settled endpoint there while the additive `viewportOffset` track
/// carries the motion. A host converting through `contentHost` therefore reads destination-space geometry
/// for the whole animation. See docs/superpowers/plans/2026-07-26-presented-geometry-for-hosts.md.
final class PresentedGeometryTests: XCTestCase {

    private func fixture(rows: Int = 200, mode: TestScrollEngine.DecelerationMode = .keyframe)
        -> (PhysicsListFixture, SyntheticClock) {
        let clock = SyntheticClock()
        let items: [CoreListItem] = (0..<rows).map { _ in IdentifiableFixedHeightItem(id: UUID(), height: 50) }
        return (PhysicsListFixture(items: items, decelerationMode: mode, clock: clock), clock)
    }

    /// The screen y the presented geometry must agree with, computed the way the lurch tests do it.
    private func expectedScreenY(_ f: PhysicsListFixture, _ item: CoreVirtualListView.Window.Item) -> CGFloat {
        f.containerOriginY + item.view.frame.minY - (f.engine.liveViewportOffset + f.viewportCorrection)
    }

    func test_atRest_presentedFrameEqualsConvert() {
        let (f, _) = fixture()
        f.listView.applyChanges(scrollTo: .init(index: 60, pointOffset: 0), transition: .easeInOut(duration: 0))
        let item = f.activeWindow.items[3]
        let converted = f.listView.convert(item.view.bounds, from: item.view)
        XCTAssertEqual(f.listView.presentedFrame(of: item.view).minY, converted.minY, accuracy: 0.001,
                       "with nothing animating the model IS the presented value")
    }

    func test_duringAFlight_convertReportsTheDestination_presentedFrameReportsTheScreen() {
        let (f, _) = fixture()
        f.listView.applyChanges(scrollTo: .init(index: 60, pointOffset: 0), transition: .easeInOut(duration: 0))
        f.simulateFlick(offsetVelocity: 9000)
        for _ in 0..<6 { f.tick(dt: 1.0 / 120) }

        let item = f.activeWindow.items[3]
        let converted = f.listView.convert(item.view.bounds, from: item.view)
        let presented = f.listView.presentedFrame(of: item.view)

        XCTAssertGreaterThan(abs(converted.minY - presented.minY), 100,
                             "mid-flight the model is the destination, hundreds of points from the screen")
        XCTAssertEqual(presented.minY, expectedScreenY(f, item), accuracy: 0.5,
                       "presentedFrame must equal where the row actually is")
        XCTAssertEqual(presented.height, item.view.frame.height, accuracy: 0.001,
                       "only the origin is corrected")
    }

    /// "Presented" means as of the last sampling tick, NOT instantaneous — it is built on `engine.offset`,
    /// which is per-frame stable by contract. Hosts read geometry from the per-frame scroll callbacks, where
    /// the two coincide, and keeping the clock out of the seam is the whole point of that contract. So two
    /// reads in the same frame must agree even though the render server has moved on between them.
    func test_offTick_presentedFrameIsStable_notInstantaneous() {
        let (f, clock) = fixture()
        f.listView.applyChanges(scrollTo: .init(index: 60, pointOffset: 0), transition: .easeInOut(duration: 0))
        f.simulateFlick(offsetVelocity: 9000)
        for _ in 0..<6 { f.tick(dt: 1.0 / 120) }

        let item = f.activeWindow.items[3]
        let atTick = f.listView.presentedFrame(of: item.view).minY
        clock.advance(by: 0.004)
        XCTAssertEqual(f.listView.presentedFrame(of: item.view).minY, atTick, accuracy: 0.001,
                       "stable within a frame — a host may call this in a loop over the loaded window")
        XCTAssertGreaterThan(abs(f.engine.liveViewportOffset - f.engine.offset), 10,
                             "…while the render server HAS moved on: the staleness is real and bounded")

        f.tick(dt: 1.0 / 120)
        XCTAssertNotEqual(f.listView.presentedFrame(of: item.view).minY, atTick,
                          "and the next tick brings it forward")
    }

    func test_duringAProgrammaticScroll_presentedFrameFollowsTheViewportTrack() {
        let (f, _) = fixture()
        f.listView.applyChanges(scrollTo: .init(index: 60, pointOffset: 0), transition: .easeInOut(duration: 0))
        f.listView.applyChanges(scrollTo: .init(index: 66, pointOffset: 0), transition: .easeInOut(duration: 0.3))
        XCTAssertGreaterThan(abs(f.viewportCorrection), 1, "precondition: a viewport track must be live")

        let item = f.activeWindow.items[3]
        XCTAssertEqual(f.listView.presentedFrame(of: item.view).minY, expectedScreenY(f, item), accuracy: 0.5)
    }

    func test_afterTheFlightSettles_presentedFrameEqualsConvertAgain() {
        let (f, _) = fixture()
        f.listView.applyChanges(scrollTo: .init(index: 60, pointOffset: 0), transition: .easeInOut(duration: 0))
        f.simulateFlick(offsetVelocity: 3000)
        var ticks = 0
        while f.engine.isDecelerating && ticks < 900 {
            f.tick(dt: 1.0 / 120)
            ticks += 1
        }
        XCTAssertFalse(f.engine.isDecelerating)

        let item = f.activeWindow.items[3]
        let converted = f.listView.convert(item.view.bounds, from: item.view)
        XCTAssertEqual(f.listView.presentedFrame(of: item.view).minY, converted.minY, accuracy: 0.001)
    }
}
