import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// `CachedPeerDataTable.get` remembers peers that have no stored row, so the chat list does not query
/// SQLite for them on every render. A remembered miss must never hide data: a `set` replaces it, and
/// `clearMemoryCache` (which `afterBegin` runs whenever another process changed the database) drops it.
final class CachedPeerDataTableMissTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    private var valueBox: SqliteValueBox!

    override func setUp() {
        super.setUp()
        let _ = FixturePeer.register
        self.queue = Queue(name: "CachedPeerDataTableMissTests")
        self.basePath = NSTemporaryDirectory() + "CachedPeerDataTableMissTests-" + UUID().uuidString
        self.queue.sync {
            self.valueBox = SqliteValueBox(basePath: self.basePath, queue: self.queue, isTemporary: true, isReadOnly: false, useCaches: true, removeDatabaseOnError: true, encryptionParameters: nil, upgradeProgress: { _ in }, inMemory: true)
        }
        XCTAssertNotNil(self.valueBox)
    }

    override func tearDown() {
        self.queue.sync {
            self.valueBox?.internalClose()
            self.valueBox = nil
        }
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    private func makeTable(useCaches: Bool) -> CachedPeerDataTable {
        return CachedPeerDataTable(valueBox: self.valueBox, table: CachedPeerDataTable.tableSpec(1200), useCaches: useCaches)
    }

    private func peerId(_ value: Int64) -> PeerId {
        return PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(value))
    }

    private func commit(_ table: CachedPeerDataTable) {
        self.valueBox.begin()
        table.beforeCommit()
        self.valueBox.commit()
    }

    func testSetReplacesARememberedMiss() {
        self.queue.sync {
            let table = self.makeTable(useCaches: true)
            let peerId = self.peerId(1)
            XCTAssertNil(table.get(peerId))
            XCTAssertNil(table.get(peerId))

            table.set(id: peerId, data: FixtureCachedPeerData(peerIds: [self.peerId(2)]))
            XCTAssertEqual((table.get(peerId) as? FixtureCachedPeerData)?.peerIds, [self.peerId(2)])
            self.commit(table)
            XCTAssertEqual((table.get(peerId) as? FixtureCachedPeerData)?.peerIds, [self.peerId(2)])
        }
    }

    func testSetAfterAMissReportsNoPreviousValue() {
        self.queue.sync {
            let table = self.makeTable(useCaches: true)
            let peerId = self.peerId(1)
            XCTAssertNil(table.get(peerId))
            table.set(id: peerId, data: FixtureCachedPeerData(peerIds: [self.peerId(3)]))
            let update = table.transactionUpdatedPeers()[peerId]
            XCTAssertNotNil(update)
            XCTAssertNil(update?.0)
            XCTAssertEqual((update?.1 as? FixtureCachedPeerData)?.peerIds, [self.peerId(3)])
        }
    }

    func testClearMemoryCacheForgetsMissesSoAnotherWritersRowIsRead() {
        self.queue.sync {
            let reader = self.makeTable(useCaches: true)
            let writer = self.makeTable(useCaches: true)
            let peerId = self.peerId(1)
            XCTAssertNil(reader.get(peerId))

            writer.set(id: peerId, data: FixtureCachedPeerData(peerIds: [self.peerId(4)]))
            self.commit(writer)

            reader.clearMemoryCache()
            XCTAssertEqual((reader.get(peerId) as? FixtureCachedPeerData)?.peerIds, [self.peerId(4)])
        }
    }

    func testWithoutCachesMissesDoNotOutliveTheTransaction() {
        self.queue.sync {
            let reader = self.makeTable(useCaches: false)
            let writer = self.makeTable(useCaches: true)
            let peerId = self.peerId(1)
            XCTAssertNil(reader.get(peerId))
            self.commit(reader)

            writer.set(id: peerId, data: FixtureCachedPeerData(peerIds: [self.peerId(5)]))
            self.commit(writer)

            XCTAssertEqual((reader.get(peerId) as? FixtureCachedPeerData)?.peerIds, [self.peerId(5)])
        }
    }

    func testStoredRowsAreStillFoundAfterOtherPeersMiss() {
        self.queue.sync {
            let writer = self.makeTable(useCaches: true)
            writer.set(id: self.peerId(10), data: FixtureCachedPeerData(peerIds: [self.peerId(11)]))
            self.commit(writer)

            let reader = self.makeTable(useCaches: true)
            XCTAssertNil(reader.get(self.peerId(12)))
            XCTAssertEqual((reader.get(self.peerId(10)) as? FixtureCachedPeerData)?.peerIds, [self.peerId(11)])
            XCTAssertNil(reader.get(self.peerId(12)))
        }
    }
}
