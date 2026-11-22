import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// `SqliteValueBox.exists` answers from `SELECT 1` instead of copying the value out. It must agree with
/// `get(...) != nil` on every table layout Postbox creates: rowid and `WITHOUT ROWID` binary tables, and
/// int64 tables, including rows whose value is empty.
final class SqliteValueBoxExistsTests: XCTestCase {
    private let tables: [ValueBoxTable] = [
        ValueBoxTable(id: 1100, keyType: .binary, compactValuesOnCreation: false),
        ValueBoxTable(id: 1101, keyType: .binary, compactValuesOnCreation: true),
        ValueBoxTable(id: 1102, keyType: .int64, compactValuesOnCreation: false),
        ValueBoxTable(id: 1103, keyType: .int64, compactValuesOnCreation: true),
    ]

    private var queue: Queue!
    private var basePath: String!
    private var valueBox: SqliteValueBox!

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "SqliteValueBoxExistsTests")
        self.basePath = NSTemporaryDirectory() + "SqliteValueBoxExistsTests-" + UUID().uuidString
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

    private func key(_ table: ValueBoxTable, _ value: Int64) -> ValueBoxKey {
        switch table.keyType {
        case .int64:
            let key = ValueBoxKey(length: 8)
            key.setInt64(0, value: value)
            return key
        case .binary:
            let key = ValueBoxKey(length: 12)
            key.setInt64(0, value: value)
            key.setInt32(8, value: 7)
            return key
        }
    }

    private func value(length: Int) -> WriteBuffer {
        let buffer = WriteBuffer()
        if length > 0 {
            let bytes = [UInt8](repeating: 0x5a, count: length)
            bytes.withUnsafeBytes { buffer.write($0.baseAddress!, offset: 0, length: length) }
        }
        return buffer
    }

    func testExistsMatchesGetOnEveryTableLayout() {
        self.queue.sync {
            for table in self.tables {
                XCTAssertFalse(self.valueBox.exists(table, key: self.key(table, 1)), "table \(table.id) before creation")

                self.valueBox.begin()
                self.valueBox.set(table, key: self.key(table, 1), value: self.value(length: 64))
                self.valueBox.set(table, key: self.key(table, 2), value: self.value(length: 0))
                self.valueBox.set(table, key: self.key(table, 3), value: self.value(length: 20_000))
                self.valueBox.commit()

                for id in Int64(0) ... 4 {
                    let key = self.key(table, id)
                    XCTAssertEqual(self.valueBox.exists(table, key: key), self.valueBox.get(table, key: key) != nil, "table \(table.id) key \(id)")
                }
                XCTAssertTrue(self.valueBox.exists(table, key: self.key(table, 1)))
                XCTAssertTrue(self.valueBox.exists(table, key: self.key(table, 2)))
                XCTAssertTrue(self.valueBox.exists(table, key: self.key(table, 3)))
                XCTAssertFalse(self.valueBox.exists(table, key: self.key(table, 4)))

                self.valueBox.begin()
                self.valueBox.remove(table, key: self.key(table, 1), secure: false)
                self.valueBox.commit()
                XCTAssertFalse(self.valueBox.exists(table, key: self.key(table, 1)))
                XCTAssertTrue(self.valueBox.exists(table, key: self.key(table, 2)))
            }
        }
    }

    func testExistsSurvivesRepeatedCallsAndInterleavedReads() {
        let table = self.tables[1]
        self.queue.sync {
            self.valueBox.begin()
            for id in Int64(0) ..< 50 where id % 2 == 0 {
                self.valueBox.set(table, key: self.key(table, id), value: self.value(length: 16))
            }
            self.valueBox.commit()

            for _ in 0 ..< 3 {
                for id in Int64(0) ..< 50 {
                    XCTAssertEqual(self.valueBox.exists(table, key: self.key(table, id)), id % 2 == 0)
                    let _ = self.valueBox.get(table, key: self.key(table, id))
                }
            }
        }
    }
}
