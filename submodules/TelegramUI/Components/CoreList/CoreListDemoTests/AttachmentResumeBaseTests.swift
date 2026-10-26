import XCTest
import UIKit
@testable import CoreListDemo

/// `presented − model` means "the additive track's contribution" only while the layer's model
/// position is still the base the render tree was committed against. `capturePresentedPositionOffsets`
/// takes the snapshot at pass entry, which guarantees *this* pass has not overwritten it — and that is
/// enough only for owners whose base nothing else writes.
///
/// An attachment is not such an owner. `renderAttachments()` rewrites every attachment's frame on
/// every render, including every user-scroll frame and every per-frame inset pass, because a PARKED
/// attachment's base has to move with the content for it to stay parked on screen. Between two frames
/// `presentation()` therefore lags the model by one frame of base movement, and reading that lag as a
/// contribution makes the next animated pass start one whole frame of displacement away from where the
/// attachment is drawn.
///
/// Measured on device (CoreList chat backend, interactive keyboard dismissal): at the touch-up pass the
/// parked date pill's layer read `model=573.00 presented=515.33` with NO animation keys at all — there
/// was no contribution to read — and the pill snapped 57.66pt before animating into place.
///
/// These need a scene-attached window: every windowless fixture resolves no presentation layer, so the
/// provider returns nil at its guard and the analytic path is taken. See
/// `PresentationResumeSamplingTests.testFixtureLayersHaveNoPresentationLayer`.
final class AttachmentResumeBaseTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 800)
    private let keyboardInsets = UIEdgeInsets(top: 336, left: 0, bottom: 88, right: 0)
    private let midDragInsets = UIEdgeInsets(top: 240, left: 0, bottom: 88, right: 0)
    private let dismissedInsets = UIEdgeInsets(top: 56, left: 0, bottom: 88, right: 0)

    private func makeRenderingWindow() throws -> UIWindow {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "no UIWindowScene in the test host; this test needs a rendering window")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: viewport)
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

    private func renderedY(_ fixture: VirtualListFixture, serial: UInt64) -> CGFloat? {
        guard let settled = fixture.listView.attachmentScreenY(serial: serial) else { return nil }
        let now = fixture.animationController.now()
        let own = fixture.animationController.positionOffset(owner: .attachment(serial),
                                                             at: now) ?? 0
        return settled - fixture.animationController.viewportOffset(at: now) + own
    }

    /// The chat's interactive keyboard dismissal in miniature: per-frame immediate inset passes while
    /// the finger drags (each one moves the parked attachment's base), then one ANIMATED pass at
    /// touch-up. The animated pass must still start from where the attachment is drawn.
    func testAParkedAttachmentDoesNotJumpWhenAnAnimatedPassFollowsAPerFramePass() throws {
        let window = try makeRenderingWindow()
        let items: [CoreListItem] = (0..<120).map { index in
            let group = index / 6
            return AttachedItem(id: index, height: 95, attachedItems: [
                "date\(group)": FixedHeightAttachment(label: "d\(group)", height: 34,
                                                      placement: .overlay, edge: .bottom,
                                                      isFloating: true),
            ])
        }
        let fixture = VirtualListFixture(viewport: viewport, items: items)
        fixture.listView.frame = CGRect(origin: .zero, size: viewport)
        window.addSubview(fixture.listView)
        fixture.listView.applyChanges(newInsets: keyboardInsets, transition: .easeInOut(duration: 0))
        window.layoutIfNeeded()
        settle()

        // A parked attachment is the one that has to be checked: its base moves every frame, while a
        // riding one keeps the same container-local frame from pass to pass.
        // Parked means sitting ON the display anchor — `y == anchorInFrameSpace`, the segment whose
        // slope in the offset is +1, which is what makes the base move with the content. A stick
        // distance alone does not say that: an attachment clamped to its band edge also reports one,
        // and its frame-space y is constant.
        let parked = try XCTUnwrap(
            fixture.activeWindow.attachments.first { attachment in
                let map = fixture.listView.attachmentMap(attachment, window: fixture.activeWindow)
                let offset = fixture.driver.engine.offset
                return abs(map.y(atOffset: offset) - map.anchorInFrameSpace(atOffset: offset)) < 0.5
            }?.serial,
            "precondition: some attachment must be parked on the display anchor")
        let parkedLayer = try XCTUnwrap(
            fixture.activeWindow.attachments.first(where: { $0.serial == parked })).view.layer
        XCTAssertNotNil(parkedLayer.presentation(),
                        "precondition: the layer must be in a render tree, or the provider is never "
                          + "reached and this test passes vacuously")

        // One drag frame: immediate, so it settles at once and moves the attachment's model base —
        // and deliberately NOT settled, so `presentation()` still holds the previous base, exactly as
        // it does between two frames of a real drag.
        fixture.listView.applyChanges(newInsets: midDragInsets,
                                      transition: .easeInOut(duration: 0))
        let lag = try XCTUnwrap(parkedLayer.presentation()).position.y - parkedLayer.position.y
        XCTAssertGreaterThan(abs(lag), 1.0,
                             "precondition: the render tree must still hold the previous base, or "
                               + "there is no stale offset to misread")

        let before = try XCTUnwrap(renderedY(fixture, serial: parked))

        // Touch-up: the animated pass.
        fixture.listView.applyChanges(newInsets: dismissedInsets,
                                      transition: .easeInOut(duration: 0.4))

        XCTAssertEqual(try XCTUnwrap(renderedY(fixture, serial: parked)), before, accuracy: 0.5,
                       "the parked attachment must start its animation from where it is drawn; a "
                         + "delta here is the stale presented base being read as a live correction")
    }

    /// The same statement at the seam, so a failure names the mechanism rather than a coordinate: an
    /// attachment's base is not pass-written, so nothing may be captured for it.
    func testNoPresentedPositionBaseIsCapturedForAnAttachment() throws {
        let window = try makeRenderingWindow()
        let items: [CoreListItem] = (0..<40).map { index -> CoreListItem in
            let group = index / 6
            return AttachedItem(id: index, height: 95, attachedItems: [
                "date\(group)": FixedHeightAttachment(label: "d\(group)", height: 34,
                                                      placement: .overlay, edge: .bottom,
                                                      isFloating: true),
            ])
        }
        let fixture = VirtualListFixture(viewport: viewport, items: items)
        fixture.listView.frame = CGRect(origin: .zero, size: viewport)
        window.addSubview(fixture.listView)
        window.layoutIfNeeded()
        settle()

        let serial = try XCTUnwrap(fixture.activeWindow.attachments.first?.serial)
        let rowIdentity = try XCTUnwrap(fixture.activeWindow.items.first.map {
            fixture.listView.items[$0.index].identity
        })

        fixture.animationController.capturePresentedPositionOffsets()
        XCTAssertNil(fixture.animationController.capturedPresentedPositionOffset(
            owner: .attachment(serial)),
                     "an attachment's base is rewritten by every render, so `presented − model` is a "
                       + "frame of base movement rather than a track contribution")
        XCTAssertNotNil(fixture.animationController.capturedPresentedPositionOffset(
            owner: .live(rowIdentity)),
                        "a row's base IS pass-written, and must keep resuming from the screen")
    }
}
