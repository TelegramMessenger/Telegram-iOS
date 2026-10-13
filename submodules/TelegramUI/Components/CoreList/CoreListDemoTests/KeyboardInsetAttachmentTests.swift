import XCTest
import UIKit
@testable import CoreListDemo

/// The chat's keyboard dismissal, expressed as CoreList sees it: an ANIMATED top-inset change on a
/// list resting at its loaded top, with floating attachments at both edges.
///
/// Device report (CoreList chat backend): dismissing the keyboard or the emoji keyboard makes the
/// gutter avatars and date pills "snap down once, then animate to their positions" while the rows
/// beside them animate correctly.
///
/// The two edges answer two different questions and both are here:
///   - a `.top`-edge attachment (the chat's gutter avatar, `stickDirection == .top` when rotated)
///     anchors on `insets.top`, so the inset change moves its parked position;
///   - a `.bottom`-edge attachment (the date pill) anchors on `logicalHeight - insets.bottom`, which
///     the keyboard does not touch, so its parked position must hold still.
final class KeyboardInsetAttachmentTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 800)
    /// Input panel + keyboard, the chat's `listInsets.top` with a keyboard up.
    private let keyboardInsets = UIEdgeInsets(top: 336, left: 0, bottom: 88, right: 0)
    /// The same chat with the keyboard gone.
    private let dismissedInsets = UIEdgeInsets(top: 56, left: 0, bottom: 88, right: 0)

    private func makeFixture() -> VirtualListFixture {
        let items: [CoreListItem] = (0..<120).map { index in
            let group = index / 6
            return AttachedItem(id: index, height: 95, attachedItems: [
                "date\(group)": FixedHeightAttachment(label: "d\(group)", height: 34,
                                                      placement: .overlay, edge: .bottom,
                                                      isFloating: true),
                "avatar\(group)": FixedHeightAttachment(label: "a\(group)", height: 32,
                                                        placement: .overlay, edge: .top,
                                                        isFloating: true),
            ])
        }
        let fixture = VirtualListFixture(viewport: viewport, items: items)
        fixture.listView.applyChanges(newInsets: keyboardInsets, transition: .easeInOut(duration: 0))
        return fixture
    }

    /// Where an attachment is DRAWN right now: its settled solve, less the shared viewport track's
    /// current displacement (it rides inside `contentHost`), plus its own additive position track.
    private func renderedY(_ fixture: VirtualListFixture, serial: UInt64) -> CGFloat? {
        guard let settled = fixture.listView.attachmentScreenY(serial: serial) else { return nil }
        let now = fixture.animationController.now()
        let own = fixture.animationController.positionOffset(owner: .attachment(serial),
                                                             at: now) ?? 0
        return settled - fixture.animationController.viewportOffset(at: now) + own
    }

    private func renderedRowY(_ fixture: VirtualListFixture, identity: AnyHashable) -> CGFloat? {
        guard let settled = fixture.settledScreenY(identity: identity) else { return nil }
        let offset = fixture.animationController.positionOffset(
            identity: identity, at: fixture.animationController.now()) ?? 0
        return settled + offset
    }

    /// The frame CoreList actually wrote on the attachment's view, in screen space — the model value
    /// the additive tracks ride on. Divergence from `renderedY` minus the tracks means the pass wrote
    /// a frame it did not account for.
    private func writtenFrameScreenY(_ fixture: VirtualListFixture, serial: UInt64) -> CGFloat? {
        guard let attachment = fixture.activeWindow.attachments
            .first(where: { $0.serial == serial })
        else { return nil }
        return fixture.listView.container.frame.origin.y
            + attachment.view.frame.minY
            - fixture.driver.engine.offset
    }

    // MARK: -

    /// Nothing may jump at the moment the pass lands: every attachment must be drawn exactly where it
    /// was drawn a moment earlier, and then travel on the pass curve.
    func testAttachmentsDoNotJumpWhenTheKeyboardInsetChanges() throws {
        let fixture = makeFixture()
        let serials = fixture.activeWindow.attachments.map(\.serial)
        XCTAssertFalse(serials.isEmpty, "precondition: attachments must be loaded")

        let before = try serials.map { serial in
            (serial, try XCTUnwrap(renderedY(fixture, serial: serial)))
        }
        let probeRow = fixture.listView.items[2].identity
        let rowBefore = try XCTUnwrap(renderedRowY(fixture, identity: probeRow))

        fixture.listView.applyChanges(newInsets: dismissedInsets,
                                      transition: .easeInOut(duration: 0.5))

        // Non-vacuity: the pass must actually move content, and at least one attachment must be
        // parked (needing a counter-track) rather than every one of them riding.
        let viewportFrom = try XCTUnwrap(fixture.viewportTrack?.from,
                                         "precondition: the inset change must displace the viewport")
        XCTAssertEqual(abs(viewportFrom), 280, accuracy: 1.0,
                       "precondition: the displacement is the whole inset delta")
        XCTAssertTrue(
            serials.contains { serial in
                (fixture.animationController.model.track(for: .attachment(serial),
                                                         property: .positionY)?.from ?? 0) != 0
            },
            "precondition: at least one attachment must counter the viewport displacement")

        // The rows are the control: they are reported as animating correctly on the device.
        XCTAssertEqual(try XCTUnwrap(renderedRowY(fixture, identity: probeRow)), rowBefore,
                       accuracy: 0.5,
                       "control: a row must not jump at the pass boundary")

        for (serial, renderedBefore) in before {
            guard let renderedAfter = renderedY(fixture, serial: serial) else { continue }
            XCTAssertEqual(renderedAfter, renderedBefore, accuracy: 0.5,
                           "attachment \(serial) jumped \(renderedAfter - renderedBefore)pt at the "
                             + "pass boundary")
        }
    }

    /// The written frame and the model's account of it must agree — a frame written outside the
    /// tracks' accounting is a snap no track can undo.
    func testTheWrittenAttachmentFrameMatchesTheModelsSettledPosition() throws {
        let fixture = makeFixture()
        let serials = fixture.activeWindow.attachments.map(\.serial)

        fixture.listView.applyChanges(newInsets: dismissedInsets,
                                      transition: .easeInOut(duration: 0.5))

        for serial in serials {
            guard let written = writtenFrameScreenY(fixture, serial: serial),
                  let settled = fixture.listView.attachmentScreenY(serial: serial)
            else { continue }
            XCTAssertEqual(written, settled, accuracy: 0.5,
                           "attachment \(serial): the written frame and the settled solve disagree")
        }
    }

    /// And it must LAND: once the pass duration has elapsed every attachment sits at its settled
    /// solve, with no correction left over.
    func testAttachmentsLandOnTheirSettledPositions() throws {
        let fixture = makeFixture()
        fixture.listView.applyChanges(newInsets: dismissedInsets,
                                      transition: .easeInOut(duration: 0.5))
        fixture.driver.tick(dt: 0.6)

        for attachment in fixture.activeWindow.attachments {
            let settled = try XCTUnwrap(
                fixture.listView.attachmentScreenY(serial: attachment.serial))
            XCTAssertEqual(try XCTUnwrap(renderedY(fixture, serial: attachment.serial)), settled,
                           accuracy: 0.5,
                           "attachment \(attachment.serial) did not land on its settled position")
        }
    }

    /// The same pass while the user's finger is on the list — the interactive keyboard drag, where the
    /// backend passes `compensatesInsetChange: false`.
    func testAttachmentsDoNotJumpWhenCompensationIsSuppressed() throws {
        let fixture = makeFixture()
        let serials = fixture.activeWindow.attachments.map(\.serial)
        let before = try serials.map { serial in
            (serial, try XCTUnwrap(renderedY(fixture, serial: serial)))
        }

        fixture.listView.applyChanges(newInsets: dismissedInsets,
                                      compensatesInsetChange: false,
                                      transition: .easeInOut(duration: 0.5))

        for (serial, renderedBefore) in before {
            guard let renderedAfter = renderedY(fixture, serial: serial) else { continue }
            XCTAssertEqual(renderedAfter, renderedBefore, accuracy: 0.5,
                           "attachment \(serial) jumped \(renderedAfter - renderedBefore)pt under "
                             + "suppressed compensation")
        }
    }

    /// Mid-collection, where the loaded top is not at the edge and the pin plays no part.
    func testAttachmentsDoNotJumpWhenScrolledIntoHistory() throws {
        let fixture = makeFixture()
        fixture.scroll(to: 900)
        let serials = fixture.activeWindow.attachments.map(\.serial)
        let before = try serials.map { serial in
            (serial, try XCTUnwrap(renderedY(fixture, serial: serial)))
        }

        fixture.listView.applyChanges(newInsets: dismissedInsets,
                                      transition: .easeInOut(duration: 0.5))

        for (serial, renderedBefore) in before {
            guard let renderedAfter = renderedY(fixture, serial: serial) else { continue }
            XCTAssertEqual(renderedAfter, renderedBefore, accuracy: 0.5,
                           "attachment \(serial) jumped \(renderedAfter - renderedBefore)pt at the "
                             + "pass boundary while scrolled into history")
        }
    }
}
