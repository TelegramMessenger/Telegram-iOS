import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// Per-peer storage statistics: every peer that references an item must be
/// credited with the item's size exactly once, so that the debit applied to every
/// referencing peer on removal brings the peer back to what its other items sum to.
final class StorageBoxPeerStatsTests: XCTestCase {
    private let contentType: UInt8 = 3

    private var basePath: String!
    private var storageBox: StorageBox!

    override func setUp() {
        super.setUp()
        self.basePath = NSTemporaryDirectory() + "StorageBoxPeerStatsTests-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)
        self.storageBox = StorageBox(logger: StorageBox.Logger(impl: { _ in }), basePath: self.basePath, isMainProcess: true)
    }

    override func tearDown() {
        self.storageBox = nil
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    // MARK: - Helpers

    private func peer(_ id: Int64) -> PeerId {
        return PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(id))
    }

    private func reference(_ peerId: PeerId, message: Int32) -> StorageBox.Reference {
        return StorageBox.Reference(peerId: peerId.toInt64(), messageNamespace: 0, messageId: message)
    }

    private func itemId(_ name: String) -> Data {
        return name.data(using: .utf8)!
    }

    /// Mirrors MediaBox: the reference is registered without a size, and the size
    /// arrives separately once the file is complete.
    private func download(_ item: String, by peerId: PeerId, message: Int32, size: Int64) {
        self.storageBox.add(reference: self.reference(peerId, message: message), to: self.itemId(item), contentType: self.contentType)
        self.storageBox.update(id: self.itemId(item), size: size)
    }

    private func peerSize(_ peerId: PeerId) -> Int64 {
        let stats = self.allStats()
        return stats.peers[peerId]?.contentTypes[self.contentType]?.size ?? 0
    }

    private func allStats() -> StorageBox.AllStats {
        let expectation = self.expectation(description: "stats")
        var result: StorageBox.AllStats?
        let disposable = self.storageBox.getAllStats().start(next: { stats in
            result = stats
            expectation.fulfill()
        })
        self.wait(for: [expectation], timeout: 5.0)
        disposable.dispose()
        return result!
    }

    // MARK: - Tests

    func testPeerReferencingAnAlreadyStoredItemIsCreditedWithItsSize() {
        let first = self.peer(1)
        let second = self.peer(2)

        self.download("shared", by: first, message: 10, size: 5_000)
        self.storageBox.add(reference: self.reference(second, message: 20), to: self.itemId("shared"), contentType: self.contentType)

        XCTAssertEqual(self.peerSize(first), 5_000)
        XCTAssertEqual(self.peerSize(second), 5_000)
    }

    func testRemovingASharedItemLeavesEachPeerWithItsOwnItems() {
        let first = self.peer(1)
        let second = self.peer(2)

        self.download("own-of-first", by: first, message: 10, size: 10_000)
        self.download("own-of-second", by: second, message: 20, size: 7_000)
        self.download("shared", by: first, message: 11, size: 5_000)
        self.storageBox.add(reference: self.reference(second, message: 21), to: self.itemId("shared"), contentType: self.contentType)

        self.storageBox.remove(ids: [self.itemId("shared")])

        XCTAssertEqual(self.peerSize(first), 10_000)
        XCTAssertEqual(self.peerSize(second), 7_000)
    }

    func testSamePeerReferencingAnItemFromASecondMessageIsNotCreditedTwice() {
        let peer = self.peer(1)

        self.download("shared", by: peer, message: 10, size: 5_000)
        self.storageBox.add(reference: self.reference(peer, message: 11), to: self.itemId("shared"), contentType: self.contentType)

        XCTAssertEqual(self.peerSize(peer), 5_000)
    }

    func testTotalIsCountedOncePerItemRegardlessOfReferencingPeers() {
        let first = self.peer(1)
        let second = self.peer(2)

        self.download("shared", by: first, message: 10, size: 5_000)
        self.storageBox.add(reference: self.reference(second, message: 20), to: self.itemId("shared"), contentType: self.contentType)

        XCTAssertEqual(self.allStats().total.contentTypes[self.contentType]?.size, 5_000)
    }
}
