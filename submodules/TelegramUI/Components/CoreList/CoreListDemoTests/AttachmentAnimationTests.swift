import XCTest
@testable import CoreListDemo

final class AttachmentAnimationTests: XCTestCase {
    func testAttachmentOwnerIsDistinctFromLiveOwnerWithTheSameRawValue() {
        XCTAssertNotEqual(ListAnimationOwner.attachment(3), ListAnimationOwner.ghostBlock(3))
        XCTAssertNotEqual(ListAnimationOwner.attachment(3), ListAnimationOwner.exit(3))
        XCTAssertTrue(ListAnimationOwner.attachment(3).isAttachment)
        XCTAssertFalse(ListAnimationOwner.live(3).isAttachment)
    }

    func testOwnerKeyedPositionTransitionStartsATrackOnTheAttachmentOwner() {
        let clock = SyntheticClock()
        let controller = ListAnimationController(compiler: CoreAnimationCompiler(emitsAnimations: false),
                                                 mediaTime: { clock.now },
                                                 durationFactor: { 1 })
        let layer = CALayer()
        controller.setReferenceLayer(layer)

        let mutation = controller.transitionPosition(owner: .attachment(7),
                                                     layer: layer,
                                                     oldSettledY: 100,
                                                     newSettledY: 140,
                                                     transition: .linear(duration: 0.3),
                                                     transactionTime: clock.now)
        guard case .started = mutation else {
            return XCTFail("a changed settled position must start a track")
        }
        let track = controller.model.track(for: .attachment(7), property: .positionY)
        XCTAssertNotNil(track)
        // Additive correction: the view was at 100, its new settled endpoint is 140, so the
        // correction runs -40 -> 0 exactly as a row's does.
        XCTAssertEqual(track!.from, -40, accuracy: 1e-9)
        XCTAssertEqual(track!.to, 0, accuracy: 1e-9)
    }

    func testOwnerKeyedUnchangedPositionIsAnExactNoOp() {
        let clock = SyntheticClock()
        let controller = ListAnimationController(compiler: CoreAnimationCompiler(emitsAnimations: false),
                                                 mediaTime: { clock.now },
                                                 durationFactor: { 1 })
        let layer = CALayer()
        controller.setReferenceLayer(layer)
        controller.transitionPosition(owner: .attachment(7), layer: layer,
                                      oldSettledY: 100, newSettledY: 140,
                                      transition: .linear(duration: 0.3), transactionTime: clock.now)
        let before = controller.model.track(for: .attachment(7), property: .positionY)!
        clock.advance(by: 0.1)
        let mutation = controller.transitionPosition(owner: .attachment(7), layer: layer,
                                                     oldSettledY: 140, newSettledY: 140,
                                                     transition: .linear(duration: 0.3),
                                                     transactionTime: clock.now)
        XCTAssertEqual(mutation, .unchanged)
        let after = controller.model.track(for: .attachment(7), property: .positionY)!
        XCTAssertEqual(after.generation, before.generation)
        XCTAssertEqual(after.startTime, before.startTime, accuracy: 1e-9)
        XCTAssertEqual(after.duration, before.duration, accuracy: 1e-9)
    }

    func testIdentityKeyedPositionStillTargetsTheLiveOwner() {
        let clock = SyntheticClock()
        let controller = ListAnimationController(compiler: CoreAnimationCompiler(emitsAnimations: false),
                                                 mediaTime: { clock.now },
                                                 durationFactor: { 1 })
        let layer = CALayer()
        controller.setReferenceLayer(layer)
        controller.transitionPosition(identity: AnyHashable(1), layer: layer,
                                      oldSettledY: 0, newSettledY: 50,
                                      transition: .linear(duration: 0.3), transactionTime: clock.now)
        XCTAssertNotNil(controller.model.track(for: .live(AnyHashable(1)), property: .positionY))
        XCTAssertNil(controller.model.track(for: .attachment(1), property: .positionY))
    }

    fileprivate func groupedItems(count: Int = 60, groupSize: Int = 5) -> [CoreListItem] {
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

    func testSettledAttachmentStateReportsContentYMatchingTheRowConvention() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let window = fixture.activeWindow
        let state = fixture.listView.settledAttachmentState(
            window,
            containerOriginY: fixture.listView.containerOriginY,
            insets: fixture.listView.viewportInsets,
            logicalHeight: 800,
            offset: fixture.listView.engine.offset,
            viewportCorrection: 0,
            at: fixture.animationController.now())

        XCTAssertEqual(state.count, window.attachments.count)
        for attachment in window.attachments {
            let settled = state[attachment.serial]!
            // contentY - offset is the screen position, the same relation a row's contentY has.
            XCTAssertEqual(settled.contentY - fixture.listView.engine.offset,
                           fixture.listView.attachmentScreenY(serial: attachment.serial)!,
                           accuracy: 1e-9)
            XCTAssertEqual(settled.size.height, attachment.measuredHeight, accuracy: 1e-9)
            XCTAssertEqual(settled.size.width, 390, accuracy: 1e-9)
        }
    }

    /// The parameterised map must honour the geometry it is GIVEN, not the list's current geometry.
    func testAttachmentMapUsesTheSuppliedGeometry() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let window = fixture.activeWindow
        let attachment = window.attachments.first!
        let withCurrent = fixture.listView.attachmentMap(
            attachment, window: window,
            containerOriginY: fixture.listView.containerOriginY,
            insets: .zero, logicalHeight: 800)
        let withInset = fixture.listView.attachmentMap(
            attachment, window: window,
            containerOriginY: fixture.listView.containerOriginY,
            insets: UIEdgeInsets(top: 64, left: 0, bottom: 0, right: 0), logicalHeight: 800)
        XCTAssertEqual(withCurrent.anchor, 0, accuracy: 1e-9)
        XCTAssertEqual(withInset.anchor, 64, accuracy: 1e-9)
    }

    /// Deleting rows above a run moves its header; that move must animate from the header's analytic
    /// current position rather than snapping.
    func testARunWhoseGeometryMovesGetsAPositionTrack() {
        var items = groupedItems()
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        // Target the SECOND run, so deleting from the first moves it.
        let serial = fixture.activeWindow.attachments[1].serial
        XCTAssertNil(fixture.animationController.model.track(for: .attachment(serial),
                                                            property: .positionY))
        items.remove(at: 0)
        fixture.apply(items, duration: 0.3)
        let track = fixture.animationController.model.track(for: .attachment(serial),
                                                           property: .positionY)
        XCTAssertNotNil(track, "a moved run must animate its header")
        XCTAssertEqual(track!.from, 50, accuracy: 0.5, "one 50pt row was removed above it")
        XCTAssertEqual(track!.to, 0, accuracy: 1e-9)
    }

    func testAnUnchangedRunIsAnExactPositionNoOp() {
        let items = groupedItems()
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        let serial = fixture.activeWindow.attachments[1].serial
        fixture.apply(items, duration: 0.3)
        XCTAssertNil(fixture.animationController.model.track(for: .attachment(serial),
                                                            property: .positionY),
                     "an unchanged settled position must not start a track")
    }

    func testAChangedAttachmentHeightGetsAHeightTrack() {
        func items(firstGroupHeight: CGFloat) -> [CoreListItem] {
            (0..<60).map { index in
                let group = index / 5
                return AttachedItem(id: index, height: 50,
                                    attachedItems: ["date\(group)": FixedHeightAttachment(
                                        label: "group\(group)",
                                        height: index < 5 ? firstGroupHeight : 30,
                                        placement: .overlay, edge: .top, isFloating: true)])
            }
        }
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: items(firstGroupHeight: 60))
        let serial = fixture.activeWindow.attachments[0].serial
        fixture.apply(items(firstGroupHeight: 30), duration: 0.3)
        let track = fixture.animationController.model.track(for: .attachment(serial),
                                                           property: .height)
        XCTAssertNotNil(track)
        XCTAssertEqual(track!.from, 60, accuracy: 1e-9)
        XCTAssertEqual(track!.to, 30, accuracy: 1e-9)
    }

    func testAnInsetChangeGivesAttachmentsAWidthTrack() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let serial = fixture.activeWindow.attachments[0].serial
        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0),
                                      transition: .easeInOut(duration: 0.3))
        let track = fixture.animationController.model.track(for: .attachment(serial),
                                                           property: .width)
        XCTAssertNotNil(track)
        XCTAssertEqual(track!.from, 390, accuracy: 1e-9)
        XCTAssertEqual(track!.to, 350, accuracy: 1e-9)
    }

    func testAGenuinelyNewRunFadesIn() {
        var items = groupedItems()
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        let before = Set(fixture.activeWindow.attachments.map(\.serial))
        // Insert 5 rows carrying a brand-new key at the top: a new run of all-new rows.
        let fresh: [CoreListItem] = (0..<5).map { offset in
            AttachedItem(id: 1000 + offset, height: 50,
                         attachedItems: ["dateNew": FixedHeightAttachment(
                            label: "new", height: 30,
                            placement: .overlay, edge: .top, isFloating: true)])
        }
        items.insert(contentsOf: fresh, at: 0)
        fixture.apply(items, duration: 0.3)

        let newSerials = Set(fixture.activeWindow.attachments.map(\.serial)).subtracting(before)
        XCTAssertEqual(newSerials.count, 1)
        let track = fixture.animationController.model.track(for: .attachment(newSerials.first!),
                                                           property: .opacity)
        XCTAssertNotNil(track, "a run of genuine inserts must fade in")
        XCTAssertEqual(track!.from, 0, accuracy: 1e-9)
        XCTAssertEqual(track!.to, 1, accuracy: 1e-9)
    }

    /// A run that merely entered the loaded window has neither inserts nor reconciles, so it must
    /// appear at full opacity. Grow the viewport to pull more rows in without touching the items.
    func testARunThatMerelyBecameLoadedDoesNotFade() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 400),
                                         items: groupedItems())
        let before = Set(fixture.activeWindow.attachments.map(\.serial))
        fixture.listView.applyChanges(newSize: CGSize(width: 390, height: 800),
                                      transition: .easeInOut(duration: 0.3))
        let newSerials = Set(fixture.activeWindow.attachments.map(\.serial)).subtracting(before)
        XCTAssertFalse(newSerials.isEmpty, "precondition: growing the viewport must load more runs")
        for serial in newSerials {
            XCTAssertNil(fixture.animationController.model.track(for: .attachment(serial),
                                                                property: .opacity),
                         "a newly LOADED run must not fade")
        }
    }

    func testScrollingARunIntoViewNeverFades() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let before = Set(fixture.activeWindow.attachments.map(\.serial))
        fixture.scroll(to: 1500)
        let newSerials = Set(fixture.activeWindow.attachments.map(\.serial)).subtracting(before)
        XCTAssertFalse(newSerials.isEmpty)
        for serial in newSerials {
            XCTAssertNil(fixture.animationController.model.track(for: .attachment(serial),
                                                                property: .opacity))
        }
    }

    /// A run leaving the window by scrolling must unbind, or its owner leaks and a later reuse of the
    /// same serial rebinds onto a stale layer.
    func testScrollingARunOutOfViewUnbindsItsOwner() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let departing = fixture.activeWindow.attachments.first!.serial
        fixture.scroll(to: 2500)
        XCTAssertFalse(fixture.activeWindow.attachments.contains { $0.serial == departing },
                       "precondition: the run must have left the window")
        XCTAssertFalse(fixture.animationController.isBound(owner: .attachment(departing)),
                       "a scrolled-out run must unbind")
    }

    /// A full replace + scrollTo is a carousel: the whole destination window is new content, so the
    /// fade-in rule fires on every incoming run. It must be suppressed — the rows do not fade, and a
    /// fading header beside a non-fading row is the artifact this exists to prevent.
    func testAFullReplaceCarouselFadesNoAttachments() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let replacement: [CoreListItem] = (0..<60).map { index in
            let group = index / 5
            return AttachedItem(id: 10_000 + index, height: 50,
                                attachedItems: ["far\(group)": FixedHeightAttachment(
                                    label: "far\(group)", height: 30,
                                    placement: .overlay, edge: .top, isFloating: true)])
        }
        fixture.listView.applyChanges(items: replacement,
                                      scrollTo: CoreListScrollTarget(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))

        XCTAssertFalse(fixture.activeWindow.attachments.isEmpty)
        for attachment in fixture.activeWindow.attachments {
            XCTAssertNil(fixture.animationController.model.track(for: .attachment(attachment.serial),
                                                                property: .opacity),
                         "a carousel must fade no attachment (serial \(attachment.serial))")
        }
    }

    /// A carousel leaves NOTHING in the content-space exit overlay — attachments included.
    ///
    /// The outgoing strip is screen-anchored, so an attachment left behind in `exitOverlay` would
    /// ride the user's finger back over the destination's rows while the rows it belongs to do not.
    /// It cannot currently happen, and this pins the reason rather than the symptom: a genuine
    /// departure joins a departing run when its old member indices all lie inside that run's range,
    /// `PriorRun.memberIdentities` holds only the run's LOADED members, and in a full replace the
    /// entire loaded window departs as one contiguous run. So every departing attachment travels
    /// inside a ghost block's wrapper, which the promotion moves, and the fade-in-place branch —
    /// the merge-loser case — is unreachable here.
    ///
    /// Group size 7 against a 50pt row and an 800pt viewport puts the loaded window's edges
    /// mid-group, which is the shape most likely to strand a run if that reasoning were wrong.
    func testACarouselParksNoAttachmentInTheContentSpaceOverlay() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems(count: 200, groupSize: 7))
        fixture.listView.applyChanges(scrollTo: CoreListScrollTarget(index: 100, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))
        let replacement: [CoreListItem] = (0..<200).map { index in
            let group = index / 7
            return AttachedItem(id: 10_000 + index, height: 50,
                                attachedItems: ["far\(group)": FixedHeightAttachment(
                                    label: "far\(group)", height: 30,
                                    placement: .overlay, edge: .top, isFloating: true)])
        }
        fixture.listView.applyChanges(items: replacement,
                                      scrollTo: CoreListScrollTarget(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))

        XCTAssertTrue(fixture.listView.fadingAttachmentViews.allObjects.isEmpty,
                      "a carousel attachment took the fade-in-place branch — it is parked in the "
                      + "content-space overlay while the strip it belongs to is screen-anchored")
        XCTAssertTrue(fixture.listView.exitOverlay.subviews.isEmpty,
                      "a carousel left content-space exit content behind")
        XCTAssertFalse(fixture.listView.carouselExitOverlay.subviews.isEmpty,
                       "precondition: the carousel must have parked its strip")
    }

    /// The suppression must stay scoped: a genuinely new run inserted among survivors still fades,
    /// even though this pass also scrolls.
    func testAnOverlappingScrollStillFadesAGenuinelyNewRun() {
        var items = groupedItems()
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        let before = Set(fixture.activeWindow.attachments.map(\.serial))
        let fresh: [CoreListItem] = (0..<5).map { offset in
            AttachedItem(id: 2000 + offset, height: 50,
                         attachedItems: ["dateNew": FixedHeightAttachment(
                            label: "new", height: 30,
                            placement: .overlay, edge: .top, isFloating: true)])
        }
        items.insert(contentsOf: fresh, at: 0)
        fixture.listView.applyChanges(items: items,
                                      scrollTo: CoreListScrollTarget(index: 2, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        let newSerials = Set(fixture.activeWindow.attachments.map(\.serial)).subtracting(before)
        XCTAssertEqual(newSerials.count, 1)
        XCTAssertNotNil(fixture.animationController.model.track(for: .attachment(newSerials.first!),
                                                               property: .opacity),
                        "an overlapping scroll must still fade a genuinely new run")
    }

    func testOwnerKeyedMakeExitTransfersStateToAFreshExitOwner() {
        let clock = SyntheticClock()
        let controller = ListAnimationController(compiler: CoreAnimationCompiler(emitsAnimations: false),
                                                 mediaTime: { clock.now },
                                                 durationFactor: { 1 })
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 100, height: 40)
        controller.setReferenceLayer(layer)
        controller.seedAttachment(owner: .attachment(9), layer: layer)

        var completed = false
        let exitOwner = controller.makeExit(owner: .attachment(9),
                                            layer: layer,
                                            contentY: 200,
                                            transition: .linear(duration: 0.3),
                                            transactionTime: clock.now,
                                            fadesOut: true) { completed = true }

        XCTAssertNotEqual(exitOwner, .attachment(9), "an exit takes a FRESH owner")
        let opacity = controller.model.track(for: exitOwner, property: .opacity)
        XCTAssertNotNil(opacity)
        XCTAssertEqual(opacity!.from, 1, accuracy: 1e-9)
        XCTAssertEqual(opacity!.to, 0, accuracy: 1e-9)
        XCTAssertFalse(controller.isBound(owner: .attachment(9)),
                       "the live owner must be released to the exit owner")
        XCTAssertFalse(completed)
    }

    func testARunLeavingOnlyTheWindowClassifiesAsSilent() {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: groupedItems())
        let departing = fixture.activeWindow.attachments.first!.serial
        fixture.scroll(to: 2500)
        XCTAssertFalse(fixture.activeWindow.attachments.contains { $0.serial == departing })
        // Scrolling drains silently, so nothing is left pending and no exit owner was made.
        XCTAssertTrue(fixture.listView.pendingAttachmentDepartures.isEmpty)
        XCTAssertTrue(fixture.driver.exitOverlay.subviews.isEmpty,
                      "a run that only left the window must not reach the exit overlay")
    }

    func testDeletingARunsRowsClassifiesAsGenuine() {
        var items = groupedItems()
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        let departing = fixture.activeWindow.attachments.first!.serial
        // Remove group 0 entirely (rows 0..4 carry key "date0").
        items.removeFirst(5)
        fixture.apply(items, duration: 0.3)
        XCTAssertFalse(fixture.activeWindow.attachments.contains { $0.serial == departing })
        XCTAssertTrue(fixture.listView.pendingAttachmentDepartures.isEmpty,
                      "the pass must drain what it classified")
    }

    /// Two adjacent runs merged into one: the serial at the merged run's top survives, the other
    /// departs and fades where it stood.
    private func mergedItems() -> [CoreListItem] {
        (0..<20).map { index in
            let key = index < 10 ? "date0" : "date\(index / 5)"
            return AttachedItem(id: index, height: 50,
                                attachedItems: [key: FixedHeightAttachment(
                                    label: "merged", height: 30,
                                    placement: .overlay, edge: .top, isFloating: true)])
        }
    }

    func testAMergeLoserFadesInPlace() {
        let split = groupedItems(count: 20, groupSize: 5)
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: split)
        let before = Set(fixture.activeWindow.attachments.map(\.serial))
        fixture.apply(mergedItems(), duration: 0.3)

        let after = Set(fixture.activeWindow.attachments.map(\.serial))
        let departed = before.subtracting(after)
        XCTAssertEqual(departed.count, 1, "exactly one serial loses the merge")
        // A fade-in-place attachment is a DIRECT exit-overlay child, not a ghost member — which is
        // what `exitSubviews` (i.e. `ghostMemberViews`) reports.
        XCTAssertEqual(fixture.driver.exitOverlay.subviews.count, 1,
                       "the loser's view must be in the exit overlay, fading")
        XCTAssertTrue(fixture.driver.exitSubviews.isEmpty,
                      "it is not a ghost member: no row departed")
    }

    /// The rows survive here, so nothing forms a ghost block — the header fades alone.
    func testAMergeLoserDoesNotCreateAGhostBlock() {
        let split = groupedItems(count: 20, groupSize: 5)
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: split)
        fixture.apply(mergedItems(), duration: 0.3)
        XCTAssertTrue(fixture.ghostBlocks.isEmpty, "no row departed, so there is no ghost block")
    }

    /// Deleting a whole group departs its rows into a ghost block; the header must join that block
    /// rather than fade in place, so it travels with the rows it belongs to.
    func testAHeaderWhoseWholeRunDepartedJoinsTheGhostBlock() {
        var items = groupedItems(count: 20, groupSize: 5)
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        let departing = fixture.activeWindow.attachments.first!.serial
        items.removeFirst(5)                       // group 0's rows and its header both go
        fixture.apply(items, duration: 0.3)

        XCTAssertFalse(fixture.activeWindow.attachments.contains { $0.serial == departing })
        XCTAssertEqual(fixture.ghostBlocks.count, 1)
        // 5 rows + 1 header.
        XCTAssertEqual(fixture.ghostBlocks[0].visibleMemberCount, 6,
                       "the header must count as a block member, or the block can be collected "
                         + "while it is still fading")
    }

    /// A RESERVING header genuinely sits above its run's first row, so it extends the block upward.
    /// (An overlay header sits AT the row top, where `localMinY == 0` is the correct answer — which is
    /// why this property needs a reserving fixture to be observable at all.)
    func testAReservingHeaderExtendsTheGhostBlockUpward() {
        func reserving(_ count: Int) -> [CoreListItem] {
            (0..<count).map { index in
                let group = index / 5
                return AttachedItem(id: index, height: 50,
                                    attachedItems: ["date\(group)": FixedHeightAttachment(
                                        label: "group\(group)", height: 30,
                                        placement: .reservesSpace, edge: .top, isFloating: false)])
            }
        }
        var items = reserving(20)
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        items.removeFirst(5)
        fixture.apply(items, duration: 0.3)

        XCTAssertEqual(fixture.ghostBlocks.count, 1)
        XCTAssertEqual(fixture.ghostBlocks[0].localMinY, -30, accuracy: 0.5,
                       "the 30pt reserved header sits above the block's first row")
    }

    /// The block wrapper owns the motion, so the header must be inside the wrapper — and therefore a
    /// ghost MEMBER — rather than a direct exit-overlay child fading on its own.
    func testTheJoinedHeaderIsAChildOfTheBlockWrapper() {
        var items = groupedItems(count: 20, groupSize: 5)
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: items)
        let departingView = fixture.activeWindow.attachments.first!.view
        items.removeFirst(5)
        fixture.apply(items, duration: 0.3)

        XCTAssertTrue(fixture.driver.isExitMember(departingView),
                      "a joined header is a ghost member")
        XCTAssertFalse(fixture.driver.exitOverlay.subviews.contains { $0 === departingView },
                       "it rides the wrapper, so it is not a direct exit-overlay child")
        let wrapper = fixture.listView.ghostBlockWrapperViews.first
        XCTAssertTrue(departingView.superview === wrapper)
    }

    /// The fading header must be removed once its opacity track completes, not leaked in the overlay.
    /// This is the leak `assertOverlayInvariants` exists to catch, so it is asserted directly rather
    /// than relied on from the assertion.
    func testAFadingHeaderIsRemovedWhenItsTrackCompletes() {
        let split = groupedItems(count: 20, groupSize: 5)
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: split)
        fixture.apply(mergedItems(), duration: 0.3)
        XCTAssertEqual(fixture.driver.exitOverlay.subviews.count, 1)
        _ = fixture.driver.runUntilSettled()
        XCTAssertTrue(fixture.driver.exitOverlay.subviews.isEmpty,
                      "the faded header must be removed, not leaked in the exit overlay")
    }
}
