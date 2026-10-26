import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// `SqliteValueBox.range` on an `.int64`-keyed table must pick the scan direction
/// from the NUMERIC order of the two bounds, because the SQL it issues binds the
/// bounds as integers (`key > ? AND key < ?`). Picking it any other way makes the
/// window empty for ordinary bound pairs.
final class SqliteValueBoxInt64RangeTests: XCTestCase {
    private let table = ValueBoxTable(id: 1000, keyType: .int64, compactValuesOnCreation: true)

    private var queue: Queue!
    private var basePath: String!
    private var valueBox: SqliteValueBox!

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "SqliteValueBoxInt64RangeTests")
        self.basePath = NSTemporaryDirectory() + "SqliteValueBoxInt64RangeTests-" + UUID().uuidString
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

    // MARK: - Helpers

    private func int64Key(_ value: Int64) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: value)
        return key
    }

    private func store(_ keys: [Int64]) {
        self.queue.sync {
            self.valueBox.begin()
            let buffer = WriteBuffer()
            for value in keys {
                buffer.reset()
                var payload = value
                buffer.write(&payload, offset: 0, length: 8)
                self.valueBox.set(self.table, key: self.int64Key(value), value: buffer)
            }
            self.valueBox.commit()
        }
    }

    private func scanKeys(start: Int64, end: Int64, limit: Int = 0) -> [Int64] {
        var result: [Int64] = []
        self.queue.sync {
            self.valueBox.range(self.table, start: self.int64Key(start), end: self.int64Key(end), keys: { key in
                result.append(key.getInt64(0))
                return true
            }, limit: limit)
        }
        return result
    }

    private func scanValues(start: Int64, end: Int64, limit: Int = 0) -> [(key: Int64, value: Int64)] {
        var result: [(key: Int64, value: Int64)] = []
        self.queue.sync {
            self.valueBox.range(self.table, start: self.int64Key(start), end: self.int64Key(end), values: { key, value in
                var payload: Int64 = 0
                value.read(&payload, offset: 0, length: 8)
                result.append((key.getInt64(0), payload))
                return true
            }, limit: limit)
        }
        return result
    }

    // MARK: - Tests

    func testAscendingKeyRangeReturnsKeysStrictlyBetweenBoundsInNumericOrder() {
        self.store([1, 2, 100, 255, 256, 1000])

        // 1 and 256 differ in which byte is non-zero, so a byte-reversed comparison
        // orders them backwards and issues `key > 256 AND key < 1`.
        XCTAssertEqual(self.scanKeys(start: 1, end: 256), [2, 100, 255])
    }

    func testDescendingKeyRangeReturnsKeysInDescendingNumericOrder() {
        self.store([1, 2, 100, 255, 256, 1000])

        XCTAssertEqual(self.scanKeys(start: 256, end: 1), [255, 100, 2])
    }

    func testAscendingValueRangeReturnsMatchingValues() {
        self.store([1, 2, 100, 255, 256, 1000])

        let scanned = self.scanValues(start: 1, end: 256)
        XCTAssertEqual(scanned.map { $0.key }, [2, 100, 255])
        XCTAssertEqual(scanned.map { $0.value }, [2, 100, 255])
    }

    func testDescendingValueRangeReturnsMatchingValuesInDescendingOrder() {
        self.store([1, 2, 100, 255, 256, 1000])

        let scanned = self.scanValues(start: 256, end: 1)
        XCTAssertEqual(scanned.map { $0.key }, [255, 100, 2])
        XCTAssertEqual(scanned.map { $0.value }, [255, 100, 2])
    }

    func testLimitAppliesInBothDirections() {
        self.store([1, 2, 100, 255, 256, 1000])

        XCTAssertEqual(self.scanKeys(start: 0, end: 2000, limit: 2), [1, 2])
        XCTAssertEqual(self.scanKeys(start: 2000, end: 0, limit: 2), [1000, 256])
    }

    func testFullSignedRangeSpansNegativeAndPositiveKeys() {
        self.store([-5, -1, 0, 7])

        XCTAssertEqual(self.scanKeys(start: Int64.min, end: Int64.max), [-5, -1, 0, 7])
        XCTAssertEqual(self.scanKeys(start: Int64.max, end: Int64.min), [7, 0, -1, -5])
    }
}
