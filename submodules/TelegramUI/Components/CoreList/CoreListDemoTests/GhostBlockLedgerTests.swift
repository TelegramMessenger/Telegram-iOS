import XCTest
@testable import CoreListDemo

final class GhostBlockLedgerTests: XCTestCase {
    func testMaxYAttachmentSubtractsSourceLocalEdgeFromLiveBoundary() throws {
        let ledger = GhostBlockLedger()
        let block = ledger.insert(rootY: -50,
                                  localMinY: 0,
                                  localMaxY: 50,
                                  attachmentEdge: .maxY,
                                  witness: .liveMinY("next"),
                                  visibleMemberCount: 1)

        let targets = ledger.resolvedTargets(liveEdges: [
            AnyHashable("next"): GhostLiveEdges(minY: 0, maxY: 50)
        ])

        XCTAssertEqual(targets[block], -50)
        XCTAssertEqual(try XCTUnwrap(ledger.snapshot(for: block)).attachmentEdge, .maxY)
    }

    func testBoundaryLinkAtomicallyChangesSourceAndWitness() throws {
        let ledger = GhostBlockLedger()
        let block = ledger.insert(rootY: 100,
                                  localMinY: 0,
                                  localMaxY: 50,
                                  witness: .liveMinY("old"),
                                  visibleMemberCount: 1)

        XCTAssertTrue(ledger.setBoundaryLink(attachmentEdge: .maxY,
                                             witness: .liveMinY("new"),
                                             for: block))

        let snapshot = try XCTUnwrap(ledger.snapshot(for: block))
        XCTAssertEqual(snapshot.attachmentEdge, .maxY)
        XCTAssertEqual(snapshot.witness, .liveMinY(AnyHashable("new")))
    }

    func testLiveAndGhostEdgesResolveInDependencyOrder() throws {
        let ledger = GhostBlockLedger()
        let anchor = ledger.insert(rootY: 100,
                                   localMinY: 0,
                                   localMaxY: 150,
                                   witness: .liveMinY("row"),
                                   visibleMemberCount: 2)
        let rider = ledger.insert(rootY: 250,
                                  localMinY: 0,
                                  localMaxY: 75,
                                  witness: .ghostMaxY(anchor),
                                  visibleMemberCount: 1)
        let tail = ledger.insert(rootY: 325,
                                 localMinY: 0,
                                 localMaxY: 50,
                                 witness: .ghostMaxY(rider),
                                 visibleMemberCount: 1)

        let targets = ledger.resolvedTargets(liveEdges: [
            AnyHashable("row"): GhostLiveEdges(minY: 140, maxY: 215)
        ])

        XCTAssertEqual(targets[anchor], 140)
        XCTAssertEqual(targets[rider], 290)
        XCTAssertEqual(targets[tail], 365)
    }

    func testCycleIsRejectedWithoutChangingOriginalWitness() throws {
        let ledger = GhostBlockLedger()
        let first = ledger.insert(rootY: 0, localMinY: 0, localMaxY: 75,
                                  witness: .unresolved, visibleMemberCount: 1)
        let second = ledger.insert(rootY: 75, localMinY: 0, localMaxY: 75,
                                   witness: .ghostMaxY(first), visibleMemberCount: 1)

        XCTAssertFalse(ledger.setWitness(.ghostMinY(second), for: first))
        XCTAssertEqual(try XCTUnwrap(ledger.snapshot(for: first)).witness,
                       .unresolved)
    }

    func testMissingLiveGeometryFreezesAtExistingRoot() {
        let ledger = GhostBlockLedger()
        let block = ledger.insert(rootY: 320, localMinY: 0, localMaxY: 75,
                                  witness: .liveMinY("offscreen"),
                                  visibleMemberCount: 1)

        XCTAssertEqual(ledger.resolvedTargets(liveEdges: [:])[block], 320)
    }

    func testCoordinateShiftMovesEveryRootWithoutChangingWitness() throws {
        let ledger = GhostBlockLedger()
        let block = ledger.insert(rootY: 120, localMinY: -5, localMaxY: 80,
                                  witness: .liveMaxY("row"),
                                  visibleMemberCount: 1)
        let witness = try XCTUnwrap(ledger.snapshot(for: block)).witness

        ledger.shiftRoots(by: 40)

        let shifted = try XCTUnwrap(ledger.snapshot(for: block))
        XCTAssertEqual(shifted.settledRootY, 160)
        XCTAssertEqual(shifted.witness, witness)
    }

    func testEmptyReferencedBlockWaitsForDependentThenCollectsCascade() {
        let ledger = GhostBlockLedger()
        let base = ledger.insert(rootY: 100, localMinY: 0, localMaxY: 75,
                                 witness: .unresolved, visibleMemberCount: 1)
        let rider = ledger.insert(rootY: 175, localMinY: 0, localMaxY: 75,
                                  witness: .ghostMaxY(base), visibleMemberCount: 1)

        ledger.removeVisibleMember(from: base)
        XCTAssertTrue(ledger.collectOrphanedEmptyBlocks().isEmpty)
        ledger.removeVisibleMember(from: rider)
        XCTAssertEqual(Set(ledger.collectOrphanedEmptyBlocks()), Set([rider, base]))
        XCTAssertTrue(ledger.snapshots.isEmpty)
    }

    func testInvariantValidationAcceptsAcyclicGraphWithExactDependents() {
        let ledger = GhostBlockLedger()
        let base = ledger.insert(rootY: 10, localMinY: 0, localMaxY: 20,
                                 witness: .liveMinY("row"), visibleMemberCount: 1)
        let rider = ledger.insert(rootY: 30, localMinY: -5, localMaxY: 15,
                                  witness: .ghostMaxY(base), visibleMemberCount: 1)
        _ = ledger.insert(rootY: 45, localMinY: 0, localMaxY: 10,
                          witness: .ghostMinY(rider), visibleMemberCount: 1)

        ledger.assertInvariants()
    }

    /// A carousel's departed strip is parked in viewport space, where a content-coordinate rebase is
    /// not a thing that happened to it. `shiftExitOverlayChildren` moves content-space children to
    /// hold their SCREEN position across a rebase; applying the same delta to a child that is already
    /// screen-anchored would move it instead.
    func testShiftRootsSkipsViewportAnchoredBlocks() {
        let ledger = GhostBlockLedger()
        let content = ledger.insert(rootY: 100,
                                    localMinY: 0,
                                    localMaxY: 50,
                                    witness: .unresolved,
                                    visibleMemberCount: 1)
        let viewportAnchored = ledger.insert(rootY: 200,
                                             localMinY: 0,
                                             localMaxY: 50,
                                             witness: .unresolved,
                                             visibleMemberCount: 1)
        ledger.setAnchoring(.viewport, for: viewportAnchored)

        ledger.shiftRoots(by: -40)

        XCTAssertEqual(ledger.snapshot(for: content)?.settledRootY, 60)
        XCTAssertEqual(ledger.snapshot(for: viewportAnchored)?.settledRootY, 200)
    }

    /// Blocks are born in content space; only an explicit promotion changes that.
    func testBlocksAreBornContentAnchored() {
        let ledger = GhostBlockLedger()
        let id = ledger.insert(rootY: 0,
                               localMinY: 0,
                               localMaxY: 10,
                               witness: .unresolved,
                               visibleMemberCount: 1)
        XCTAssertEqual(ledger.snapshot(for: id)?.anchoring, .content)
    }
}
