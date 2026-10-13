import XCTest
@testable import CoreListDemo

final class ItemDiffTests: XCTestCase {

    private func id(_ x: Int) -> IdentifiableFixedHeightItem {
        // Deterministic UUIDs derived from an integer.
        let s = String(format: "00000000-0000-0000-0000-%012d", x)
        return IdentifiableFixedHeightItem(id: UUID(uuidString: s)!, height: 50)
    }

    func testDiff_noChanges_allSurvivors_inOrder() {
        let old: [CoreListItem] = [id(0), id(1), id(2)]
        let new: [CoreListItem] = [id(0), id(1), id(2)]
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.survivorMap, [0: 0, 1: 1, 2: 2])
        XCTAssertEqual(diff.deletes, [])
        XCTAssertEqual(diff.inserts, [])
    }

    func testDiff_pureInsert_atMiddle() {
        let old: [CoreListItem] = [id(0), id(1), id(2)]
        let new: [CoreListItem] = [id(0), id(99), id(1), id(2)]
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.survivorMap, [0: 0, 1: 2, 2: 3])
        XCTAssertEqual(diff.deletes, [])
        XCTAssertEqual(diff.inserts, [1])
    }

    func testDiff_pureDelete_atMiddle() {
        let old: [CoreListItem] = [id(0), id(1), id(2)]
        let new: [CoreListItem] = [id(0), id(2)]
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.survivorMap, [0: 0, 2: 1])
        XCTAssertEqual(diff.deletes, [1])
        XCTAssertEqual(diff.inserts, [])
    }

    func testDiff_move_singleRow() {
        // Move item 2 to the front: old [0,1,2] → new [2,0,1].
        // Phase 5c (LIS reclassification): survivors' NEW indices in OLD order are [1,2,0];
        // the LIS is [1,2] (items 0,1, which merely shifted while preserving order), so the
        // complement {item 2} is the genuinely-moved row → reclassified to delete(2)+insert(0).
        // (Pre-Phase-5c this returned all-survivors / empty deletes+inserts, which fell to the
        // legacy blanket-cancelled path; the diff now drives the mixed crossfade machinery.)
        let old: [CoreListItem] = [id(0), id(1), id(2)]
        let new: [CoreListItem] = [id(2), id(0), id(1)]
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.survivorMap, [0: 1, 1: 2])
        XCTAssertEqual(diff.deletes, [2])
        XCTAssertEqual(diff.inserts, [0])
    }

    func testDiff_fullReplacement_noSurvivors() {
        let old: [CoreListItem] = [id(0), id(1)]
        let new: [CoreListItem] = [id(10), id(11)]
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.survivorMap, [:])
        XCTAssertEqual(diff.deletes.sorted(), [0, 1])
        XCTAssertEqual(diff.inserts.sorted(), [0, 1])
    }

    func testDiff_empty_old() {
        let old: [CoreListItem] = []
        let new: [CoreListItem] = [id(0), id(1)]
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.survivorMap, [:])
        XCTAssertEqual(diff.deletes, [])
        XCTAssertEqual(diff.inserts.sorted(), [0, 1])
    }

    func testDiff_empty_new() {
        let old: [CoreListItem] = [id(0), id(1)]
        let new: [CoreListItem] = []
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.survivorMap, [:])
        XCTAssertEqual(diff.deletes.sorted(), [0, 1])
        XCTAssertEqual(diff.inserts, [])
    }

    func testComputeDiff_reorder_reclassifiesLISComplementToDeleteInsert() {
        // Move item 5 to the front: old [0,1,2,3,4,5] → new [5,0,1,2,3,4].
        // Survivors' NEW indices in OLD order are [1,2,3,4,5,0]; the LIS is [1,2,3,4,5]
        // (items 0..4), so the complement {item 5} reclassifies to delete(5)+insert(0).
        let old: [CoreListItem] = [id(0), id(1), id(2), id(3), id(4), id(5)]
        let new: [CoreListItem] = [id(5), id(0), id(1), id(2), id(3), id(4)]
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.deletes, [5])
        XCTAssertEqual(diff.inserts, [0])
        XCTAssertEqual(diff.survivorMap[0], 1)
        XCTAssertEqual(diff.survivorMap[1], 2)
        XCTAssertEqual(diff.survivorMap[2], 3)
        XCTAssertEqual(diff.survivorMap[3], 4)
        XCTAssertEqual(diff.survivorMap[4], 5)
        XCTAssertNil(diff.survivorMap[5])
    }

    func testComputeDiff_reorder_recordsMovePairing() {
        // Phase 5c Case C Layer 2: the reorder's reclassification ALSO records the (old, new)
        // pairing in `moves` so the slide-across path can reuse the one view across the
        // delete→insert. The footprint representation is UNCHANGED — the moved id stays in
        // deletes (old slot) and inserts (new slot) so the neighbours' close/open still ride
        // the existing causer footprints; only the moved item's OWN visual changes.
        let old: [CoreListItem] = [id(0), id(1), id(2), id(3), id(4), id(5)]
        let new: [CoreListItem] = [id(5), id(0), id(1), id(2), id(3), id(4)]
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.moves.map { [$0.old, $0.new] }, [[5, 0]])
        XCTAssertEqual(diff.deletes, [5])   // footprint preserved
        XCTAssertEqual(diff.inserts, [0])
    }

    func testComputeDiff_pureDelete_doesNotReclassifyShiftedSurvivors() {
        // Deleting item 0 shifts indices but PRESERVES order — they stay survivors.
        let old: [CoreListItem] = [id(0), id(1), id(2), id(3)]
        let new: [CoreListItem] = [id(1), id(2), id(3)]
        let diff = CoreVirtualListView.computeDiff(old: old, new: new)
        XCTAssertEqual(diff.deletes, [0])
        XCTAssertEqual(diff.inserts, [])
        XCTAssertEqual(diff.survivorMap[1], 0)
        XCTAssertEqual(diff.survivorMap[2], 1)
        XCTAssertEqual(diff.survivorMap[3], 2)
    }
}
