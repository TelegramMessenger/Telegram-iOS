import Foundation
import XCTest
import SwiftSignalKit
import RangeSet
@testable import Postbox

/// `MediaBoxFileMap.read` parses `<id>_partial.meta`, a file the app rewrites in place
/// without atomic replacement. Any corruption must surface as a thrown error, which the
/// file context recovers from by resetting the map; it must never trap, because the map
/// is read every time a not-yet-complete resource is requested.
final class MediaBoxFileMapReadTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    private var manager: MediaBoxFileManager!

    private var metaPath: String { return self.basePath + "/resource_partial.meta" }

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "MediaBoxFileMapReadTests")
        self.basePath = NSTemporaryDirectory() + "MediaBoxFileMapReadTests-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)
        self.manager = MediaBoxFileManager(queue: self.queue)
    }

    override func tearDown() {
        self.manager = nil
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    // MARK: - Helpers

    private static let magic: UInt32 = 0x7bac1487

    /// Builds a new-format meta file by hand: magic, crc, count, then the payload
    /// (truncation size followed by `count` offset/length pairs).
    private func writeMeta(crc: UInt32, count: Int32, payload: Data) {
        var data = Data()
        var magic = MediaBoxFileMapReadTests.magic
        var crc = crc
        var count = count
        withUnsafeBytes(of: &magic) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &crc) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        data.append(payload)
        XCTAssertTrue(FileManager.default.createFile(atPath: self.metaPath, contents: data))
    }

    private func read() -> Result<MediaBoxFileMap, Error> {
        var result: Result<MediaBoxFileMap, Error>!
        self.queue.sync {
            do {
                result = .success(try MediaBoxFileMap.read(manager: self.manager, path: self.metaPath))
            } catch let error {
                result = .failure(error)
            }
        }
        return result
    }

    private func assertReadThrows(_ message: String, file: StaticString = #file, line: UInt = #line) {
        if case .success = self.read() {
            XCTFail(message, file: file, line: line)
        }
    }

    // MARK: - Tests

    func testCorruptCountLargeEnoughToOverflowInt32ThrowsInsteadOfTrapping() {
        // 2^27 pairs of two Int64s is 2^31 bytes: exactly one past Int32.max.
        self.writeMeta(crc: 0, count: 1 << 27, payload: Data(count: 8))

        self.assertReadThrows("a count whose byte size overflows Int32 must be rejected as corrupt")
    }

    func testCorruptMaximalCountThrowsInsteadOfTrapping() {
        self.writeMeta(crc: 0, count: Int32.max, payload: Data(count: 8))

        self.assertReadThrows("Int32.max pairs cannot fit in any meta file and must be rejected")
    }

    func testCountLargerThanTheFileThrows() {
        // Plausible count, but the file holds no pairs at all.
        self.writeMeta(crc: 0, count: 3, payload: Data(count: 8))

        self.assertReadThrows("a count the file cannot hold must be rejected")
    }

    func testChecksumMismatchThrows() {
        var payload = Data(count: 8)
        var offset: Int64 = 0
        var length: Int64 = 16
        withUnsafeBytes(of: &offset) { payload.append(contentsOf: $0) }
        withUnsafeBytes(of: &length) { payload.append(contentsOf: $0) }
        self.writeMeta(crc: 0xDEAD_BEEF, count: 1, payload: payload)

        self.assertReadThrows("a checksum mismatch must be rejected")
    }

    func testSerializedMapReadsBack() {
        self.queue.sync {
            let map = MediaBoxFileMap()
            map.fill(0 ..< 16)
            map.fill(32 ..< 48)
            map.truncate(64)
            map.serialize(manager: self.manager, to: self.metaPath)
        }

        guard case let .success(map) = self.read() else {
            return XCTFail("a map written by serialize must read back")
        }
        var expected = RangeSet<Int64>()
        expected.insert(contentsOf: 0 ..< 16)
        expected.insert(contentsOf: 32 ..< 48)
        XCTAssertEqual(map.ranges, expected)
        XCTAssertEqual(map.sum, 32)
        XCTAssertEqual(map.truncationSize, 64)
    }
}
