import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// `TempScanDatabase.topByAccessTime` feeds the size-limit eviction: it visits scanned
/// storage oldest first and must stop the moment the closure returns false, because the
/// closure unlinks each file it is handed before it re-checks the remaining size.
/// A completed download is two hard links to one inode (`<id>` and `<id>_partial`), so
/// the scan must count that storage once and hand both links to the closure together.
final class TimeBasedCleanupScanTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    private var database: TempScanDatabase!

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "TimeBasedCleanupScanTests")
        self.basePath = NSTemporaryDirectory() + "TimeBasedCleanupScanTests-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)
        self.queue.sync {
            self.database = TempScanDatabase(queue: self.queue, basePath: self.basePath + "/db")
        }
        XCTAssertNotNil(self.database)
    }

    override func tearDown() {
        self.queue.sync {
            self.database?.dispose()
            self.database = nil
        }
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    // MARK: - Helpers

    private func add(_ entries: [(path: String, size: Int64, timestamp: Int32)]) {
        self.queue.sync {
            self.database.begin()
            for entry in entries {
                entry.path.withCString { cString in
                    self.database.add(pathBuffer: UnsafeMutablePointer(mutating: cString), pathSize: strlen(cString), size: entry.size, timestamp: entry.timestamp)
                }
            }
            self.database.commit()
        }
    }

    /// Runs the visitor and returns each visit's paths. `stopAfter` is the number of
    /// visits after which the closure answers false.
    private func visit(stopAfter: Int? = nil) -> [[String]] {
        var visited: [[String]] = []
        self.queue.sync {
            self.database.topByAccessTime { _, paths in
                visited.append(paths)
                if let stopAfter = stopAfter, visited.count >= stopAfter {
                    return false
                }
                return true
            }
        }
        return visited
    }

    private func writeFile(_ name: String, bytes: Int) -> String {
        let path = self.basePath + "/" + name
        XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data(repeating: 0x5A, count: bytes)))
        return path
    }

    private func hardLink(_ source: String, as name: String) -> String {
        let path = self.basePath + "/" + name
        XCTAssertEqual(link(source, path), 0, "link failed: \(String(cString: strerror(errno)))")
        return path
    }

    private func scan(_ directory: String) -> (result: ScanFilesResult, visits: [(size: Int64, paths: Set<String>)]) {
        var result = ScanFilesResult()
        var visits: [(size: Int64, paths: Set<String>)] = []
        self.queue.sync {
            self.database.begin()
            var remaining = 100
            var seen = Set<FileIdentity>()
            result = scanFiles(at: directory, olderThan: 0, includeSubdirectories: false, performSizeMapping: true, tempDatabase: self.database, reportMemoryUsageInterval: 100, reportMemoryUsageRemaining: &remaining, seenLinkedInodes: &seen)
            self.database.commit()
            self.database.topByAccessTime { size, paths in
                visits.append((size, Set(paths)))
                return true
            }
        }
        return (result, visits)
    }

    // MARK: - Walk order and stopping

    func testVisitingStopsWhenTheClosureReturnsFalse() {
        self.add([
            ("/a", 100, 1_000),
            ("/b", 100, 2_000),
            ("/c", 100, 3_000),
            ("/d", 100, 4_000),
            ("/e", 100, 5_000),
        ])

        XCTAssertEqual(self.visit(stopAfter: 2), [["/a"], ["/b"]])
    }

    func testEvictionClosureSeesNoMoreFilesOnceTheLimitIsMet() {
        self.add([
            ("/oldest", 300, 1_000),
            ("/older", 300, 2_000),
            ("/newer", 300, 3_000),
            ("/newest", 300, 4_000),
        ])
        let limit: Int64 = 700
        var remaining: Int64 = 1_200
        var unlinked: [String] = []

        self.queue.sync {
            self.database.topByAccessTime { size, paths in
                remaining -= size
                unlinked.append(contentsOf: paths)
                return remaining > limit
            }
        }

        XCTAssertEqual(unlinked, ["/oldest", "/older"])
        XCTAssertEqual(remaining, 600)
    }

    func testVisitsEveryEntryOldestFirstAcrossPageBoundaries() {
        let count = 1_300
        var entries: [(path: String, size: Int64, timestamp: Int32)] = []
        for i in 0 ..< count {
            entries.append(("/file-\(String(format: "%05d", i))", 1, Int32(10_000 + i)))
        }
        self.add(entries.shuffled())

        let visited = self.visit()

        XCTAssertEqual(visited.count, count)
        XCTAssertEqual(visited.flatMap { $0 }, entries.map { $0.path })
    }

    func testEntriesWithEqualTimestampsAreEachVisitedOnce() {
        self.add([
            ("/x", 10, 5_000),
            ("/y", 10, 5_000),
            ("/z", 10, 5_000),
        ])

        XCTAssertEqual(Set(self.visit().flatMap { $0 }), ["/x", "/y", "/z"])
        XCTAssertEqual(self.visit().count, 3)
    }

    // MARK: - Hard links

    func testLinksRegisteredForOneIdentityAreVisitedTogetherWithTheSizeOnce() {
        let identity = FileIdentity(device: 1, inode: 42)
        self.queue.sync {
            self.database.begin()
            "/media/abc".withCString { cString in
                self.database.add(pathBuffer: UnsafeMutablePointer(mutating: cString), pathSize: strlen(cString), size: 300, timestamp: 1_000, identity: identity)
            }
            "/media/abc_partial".withCString { cString in
                self.database.addLink(pathBuffer: UnsafeMutablePointer(mutating: cString), pathSize: strlen(cString), identity: identity)
            }
            "/media/def".withCString { cString in
                self.database.add(pathBuffer: UnsafeMutablePointer(mutating: cString), pathSize: strlen(cString), size: 100, timestamp: 2_000)
            }
            self.database.commit()
        }

        var visits: [(size: Int64, paths: Set<String>)] = []
        self.queue.sync {
            self.database.topByAccessTime { size, paths in
                visits.append((size, Set(paths)))
                return true
            }
        }

        XCTAssertEqual(visits.count, 2)
        XCTAssertEqual(visits[0].size, 300)
        XCTAssertEqual(visits[0].paths, ["/media/abc", "/media/abc_partial"])
        XCTAssertEqual(visits[1].size, 100)
        XCTAssertEqual(visits[1].paths, ["/media/def"])
    }

    func testScanCountsAHardLinkedFileOnceAndGroupsItsLinks() {
        let directory = self.basePath + "/media"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let complete = self.writeFile("media/abc", bytes: 300)
        let partial = self.hardLink(complete, as: "media/abc_partial")
        let single = self.writeFile("media/def", bytes: 100)

        let (result, visits) = self.scan(directory)

        XCTAssertEqual(result.totalSize, 400)
        XCTAssertEqual(visits.count, 2)
        XCTAssertEqual(visits.map { $0.size }.sorted(), [100, 300])
        XCTAssertTrue(visits.contains { $0.paths == [complete, partial] }, "the two links must arrive in one visit: \(visits)")
        XCTAssertTrue(visits.contains { $0.paths == [single] })
    }

    func testScanStillCountsDistinctFilesOfEqualSizeSeparately() {
        let directory = self.basePath + "/media"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let _ = self.writeFile("media/one", bytes: 250)
        let _ = self.writeFile("media/two", bytes: 250)

        let (result, visits) = self.scan(directory)

        XCTAssertEqual(result.totalSize, 500)
        XCTAssertEqual(visits.count, 2)
    }
}
