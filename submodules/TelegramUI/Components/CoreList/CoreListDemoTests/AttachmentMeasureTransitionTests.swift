import UIKit
import XCTest
@testable import CoreListDemo

/// Attachments go through `attachmentMeasureTransition(serial:isFreshView:)`, the sibling of a row's
/// `measureTransition(forItemAt:view:)`, and it has to answer the same question: does this attachment
/// have to re-lay-out, and does it have a prior layout to animate from.
///
/// Two bugs are pinned here. The predicate was content-only, so a pass that changed `contentWidth`
/// re-measured every attachment at a new width with `.immediate` — and a chat date pill CENTRES in
/// `contentWidth`, so a side inset moves it: it snapped across while every row animated. And
/// `reconciledAttachmentSerials` was never cleared despite its comment claiming it was "cleared with
/// [reconciledIdentities] at the end of each pass", so any attachment that reconciled once measured
/// with the pass transition on every later animated pass, forever.
final class AttachmentMeasureTransitionTests: XCTestCase {
    private func items(count: Int = 12,
                      groupSize: Int = 4,
                      label: String = "a",
                      keyPrefix: String = "key") -> [CoreListItem] {
        (0..<count).map { index in
            let group = index / groupSize
            return AttachedItem(id: index,
                                height: 50,
                                attachedItems: ["\(keyPrefix)\(group)": FixedHeightAttachment(
                                    label: "\(label)\(group)",
                                    height: 30,
                                    placement: .overlay,
                                    edge: .top,
                                    isFloating: true)])
        }
    }

    private func attachmentViews(_ fixture: VirtualListFixture) -> [FixedHeightAttachmentView] {
        fixture.activeWindow.attachments.compactMap { $0.view as? FixedHeightAttachmentView }
    }

    private func makeFixture() -> VirtualListFixture {
        VirtualListFixture(viewport: CGSize(width: 390, height: 400), items: items())
    }

    // MARK: - The width case

    func testHorizontalInsetChangeMeasuresAttachmentsWithThePassTransition() {
        let fixture = makeFixture()
        XCTAssertFalse(attachmentViews(fixture).isEmpty, "precondition: attachments are loaded")

        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                      transition: .linear(duration: 0.3))

        for view in attachmentViews(fixture) {
            XCTAssertEqual(view.lastMeasureTransition?.animation, .curve(duration: 0.3, curve: .linear),
                           "an attachment re-measured at a new width must animate its internals")
        }
    }

    func testVerticalInsetChangeLeavesAttachmentsImmediate() {
        let fixture = makeFixture()

        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 120, left: 0, bottom: 0, right: 0),
                                      transition: .linear(duration: 0.3))

        for view in attachmentViews(fixture) {
            XCTAssertEqual(view.lastMeasureTransition?.isImmediate, true,
                           "a vertical-only inset leaves contentWidth alone, so nothing re-lays-out")
        }
    }

    // MARK: - The stale-reconciliation case

    func testReconciledAttachmentDoesNotKeepAnimatingOnLaterPasses() {
        let fixture = makeFixture()

        // Pass 1: change the attachment content, so its serial reconciles.
        fixture.listView.applyChanges(items: items(label: "b"), transition: .linear(duration: 0.3))
        XCTAssertEqual(attachmentViews(fixture).first?.lastMeasureTransition?.animation,
                       .curve(duration: 0.3, curve: .linear),
                       "precondition: a reconciled attachment measures with the pass transition")

        // Pass 2: nothing about the attachments changed, and the width is untouched.
        fixture.listView.applyChanges(items: items(label: "b"), transition: .linear(duration: 0.3))

        for view in attachmentViews(fixture) {
            XCTAssertEqual(view.lastMeasureTransition?.isImmediate, true,
                           "reconciliation must not persist past the pass that caused it")
        }
    }

    // MARK: - Controls

    func testFreshAttachmentViewInAWidthChangingPassIsStillImmediate() {
        // Changing the run KEY departs every old run and mints new serials, so `viewBySerial` finds no
        // reuse and every attachment view in this pass is freshly created — while the same pass also
        // changes the width. Exactly the collision the fresh guard has to win.
        //
        // The list must be NON-EMPTY for this to test anything: with an empty window `applyChanges`
        // installs the new geometry early (CoreVirtualListView.swift:805-806), before
        // `contentWidthChangedInPass` is computed, so the flag reads false and the assertion would
        // hold for the wrong reason.
        let fixture = makeFixture()
        let before = Set(attachmentViews(fixture).map(ObjectIdentifier.init))
        XCTAssertFalse(before.isEmpty, "precondition: the list already has attachment views")

        fixture.listView.applyChanges(items: items(keyPrefix: "other"),
                                      newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                      transition: .linear(duration: 0.3))

        let views = attachmentViews(fixture)
        XCTAssertFalse(views.isEmpty, "precondition: the pass produced attachment views")
        for view in views {
            XCTAssertFalse(before.contains(ObjectIdentifier(view)), "precondition: view is fresh")
            XCTAssertEqual(view.lastMeasureTransition?.isImmediate, true,
                           "an attachment view created in this pass has nothing to animate from")
        }
    }

    func testUnchangedPassLeavesAttachmentsImmediate() {
        let fixture = makeFixture()

        fixture.listView.applyChanges(items: items(), transition: .linear(duration: 0.3))

        for view in attachmentViews(fixture) {
            XCTAssertEqual(view.lastMeasureTransition?.isImmediate, true)
        }
    }

    // MARK: - Reserving attachments are measured once, not twice

    private func reservingItems(count: Int = 12, groupSize: Int = 4, label: String = "a") -> [CoreListItem] {
        (0..<count).map { index in
            let group = index / groupSize
            return AttachedItem(id: index,
                                height: 50,
                                attachedItems: ["key\(group)": FixedHeightAttachment(
                                    label: "\(label)\(group)",
                                    height: 30,
                                    placement: .reservesSpace,
                                    edge: .top,
                                    isFloating: false)])
        }
    }

    /// A `.reservesSpace` run is measured during stacking, to learn its reserve, and again by
    /// `resolveAttachments`. The stacking probe used to do that on the LIVE view, laying it out at the
    /// target with `.immediate`; the real measure that followed then found every setter already at its
    /// target and, because transition setters early-out on an equal target
    /// (`ComponentTransition.setFrame` returns immediately when `view.frame == frame`), animated
    /// nothing.
    ///
    /// This asserts the INVARIANT — a live view is laid out exactly once per pass — rather than the
    /// animation loss it caused, because the fixture view is a pure recorder with no transition
    /// setters and therefore nothing to early-out. Asserting the count is also the stronger test: it
    /// holds regardless of what a given attachment view does with the transition it is handed.
    func testReservingAttachmentLiveViewIsMeasuredOncePerPass() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 400),
                                         items: reservingItems())
        let views = attachmentViews(fixture)
        XCTAssertFalse(views.isEmpty, "precondition: reserving attachments are loaded")
        let baseline = views.map(\.measureCount)

        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                      transition: .linear(duration: 0.3))

        for (view, before) in zip(attachmentViews(fixture), baseline) {
            XCTAssertEqual(view.measureCount - before, 1,
                           "the stacking probe must not lay out the live view a second time")
        }
    }

    func testReservingAttachmentAnimatesOnAWidthChange() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 400),
                                         items: reservingItems())

        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                      transition: .linear(duration: 0.3))

        for view in attachmentViews(fixture) {
            XCTAssertEqual(view.lastMeasureTransition?.animation, .curve(duration: 0.3, curve: .linear),
                           "a reserving attachment re-measured at a new width must animate too")
        }
    }

    func testReservationHeightIsStillHonoured() {
        // The probe exists to size the reserve. Whatever it measures on must keep producing the same
        // gap, or rows jump.
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: reservingItems(count: 12, groupSize: 4))
        let window = fixture.activeWindow
        let firstOfSecondRun = window.localFrame(for: 4)!.minY
        let lastOfFirstRun = window.localFrame(for: 3)!.maxY
        XCTAssertEqual(firstOfSecondRun - lastOfFirstRun, 30, accuracy: 1e-6,
                       "a new run still reserves its attachment's measured height")
    }
}

// The chat backend's exact `applyChanges` call shape, and the one ordering that defeats the width
// case. Written while chasing "a header attachment measures `.immediate` on an animated side-inset
// pass"; four of the five ingredients turned out to be innocent.
extension AttachmentMeasureTransitionTests {
    private func probeItems() -> [CoreListItem] {
        (0..<12).map { (index: Int) -> CoreListItem in
            let group = index / 4
            return AttachedItem(id: AnyHashable(index),
                                height: 50,
                                attachedItems: [AnyHashable("key\(group)"): FixedHeightAttachment(
                                    label: "a\(group)", height: 30,
                                    placement: .overlay, edge: .top, isFloating: true)])
        }
    }

    private func probeFixture() -> VirtualListFixture {
        VirtualListFixture(viewport: CGSize(width: 390, height: 400), items: probeItems())
    }

    private func firstTransition(_ f: VirtualListFixture) -> CoreListTransition? {
        (f.activeWindow.attachments.first?.view as? FixedHeightAttachmentView)?.lastMeasureTransition
    }

    /// Everything the chat passes, in one call: `newSize` alongside `newInsets`, an explicit
    /// `anchorMode`, a synthesised `scrollTo` (the unread re-pin does this on inset changes), and
    /// `compensatesInsetChange: false` (a drag-driven inset). None of it interferes.
    func testChatShapedInsetPassStillAnimatesAttachments() {
        let f = probeFixture()
        f.listView.applyChanges(newSize: CGSize(width: 390, height: 400),
                                newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                scrollTo: .init(index: 3, pointOffset: 0),
                                anchorMode: .preserveVisibleContent,
                                compensatesInsetChange: false,
                                transition: .linear(duration: 0.3))
        XCTAssertEqual(firstTransition(f)?.isImmediate, false)
    }

    /// CHARACTERIZATION, and a KNOWN LIMIT: `contentWidthChangedInPass` is a per-PASS delta, so
    /// whichever pass carries the width change owns the relayout. A caller that installs a geometry
    /// change in one pass and animates in the next gets a snap, and nothing in `measureTransition` can
    /// recover it — by then the layout is already correct and an animation would be an equal-target
    /// no-op.
    ///
    /// The chat does NOT do this (one `containerLayoutUpdated` submits the inset change and its
    /// animation together, and `contentBounds` is independent of the side panel), so this documents a
    /// constraint on future callers rather than a live defect.
    func testWidthChangeConsumedByAnEarlierImmediatePassIsNotReplayed() {
        let f = probeFixture()
        f.listView.applyChanges(newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                transition: .immediate)
        f.listView.applyChanges(newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                transition: .linear(duration: 0.3))
        XCTAssertEqual(firstTransition(f)?.isImmediate, true,
                       "the second pass changes nothing, so it must not animate")
    }
}
