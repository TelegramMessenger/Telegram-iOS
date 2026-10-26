import XCTest
@testable import CoreListDemo

/// `AttachmentContainerView` spans the whole content area and is the topmost sibling in `contentHost`,
/// so its `point(inside:with:)` decides whether anything below it can be touched at all. It must be a
/// strict passthrough: claim a point only where one of its own attachments would take it.
///
/// The regression these lock down shipped: the override opened with
/// `if super.point(inside:with:) { return true }`, which is true across the container's entire bounds,
/// so `hitTest` returned the container for every point not on an attachment and the chat's message
/// bubbles received no touches. Scrolling kept working — the pan recognizer is on an ancestor, and
/// ancestors see touches regardless of which view hit-testing settles on — which is what let it
/// through.
final class AttachmentContainerHitTestTests: XCTestCase {
    private func makeContainer(attachmentFrame: CGRect,
                               configure: (UIView) -> Void = { _ in }) -> (AttachmentContainerView, UIView) {
        let container = AttachmentContainerView(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        container.clipsToBounds = false
        let attachment = UIView(frame: attachmentFrame)
        configure(attachment)
        container.addSubview(attachment)
        return (container, attachment)
    }

    // MARK: - The passthrough itself

    func testEmptyAreaInsideBoundsIsNotClaimed() {
        let (container, _) = makeContainer(attachmentFrame: CGRect(x: 0, y: 0, width: 390, height: 30))

        // Well inside the container, far from the only attachment: this is where a message bubble is.
        XCTAssertFalse(container.point(inside: CGPoint(x: 195, y: 400), with: nil),
                       "the container must not claim bounds it has no attachment in")
    }

    func testHitTestFallsThroughToASiblingBelow() {
        // The real arrangement: rows underneath, attachment container on top, both full-size.
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let rows = UIView(frame: host.bounds)
        let bubble = UIView(frame: CGRect(x: 20, y: 380, width: 250, height: 60))
        rows.addSubview(bubble)
        host.addSubview(rows)

        let (container, _) = makeContainer(attachmentFrame: CGRect(x: 0, y: 0, width: 390, height: 30))
        host.addSubview(container)

        XCTAssertTrue(host.subviews.last === container, "precondition: attachments are topmost")
        XCTAssertTrue(container.isUserInteractionEnabled,
                      "precondition: the container is interactive, so only point(inside:) protects the rows")

        XCTAssertIdentical(host.hitTest(CGPoint(x: 100, y: 400), with: nil), bubble,
                           "a touch on a row must reach the row, not the attachment container")
    }

    func testAttachmentStillTakesItsOwnTouches() {
        let (container, attachment) = makeContainer(attachmentFrame: CGRect(x: 0, y: 0, width: 390, height: 30))

        XCTAssertTrue(container.point(inside: CGPoint(x: 195, y: 15), with: nil))
        XCTAssertIdentical(container.hitTest(CGPoint(x: 195, y: 15), with: nil), attachment)
    }

    // MARK: - Why the override exists at all

    func testAttachmentRenderedOutsideBoundsIsStillHittable() {
        // The degenerate case the override was written for: a run shorter than its attachment leaves
        // the attachment solved slightly outside the container. `clipsToBounds = false` renders it,
        // but UIKit hit-testing clips to bounds, so the subview scan is what keeps it tappable.
        let (container, attachment) = makeContainer(attachmentFrame: CGRect(x: 0, y: -20, width: 390, height: 30))

        let pointAboveBounds = CGPoint(x: 195, y: -10)
        XCTAssertFalse(container.bounds.contains(pointAboveBounds), "precondition: outside bounds")
        XCTAssertTrue(container.point(inside: pointAboveBounds, with: nil),
                      "an attachment rendered outside the container must still take its taps")
        XCTAssertIdentical(container.hitTest(pointAboveBounds, with: nil), attachment)
    }

    // MARK: - Staying in sync with UIKit's own criteria

    /// A point claimed here that `hitTest` then declines to route into any subview resolves to the
    /// container itself — the same swallowed touch, in a narrower case. So the subview tests must
    /// match the ones UIKit applies when it recurses.
    func testSubviewsUIKitWouldSkipDoNotClaimPoints() {
        for (name, configure) in [
            ("hidden", { (view: UIView) in view.isHidden = true }),
            ("non-interactive", { (view: UIView) in view.isUserInteractionEnabled = false }),
            ("transparent", { (view: UIView) in view.alpha = 0.0 }),
        ] {
            let (container, _) = makeContainer(
                attachmentFrame: CGRect(x: 0, y: 0, width: 390, height: 30),
                configure: configure
            )
            let pointOnAttachment = CGPoint(x: 195, y: 15)

            XCTAssertFalse(container.point(inside: pointOnAttachment, with: nil),
                           "a \(name) attachment must not claim a point UIKit would not route to it")
            XCTAssertNil(container.hitTest(pointOnAttachment, with: nil),
                         "\(name): the container must not become the hit-test result itself")
        }
    }
}
