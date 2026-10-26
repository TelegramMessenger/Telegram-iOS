import XCTest
@testable import CoreListDemo

/// Regression tests for: attachments (especially `.bottom`) snapping under Chaos and rapid
/// insert/remove.
///
/// Root cause was demo DATA, not the engine. The demo derives attachment keys from `groupIndex`, and
/// every item factory omitted it — so an inserted row defaulted to group 0, landed in the middle of
/// another group's run, SPLIT that run, and dropped a stray one-row run between the halves. The
/// non-witness half then took a fresh serial and a fresh view, which appears instantly. That is what
/// "the header snapped" looked like.
final class AttachmentSnapReproTests: XCTestCase {
    /// Number of distinct attachment serials born across a sequence of inserts. A run that survives
    /// keeps its serial and animates; a churned run gets a fresh one.
    private func serialChurn(insertedGroupIndex: (Int, [DemoListItem]) -> Int) -> Int {
        var items: [DemoListItem] = DemoListItem.makeItems(count: 60, groupSize: 6)
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: items.map { $0 as CoreListItem })
        var seen = Set(fixture.activeWindow.attachments.map(\.serial))

        for step in 0..<10 {
            let position = min(items.count, 8 + step)
            items.insert(DemoListItem(id: UUID(),
                                      title: "Inserted \(step)",
                                      detail: "",
                                      accentColor: .systemPink,
                                      groupIndex: insertedGroupIndex(position, items)),
                         at: position)
            fixture.apply(items.map { $0 as CoreListItem }, duration: 0.3)
            seen.formUnion(fixture.activeWindow.attachments.map(\.serial))
        }
        return seen.count
    }

    /// A row that JOINS the run it lands in must not churn serials the way a group-0 default does.
    /// This is the property every demo item factory now upholds; regressing any of them reintroduces
    /// the snapping.
    func testJoiningTheLandingRunChurnsFewerSerialsThanDefaultingToGroupZero() {
        let churnWithDefault = serialChurn { _, _ in 0 }
        let churnWhenJoining = serialChurn { position, items in
            let clamped = min(max(position, 0), items.count - 1)
            return items[clamped].groupIndex
        }

        XCTAssertLessThan(
            churnWhenJoining, churnWithDefault,
            "an insert that joins its landing run must churn fewer attachment serials than one "
                + "defaulted to group 0, which splits the run it lands in"
        )
    }

    /// `Load +5` from the DEFAULT state: prepend rows under `.preserveVisibleContent`. That drops the
    /// list out of "top loaded", so the engine rebases onto its private virtual canvas and
    /// `containerOriginY` jumps by ~5,000,000. Every attachment's SCREEN position is unchanged, so
    /// none of them may animate — a track here means the pass compared coordinates across two
    /// different bases.
    ///
    /// Starting at the top matters: scrolled into the middle the window stays in one base, the delta
    /// is zero, and the defect is invisible. That is exactly why two earlier repros of this bug
    /// passed.
    func testPrependingUnderPreserveVisibleContentDoesNotAnimateAttachments() {
        var items: [CoreListItem] = (0..<180).map { index in
            let group = index / 6
            return AttachedItem(id: index, height: 95,
                                attachedItems: ["date\(group)": FixedHeightAttachment(
                                    label: "g\(group)", height: 34,
                                    placement: .overlay, edge: .top, isFloating: true)])
        }
        let fixture = VirtualListFixture(viewport: CGSize(width: 393, height: 852), items: items)

        let before = fixture.activeWindow.attachments.map {
            ($0.serial, fixture.listView.attachmentScreenY(serial: $0.serial)!)
        }
        XCTAssertFalse(before.isEmpty, "precondition: attachments must be loaded")

        // Five new rows keyed to the SAME group as the current row 0, exactly as `Load +5` does.
        let loaded: [CoreListItem] = (0..<5).map { offset in
            AttachedItem(id: 10_000 + offset, height: 95,
                         attachedItems: ["date0": FixedHeightAttachment(
                            label: "g0", height: 34,
                            placement: .overlay, edge: .top, isFloating: true)])
        }
        items.insert(contentsOf: loaded, at: 0)
        fixture.listView.applyChanges(items: items,
                                      anchorMode: .preserveVisibleContent,
                                      transition: .easeInOut(duration: 0.3))

        for (serial, screenBefore) in before {
            guard let screenAfter = fixture.listView.attachmentScreenY(serial: serial) else {
                continue    // left the window; not what this test is about
            }
            XCTAssertEqual(screenAfter, screenBefore, accuracy: 0.5,
                           "precondition: serial \(serial) must hold its screen position")
            let track = fixture.animationController.model.track(for: .attachment(serial),
                                                               property: .positionY)
            XCTAssertNil(track,
                         "serial \(serial) did not move on screen but animated "
                           + "from \(track?.from ?? 0) — the pass compared across coordinate bases")
        }
    }

    /// Rapid `-top`: each pass interrupts the previous one while a correction is still live.
    ///
    /// `ListAnimationModel.transitionPositionOffset` computes `currentVisibleY = oldSettledY +
    /// currentOffset` itself, so the caller must pass the old SETTLED position. Passing the presented
    /// one counts the correction twice and the track's `from` grows as `delta + 2 × correction`,
    /// roughly doubling per pass — 95, 274, 613, 1252, 2458 — which reads as a violent snap on an
    /// attachment that is merely riding its run.
    ///
    /// Asserts the model's contract directly: `from == screenDelta + correctionBeforeThePass`.
    func testOverlappingPassesDoNotDoubleCountTheLiveCorrection() {
        var items: [CoreListItem] = (0..<180).map { index in
            let group = index / 6
            return AttachedItem(id: index, height: 95,
                                attachedItems: ["avatar\(group)": FixedHeightAttachment(
                                    label: "a\(group)", height: 32,
                                    placement: .overlay, edge: .bottom, isFloating: true)])
        }
        let fixture = VirtualListFixture(viewport: CGSize(width: 393, height: 852), items: items)

        // The first run's avatar rides its band rather than parking at an edge — the case that snapped.
        let serial = fixture.activeWindow.attachments.first!.serial
        var sawAnInterruptedPass = false

        for _ in 0..<5 {
            let screenBefore = fixture.listView.attachmentScreenY(serial: serial)
            let correctionBefore = fixture.animationController.positionOffset(
                owner: .attachment(serial), at: fixture.animationController.now()) ?? 0

            items.removeFirst()
            fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
            fixture.driver.tick(dt: 0.05)   // interrupt: far shorter than the 0.3s duration

            guard let screenBefore,
                  let screenAfter = fixture.listView.attachmentScreenY(serial: serial),
                  let track = fixture.animationController.model.track(for: .attachment(serial),
                                                                     property: .positionY)
            else { continue }

            if correctionBefore != 0 { sawAnInterruptedPass = true }
            XCTAssertEqual(track.from,
                           (screenBefore - screenAfter) + correctionBefore,
                           accuracy: 0.5,
                           "the live correction must be counted ONCE: the model adds it internally")
        }

        XCTAssertTrue(sawAnInterruptedPass,
                      "precondition: at least one pass must have interrupted a live correction, "
                        + "or this test cannot observe double-counting")
    }

    /// Tapping `Top` while slightly scrolled: a programmatic scroll's displacement belongs to the
    /// SHARED viewport track. An attachment's own track must carry only what the viewport track does
    /// not — otherwise the two cancel at t=0 and every floating attachment sits at its destination
    /// while the content is still travelling.
    ///
    /// Both halves are asserted, because measuring relative to the RENDERED viewport is what produces
    /// them from one rule:
    ///   - an attachment RIDING its run moves with the content, so it needs no track of its own;
    ///   - a PARKED attachment must hold still, so it needs a counter-track cancelling the viewport
    ///     displacement exactly.
    func testAProgrammaticScrollLeavesItsDisplacementWithTheViewportTrack() {
        let items: [CoreListItem] = (0..<180).map { index in
            let group = index / 6
            return AttachedItem(id: index, height: 95,
                                attachedItems: [
                                    "date\(group)": FixedHeightAttachment(
                                        label: "g\(group)", height: 34,
                                        placement: .overlay, edge: .top, isFloating: true),
                                    "avatar\(group)": FixedHeightAttachment(
                                        label: "a\(group)", height: 32,
                                        placement: .overlay, edge: .bottom, isFloating: true),
                                ])
        }
        let fixture = VirtualListFixture(viewport: CGSize(width: 393, height: 852), items: items)
        fixture.scroll(to: 250)

        let anchorTop = 0.0
        let anchorBottom = 852 - 32.0
        let before = fixture.activeWindow.attachments.map {
            ($0.serial, fixture.listView.attachmentScreenY(serial: $0.serial)!)
        }
        fixture.listView.applyChanges(scrollTo: .init(index: 0, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))

        guard let viewportTrack = fixture.viewportTrack else {
            return XCTFail("precondition: a programmatic scroll must install a viewport track")
        }
        XCTAssertGreaterThan(abs(viewportTrack.from), 1, "precondition: a real displacement")

        var checkedRiding = false
        var checkedParked = false
        for (serial, screenBefore) in before {
            guard fixture.listView.attachmentScreenY(serial: serial) != nil else { continue }
            let track = fixture.animationController.model.track(for: .attachment(serial),
                                                               property: .positionY)
            let wasParked = abs(screenBefore - anchorTop) < 0.5
                || abs(screenBefore - anchorBottom) < 0.5
            if wasParked {
                checkedParked = true
                XCTAssertEqual(track?.from ?? 0, viewportTrack.from, accuracy: 0.5,
                               "a parked attachment must counter the viewport displacement exactly "
                                 + "so it holds still (serial \(serial))")
            } else {
                checkedRiding = true
                XCTAssertNil(track,
                             "an attachment riding its run must ride the VIEWPORT track alone; its "
                               + "own track would double the scroll (serial \(serial))")
            }
        }
        XCTAssertTrue(checkedRiding, "precondition: at least one attachment must be riding")
        XCTAssertTrue(checkedParked, "precondition: at least one attachment must be parked")
    }

    /// The direct form of the defect: rebuilding a row for a size change must PRESERVE its group.
    /// Dropping it silently re-keys the row to group 0 and splits whatever run it belonged to.
    func testRebuildingARowForASizeChangePreservesItsGroup() {
        let original = DemoListItem(id: UUID(), title: "t", detail: "d",
                                    accentColor: .systemBlue, minHeight: 0, groupIndex: 7)
        let resized = DemoListItem(id: original.id, title: original.title, detail: original.detail,
                                   accentColor: original.accentColor, minHeight: 240,
                                   groupIndex: original.groupIndex)
        XCTAssertEqual(resized.groupIndex, 7)
        XCTAssertEqual(Set(resized.attachedItems.keys), Set(original.attachedItems.keys),
                       "a resized row must keep publishing the same attachment keys")
    }
}
