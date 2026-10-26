import XCTest
@testable import CoreListDemo

final class AttachmentRunTests: XCTestCase {
    func testItemWithoutAttachmentsDefaultsToEmptyDictionary() {
        let item = FixedHeightItem(height: 40)
        XCTAssertTrue(item.attachedItems.isEmpty)
    }

    func testCombinesDefaultsToTrue() {
        let attachment = DefaultCombiningAttachment()
        XCTAssertTrue(attachment.combines(with: DefaultCombiningAttachment()))
    }

    private func items(_ specs: [[String: FixedHeightAttachment]]) -> [CoreListItem] {
        specs.enumerated().map { index, attachments in
            AttachedItem(id: index,
                         attachedItems: attachments.reduce(into: [:]) { $0[$1.key] = $1.value })
        }
    }

    func testAdjacentItemsWithTheSameKeyFormOneRun() {
        let list = items([
            ["date": FixedHeightAttachment(label: "Jan 1")],
            ["date": FixedHeightAttachment(label: "Jan 1")],
            ["date": FixedHeightAttachment(label: "Jan 1")],
        ])
        let runs = AttachmentRuns.pendingRuns(in: list, loadedRange: 0..<3)
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].memberRange, 0..<3)
        XCTAssertTrue(runs[0].startsCollectionRun)
        XCTAssertTrue(runs[0].endsCollectionRun)
    }

    func testDifferentKeysProduceDisjointRuns() {
        let list = items([
            ["date": FixedHeightAttachment(label: "Jan 1")],
            ["date": FixedHeightAttachment(label: "Jan 1")],
            ["other": FixedHeightAttachment(label: "Jan 2")],
        ])
        let runs = AttachmentRuns.pendingRuns(in: list, loadedRange: 0..<3)
        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(runs[0].memberRange, 0..<2)
        XCTAssertEqual(runs[1].memberRange, 2..<3)
    }

    func testAGapBreaksARunIntoTwo() {
        let list = items([
            ["date": FixedHeightAttachment(label: "a")],
            [:],
            ["date": FixedHeightAttachment(label: "a")],
        ])
        let runs = AttachmentRuns.pendingRuns(in: list, loadedRange: 0..<3)
        XCTAssertEqual(runs.map(\.memberRange), [0..<1, 2..<3])
    }

    func testCombinesFalseBreaksARunDespiteAMatchingKey() {
        let list = items([
            ["avatar": FixedHeightAttachment(label: "p", combinesWithNeighbours: true)],
            ["avatar": FixedHeightAttachment(label: "p", combinesWithNeighbours: false)],
            ["avatar": FixedHeightAttachment(label: "p", combinesWithNeighbours: true)],
        ])
        let runs = AttachmentRuns.pendingRuns(in: list, loadedRange: 0..<3)
        XCTAssertEqual(runs.map(\.memberRange), [0..<1, 1..<2, 2..<3])
    }

    func testRepresentativeIsTheMemberNearestThePinningEdge() {
        let list = items([
            ["k": FixedHeightAttachment(label: "first", edge: .top)],
            ["k": FixedHeightAttachment(label: "last", edge: .top)],
        ])
        let topRun = AttachmentRuns.pendingRuns(in: list, loadedRange: 0..<2)[0]
        XCTAssertEqual((topRun.representative as? FixedHeightAttachment)?.label, "first")

        let bottomList = items([
            ["k": FixedHeightAttachment(label: "first", edge: .bottom)],
            ["k": FixedHeightAttachment(label: "last", edge: .bottom)],
        ])
        let bottomRun = AttachmentRuns.pendingRuns(in: bottomList, loadedRange: 0..<2)[0]
        XCTAssertEqual((bottomRun.representative as? FixedHeightAttachment)?.label, "last")
    }

    /// A run clipped by the loaded window is NOT a collection-level boundary. This is what keeps
    /// reservation from appearing above an unloaded run head.
    func testLoadedClippingIsNotACollectionBoundary() {
        let list = items(Array(repeating: ["date": FixedHeightAttachment(label: "a")], count: 5))
        let runs = AttachmentRuns.pendingRuns(in: list, loadedRange: 1..<4)
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].memberRange, 1..<4)
        XCTAssertFalse(runs[0].startsCollectionRun)
        XCTAssertFalse(runs[0].endsCollectionRun)
    }

    private func resolve(_ list: [CoreListItem],
                         prior: [AttachmentRuns.PriorRun],
                         nextSerial: inout UInt64)
        -> (assigned: [AttachmentRuns.ResolvedRun], departed: [AttachmentRuns.PriorRun]) {
        AttachmentRuns.assignSerials(
            pending: AttachmentRuns.pendingRuns(in: list, loadedRange: 0..<list.count),
            newIdentities: list.map(\.identity),
            prior: prior,
            nextSerial: &nextSerial
        )
    }

    private func prior(_ serial: UInt64,
                       _ identities: [AnyHashable],
                       edge: CoreListAttachmentEdge = .top,
                       key: AnyHashable = "date") -> AttachmentRuns.PriorRun {
        AttachmentRuns.PriorRun(key: key, serial: serial, memberIdentities: identities, edge: edge)
    }

    private func run(_ ids: [Int],
                     edge: CoreListAttachmentEdge = .top,
                     key: AnyHashable = "date") -> [CoreListItem] {
        ids.map { AttachedItem(id: $0,
                               attachedItems: [key: FixedHeightAttachment(label: "a", edge: edge)]) }
    }

    func testAFreshRunGetsAFreshSerialAndIsMarkedFresh() {
        var next: UInt64 = 0
        let (assigned, departed) = resolve(run([1, 2]), prior: [], nextSerial: &next)
        XCTAssertEqual(assigned.count, 1)
        XCTAssertEqual(assigned[0].serial, 0)
        XCTAssertTrue(assigned[0].isFresh)
        XCTAssertTrue(departed.isEmpty)
        XCTAssertEqual(next, 1)
    }

    func testInsertAtRunHeadKeepsTheSerial() {
        var next: UInt64 = 7
        let (assigned, departed) = resolve(run([9, 1, 2]),
                                           prior: [prior(3, [1, 2])],
                                           nextSerial: &next)
        XCTAssertEqual(assigned.map(\.serial), [3])
        XCTAssertFalse(assigned[0].isFresh)
        XCTAssertTrue(departed.isEmpty)
        XCTAssertEqual(next, 7, "no fresh serial was needed")
    }

    /// A split hands the view to the piece the view is visually in: the witness of a `.top` run is
    /// its first member, so the upper piece keeps it.
    func testSplitGivesTheSerialToThePieceHoldingTheWitness() {
        var next: UInt64 = 10
        var list = run([1, 2])
        list.append(AttachedItem(id: 99))                       // gap
        list.append(contentsOf: run([3, 4]))
        let (assigned, departed) = resolve(list,
                                           prior: [prior(5, [1, 2, 3, 4])],
                                           nextSerial: &next)
        XCTAssertEqual(assigned.map(\.serial), [5, 10])
        XCTAssertEqual(assigned.map(\.isFresh), [false, true])
        XCTAssertTrue(departed.isEmpty)
    }

    /// Deleting the edge-most member must MOVE the view, not recreate it: the witness walks inward.
    func testDeletingTheEdgeMostMemberWalksTheWitnessInward() {
        var next: UInt64 = 10
        let (assigned, departed) = resolve(run([2, 3]),
                                           prior: [prior(5, [1, 2, 3])],
                                           nextSerial: &next)
        XCTAssertEqual(assigned.map(\.serial), [5])
        XCTAssertFalse(assigned[0].isFresh)
        XCTAssertTrue(departed.isEmpty)
    }

    /// A merge keeps the serial nearest the merged run's pinning edge; the loser departs.
    func testMergeKeepsTheEdgeMostSerialAndDepartsTheOther() {
        var next: UInt64 = 10
        let (assigned, departed) = resolve(run([1, 2, 3, 4]),
                                           prior: [prior(5, [1, 2]), prior(6, [3, 4])],
                                           nextSerial: &next)
        XCTAssertEqual(assigned.map(\.serial), [5])
        XCTAssertEqual(departed.map(\.serial), [6])
    }

    /// The same merge with a `.bottom` edge keeps the OTHER serial — the one whose view is already
    /// at the merged run's bottom.
    func testBottomEdgeMergeKeepsTheLowerSerial() {
        var next: UInt64 = 10
        let (assigned, departed) = resolve(run([1, 2, 3, 4], edge: .bottom),
                                           prior: [prior(5, [1, 2], edge: .bottom),
                                                   prior(6, [3, 4], edge: .bottom)],
                                           nextSerial: &next)
        XCTAssertEqual(assigned.map(\.serial), [6])
        XCTAssertEqual(departed.map(\.serial), [5])
    }

    func testARunWhoseMembersAllVanishDeparts() {
        var next: UInt64 = 10
        let (assigned, departed) = resolve([AttachedItem(id: 99)],
                                           prior: [prior(5, [1, 2])],
                                           nextSerial: &next)
        XCTAssertTrue(assigned.isEmpty)
        XCTAssertEqual(departed.map(\.serial), [5])
    }

    func testAPriorRunOfADifferentKeyNeverDonates() {
        var next: UInt64 = 10
        let (assigned, departed) = resolve(run([1, 2]),
                                           prior: [prior(5, [1, 2], key: "avatar")],
                                           nextSerial: &next)
        XCTAssertEqual(assigned.map(\.serial), [10])
        XCTAssertTrue(assigned[0].isFresh)
        XCTAssertEqual(departed.map(\.serial), [5])
    }
}

/// Conforms WITHOUT implementing `combines(with:)`, proving the protocol extension supplies it.
private final class DefaultCombiningAttachment: CoreListAttachedItem {
    var placement: CoreListAttachmentPlacement { .overlay }
    var edge: CoreListAttachmentEdge { .top }
    var isFloating: Bool { true }
    func view() -> UIView & CoreListAttachedItemView { FixedHeightAttachmentView(height: 10) }
    func isEqual(to other: CoreListAttachedItem) -> Bool { other is DefaultCombiningAttachment }
    func apply(to view: UIView & CoreListAttachedItemView, transition: CoreListTransition) {}
}
