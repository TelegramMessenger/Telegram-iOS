import XCTest
import UIKit
@testable import CoreListDemo

/// `animateInsertedBlock` lets a host slide a run of freshly inserted rows in from beyond one edge of
/// where they settled, as one rigid block. The chat history backend uses it for messages arriving at
/// the newest edge, where `ListViewImpl` gets the same movement from
/// `ChatMessageItemView.animateInsertion` — a mechanism that is inert under a host that owns the
/// node's frame.
///
/// Sibling of `InsertionFadeSuppressionTests`: the fade and the slide are the two things that can
/// happen to an entering row, and both have to survive the same re-entrancy deferral.
final class InsertedBlockSlideTests: XCTestCase {
    private final class Item: CoreListItem {
        let id: Int
        let height: CGFloat

        var identity: AnyHashable { id }

        init(id: Int, height: CGFloat = 50) {
            self.id = id
            self.height = height
        }

        func view() -> UIView & CoreListItemView {
            FixedHeightItemView(height: height)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? Item)?.id == id
        }
    }

    private func makeFixture(ids: Range<Int>) -> VirtualListFixture {
        VirtualListFixture(viewport: CGSize(width: 390, height: 300),
                           items: ids.map { Item(id: $0) },
                           preloadMargin: 100)
    }

    /// Prepends `newIds` — inside the loaded window at any preload margin, so the rows have layers.
    private func itemsPrepending(_ newIds: [Int], to ids: Range<Int>) -> [CoreListItem] {
        newIds.map { Item(id: $0) } + ids.map { Item(id: $0) }
    }

    private func applyArrival(_ fixture: VirtualListFixture,
                              newIds: [Int],
                              to ids: Range<Int>,
                              origin: CoreListBlockOrigin = .beforeBlock,
                              transition: CoreListTransition = .easeInOut(duration: 1)) {
        fixture.listView.applyChanges(items: itemsPrepending(newIds, to: ids),
                                      transition: transition)
        fixture.listView.animateInsertedBlock(identities: newIds.map { AnyHashable($0) },
                                              origin: origin,
                                              transition: transition)
    }

    func testAnEnteringBlockStartsOneBlockHeightBeforeItsSettledPosition() throws {
        let fixture = makeFixture(ids: 0..<10)

        applyArrival(fixture, newIds: [999], to: 0..<10)

        let track = try XCTUnwrap(fixture.positionTrack(identity: AnyHashable(999)))
        XCTAssertEqual(track.from, -50, accuracy: 1e-9)
        XCTAssertEqual(track.to, 0, accuracy: 1e-9)
    }

    /// The whole point of the "block" framing: three rows arriving together travel by the height of
    /// all three, identically, so their spacing is preserved for the entire travel. Per-row
    /// displacement would give each one a different offset and fan them out.
    func testTheBlockTravelsRigidly() throws {
        let fixture = makeFixture(ids: 0..<10)

        applyArrival(fixture, newIds: [999, 998, 997], to: 0..<10)

        let offsets = try [999, 998, 997].map { id in
            try XCTUnwrap(fixture.positionTrack(identity: AnyHashable(id))).from
        }
        for offset in offsets {
            XCTAssertEqual(offset, -150, accuracy: 1e-9)
        }
    }

    func testAfterBlockTravelsFromTheOtherSide() throws {
        let fixture = makeFixture(ids: 0..<10)

        applyArrival(fixture, newIds: [999, 998], to: 0..<10, origin: .afterBlock)

        let track = try XCTUnwrap(fixture.positionTrack(identity: AnyHashable(999)))
        XCTAssertEqual(track.from, 100, accuracy: 1e-9)
    }

    /// The control for every assertion above: without it they could all pass on a list that gives an
    /// entering row a position track anyway.
    func testAnEnteringRowHasNoPositionTrackWithoutTheCall() throws {
        let fixture = makeFixture(ids: 0..<10)

        fixture.listView.applyChanges(items: itemsPrepending([999], to: 0..<10),
                                      transition: .easeInOut(duration: 1))

        XCTAssertNil(fixture.positionTrack(identity: AnyHashable(999)))
    }

    func testAnImmediatePassSlidesNothing() throws {
        let fixture = makeFixture(ids: 0..<10)

        applyArrival(fixture, newIds: [999], to: 0..<10, transition: .immediate)

        XCTAssertNil(fixture.positionTrack(identity: AnyHashable(999)))
    }

    /// The shape a real chat arrival takes: the history view is a bounded sliding window, so the row
    /// landing at one end pushes one off the other end in the SAME pass. The entering block must still
    /// travel — the departure is unrelated to it, and it is not even loaded.
    func testAnArrivalThatAlsoDropsRowsOffTheFarEndStillSlides() throws {
        let fixture = makeFixture(ids: 0..<40)

        // 999 arrives at the front; 39 falls out of the collection at the back.
        let slid: [CoreListItem] = [Item(id: 999)] + (0..<39).map { Item(id: $0) }
        fixture.listView.applyChanges(items: slid, transition: .easeInOut(duration: 1))
        fixture.listView.animateInsertedBlock(identities: [AnyHashable(999)],
                                              origin: .beforeBlock,
                                              transition: .easeInOut(duration: 1))

        let track = try XCTUnwrap(fixture.positionTrack(identity: AnyHashable(999)))
        XCTAssertEqual(track.from, -50, accuracy: 1e-9)
        XCTAssertEqual(track.to, 0, accuracy: 1e-9)
    }

    /// A row outside the loaded window has no layer to animate, and is off screen anyway. Naming it
    /// must be a no-op rather than a crash or a track on the wrong row.
    func testUnloadedRowsAreSkipped() throws {
        let fixture = makeFixture(ids: 0..<200)

        fixture.listView.applyChanges(items: itemsPrepending([999], to: 0..<200),
                                      transition: .easeInOut(duration: 1))
        let unloaded = try XCTUnwrap(fixture.loadedIndices.last) + 20
        XCTAssertNil(fixture.view(identity: AnyHashable(unloaded)),
                     "index \(unloaded) is loaded — the test proves nothing")

        fixture.listView.animateInsertedBlock(identities: [AnyHashable(999), AnyHashable(unloaded)],
                                              origin: .beforeBlock,
                                              transition: .easeInOut(duration: 1))

        // The loaded member still travels by ITS OWN height only: an unloaded row contributes no
        // measured height, so it cannot stretch the block it is not visibly part of.
        let track = try XCTUnwrap(fixture.positionTrack(identity: AnyHashable(999)))
        XCTAssertEqual(track.from, -50, accuracy: 1e-9)
        XCTAssertNil(fixture.positionTrack(identity: AnyHashable(unloaded)))
    }

    /// Fires a closure from inside `update(width:transition:)`, i.e. while a pass is running, so a
    /// nested `applyChanges` hits the re-entrancy guard. Same device as
    /// `InsertionFadeSuppressionTests`.
    private final class TriggerItemView: UIView, CoreListItemView {
        var onContentDidChange: ((Bool) -> Void)?
        var onUpdate: (@MainActor () -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError()
        }

        nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
            MainActor.assumeIsolated {
                onUpdate?()
            }
            return 50
        }
    }

    private final class TriggerItem: CoreListItem {
        let id: Int
        private let onUpdate: @MainActor () -> Void

        var identity: AnyHashable { id }

        init(id: Int, onUpdate: @escaping @MainActor () -> Void) {
            self.id = id
            self.onUpdate = onUpdate
        }

        func view() -> UIView & CoreListItemView {
            let view = TriggerItemView(frame: .zero)
            view.onUpdate = onUpdate
            return view
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? TriggerItem)?.id == id
        }
    }

    /// The trap this API exists to avoid on the host side: `applyChanges` landing inside another pass
    /// re-dispatches itself and returns having done nothing, so a caller reading the window straight
    /// afterwards would displace the PREVIOUS window's rows. Deferring onto the same scheduler is what
    /// makes "call it right after `applyChanges`" honest.
    func testTheSlideSurvivesTheReentrancyDeferral() throws {
        let fixture = makeFixture(ids: 0..<10)

        var nestedArrival: (@MainActor () -> Void)?
        var didTrigger = false
        let trigger = TriggerItem(id: -1) {
            guard !didTrigger else { return }
            didTrigger = true
            nestedArrival?()
        }

        let outerItems: [CoreListItem] = [trigger] + (0..<10).map { Item(id: $0) }
        let nestedItems: [CoreListItem] = [Item(id: 999), trigger] + (0..<10).map { Item(id: $0) }

        nestedArrival = { [unowned fixture] in
            fixture.listView.applyChanges(items: nestedItems, transition: .easeInOut(duration: 1))
            fixture.listView.animateInsertedBlock(identities: [AnyHashable(999)],
                                                  origin: .beforeBlock,
                                                  transition: .easeInOut(duration: 1))
        }

        // Inserting `trigger` builds its view, whose `update` fires the nested pass mid-flight.
        fixture.listView.applyChanges(items: outerItems, transition: .easeInOut(duration: 1))

        // Occupancy probe: without this a green test could mean the nested pass never ran.
        XCTAssertTrue(didTrigger, "the nested pass never fired — the test proves nothing")

        fixture.flushScheduler()

        let track = try XCTUnwrap(fixture.positionTrack(identity: AnyHashable(999)))
        XCTAssertEqual(track.from, -50, accuracy: 1e-9)
    }

    /// A second arrival landing mid-slide composes with the one in flight instead of restarting from a
    /// full block height — which is the property that comes free from going through
    /// `transitionPosition` rather than adding a raw additive animation to the layer.
    func testASecondArrivalMidSlideResumesFromWhereTheFirstHasGot() throws {
        let fixture = makeFixture(ids: 0..<10)

        applyArrival(fixture, newIds: [999], to: 0..<10)
        fixture.clock.advance(by: 0.5)

        let inFlight = try XCTUnwrap(fixture.animationController.positionOffset(identity: AnyHashable(999),
                                                                               at: fixture.animationController.now()))
        XCTAssertLessThan(inFlight, 0, "the first slide already settled — the test proves nothing")
        XCTAssertGreaterThan(inFlight, -50)

        fixture.listView.applyChanges(items: itemsPrepending([998, 999], to: 0..<10),
                                      transition: .easeInOut(duration: 1))
        fixture.listView.animateInsertedBlock(identities: [AnyHashable(998)],
                                              origin: .beforeBlock,
                                              transition: .easeInOut(duration: 1))

        // 999 is a survivor of the second pass, not a member of its block, so its track is replaced by
        // the ordinary survivor path — from `oldSettled + inFlightOffset - newSettled`. Its settled
        // position moved down by 998's height, so the composition is exactly the offset it had reached
        // plus that push: continuous at the boundary, with the in-flight travel neither dropped nor
        // counted twice.
        let resumed = try XCTUnwrap(fixture.positionTrack(identity: AnyHashable(999)))
        XCTAssertEqual(resumed.from, inFlight - 50, accuracy: 1e-9)
        XCTAssertEqual(resumed.to, 0, accuracy: 1e-9)
    }
}
