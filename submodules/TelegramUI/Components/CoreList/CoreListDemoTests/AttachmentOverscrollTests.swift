import XCTest
@testable import CoreListDemo

/// A mutation pass that lands while the list is presented in rubber-band overscroll.
///
/// Rubber-band displacement is presentation-only: the pass resolves its window against the offset
/// CLAMPED to the loaded edges, then restores the displacement on top. Rows are immune, because their
/// frames are container-local and offset-independent — the restore moves the container and every row
/// with it. An attachment's settled position is NOT offset-independent: the solve consumes the offset,
/// so an attachment must be snapshotted at the offset it was PRESENTED at, not the clamped one.
///
/// Getting that wrong does not move the settled endpoint, so it is invisible at rest and to every
/// settled-geometry assertion. It corrupts only the transition's STARTING point: the attachment jumps
/// by the overscroll residual and eases back over the pass duration. Reported from the demo as "scroll
/// into the rubber-band area, wait for it to settle, then spamming Swap makes the first header drift
/// upwards, then it corrects itself" — a bounce settles carrying a fractional residual (0.33pt
/// measured on the K2 simulator), and every subsequent pass replays that jump.
///
/// The physics fixture is the one that can express this: its core is clampless, whereas the
/// UIScrollView-backed fixture has overscroll writes clamped back to the edge by UIKit.
final class AttachmentOverscrollTests: XCTestCase {
    /// 20 rows of 50pt in an 800pt viewport, grouped in 5s, each group its own key — the same shape
    /// `AttachmentGeometryTests` uses.
    private func groupedItems(count: Int = 20, groupSize: Int = 5) -> [CoreListItem] {
        (0..<count).map { index in
            let group = index / groupSize
            return AttachedItem(id: index,
                                height: 50,
                                attachedItems: ["date\(group)": FixedHeightAttachment(
                                    label: "group\(group)",
                                    height: 30,
                                    placement: .overlay,
                                    edge: .top,
                                    isFloating: true)])
        }
    }

    /// Where the attachment is actually drawn: its settled screen position plus whatever analytic
    /// correction is in force.
    private func presentedY(_ fixture: PhysicsListFixture, serial: UInt64) -> CGFloat? {
        guard let settled = fixture.listView.attachmentScreenY(serial: serial) else { return nil }
        let correction = fixture.animationController.positionOffset(
            owner: .attachment(serial),
            at: fixture.animationController.now()) ?? 0
        return settled + correction
    }

    /// Park the list past its top edge, the way a settled rubber-band bounce leaves it.
    private func overscrolledFixture(by residual: CGFloat)
        -> (fixture: PhysicsListFixture, serial: UInt64) {
        let fixture = PhysicsListFixture(items: groupedItems())
        let serial = fixture.activeWindow.attachments.first!.serial
        fixture.engine.setOffset(fixture.offset - residual)
        return (fixture, serial)
    }

    func testMutationInOverscrollDoesNotJumpAParkedAttachment() {
        let (fixture, serial) = overscrolledFixture(by: 8)

        let before = presentedY(fixture, serial: serial)
        XCTAssertNotNil(before)

        // A reorder inside a LATER group: it changes nothing about this run's own band, so this
        // attachment's settled position is genuinely unchanged and any motion at all is pure error.
        var items = fixture.listView.items
        items.swapAt(11, 13)
        fixture.listView.applyChanges(items: items, transition: .linear(duration: 0.3))

        let after = presentedY(fixture, serial: serial)
        XCTAssertNotNil(after)
        XCTAssertEqual(after!, before!, accuracy: 1e-6,
                       "an attachment must not jump at a pass boundary taken in overscroll")
    }

    /// The same defect stated as a track property: with the attachment's settled place unchanged, the
    /// pass must be an exact no-op rather than a correction worth the overscroll residual.
    func testMutationInOverscrollInstallsNoSpuriousAttachmentTrack() {
        let (fixture, serial) = overscrolledFixture(by: 8)

        var items = fixture.listView.items
        items.swapAt(11, 13)
        fixture.listView.applyChanges(items: items, transition: .linear(duration: 0.3))

        if let track = fixture.animationController.model.track(for: .attachment(serial),
                                                               property: .positionY) {
            XCTAssertEqual(track.from, 0, accuracy: 1e-6,
                           "an unchanged attachment must not be corrected by the overscroll residual")
        }
    }

    /// The fractional residual actually measured in the demo, which is what made this read as a
    /// jitter rather than a jump.
    func testSubPointOverscrollResidualIsAlsoExact() {
        let (fixture, serial) = overscrolledFixture(by: 0.33)

        let before = presentedY(fixture, serial: serial)
        var items = fixture.listView.items
        items.swapAt(11, 13)
        fixture.listView.applyChanges(items: items, transition: .linear(duration: 0.3))

        XCTAssertEqual(presentedY(fixture, serial: serial)!, before!, accuracy: 1e-6)
    }
}
