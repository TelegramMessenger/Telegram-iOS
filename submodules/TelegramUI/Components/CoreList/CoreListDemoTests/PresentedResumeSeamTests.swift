import XCTest
import UIKit
@testable import CoreListDemo

/// The seam between a GROWING row's bottom and the top of the row below it, measured on the render
/// server while passes re-target in flight — the shape a streaming chat message makes.
///
/// That seam is the sum of two animated properties from two owners: the growing row's `.height` and
/// the follower's (or the grower's own) `.positionY`. It is exact in the analytic model at every
/// phase, so **every other suite in this project is blind to it** — `VirtualListFixture` never enters
/// a render tree, `presentation()` is nil, and both properties take the analytic path and agree
/// trivially. It needs a window on a real scene AND `emitsCA: true`.
///
/// It went wrong when the two resumed from DIFFERENT bases. `.height` resumes from the screen (the
/// chat's hosted item node sets its own box from `presentation()`, so the row and the node diverged
/// one-signed up to 3.2pt per streamed token); `.positionY` resumed from the analytic model, which
/// leads the screen by the commit delay δ. Each re-target then moved position to a value δ×velocity
/// ahead while height stayed where the screen was, and the difference accumulated: measured −1.885pt
/// over ten 20pt growth steps at 50ms intervals under a 300ms curve, reported from the device as
/// micro-wobble at the boundary of a streaming bubble.
final class PresentedResumeSeamTests: XCTestCase {
    private func makeRenderingWindow() throws -> UIWindow {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "no UIWindowScene in the test host; this test needs a rendering window")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
        window.makeKeyAndVisible()
        return window
    }

    private func presentedFrame(_ view: UIView) -> CGRect {
        (view.layer.presentation() ?? view.layer).frame
    }

    /// Ten growth steps arriving every 50ms under a 300ms curve, so every pass re-targets both
    /// properties mid-flight. The two rows share a container, so their relative geometry is immune to
    /// whatever the viewport is doing.
    func testTheSeamBelowAGrowingRowHoldsAcrossReTargets() throws {
        let window = try makeRenderingWindow()
        let growerId = UUID()
        let followerId = UUID()
        let history: [CoreListItem] = (0..<20).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: 50)
        }
        func items(growerHeight: CGFloat) -> [CoreListItem] {
            [ContentResizableItem(id: growerId, contentHeight: growerHeight),
             IdentifiableFixedHeightItem(id: followerId, height: 60)] + history
        }

        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 400),
                                         items: items(growerHeight: 100),
                                         mediaTime: { CACurrentMediaTime() },
                                         emitsCA: true)
        window.addSubview(fixture.listView)
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        let grower = try XCTUnwrap(fixture.view(identity: growerId))
        let follower = try XCTUnwrap(fixture.view(identity: followerId))
        XCTAssertEqual(presentedFrame(grower).maxY, presentedFrame(follower).minY, accuracy: 1e-6,
                       "precondition: the rows meet exactly before anything animates")

        var height: CGFloat = 100
        for step in 0..<10 {
            height += 20
            fixture.listView.applyChanges(items: items(growerHeight: height),
                                          transition: .easeInOut(duration: 0.3))
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))

            XCTAssertEqual(presentedFrame(grower).maxY, presentedFrame(follower).minY, accuracy: 0.05,
                           "step \(step): the rendered seam must not open — position and height have "
                           + "to resume from the same base, or their sum loses δ×velocity per pass")
        }
    }

    /// The reported shape: a bottom-edge pin, released, the user parked inside the slack region, and a
    /// reply streaming below them. The growth is absorbed by the retreating slack, so the pinned row
    /// does not move at all — which puts the position track on the GROWER instead of the follower, and
    /// makes the seam the sum of two properties on ONE layer.
    ///
    /// Same defect, milder: measured 1.885pt over these ten steps against ~24pt without a pin, because
    /// absorption leaves the follower nothing to travel.
    func testTheSeamHoldsUnderAnAbsorbedStreamingGrowth() throws {
        let window = try makeRenderingWindow()
        let replyId = UUID()
        let pinnedId = UUID()
        let viewport = CGSize(width: 390, height: 400)
        let history: [CoreListItem] = (0..<20).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: 50)
        }
        func items(replyHeight: CGFloat, pinned: Bool) -> [CoreListItem] {
            [ContentResizableItem(id: replyId, contentHeight: replyHeight),
             pinned ? PinnedFixedHeightItem(id: pinnedId, height: 60)
                    : IdentifiableFixedHeightItem(id: pinnedId, height: 60)] + history
        }

        let fixture = VirtualListFixture(viewport: viewport,
                                         items: items(replyHeight: 100, pinned: false),
                                         mediaTime: { CACurrentMediaTime() },
                                         emitsCA: true)
        window.addSubview(fixture.listView)
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        fixture.listView.applyChanges(items: items(replyHeight: 100, pinned: true),
                                      transition: .easeInOut(duration: 0))
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: 1) { height, _ in
                let ext = max(0, height - viewport.height * 0.5)
                return viewport.height + ext - height
            },
            transition: .easeInOut(duration: 0))
        fixture.beginUserDrag()      // releases the latch
        fixture.scroll(to: -100)     // parked 140 short of the -240 edge
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        let reply = try XCTUnwrap(fixture.view(identity: replyId))
        let pinned = try XCTUnwrap(fixture.view(identity: pinnedId))

        var height: CGFloat = 100
        for step in 0..<10 {
            height += 20
            fixture.listView.applyChanges(items: items(replyHeight: height, pinned: true),
                                          transition: .easeInOut(duration: 0.3))
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))

            XCTAssertEqual(presentedFrame(reply).maxY, presentedFrame(pinned).minY, accuracy: 0.05,
                           "step \(step): the streaming reply must meet the pinned row exactly")
        }
    }
}
