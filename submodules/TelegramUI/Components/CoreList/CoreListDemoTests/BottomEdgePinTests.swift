import XCTest
import UIKit
@testable import CoreListDemo

/// A row declaring `pinsToBottomEdge` is held against the viewport's BOTTOM edge, with the list
/// declaring whatever extra top-inset slack is needed to bring it there.
///
/// The analogue of `ListViewImpl`'s `pinToEdgeWithInset` + `calculatePinToEdgeTopInset`
/// (`Display/Source/ListView.swift:1106`). Under the chat's π rotation CoreList's bottom edge is the
/// SCREEN TOP, which is why the chat uses this to hold a user's question in view while a bot streams
/// a reply below it — but nothing in CoreList knows that, and neither does this suite.
///
/// Fixture convention throughout, mirroring the real shape: index 0 is the growing reply, index 1 is
/// the pinned row, higher indices are older history.
final class BottomEdgePinTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 400)
    private let replyId = UUID()
    private let pinnedId = UUID()

    /// Builds the list UNPINNED and then introduces the pin in a pass, which is how it arrives in
    /// reality — the flag appears when the bot starts streaming, never at construction.
    ///
    /// Not merely realistic. `VirtualListDriver.init` ends with `layoutIfNeeded()`, and UIScrollView
    /// clamps a negative `bounds.origin.y` on a layout pass. That is a PRE-EXISTING property of the
    /// harness with nothing to do with the pin — a plain 100pt top inset applied at construction is
    /// clamped from -100 to 0 the same way, leaving index 0 at 0 instead of 100 — but a pin
    /// established during `init` would run headlong into it. Every other suite here applies its
    /// geometry after construction and so never meets it.
    private func fixture(replyHeight: CGFloat = 100,
                         pinnedHeight: CGFloat = 60,
                         historyCount: Int = 20) -> VirtualListFixture {
        // Built ONCE and shared by both collections: fresh UUIDs per call would make the pass below a
        // full replace rather than the flag change it is meant to be.
        let history: [CoreListItem] = (0..<historyCount).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: 50)
        }
        func items(pinned: Bool) -> [CoreListItem] {
            var items: [CoreListItem] = [
                // `ContentResizableItem`, not `IdentifiableFixedHeightItem`: the latter's `isEqual`
                // compares only `id`, so a height change reads as an UNCHANGED survivor and the engine
                // never re-measures it — which would make every growth assertion below vacuous.
                ContentResizableItem(id: replyId, contentHeight: replyHeight),
                pinned
                    ? PinnedFixedHeightItem(id: pinnedId, height: pinnedHeight)
                    : IdentifiableFixedHeightItem(id: pinnedId, height: pinnedHeight)
            ]
            items.append(contentsOf: history)
            return items
        }

        return self.fixture(unpinned: items(pinned: false), pinned: items(pinned: true))
    }

    /// Builds `unpinned` and then applies `pinned`, for the shapes the shared helper above does not
    /// cover. Same reason: the pin must arrive in a pass, not at construction.
    private func fixture(unpinned: [CoreListItem], pinned: [CoreListItem]) -> VirtualListFixture {
        let fixture = VirtualListFixture(viewport: viewport, items: unpinned)
        fixture.listView.applyChanges(items: pinned, transition: .easeInOut(duration: 0))
        return fixture
    }

    /// Arms the pin latch the way the chat does: one explicit `scrollTo` at the pinned index,
    /// carrying the pin placement. `CoreListChatHistoryBackend.pointOffset(for:index:height:view:)`
    /// replaces the chat's requested `.top(0.0)` with exactly this expression for a lowest
    /// pin-to-edge index, as `ListViewImpl` does at `Display/Source/ListView.swift:3146-3170`.
    ///
    /// Fired ONCE. The latch holds it from then on, and re-arming per pass would test nothing.
    ///
    /// Assumes zero insets, which every caller has at arming time. `testPinRespectsViewportInsets`
    /// applies insets afterwards, which is also the realistic order — the keyboard opens after the
    /// reply has started streaming.
    private func armPin(_ fixture: VirtualListFixture,
                        pinnedIndex: Int = 1,
                        viewport: CGSize? = nil) {
        let size = viewport ?? self.viewport
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: pinnedIndex) { height, _ in
                let visibleArea = size.height
                let ext = max(0, height - visibleArea * 0.5)
                return visibleArea + ext - height
            },
            transition: .easeInOut(duration: 0))
    }

    // MARK: - Placement

    /// visibleArea 400, reply 100 + pinned 60 = 160 above-and-including the pin, so the list must
    /// declare 240 of slack. The pinned row's maxY then sits exactly on the bottom edge.
    func testPinnedRowRestsOnTheBottomEdge() throws {
        let fixture = self.fixture()

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)), 340,
                       accuracy: 1e-6, "pinned row minY = slack 240 + reply 100")
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: replyId)), 240,
                       accuracy: 1e-6, "index 0 rides the EFFECTIVE inset edge, 240 below the raw one")
    }

    /// The declared minimum edge carries the slack — this is what stops the pass's own clamp
    /// (`newSettledOffset = max(newSettledOffset, minimum)`) from undoing the placement above.
    func testDeclaredMinimumEdgeCarriesTheSlack() throws {
        let fixture = self.fixture()

        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), -240, accuracy: 1e-6)
    }

    /// A row taller than half the viewport hangs off the bottom edge by the excess, so it never
    /// occupies more than half the screen. `pinToEdgeBottomExtension`, `ListView.swift:1137`.
    func testOverTallPinnedRowHangsOffTheEdge() throws {
        let fixture = self.fixture(pinnedHeight: 300)

        // ext = 300 - 200 = 100; span = 100 + 300 = 400; slack = (400 + 100) - 400 = 100.
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: replyId)), 100,
                       accuracy: 1e-6)
        let pinnedY = try XCTUnwrap(fixture.settledScreenY(identity: pinnedId))
        XCTAssertEqual(pinnedY, 200, accuracy: 1e-6)
        XCTAssertEqual(pinnedY + 300, 500, accuracy: 1e-6, "maxY hangs 100 past the bottom edge")
        XCTAssertEqual(400 - pinnedY, 200, accuracy: 1e-6, "exactly half the viewport is on screen")
    }

    /// Non-zero insets: the slack is measured against the inset-reduced viewport, and the pin target
    /// is the bottom INSET edge.
    func testPinRespectsViewportInsets() throws {
        let fixture = self.fixture()
        fixture.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 20, left: 0, bottom: 30, right: 0),
            transition: .easeInOut(duration: 0))

        // visibleArea 350; span 160; slack = (400 - 30) - (20 + 160) = 190.
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: replyId)), 210,
                       accuracy: 1e-6, "inset 20 + slack 190")
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 370,
                       accuracy: 1e-6, "pinned maxY on the bottom inset edge")
    }

    // MARK: - Guards

    /// No pinned row: nothing changes, index 0 rides the raw inset edge.
    func testNoPinnedRowDeclaresNoSlack() throws {
        let fixture = VirtualListFixture(itemCount: 22, itemHeight: 50, viewport: viewport)
        let first = fixture.listView.items[0].identity

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: first)), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), 0, accuracy: 1e-6)
    }

    /// `ListViewImpl` requires index 0 to be loaded (`sawIndexZero`) before it declares any inset,
    /// because the slack only means anything at the edge you can actually reach.
    func testSlackIsNotDeclaredWhileIndexZeroIsUnloaded() throws {
        let fixture = self.fixture(historyCount: 60)
        // Stepped: `handleUserScroll` clamps any single delta to one viewport height, so one jump to
        // 900 would only travel 400.
        for offset in stride(from: CGFloat(0), through: 900, by: 300) {
            fixture.scroll(to: offset)
        }

        XCTAssertFalse(fixture.loadedIndices.contains(0), "precondition: scrolled away from the top")
        XCTAssertNil(fixture.declaredEdges.min, "an unloaded top declares no minimum at all")
    }

    // MARK: - Invariance under growth

    /// THE property. As the reply above the pin grows, the slack shrinks by exactly as much, so the
    /// pinned row does not move. A backend computing the slack from pre-pass geometry would be one
    /// pass stale here and the row would jerk by the height delta on every token.
    func testPinnedRowDoesNotMoveWhileTheRowAboveGrows() throws {
        let fixture = self.fixture()
        let history = Array(fixture.listView.items.dropFirst(2))

        for replyHeight in [CGFloat(100), 150, 220, 300, 340] {
            var items: [CoreListItem] = [
                ContentResizableItem(id: replyId, contentHeight: replyHeight),
                PinnedFixedHeightItem(id: pinnedId, height: 60)
            ]
            items.append(contentsOf: history)
            fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

            XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                           accuracy: 1e-6,
                           "pinned maxY must hold the bottom edge at reply height \(replyHeight)")
        }
    }

    /// The same invariance, walked ACROSS the threshold rather than up to it.
    ///
    /// The test above stops at reply height 340, which is exactly `visibleArea 400 - pinned 60` — the
    /// point where the content above the pin fills the viewport. Every other fixture in this suite
    /// either stops there or jumps straight to an over-tall reply in a single pass. On device the
    /// reply GROWS through that boundary across many streamed passes, and this subsystem has
    /// repeatedly turned out to be sensitive to the sequence rather than the state: two single-pass
    /// attempts at this case both passed, because the initial build had already loaded the pinned row.
    ///
    /// Past the threshold the slack is zero and the LATCH is the only thing holding the row, which is
    /// why this arms the pin and the tests above do not.
    func testPinnedRowHoldsWhileTheReplyGrowsPastTheViewport() throws {
        let fixture = self.fixture()
        let history = Array(fixture.listView.items.dropFirst(2))
        self.armPin(fixture)

        for replyHeight in [CGFloat(300), 340, 360, 420, 500, 620] {
            var items: [CoreListItem] = [
                ContentResizableItem(id: replyId, contentHeight: replyHeight),
                PinnedFixedHeightItem(id: pinnedId, height: 60)
            ]
            items.append(contentsOf: history)
            fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

            XCTAssertTrue(fixture.loadedIndices.contains(1),
                          "the anchor loads its own row; reply \(replyHeight), loaded: \(fixture.loadedIndices)")
            XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                           accuracy: 1e-6,
                           "pinned maxY must hold the bottom edge at reply height \(replyHeight)")
        }
    }

    /// The same invariance DURING the animation, not just at its endpoints. The settled assertions
    /// above would pass even if the pass rebased the coordinate system and let every loaded row
    /// animate the rebase away, which reads on screen as the pinned bubble jumping and easing back.
    ///
    /// The boundary between the two rows is what the eye actually watches, so that is what is
    /// asserted: the growing row's maxY and the pinned row's minY are the same edge, and it must not
    /// move at any phase.
    ///
    /// Written while chasing a reported wobble in the streaming reply. It is NOT the reproduction —
    /// the wobble turned out to live in `CoreListNodeHostView`'s height compensation (TelegramUI),
    /// which this suite cannot see because the demo item views carry no π rotation. These assertions
    /// are what established that the list-side geometry is exact, so keep them.
    func testPinnedRowDoesNotMoveDuringTheGrowthAnimation() throws {
        let fixture = self.fixture()
        var items: [CoreListItem] = [
            ContentResizableItem(id: replyId, contentHeight: 150),
            PinnedFixedHeightItem(id: pinnedId, height: 60)
        ]
        items.append(contentsOf: fixture.listView.items.dropFirst(2))
        fixture.listView.applyChanges(items: items, transition: .linear(duration: 0.3))

        for phase in 0...6 {
            if phase > 0 { fixture.tick(dt: 0.05) }
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: pinnedId)), 340,
                           accuracy: 0.5, "pinned row minY at phase \(phase)")
            let replyY = try XCTUnwrap(fixture.screenY(identity: replyId))
            let replyHeight = try XCTUnwrap(fixture.visualHeight(identity: replyId))
            XCTAssertEqual(replyY + replyHeight, 340,
                           accuracy: 0.5, "growing row maxY at phase \(phase)")
        }
    }

    /// The same, driven by an ANIMATED self-update flush rather than a transaction. This is the path
    /// a streaming bubble actually takes: the node re-measures itself and asks the list to animate.
    func testPinnedRowDoesNotMoveDuringAnAnimatedSelfUpdateFlush() throws {
        let history: [CoreListItem] = (0..<20).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: 50)
        }
        func items(pinned: Bool) -> [CoreListItem] {
            var items: [CoreListItem] = [
                SelfUpdatingItem(id: replyId, initialHeight: 100),
                pinned
                    ? PinnedFixedHeightItem(id: pinnedId, height: 60)
                    : IdentifiableFixedHeightItem(id: pinnedId, height: 60)
            ]
            items.append(contentsOf: history)
            return items
        }
        let fixture = VirtualListFixture(viewport: viewport, items: items(pinned: false))
        fixture.listView.applyChanges(items: items(pinned: true),
                                      transition: .easeInOut(duration: 0))
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: pinnedId)), 340,
                       accuracy: 1e-6, "precondition: pinned")

        let replyView = try XCTUnwrap(fixture.view(identity: replyId) as? SelfUpdatingItemView)
        replyView.simulateContentChange(newHeight: 150, animated: true)
        fixture.flushScheduler()

        for phase in 0...8 {
            if phase > 0 { fixture.tick(dt: 0.05) }
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: pinnedId)), 340,
                           accuracy: 0.5, "pinned row minY at phase \(phase)")
            let replyY = try XCTUnwrap(fixture.screenY(identity: replyId))
            let replyHeight = try XCTUnwrap(fixture.visualHeight(identity: replyId))
            XCTAssertEqual(replyY + replyHeight, 340,
                           accuracy: 0.5, "growing row maxY at phase \(phase)")
        }
    }

    /// The same growth under `.preserveVisibleContent` — the anchor mode the chat selects whenever it
    /// passes a `stationaryItemRange`. That policy preserves a row's distance from the top inset
    /// edge, and the question is which edge it means once the pin has moved the effective one.
    func testPinnedRowDoesNotMoveUnderPreserveVisibleContent() throws {
        let fixture = self.fixture()
        var items: [CoreListItem] = [
            ContentResizableItem(id: replyId, contentHeight: 150),
            PinnedFixedHeightItem(id: pinnedId, height: 60)
        ]
        items.append(contentsOf: fixture.listView.items.dropFirst(2))
        fixture.listView.applyChanges(items: items,
                                      anchorMode: .preserveVisibleContent,
                                      transition: .linear(duration: 0.3))

        for phase in 0...8 {
            if phase > 0 { fixture.tick(dt: 0.05) }
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: pinnedId)), 340,
                           accuracy: 0.5, "pinned row minY at phase \(phase)")
        }
    }

    /// The reply outgrowing the viewport ON ITS OWN is the shape the chat streams into. Under the old
    /// slack-only mechanism `appendUntilPinnedRowLoaded` stopped as soon as the window filled the
    /// viewport — which index 0 does by itself here — so the pinned row was never loaded,
    /// `bottomEdgePinSlack` could not find it, and the pin silently released. The anchor cannot fail
    /// that way: it IS the pinned row, so the row is loaded before anything else is measured.
    ///
    /// Viewport 400, reply 500, pinned 60: `ext` is 0 (60 < half of 400), so the pinned row's maxY
    /// belongs on the bottom edge exactly as in every other placement test.
    func testPinHoldsWhenTheReplyAloneOutgrowsTheViewport() throws {
        let fixture = self.fixture()
        self.armPin(fixture)
        var items: [CoreListItem] = [
            ContentResizableItem(id: replyId, contentHeight: 500),
            PinnedFixedHeightItem(id: pinnedId, height: 60)
        ]
        items.append(contentsOf: fixture.listView.items.dropFirst(2))
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                       accuracy: 1e-6, "pinned maxY on the bottom edge")
    }

    /// Once the content above the pin fills the viewport the slack CLAMPS to zero, as `ListViewImpl`
    /// clamps the same expression (`ListView.swift:1134`). It has nothing left to do there: the pin's
    /// target has moved inside the natural scroll range, so no extra room is needed and the latch
    /// carries the hold from here on.
    ///
    /// It was briefly unclamped, to make the edge hold the row without a latch. The negative value fed
    /// `loadedEdgeRange`'s minimum and extended the scroll range into empty space, so on device a tall
    /// streaming reply could not be scrolled down to at all — it overscroll-bounced.
    ///
    /// Viewport 400, reply 400, pinned 60 — the raw expression is `400 - 460 = -60`, and 0 is reported.
    func testTheSlackClampsToZeroOnceTheRowAboveFillsTheViewport() throws {
        let fixture = self.fixture()
        var items: [CoreListItem] = [
            ContentResizableItem(id: replyId, contentHeight: 400),
            PinnedFixedHeightItem(id: pinnedId, height: 60)
        ]
        items.append(contentsOf: fixture.listView.items.dropFirst(2))
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), 0, accuracy: 1e-6,
                       "never negative: the minimum edge must not extend into empty space")
    }

    /// The same growth through a SELF-UPDATE flush (`onContentDidChange` → `markDirty` → an internal
    /// `applyChanges` with no items, size or insets). This path never reaches the host at all, which
    /// is one of the three reasons the slack cannot live in the backend.
    func testPinnedRowHoldsAcrossASelfUpdateFlush() throws {
        let history: [CoreListItem] = (0..<20).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: 50)
        }
        func items(pinned: Bool) -> [CoreListItem] {
            var items: [CoreListItem] = [
                SelfUpdatingItem(id: replyId, initialHeight: 100),
                pinned
                    ? PinnedFixedHeightItem(id: pinnedId, height: 60)
                    : IdentifiableFixedHeightItem(id: pinnedId, height: 60)
            ]
            items.append(contentsOf: history)
            return items
        }
        let fixture = VirtualListFixture(viewport: viewport, items: items(pinned: false))
        fixture.listView.applyChanges(items: items(pinned: true),
                                      transition: .easeInOut(duration: 0))
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                       accuracy: 1e-6, "precondition: pinned")

        let replyView = try XCTUnwrap(fixture.view(identity: replyId) as? SelfUpdatingItemView)
        for replyHeight in [CGFloat(150), 220, 300] {
            replyView.simulateContentChange(newHeight: replyHeight, animated: false)
            fixture.flushScheduler()

            XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                           accuracy: 1e-6,
                           "pinned maxY must hold across a flush to \(replyHeight)")
        }
    }

    // MARK: - Released, while the reply keeps streaming

    /// Applies the growth sequence a streaming reply produces, returning the pinned row's settled
    /// screen Y after each step. Parked deliberately OFF the pin: the at-the-edge case is covered by
    /// `testPinnedRowDoesNotMoveWhileTheRowAboveGrows`, and it is the only one the released state used
    /// to get right.
    private func pinnedYWhileGrowing(from parkedOffset: CGFloat,
                                     through replyHeights: [CGFloat]) throws -> [CGFloat] {
        let fixture = self.fixture()
        self.armPin(fixture)
        fixture.beginUserDrag()
        fixture.scroll(to: parkedOffset)

        let history = Array(fixture.listView.items.dropFirst(2))
        var result: [CGFloat] = [try XCTUnwrap(fixture.settledScreenY(identity: pinnedId))]
        for replyHeight in replyHeights {
            var items: [CoreListItem] = [
                ContentResizableItem(id: replyId, contentHeight: replyHeight),
                PinnedFixedHeightItem(id: pinnedId, height: 60)
            ]
            items.append(contentsOf: history)
            fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))
            result.append(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)))
        }
        return result
    }

    /// THE property for the released state, and it is the same one the engaged state has: while the
    /// slack still has room, a growing reply SPENDS that room and moves nothing.
    ///
    /// The slack is `visibleArea + ext - span`, so it shrinks by exactly the growth. Riding the
    /// effective top edge (`inset + slack`) rather than an absolute offset is what turns that retreat
    /// into absorption: the reply extends into the room the slack gives up, and the pinned row — with
    /// every row of history below it, which is what the user is actually reading — holds still.
    ///
    /// Held absolutely instead, the growth had nowhere to go but into pushing those rows: reported from
    /// the device as the chat drifting upward under a streaming reply. The settle clamp then cancelled
    /// only the part that crossed the edge, which is this same absorption arriving late, partially and
    /// in one jerk — drift, tug, drift, tug, measured as +100, +40, +60, +100 for four equal 100pt
    /// steps.
    ///
    /// Reply 100 → 340 with a 60pt pin in a 400pt viewport: `span` reaches `visibleArea` exactly at
    /// 340, so every step here has room left to spend.
    func testReleasedGrowthIsAbsorbedWhileTheSlackHasRoom() throws {
        let pinnedY = try self.pinnedYWhileGrowing(from: -100,   // parked 140 short of the -240 edge
                                                   through: [150, 200, 250, 300, 340])

        for (step, y) in pinnedY.enumerated() {
            XCTAssertEqual(y, pinnedY[0], accuracy: 1e-6,
                           "step \(step): the slack absorbs the growth, so nothing moves")
        }
    }

    /// Past the threshold the slack is clamped at zero and has nothing left to give, so the growth has
    /// nowhere to go but into the rows below — one-directional, never a tug back.
    ///
    /// Reply 100 → 340 → 400 → 500. The first step spends all 240 points of slack on 240 points of
    /// growth and moves nothing; from 340 on there is none left, and each step moves the row by the
    /// whole growth.
    func testReleasedGrowthPushesOnceTheSlackIsSpent() throws {
        let pinnedY = try self.pinnedYWhileGrowing(from: -100, through: [340, 400, 500])

        let deltas = zip(pinnedY.dropFirst(), pinnedY).map { $0 - $1 }
        XCTAssertEqual(deltas[0], 0, accuracy: 1e-6, "100 → 340: 240 of slack absorbs 240 of growth")
        XCTAssertEqual(deltas[1], 60, accuracy: 1e-6, "340 → 400: nothing left, the growth pushes")
        XCTAssertEqual(deltas[2], 100, accuracy: 1e-6, "400 → 500: likewise, point for point")
    }

    /// The end of streaming is not a growth: the typing draft carrying
    /// `TypingDraftMessageAttribute` is REPLACED by the real cloud message
    /// (`ChatHistoryListNode.swift:2240`), so index 0 departs and a new identity takes its place, at
    /// whatever height the final rendering measures.
    ///
    /// That moves the anchor. `topItemWasDeleted` sends `resolveAnchor` past index 0 to the first
    /// surviving row, which is the PINNED row itself — and a row at or below the pin does not move
    /// when the content above it changes, so its old screen position is already the right answer.
    /// Riding the effective edge on top of that moves it by the height delta: one jerk, at the end of
    /// streaming, and only when the final message measures differently from the last draft.
    func testTheDraftBecomingTheRealMessageDoesNotMoveThePin() throws {
        let fixture = self.fixture()
        self.armPin(fixture)
        fixture.beginUserDrag()
        fixture.scroll(to: -100)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: pinnedId))

        var items: [CoreListItem] = [
            // A NEW identity at a different height: the draft departing, the real message arriving.
            ContentResizableItem(id: UUID(), contentHeight: 150),
            PinnedFixedHeightItem(id: pinnedId, height: 60)
        ]
        items.append(contentsOf: fixture.listView.items.dropFirst(2))
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)), before,
                       accuracy: 1e-6,
                       "the pin anchors the pass itself; nothing above it may displace it")
    }

    // MARK: - The latch

    /// Release is the TOUCH, not the movement. A programmatic offset write keeps the pin — which is
    /// what every self-update flush and inset change ultimately is.
    func testProgrammaticScrollingDoesNotReleaseTheLatch() throws {
        let fixture = self.fixture()
        self.armPin(fixture)
        fixture.scroll(to: -140)

        var items = fixture.listView.items
        items.append(IdentifiableFixedHeightItem(id: UUID(), height: 50))
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                       accuracy: 1e-6, "the latch survives a programmatic offset write")
    }

    /// Releasing must not shrink the declared scroll range. `ListViewImpl` computes its pin inset
    /// unconditionally (`ListView.swift:1106`) for this reason: release happens at finger-DOWN, so a
    /// range that shrank with it would move content under the user's finger before the drag had
    /// travelled a single point.
    func testReleasingTheLatchLeavesTheScrollRangeAlone() throws {
        let fixture = self.fixture()
        self.armPin(fixture)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), -240, accuracy: 1e-6,
                       "precondition: the slack is declared")

        fixture.beginUserDrag()
        fixture.listView.applyChanges(newInsets: .zero, transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), -240, accuracy: 1e-6,
                       "the pin is released but its scroll room stays reachable")
    }

    /// UNARMED, deliberately. Where the slack is positive it also places the row: `pinsLoadedTop`
    /// requires the content to have been resting exactly at the declared min edge, which the slack has
    /// moved to the pin's position. So the short-content case still re-pins with no latch at all, and
    /// that is `ListViewImpl`'s arrangement too — its inset does this work, its latch does the rest.
    ///
    /// The latch is what carries the case this cannot reach: content above the pin taller than the
    /// viewport, where the slack clamps to zero and stops placing anything.
    func testAnOrdinaryLaterPassRePins() throws {
        let fixture = self.fixture()
        var items = fixture.listView.items
        items.append(IdentifiableFixedHeightItem(id: UUID(), height: 50))
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                       accuracy: 1e-6)
    }

    /// …and moving off the edge breaks that same `pinsLoadedTop` condition, so an unarmed pass does not
    /// yank the user back. The slack itself REMAINS declared, so the pin stays reachable by scrolling.
    ///
    /// Distinct from the latch's release, which is `beginUserDrag()` and is covered above: this is the
    /// unarmed path, where there is no latch to release.
    func testAPassAfterScrollingAwayDoesNotRePin() throws {
        let fixture = self.fixture()
        fixture.scroll(to: -140)   // 100 up from the -240 min edge
        let before = try XCTUnwrap(fixture.settledScreenY(identity: pinnedId))
        XCTAssertEqual(before, 240, accuracy: 1e-6, "precondition: moved 100 off the pin")

        var items = fixture.listView.items
        items.append(IdentifiableFixedHeightItem(id: UUID(), height: 50))
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)), before,
                       accuracy: 1e-6, "the pass must not drag the user back to the pin")
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), -240, accuracy: 1e-6,
                       "the slack stays declared — the pin is still reachable")
    }

    // MARK: - Inset compensation against the EFFECTIVE edge

    /// The anchor keeps its distance from the effective top edge, not the raw one. While the pin is
    /// active those two move in opposite directions by the same amount — the slack is
    /// `… - (viewportInsets.top + span)` — so the effective edge does not move at all and content
    /// must stay exactly put. The raw delta alone would shove it 50 points.
    ///
    /// Scrolled off the pin deliberately: at the pin, `pinsLoadedTop` would produce the right answer
    /// for the wrong reason and the compensation would go untested.
    func testTopInsetChangeMovesNothingWhileThePinIsActive() throws {
        let fixture = self.fixture()
        fixture.scroll(to: -140)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: pinnedId))

        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0),
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)), before,
                       accuracy: 1e-6,
                       "slack 240 → 190 absorbs the inset 0 → 50 exactly")
    }

    /// Absorption is exact only while the slack has room left to give. Pushing the top inset to 300
    /// asks for more than the 240 the slack holds, and the slack clamps at zero rather than going
    /// negative — so it absorbs 240 of the 300 and the remaining 60 moves the content.
    ///
    /// The effective edge is `inset + slack`: 0 + 240 = 240 before, 300 + 0 = 300 after. Content
    /// follows that 60: not the raw 300, and not nothing.
    ///
    /// (While the slack was unclamped this same case moved content by 10 — the change in `ext`, since
    /// a 100pt visible area makes the 60pt pinned row taller than half of it. That is now subsumed:
    /// `ext` still enters the slack, but the clamp binds first.)
    func testPartiallyAbsorbedInsetChangeMovesContentByTheUnabsorbedRemainder() throws {
        let fixture = self.fixture()
        fixture.scroll(to: -140)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: pinnedId))

        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)), before + 60,
                       accuracy: 1e-6, "effective edge 0+240 → 300+0")
    }

    /// Suppression still drops the WHOLE addend, slack half included — the caller is stating that its
    /// own drag owns the movement. Uses the 300 case, because that is the one where the addend is
    /// non-zero and so the switch has something to switch off.
    func testSuppressedCompensationDropsTheSlackHalfToo() throws {
        let fixture = self.fixture()
        fixture.scroll(to: -140)
        let before = try XCTUnwrap(fixture.settledScreenY(identity: pinnedId))

        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0),
                                      compensatesInsetChange: false,
                                      transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)), before,
                       accuracy: 1e-6)
    }

    /// A growth-only pass carries no compensation at all — and that is PROVABLE rather than gated:
    /// both slack samples read the same `oldWindow` and the same `_items`, so they can differ only if
    /// `logicalSize` or `viewportInsets` changed. Asserted as "compensated and suppressed agree",
    /// which is anchor-agnostic: with no addend, the switch has nothing to switch off.
    func testGrowthOnlyPassCarriesNoCompensation() throws {
        func pinnedYAfterGrowth(compensates: Bool) throws -> CGFloat {
            let fixture = self.fixture()
            fixture.scroll(to: -140)
            var items: [CoreListItem] = [
                ContentResizableItem(id: replyId, contentHeight: 180),
                PinnedFixedHeightItem(id: pinnedId, height: 60)
            ]
            items.append(contentsOf: fixture.listView.items.dropFirst(2))
            fixture.listView.applyChanges(items: items,
                                          compensatesInsetChange: compensates,
                                          transition: .easeInOut(duration: 0))
            return try XCTUnwrap(fixture.settledScreenY(identity: pinnedId))
        }

        XCTAssertEqual(try pinnedYAfterGrowth(compensates: true),
                       try pinnedYAfterGrowth(compensates: false),
                       accuracy: 1e-6)
    }

    // MARK: - The strict query

    /// The host's question is "is the pin currently held", and it is ONE member rather than a slack
    /// getter the host compares against — a pair is a pair a backend can half-implement, which is how
    /// `trackingOffset`/`beganTrackingAtTopOrigin` silently disabled keyboard snap-back.
    ///
    /// Every case here ARMS the pin, because the query reads the latch. The geometry alone cannot
    /// answer it, which is the point: a row can be at the edge without being held there.
    func testStrictlyPinnedWhileResting() throws {
        let fixture = self.fixture()
        self.armPin(fixture)

        XCTAssertTrue(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    /// The release is the touch. `beginUserDrag()` moves nothing at all — the row is still sitting
    /// exactly on the bottom edge — and the answer is still false, because nothing is holding it
    /// there any more.
    func testNotStrictlyPinnedAfterTheUserTouchesTheScroll() throws {
        let fixture = self.fixture()
        self.armPin(fixture)
        XCTAssertTrue(fixture.listView.isStrictlyPinnedToBottomEdge, "precondition: held")

        fixture.beginUserDrag()

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                       accuracy: 1e-6, "the row has not moved…")
        XCTAssertFalse(fixture.listView.isStrictlyPinnedToBottomEdge, "…but it is no longer held")
    }

    func testNotStrictlyPinnedWithoutAPinnedRow() throws {
        let fixture = VirtualListFixture(itemCount: 22, itemHeight: 50, viewport: viewport)

        XCTAssertFalse(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    /// A reply that outgrows the viewport does NOT end the pin. The slack clamps to zero there and the
    /// LATCH carries the hold alone, which is the whole division of labour: the slack answers whether
    /// there is scroll room, the latch answers whether the row is held.
    ///
    /// Viewport 400, reply 400, pinned 60: `span` is 460, so the raw slack would be `400 - 460 = -60`
    /// and clamps to 0 — the pin's target is inside the natural scroll range and needs no extra room.
    func testStillStrictlyPinnedOnceTheReplyOutgrowsTheViewport() throws {
        let fixture = self.fixture()
        self.armPin(fixture)
        var items: [CoreListItem] = [
            ContentResizableItem(id: replyId, contentHeight: 400),
            PinnedFixedHeightItem(id: pinnedId, height: 60)
        ]
        items.append(contentsOf: fixture.listView.items.dropFirst(2))
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), 0, accuracy: 1e-6,
                       "no extra scroll room is needed once the content above fills the viewport")
        XCTAssertTrue(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    /// The case the query must still reject, and the reason a latch beats a geometric test: the row is
    /// sitting exactly on the bottom edge and NOTHING is holding it there. `ListViewImpl` needs
    /// `pinToEdgeTopInset > 0 || extension > 0` to detect this (`ListView.swift:2712-2720`); the latch
    /// answers it directly, and answers it correctly in the tall-content regime too, where that guard
    /// reads false on a row that IS held.
    ///
    /// Viewport 400, pinned 60, so a 340 reply lands `span == visibleArea` on the nose.
    func testNotStrictlyPinnedWhenTheRowSitsAtTheEdgeByCoincidence() throws {
        let fixture = self.fixture(replyHeight: 340)

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                       accuracy: 1e-6, "precondition: the row IS on the bottom edge")
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), 0, accuracy: 1e-6,
                       "precondition: slack exactly 0")
        XCTAssertFalse(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    /// An over-tall row hangs off the edge whether or not the slack is gone, and an armed pin is held.
    func testStrictlyPinnedOnExtensionAlone() throws {
        let fixture = self.fixture(replyHeight: 200, pinnedHeight: 300)
        self.armPin(fixture)

        // ext = 300 - 200 = 100; span = 500; slack = max(0, 500 - 500) = 0 — the extension alone.
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), 0, accuracy: 1e-6)
        XCTAssertTrue(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    // MARK: - Collection edges

    /// The shape of a FRESH bot chat: a couple of rows, both loaded edges reachable, everything
    /// shorter than the viewport. `maximum` collapses onto `minimum` here, which is the path
    /// `applyChanges` guards at `:1379-1381`.
    func testShortCollectionWithBothEdgesLoadedStillPins() throws {
        let fixture = self.fixture(
            unpinned: [ContentResizableItem(id: replyId, contentHeight: 100),
                       IdentifiableFixedHeightItem(id: pinnedId, height: 60)],
            pinned: [ContentResizableItem(id: replyId, contentHeight: 100),
                     PinnedFixedHeightItem(id: pinnedId, height: 60)])

        self.armPin(fixture)

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)) + 60, 400,
                       accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), -240, accuracy: 1e-6)
        XCTAssertTrue(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    /// Degenerate: the pinned row IS index 0, so there is nothing above it at all.
    func testPinnedRowAtIndexZero() throws {
        let history: [CoreListItem] = (0..<20).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: 50)
        }
        let fixture = self.fixture(
            unpinned: [IdentifiableFixedHeightItem(id: pinnedId, height: 60)] + history,
            pinned: [PinnedFixedHeightItem(id: pinnedId, height: 60)] + history)
        self.armPin(fixture, pinnedIndex: 0)

        // span = 60; slack = 400 - 60 = 340.
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)), 340,
                       accuracy: 1e-6)
        XCTAssertTrue(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    /// A single-row collection that is itself the pin.
    func testSingleRowCollectionThatIsThePin() throws {
        let fixture = self.fixture(
            unpinned: [IdentifiableFixedHeightItem(id: pinnedId, height: 60)],
            pinned: [PinnedFixedHeightItem(id: pinnedId, height: 60)])

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)), 340,
                       accuracy: 1e-6)
    }

    /// An empty collection must not trap or declare anything.
    func testEmptyCollectionIsInert() throws {
        let fixture = self.fixture()
        fixture.listView.applyChanges(items: [], transition: .easeInOut(duration: 0))

        XCTAssertFalse(fixture.listView.isStrictlyPinnedToBottomEdge)
        XCTAssertTrue(fixture.loadedIndices.isEmpty)
    }

    /// The pinned row losing the flag (the stream finished, the chat cleared it) returns the list to
    /// its ordinary edge with no jump left behind.
    func testRemovingTheFlagReleasesTheSlack() throws {
        let fixture = self.fixture()
        var items: [CoreListItem] = [
            ContentResizableItem(id: replyId, contentHeight: 100),
            IdentifiableFixedHeightItem(id: pinnedId, height: 60)   // same identity, no longer pinned
        ]
        items.append(contentsOf: fixture.listView.items.dropFirst(2))
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: replyId)), 0, accuracy: 1e-6)
        XCTAssertFalse(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    /// An EXPLICIT scroll to the pin, using the placement the backend's `pointOffset` override
    /// computes. This is the one the design asserts "by construction": a `scrollTo` clears
    /// `pinsLoadedTop`, so `alignTopIfUnderfilled` would drag the window back to the top edge — except
    /// that the resolver's placement puts `window.minY` at exactly `viewportInsets.top + slack`, which
    /// IS the effective `topEdge`, so its `window.minY > topEdge` guard is false. Against a raw
    /// `topEdge` the row would land at 0 instead of 340.
    func testExplicitScrollToThePinLandsOnIt() throws {
        let fixture = self.fixture()
        fixture.scroll(to: -100)
        XCTAssertFalse(fixture.listView.isStrictlyPinnedToBottomEdge, "precondition: moved off")

        // The backend's override, in CoreList's resolver convention (offset from the top inset edge):
        // `(H - insets.bottom + ext) - height - insets.top` = (400 - 0 + 0) - 60 - 0 = 340. Insets are
        // zero in this suite, so `viewportHeight` and the content area coincide.
        let viewportHeight = viewport.height
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: 1) { height, _ in
                let ext = max(0, height - viewportHeight * 0.5)
                return (viewportHeight + ext) - height
            },
            transition: .easeInOut(duration: 0))

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: pinnedId)), 340,
                       accuracy: 1e-6)
        XCTAssertTrue(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    /// Two pinned rows: the LOWEST index wins, matching `lowestPinnedIndex`.
    func testLowestPinnedIndexWins() throws {
        let upperId = UUID()
        let history: [CoreListItem] = (0..<20).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: 50)
        }
        let fixture = self.fixture(
            unpinned: [ContentResizableItem(id: replyId, contentHeight: 100),
                       IdentifiableFixedHeightItem(id: upperId, height: 60),
                       IdentifiableFixedHeightItem(id: pinnedId, height: 60)] + history,
            pinned: [ContentResizableItem(id: replyId, contentHeight: 100),
                     PinnedFixedHeightItem(id: upperId, height: 60),
                     PinnedFixedHeightItem(id: pinnedId, height: 60)] + history)

        XCTAssertEqual(try XCTUnwrap(fixture.settledScreenY(identity: upperId)) + 60, 400,
                       accuracy: 1e-6, "index 1 is the pin; index 2 is just another row")
    }
}
