import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// The read-state synchronization table persists pending `Push`/`Validate`
/// operations so they survive a relaunch. `get()` must return every operation
/// that `beforeCommit()` wrote.
final class MessageHistorySynchronizeReadStateTableTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    private var valueBox: SqliteValueBox!

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "MessageHistorySynchronizeReadStateTableTests")
        self.basePath = NSTemporaryDirectory() + "MessageHistorySynchronizeReadStateTableTests-" + UUID().uuidString
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

    private func makeTable() -> MessageHistorySynchronizeReadStateTable {
        return MessageHistorySynchronizeReadStateTable(valueBox: self.valueBox, table: MessageHistorySynchronizeReadStateTable.tableSpec(15), useCaches: true)
    }

    private func peerId(_ namespace: Int32, _ id: Int64) -> PeerId {
        return PeerId(namespace: PeerId.Namespace._internalFromInt32Value(namespace), id: PeerId.Id._internalFromInt64Value(id))
    }

    func testPersistedOperationsAreReadBackByAFreshTableInstance() {
        let user = self.peerId(0, 123456)
        let channel = self.peerId(1, 9876543210)
        let secret = self.peerId(3, -42)

        self.queue.sync {
            self.valueBox.begin()
            let writer = self.makeTable()
            var operations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
            writer.set(user, operation: .Validate, operations: &operations)
            writer.set(channel, operation: .Push(state: nil, thenSync: true), operations: &operations)
            writer.set(secret, operation: .Push(state: nil, thenSync: false), operations: &operations)
            writer.beforeCommit()
            self.valueBox.commit()
        }

        var readBack: [PeerId: PeerReadStateSynchronizationOperation] = [:]
        self.queue.sync {
            readBack = self.makeTable().get(getCombinedPeerReadState: { _ in nil })
        }

        XCTAssertEqual(readBack.count, 3)
        XCTAssertEqual(readBack[user], .Validate)
        XCTAssertEqual(readBack[channel], .Push(state: nil, thenSync: true))
        XCTAssertEqual(readBack[secret], .Push(state: nil, thenSync: false))
    }

    func testRemovedOperationIsNotReadBack() {
        let user = self.peerId(0, 1)
        let other = self.peerId(0, 2)

        self.queue.sync {
            self.valueBox.begin()
            let writer = self.makeTable()
            var operations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
            writer.set(user, operation: .Validate, operations: &operations)
            writer.set(other, operation: .Validate, operations: &operations)
            writer.beforeCommit()
            writer.set(user, operation: nil, operations: &operations)
            writer.beforeCommit()
            self.valueBox.commit()
        }

        var readBack: [PeerId: PeerReadStateSynchronizationOperation] = [:]
        self.queue.sync {
            readBack = self.makeTable().get(getCombinedPeerReadState: { _ in nil })
        }

        XCTAssertEqual(Array(readBack.keys), [other])
    }
}
