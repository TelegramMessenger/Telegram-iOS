import XCTest
import UIKit
@testable import CoreListDemo

/// A position track must start at the difference between where the row is RENDERED and where it will
/// settle — one displacement, never two.
///
/// For one build `.positionY` resumed from `presentation().position.y - layer.position.y`, which is
/// the additive contribution only while the layer's MODEL position still holds the value the render
/// tree was committed at. It does not, at the point the provider is asked: `render()` writes every
/// window item's new settled frame (`CoreVirtualListView.swift:2870`) and the transitions install ~550
/// lines later (`:2022`). So the provider measured against the pass's NEW settled position while
/// `transitionPositionOffset` added it back onto `oldSettledY`, counting the pass's own displacement
/// twice: every row below a growing one snapped a whole growth backwards before animating into place.
///
/// These lock the arithmetic rather than the mechanism, so they stay honest if a later change resumes
/// positions from the screen properly — by hoisting the sample to before `render()`, the order
/// `CoreListTransition.setPositionY` (`Transition/CoreListTransition.swift:178`) already uses.
final class PresentedPositionResumeBaseTests: XCTestCase {
    /// A window on the test host's scene, so its layers enter the render tree and resolve a
    /// presentation layer at all (a scene-less `UIWindow` never does — see
    /// `PresentationResumeSamplingTests.testFixtureLayersHaveNoPresentationLayer`).
    private func makeRenderingWindow() throws -> UIWindow {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "no UIWindowScene in the test host; this test needs a rendering window")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
        window.makeKeyAndVisible()
        return window
    }

    private func settle() {
        CATransaction.flush()
        let deadline = Date().addingTimeInterval(0.1)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    // MARK: - The seam

    /// One layer, no animation in flight, one 100pt displacement. The additive track must start at
    /// -100: the row is rendered 100pt above where it will settle.
    func testPositionResumesFromTheRenderedBaseNotThePassesNewSettledPosition() throws {
        let window = try makeRenderingWindow()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 40))
        host.layer.anchorPoint = CGPoint(x: 0, y: 0)
        host.layer.position = CGPoint(x: 0, y: 0)
        window.addSubview(host)
        window.layoutIfNeeded()
        settle()

        let presented = try XCTUnwrap(host.layer.presentation())
        XCTAssertEqual(presented.position.y, 0, accuracy: 0.5,
                       "precondition: the render tree holds the OLD settled position")

        // What `render()` does, before any transition installs.
        host.layer.position.y = 100

        let controller = ListAnimationController()
        let identity = AnyHashable(UUID())
        controller.transitionPosition(identity: identity,
                                      layer: host.layer,
                                      oldSettledY: 0,
                                      newSettledY: 100,
                                      transition: .linear(duration: 0.3))

        let track = try XCTUnwrap(
            controller.model.track(for: .live(identity), property: .positionY))
        XCTAssertEqual(track.from, -100, accuracy: 1e-6,
                       "the pass displacement was counted twice: the row snaps a further 100pt back "
                       + "before animating")
        XCTAssertEqual(track.to, 0, accuracy: 1e-6)
    }

    // MARK: - End to end

    /// The user-visible shape of the same defect: one row grows, and the rows below it snap backwards
    /// by the growth before animating into place.
    ///
    /// `emitsCA: false` keeps this deterministic — nothing is animating, so `presentation()` is
    /// exactly the last committed model value and the correct `from` is exactly `-growth`.
    func testRowsBelowAGrowingRowResumeFromWhereTheyAreRendered() throws {
        let window = try makeRenderingWindow()
        let ids = (0..<12).map { _ in UUID() }
        let items = ids.map { ContentResizableItem(id: $0, contentHeight: 50) }
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 400),
                                         items: items)
        window.addSubview(fixture.listView)
        window.layoutIfNeeded()
        settle()

        let follower = AnyHashable(ids[1])
        let followerLayer = try XCTUnwrap(fixture.view(identity: follower)).layer
        XCTAssertEqual(try XCTUnwrap(followerLayer.presentation()).position.y,
                       followerLayer.position.y, accuracy: 0.5,
                       "precondition: the render tree is caught up with the model")

        var grown = items
        grown[0] = ContentResizableItem(id: ids[0], contentHeight: 150)
        fixture.listView.applyChanges(items: grown, transition: .linear(duration: 0.3))

        let track = try XCTUnwrap(fixture.positionTrack(identity: follower),
                                  "the row below the growth must animate its position")
        XCTAssertEqual(track.from, -100, accuracy: 1e-6,
                       "row 1 is rendered 100pt above its new settled position, so the additive "
                       + "track must start at -100; -200 means it snaps a further 100pt back first")
    }
}
