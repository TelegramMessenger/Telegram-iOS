import XCTest
@testable import CoreListDemo

final class AttachmentGeometryTests: XCTestCase {
    /// 20 rows of 50pt in an 800pt viewport, in groups of 5.
    ///
    /// Each group gets its own KEY, not merely its own label. That is the faithful model: a run is
    /// identified by key, and `ChatMessageDateHeader` puts its rounded timestamp inside its id — so a
    /// new date is a new key, not new content under one key. One key across every row would be one
    /// giant run, which is correct behavior for the case it actually models (one peer's avatar across
    /// all of their messages).
    fileprivate func groupedItems(count: Int = 20, groupSize: Int = 5) -> [CoreListItem] {
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

    func testWindowCarriesOneAttachmentPerLoadedRun() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let attachments = fixture.activeWindow.attachments
        XCTAssertFalse(attachments.isEmpty)
        // Every loaded row belongs to exactly one attachment's member range.
        for item in fixture.activeWindow.items {
            let owners = attachments.filter { $0.memberRange.contains(item.index) }
            XCTAssertEqual(owners.count, 1, "row \(item.index) must belong to exactly one run")
        }
    }

    func testAttachmentsAreMeasuredAtContentWidth() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        for attachment in fixture.activeWindow.attachments {
            XCTAssertEqual(attachment.measuredHeight, 30, accuracy: 1e-9)
            let view = attachment.view as? FixedHeightAttachmentView
            XCTAssertEqual(view?.lastMeasuredWidth ?? -1, 390, accuracy: 1e-9)
        }
    }

    func testBandSpansTheRunsLoadedMembers() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let window = fixture.activeWindow
        for attachment in window.attachments {
            let members = window.items.filter { attachment.memberRange.contains($0.index) }
            XCTAssertEqual(attachment.bandTop, members.map(\.frame.minY).min()!, accuracy: 1e-9)
            XCTAssertEqual(attachment.bandBottom, members.map(\.frame.maxY).max()!, accuracy: 1e-9)
        }
    }

    func testAttachmentViewIsReusedAcrossAPassWhenItsRunSurvives() {
        let items = groupedItems()
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        let before = fixture.activeWindow.attachments.first!.view
        fixture.apply(items, duration: 0)
        let after = fixture.activeWindow.attachments.first!.view
        XCTAssertTrue(before === after, "a surviving run must keep its view instance")
    }

    func testAttachmentViewsAreInTheAttachmentContainerAboveRows() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let container = fixture.listView.attachmentContainer
        for attachment in fixture.activeWindow.attachments {
            XCTAssertTrue(attachment.view.superview === container)
        }
        let host = fixture.listView.engine.contentHost
        let rowsIndex = host.subviews.firstIndex(of: fixture.listView.container)!
        let attachmentsIndex = host.subviews.firstIndex(of: container)!
        XCTAssertLessThan(rowsIndex, attachmentsIndex, "attachments must render above rows")

        // Above the OVERLAYS as well. A crossing carry and a ghost block are row content that is on
        // its way out, and a floating header sits above row content — otherwise a departing row draws
        // over a parked header for the length of its exit fade, which (rows being opaque) looks like
        // the header fading in from nothing.
        let crossingIndex = host.subviews.firstIndex(of: fixture.listView.crossingOverlay)!
        let exitIndex = host.subviews.firstIndex(of: fixture.listView.exitOverlay)!
        XCTAssertLessThan(crossingIndex, attachmentsIndex,
                          "attachments must render above crossing carries")
        XCTAssertLessThan(exitIndex, attachmentsIndex,
                          "attachments must render above departing ghosts")
    }

    func testFloatingTopAttachmentStartsAtItsRunTop() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        // The first group occupies rows 0–4, i.e. screen y 0…250 at rest.
        let first = fixture.activeWindow.attachments.first!
        XCTAssertEqual(fixture.listView.attachmentScreenY(serial: first.serial)!, 0, accuracy: 1e-9)
    }

    func testAttachmentSpansContentWidthAtTheLeftInset() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let view = fixture.activeWindow.attachments.first!.view
        XCTAssertEqual(view.frame.minX, 0, accuracy: 1e-9)
        XCTAssertEqual(view.frame.width, 390, accuracy: 1e-9)
        XCTAssertEqual(view.frame.height, 30, accuracy: 1e-9)
    }

    func testAViewWhoseRunLeftTheWindowIsRemovedFromTheContainer() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems(count: 60))
        let firstView = fixture.activeWindow.attachments.first!.view
        fixture.scroll(to: 2000)
        XCTAssertNil(firstView.superview,
                     "a run that scrolled out must have its view dropped, not merely repositioned")
    }

    /// `rebalanceActiveWindow` mutates `window.items` directly and never calls `buildWindow`, so
    /// without its own resolution call the attachment set would go stale the moment scrolling loads
    /// a row belonging to a run the window had not seen.
    func testScrollingIntoANewRunResolvesIt() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems(count: 60))
        let before = Set(fixture.activeWindow.attachments.map(\.serial))
        fixture.scroll(to: 2000)
        let after = fixture.activeWindow.attachments
        XCTAssertFalse(after.isEmpty)
        XCTAssertTrue(after.allSatisfy { $0.memberRange.overlaps(
            fixture.activeWindow.startIndex..<(fixture.activeWindow.endIndex + 1)) })
        XCTAssertNotEqual(Set(after.map(\.serial)), before,
                          "scrolling to a different region must resolve different runs")
    }

    func testFloatingTopAttachmentParksAtTheDisplayTopWhileItsRunIsOnScreen() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems(count: 60))
        let serial = fixture.activeWindow.attachments.first!.serial
        // Group 0 spans rows 0–4 => content 0…250. Scroll 100pt: the run top is above the display
        // top, so the attachment parks at the display top (inset 0).
        fixture.scroll(to: 100)
        XCTAssertEqual(fixture.listView.attachmentScreenY(serial: serial)!, 0, accuracy: 0.5)
    }

    func testFloatingTopAttachmentIsPushedOutByItsRunsEnd() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems(count: 60))
        let serial = fixture.activeWindow.attachments.first!.serial
        // At offset 235 the run's bottom (250) is 15pt below the display top, and the 30pt
        // attachment can no longer fit above it: it is pushed to bandBottom - h = 250 - 30 = 220,
        // i.e. screen y 220 - 235 = -15.
        fixture.scroll(to: 235)
        XCTAssertEqual(fixture.listView.attachmentScreenY(serial: serial)!, -15, accuracy: 0.5)
    }

    /// `attachmentScreenY` recomputes from the map, so it would agree with the solve even if nothing
    /// were rendered. This asserts on the RENDERED view frame, which is the thing that goes stale.
    func testTheSolveRunsEvenWhenTheWindowDoesNotChange() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems(count: 60))
        let loadedBefore = fixture.loadedIndices
        fixture.scroll(to: 20)
        XCTAssertEqual(fixture.loadedIndices, loadedBefore,
                       "precondition: this scroll must not change the window")

        let window = fixture.activeWindow
        let attachment = window.attachments.first!
        let solvedFrameSpaceY = fixture.listView.attachmentScreenY(serial: attachment.serial)!
            - fixture.listView.containerOriginY
            + window.minY
            + fixture.listView.engine.offset
        XCTAssertEqual(attachment.view.frame.minY,
                       solvedFrameSpaceY - window.minY,
                       accuracy: 0.001,
                       "the rendered frame must agree with the solve after a pure scroll")
    }

    /// Reserving variant: 30pt `.top` header per group, one key per group (see `groupedItems`).
    fileprivate func reservingItems(count: Int = 20,
                                    groupSize: Int = 5,
                                    isFloating: Bool = true) -> [CoreListItem] {
        (0..<count).map { index in
            let group = index / groupSize
            return AttachedItem(id: index,
                                height: 50,
                                attachedItems: ["date\(group)": FixedHeightAttachment(
                                    label: "group\(group)",
                                    height: 30,
                                    placement: .reservesSpace,
                                    edge: .top,
                                    isFloating: isFloating)])
        }
    }

    func testReservationPushesRowsDownByTheMeasuredHeight() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: reservingItems())
        let window = fixture.activeWindow
        // Row 0 starts at 0 with its band above it; rows 1–4 follow with no gap; row 5 starts a new
        // run, so it gains a 30pt gap.
        XCTAssertEqual(window.localFrame(for: 5)!.minY
                        - window.localFrame(for: 4)!.maxY, 30, accuracy: 1e-9)
    }

    func testOverlayPlacementReservesNothing() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let window = fixture.activeWindow
        XCTAssertEqual(window.localFrame(for: 5)!.minY
                        - window.localFrame(for: 4)!.maxY, 0, accuracy: 1e-9)
    }

    func testWindowMinYCoversTheLeadingReservedBand() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: reservingItems())
        let window = fixture.activeWindow
        XCTAssertEqual(window.items.first!.reservedTop, 30, accuracy: 1e-9)
        XCTAssertEqual(window.minY, window.items.first!.frame.minY - 30, accuracy: 1e-9)
    }

    /// At the loaded top the BAND rides the inset edge, not the row — which is what makes a section
    /// header visible rather than hidden above the inset.
    func testAtTheLoadedTopTheBandRidesTheInsetEdge() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: reservingItems())
        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 64, left: 0, bottom: 0, right: 0),
                                      transition: .immediate)
        let serial = fixture.activeWindow.attachments.first!.serial
        XCTAssertEqual(fixture.listView.attachmentScreenY(serial: serial)!, 64, accuracy: 0.5)
        XCTAssertEqual(fixture.screenY(identity: AnyHashable(0))!, 94, accuracy: 0.5)
    }

    /// `CoreListScrollTarget.resolve` returns the ROW's settled Y, and reservation does not change
    /// that: scrolling to a run's head places the row at the requested offset and leaves its reserved
    /// header off-screen above. ListViewImpl has the identical property and hosts compensate for it
    /// (chat's `scrollPositioningInsets`). Locking it here so a future change to make the list
    /// compensate is a deliberate decision rather than an accident.
    /// Uses a NON-floating header deliberately. A floating one whose band straddles the display top
    /// parks at the anchor, which would mask the property under test.
    func testScrollToPlacesTheRowNotTheBand() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: reservingItems(count: 60, isFloating: false))
        // Row 10 starts a run (groups of 5), so it carries a 30pt reserved band above it.
        fixture.listView.applyChanges(scrollTo: CoreListScrollTarget(index: 10, pointOffset: 0),
                                      transition: .immediate)
        XCTAssertEqual(fixture.screenY(identity: AnyHashable(10))!, 0, accuracy: 0.5)
        let serial = fixture.activeWindow.attachments
            .first { $0.memberRange.contains(10) }!.serial
        XCTAssertEqual(fixture.listView.attachmentScreenY(serial: serial)!, -30, accuracy: 0.5,
                       "the band sits above the row and therefore off-screen")
    }

    /// The floating counterpart of the above: the same jump parks the header at the display top
    /// instead of leaving it off-screen. Both behaviors are correct; they differ only in `isFloating`.
    func testScrollToWithAFloatingHeaderParksItAtTheDisplayTop() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: reservingItems(count: 60))
        fixture.listView.applyChanges(scrollTo: CoreListScrollTarget(index: 10, pointOffset: 0),
                                      transition: .immediate)
        XCTAssertEqual(fixture.screenY(identity: AnyHashable(10))!, 0, accuracy: 0.5)
        let serial = fixture.activeWindow.attachments
            .first { $0.memberRange.contains(10) }!.serial
        XCTAssertEqual(fixture.listView.attachmentScreenY(serial: serial)!, 0, accuracy: 0.5)
    }

    /// A run clipped by the loaded window reserves nothing, because the band above its unloaded head
    /// is off-window — yet the floating attachment still shows, clamped into the loaded band.
    func testAnUnloadedRunHeadReservesNothingButStillShows() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: reservingItems(count: 200, groupSize: 200))
        fixture.scroll(to: 4000)
        let window = fixture.activeWindow
        XCTAssertGreaterThan(window.startIndex, 0, "precondition: the run head must be unloaded")
        XCTAssertEqual(window.items.first!.reservedTop, 0, accuracy: 1e-9)
        XCTAssertEqual(window.attachments.count, 1)
        XCTAssertFalse(window.attachments[0].startsCollectionRun)
        XCTAssertNotNil(fixture.listView.attachmentScreenY(serial: window.attachments[0].serial))
    }

    /// `render()` runs mid-pass, BEFORE `applyChanges` writes the pass's final engine offset. Row
    /// frames are offset-independent so they do not care; the attachment solve consumes the offset,
    /// so a header rendered at that point is parked against a stale one and lands a whole
    /// inset-change away. Asserts the RENDERED frame — `attachmentScreenY` recomputes from the map
    /// and agreed with the solve even while the view on screen was 302pt wrong.
    func testRenderedFrameUsesThePassFinalOffset() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: reservingItems(count: 60))
        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 302, left: 0, bottom: 0, right: 0),
                                      transition: .immediate)
        let window = fixture.activeWindow
        let attachment = window.attachments.first!
        let solved = fixture.listView.attachmentMap(attachment, window: window)
            .y(atOffset: fixture.listView.engine.offset)
        XCTAssertEqual(attachment.view.frame.minY, solved - window.minY, accuracy: 0.001,
                       "the rendered frame must use the offset the pass settled on")
        // And that lands the band on the inset edge.
        XCTAssertEqual(fixture.listView.attachmentScreenY(serial: attachment.serial)!, 302,
                       accuracy: 0.5)
    }

    func testAttachmentSelfUpdateSchedulesAFlushAndRemeasures() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let view = fixture.activeWindow.attachments.first!.view as! FixedHeightAttachmentView
        let measuresBefore = view.measureCount
        view.onContentDidChange?(false)
        fixture.flushScheduler()
        XCTAssertGreaterThan(view.measureCount, measuresBefore,
                             "the flush must re-measure the attachment")
    }
}
