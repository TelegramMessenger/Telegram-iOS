import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// Covers `TimeBasedCleanup` end to end (touch flushing, age and size eviction) and the
/// parts of the scan that decide what is counted and what can be evicted.
///
/// The end-to-end tests go through the real 10 s scan delay and 10 s touch batching, so
/// each takes about 11 s. Size-limit tests use sparse files: the limit is set in whole
/// gigabytes and the scan reads `st_size`, so a 600 MB file costs no disk space.
final class TimeBasedCleanupTests: XCTestCase {
    private var basePath: String!
    private var mediaPath: String!
    private var logLines: Atomic<[String]>!
    private var scanQueue: Queue!
    private var database: TempScanDatabase!

    private static let megabyte: Int64 = 1024 * 1024

    override func setUp() {
        super.setUp()
        self.basePath = NSTemporaryDirectory() + "TimeBasedCleanupTests-" + UUID().uuidString
        self.mediaPath = self.basePath + "/media"
        for directory in [self.mediaPath!, self.mediaPath + "/cache", self.mediaPath + "/animation-cache", self.mediaPath + "/short-cache"] {
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        TempBox.initializeShared(basePath: self.basePath + "/tempbox", processType: "test", launchSpecificId: 1)

        let logLines = Atomic<[String]>(value: [])
        self.logLines = logLines
        setPostboxLogger({ line in
            let _ = logLines.modify { $0 + [line] }
        }, sync: {})

        self.scanQueue = Queue(name: "TimeBasedCleanupTests.scan")
        self.scanQueue.sync {
            self.database = TempScanDatabase(queue: self.scanQueue, basePath: self.basePath + "/scan-db")
        }
        XCTAssertNotNil(self.database)
    }

    override func tearDown() {
        self.scanQueue.sync {
            self.database?.dispose()
            self.database = nil
        }
        setPostboxLogger({ _ in }, sync: {})
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    // MARK: - Helpers

    private func path(_ name: String) -> String {
        return self.mediaPath + "/" + name
    }

    @discardableResult
    private func writeFile(_ name: String, bytes: Int) -> String {
        let path = self.path(name)
        XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data(repeating: 0x5A, count: bytes)))
        return path
    }

    @discardableResult
    private func writeSparseFile(_ name: String, megabytes: Int64) -> String {
        let path = self.path(name)
        let fd = open(path, O_CREAT | O_WRONLY | O_TRUNC, 0o644)
        XCTAssertGreaterThanOrEqual(fd, 0)
        XCTAssertEqual(ftruncate(fd, off_t(megabytes * TimeBasedCleanupTests.megabyte)), 0)
        close(fd)
        return path
    }

    private func setModificationTime(_ path: String, secondsSince1970: Int) {
        var times = [
            timeval(tv_sec: secondsSince1970, tv_usec: 0),
            timeval(tv_sec: secondsSince1970, tv_usec: 0)
        ]
        XCTAssertEqual(lutimes(path, &times), 0, "lutimes failed: \(String(cString: strerror(errno)))")
    }

    private func setAge(_ path: String, seconds: Int) {
        self.setModificationTime(path, secondsSince1970: Int(Date().timeIntervalSince1970) - seconds)
    }

    private func modificationTime(_ path: String) -> Int? {
        var value = stat()
        guard stat(path, &value) == 0 else {
            return nil
        }
        return value.st_mtimespec.tv_sec
    }

    private func exists(_ path: String) -> Bool {
        var value = stat()
        return lstat(path, &value) == 0
    }

    private func scan(_ directory: String, olderThan: Int32 = 0) -> (result: ScanFilesResult, visits: [(size: Int64, paths: Set<String>)]) {
        var result = ScanFilesResult()
        var visits: [(size: Int64, paths: Set<String>)] = []
        self.scanQueue.sync {
            self.database.begin()
            var remaining = 100
            var seen = Set<FileIdentity>()
            result = scanFiles(at: directory, olderThan: olderThan, includeSubdirectories: false, performSizeMapping: true, tempDatabase: self.database, reportMemoryUsageInterval: 100, reportMemoryUsageRemaining: &remaining, seenLinkedInodes: &seen)
            self.database.commit()
            self.database.topByAccessTime { size, paths in
                visits.append((size, Set(paths)))
                return true
            }
        }
        return (result, visits)
    }

    private func makeCleanup(scanDelay: Double = 10.0) -> TimeBasedCleanup {
        return self.makeCleanupWithStorage(scanDelay: scanDelay).cleanup
    }

    private func makeCleanupWithStorage(scanDelay: Double = 10.0) -> (cleanup: TimeBasedCleanup, storageBox: StorageBox, cacheStorageBox: StorageBox) {
        let storageBox = StorageBox(logger: StorageBox.Logger(impl: { _ in }), basePath: self.basePath + "/storage", isMainProcess: true)
        let cacheStorageBox = StorageBox(logger: StorageBox.Logger(impl: { _ in }), basePath: self.basePath + "/cache-storage", isMainProcess: true)
        let cleanup = TimeBasedCleanup(storageBox: storageBox, cacheStorageBox: cacheStorageBox, generalPaths: [
            self.mediaPath + "/cache",
            self.mediaPath + "/animation-cache"
        ], totalSizeBasedPath: self.mediaPath, shortLivedPaths: [
            self.mediaPath + "/short-cache"
        ], scanDelay: scanDelay)
        return (cleanup, storageBox, cacheStorageBox)
    }

    private func scanEvents() -> [(id: String, finished: Bool)] {
        return self.logLines.with { lines in
            return lines.compactMap { line -> (id: String, finished: Bool)? in
                if let range = line.range(of: "TimeBasedCleanup: reset scan id: ") {
                    return (String(line[range.upperBound...]), false)
                }
                if let range = line.range(of: "TimeBasedCleanup: scan id: "), let end = line.range(of: " finished") {
                    return (String(line[range.upperBound ..< end.lowerBound]), true)
                }
                return nil
            }
        }
    }

    private func storedIds(_ storageBox: StorageBox, _ ids: [String]) -> Set<String> {
        let semaphore = DispatchSemaphore(value: 0)
        var result = Set<String>()
        let disposable = storageBox.get(ids: ids.map { $0.data(using: .utf8)! }).start(next: { entries in
            result = Set(entries.compactMap { String(data: $0.id, encoding: .utf8) })
            semaphore.signal()
        })
        XCTAssertEqual(semaphore.wait(timeout: .now() + 10.0), .success)
        disposable.dispose()
        return result
    }

    /// Waits until `count` scans started by `setMaxStoreTimes` have logged that they finished.
    private func waitForScan(count: Int = 1, timeout: Double = 120.0) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if self.scanEvents().filter({ $0.finished }).count >= count {
                return
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTFail("\(count) scan(s) did not finish within \(timeout) s: \(self.scanEvents())")
    }

    // MARK: - Scan accounting

    func testASymlinkIsNotCountedAsASecondCopyOfItsTarget() {
        let target = self.writeFile("resource", bytes: 1_000)
        let link = self.path("resource.mp4")
        XCTAssertEqual(symlink(target, link), 0)

        let (result, visits) = self.scan(self.mediaPath)

        XCTAssertEqual(result.totalSize, 1_000)
        XCTAssertEqual(visits.map { $0.size }.reduce(0, +), 1_000)
        XCTAssertEqual(Set(visits.flatMap { $0.paths }), [target, link])
    }

    func testASymlinkToAHardLinkedFileIsStillCountedOnce() {
        let complete = self.writeFile("resource", bytes: 1_000)
        let partial = self.path("resource_partial")
        XCTAssertEqual(link(complete, partial), 0)
        let symlinkPath = self.path("resource.jpg")
        XCTAssertEqual(symlink(complete, symlinkPath), 0)

        let (result, visits) = self.scan(self.mediaPath)

        XCTAssertEqual(result.totalSize, 1_000)
        XCTAssertEqual(visits.map { $0.size }.reduce(0, +), 1_000)
        XCTAssertEqual(Set(visits.flatMap { $0.paths }), [complete, partial, symlinkPath])
    }

    func testASymlinkToADeviceNodeIsScannedWithoutTrapping() {
        let link = self.path("disabled-cache")
        XCTAssertEqual(symlink("/dev/null", link), 0)
        let normal = self.writeFile("normal", bytes: 10)

        let (result, visits) = self.scan(self.mediaPath)

        XCTAssertEqual(result.totalSize, 10)
        XCTAssertEqual(Set(visits.flatMap { $0.paths }), [link, normal])
    }

    func testAFileWithAModificationTimeBeyondInt32IsScannedAndVisited() {
        let future = self.writeFile("future", bytes: 10)
        self.setModificationTime(future, secondsSince1970: Int(Int32.max) + 1_000_000)
        let normal = self.writeFile("normal", bytes: 10)

        let (result, visits) = self.scan(self.mediaPath)

        XCTAssertEqual(result.totalSize, 20)
        XCTAssertEqual(Set(visits.flatMap { $0.paths }), [future, normal])
    }

    func testAFileWithAPreEpochModificationTimeIsRemovedAsExpired() {
        let old = self.writeFile("old", bytes: 10)
        self.setModificationTime(old, secondsSince1970: -86_400)
        let normal = self.writeFile("normal", bytes: 10)

        let (result, visits) = self.scan(self.mediaPath)

        XCTAssertEqual(result.unlinkedCount, 1)
        XCTAssertFalse(self.exists(old))
        XCTAssertEqual(visits.map { $0.paths }, [[normal]])
    }

    func testAFileWithTheLargestInt32ModificationTimeIsVisited() {
        let edge = self.writeFile("edge", bytes: 10)
        self.setModificationTime(edge, secondsSince1970: Int(Int32.max))

        let (_, visits) = self.scan(self.mediaPath)

        XCTAssertEqual(visits.map { $0.paths }, [[edge]])
    }

    func testTheAgeScanDoesNotFollowASymlinkedDirectoryOutOfTheCache() {
        let outside = self.basePath + "/outside"
        try? FileManager.default.createDirectory(atPath: outside, withIntermediateDirectories: true)
        let outsideFile = outside + "/keep"
        XCTAssertTrue(FileManager.default.createFile(atPath: outsideFile, contents: Data(repeating: 1, count: 10)))
        self.setAge(outsideFile, seconds: 10 * 86_400)
        XCTAssertEqual(symlink(outside, self.path("cache/linked-directory")), 0)
        let oldCache = self.writeFile("cache/old-representation", bytes: 10)
        self.setAge(oldCache, seconds: 10 * 86_400)

        self.scanQueue.sync {
            self.database.begin()
            var remaining = 100
            var seen = Set<FileIdentity>()
            let _ = scanFiles(at: self.mediaPath + "/cache", olderThan: Int32(Date().timeIntervalSince1970) - 7 * 86_400, includeSubdirectories: true, performSizeMapping: true, tempDatabase: self.database, reportMemoryUsageInterval: 100, reportMemoryUsageRemaining: &remaining, seenLinkedInodes: &seen)
            self.database.commit()
        }

        XCTAssertFalse(self.exists(oldCache))
        XCTAssertTrue(self.exists(outsideFile), "a file outside the cache must never be deleted")
    }

    // MARK: - Touch

    func testTouchRefreshesTheModificationTimeAfterTheBatchInterval() {
        let file = self.writeFile("touched", bytes: 10)
        self.setAge(file, seconds: 5 * 86_400)
        let untouched = self.writeFile("untouched", bytes: 10)
        self.setAge(untouched, seconds: 5 * 86_400)
        let before = self.modificationTime(untouched)

        let cleanup = self.makeCleanup()
        cleanup.touch(paths: [file, self.path("missing")])

        let deadline = Date().addingTimeInterval(20.0)
        let now = Int(Date().timeIntervalSince1970)
        while Date() < deadline, (self.modificationTime(file) ?? 0) < now - 60 {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertGreaterThanOrEqual(self.modificationTime(file) ?? 0, now - 60)
        XCTAssertEqual(self.modificationTime(untouched), before)
        XCTAssertFalse(self.exists(self.path("missing")))
        withExtendedLifetime(cleanup) {}
    }

    func testTouchingTensOfThousandsOfDistinctPathsIsFlushedWithinTheBatchInterval() {
        let count = 30_000
        var paths: [String] = []
        paths.reserveCapacity(count)
        for i in 0 ..< count {
            paths.append(self.path("resource-\(i)"))
        }
        let marker = self.writeFile("marker", bytes: 1)
        self.setAge(marker, seconds: 5 * 86_400)

        let cleanup = self.makeCleanup()
        let start = Date()
        for path in paths {
            cleanup.touch(paths: [path])
        }
        cleanup.touch(paths: [marker])

        let now = Int(start.timeIntervalSince1970)
        while Date().timeIntervalSince(start) < 30.0, (self.modificationTime(marker) ?? 0) < now - 60 {
            Thread.sleep(forTimeInterval: 0.2)
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(self.modificationTime(marker) ?? 0, now - 60, "the flush did not happen within 30 s")
        XCTAssertLessThan(elapsed, 16.0, "touching \(count) paths delayed the 10 s flush to \(elapsed) s")
        withExtendedLifetime(cleanup) {}
    }

    // MARK: - Eviction

    func testTheAgeLimitRemovesOldCacheFilesAndLeavesTheMediaRootAlone() {
        let oldCache = self.writeFile("cache/old-representation", bytes: 10)
        self.setAge(oldCache, seconds: 10 * 86_400)
        let freshCache = self.writeFile("cache/fresh-representation", bytes: 10)
        let oldRoot = self.writeFile("old-resource", bytes: 10)
        self.setAge(oldRoot, seconds: 10 * 86_400)

        let cleanup = self.makeCleanup()
        cleanup.setMaxStoreTimes(general: 7 * 86_400, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertFalse(self.exists(oldCache))
        XCTAssertTrue(self.exists(freshCache))
        XCTAssertTrue(self.exists(oldRoot))
        withExtendedLifetime(cleanup) {}
    }

    func testTheSizeLimitEvictsOldestFirstUntilTheCacheFits() {
        let oldest = self.writeSparseFile("oldest", megabytes: 600)
        self.setAge(oldest, seconds: 3 * 86_400)
        let middle = self.writeSparseFile("middle", megabytes: 500)
        self.setAge(middle, seconds: 2 * 86_400)
        let newest = self.writeSparseFile("newest", megabytes: 300)
        self.setAge(newest, seconds: 86_400)

        let cleanup = self.makeCleanup()
        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertFalse(self.exists(oldest))
        XCTAssertTrue(self.exists(middle))
        XCTAssertTrue(self.exists(newest))
        withExtendedLifetime(cleanup) {}
    }

    func testASymlinkDoesNotMakeACacheUnderTheLimitLookFull() {
        let target = self.writeSparseFile("big", megabytes: 600)
        self.setAge(target, seconds: 3 * 86_400)
        XCTAssertEqual(symlink(target, self.path("big.mp4")), 0)
        let newer = self.writeSparseFile("newer", megabytes: 300)
        self.setAge(newer, seconds: 86_400)

        let cleanup = self.makeCleanup()
        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertTrue(self.exists(target), "900 MB of media fits a 1 GB limit, nothing should be evicted")
        XCTAssertTrue(self.exists(self.path("big.mp4")))
        XCTAssertTrue(self.exists(newer))
        withExtendedLifetime(cleanup) {}
    }

    func testAPreEpochFileDoesNotCauseTheWholeCacheToBeEvicted() {
        let ancient = self.writeSparseFile("ancient", megabytes: 700)
        self.setModificationTime(ancient, secondsSince1970: -86_400)
        let recent = self.writeSparseFile("recent", megabytes: 500)
        self.setAge(recent, seconds: 86_400)

        let cleanup = self.makeCleanup()
        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertFalse(self.exists(ancient), "the oldest file is the one to evict")
        XCTAssertTrue(self.exists(recent), "evicting the oldest file is enough to fit the limit")
        withExtendedLifetime(cleanup) {}
    }

    func testSizeLimitEvictionsAreReportedInTheLog() {
        let oldest = self.writeSparseFile("oldest", megabytes: 700)
        self.setAge(oldest, seconds: 3 * 86_400)
        let newest = self.writeSparseFile("newest", megabytes: 500)
        self.setAge(newest, seconds: 86_400)

        let cleanup = self.makeCleanup()
        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertFalse(self.exists(oldest))
        var summary: String?
        let deadline = Date().addingTimeInterval(5.0)
        while summary == nil, Date() < deadline {
            summary = self.logLines.with { $0.first(where: { $0.hasPrefix("[TimeBasedCleanup]") }) }
            if summary == nil {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        XCTAssertNotNil(summary, "a scan that evicted files must log a summary")
        XCTAssertTrue(summary?.contains("1 limit files") ?? false, "summary: \(summary ?? "nil")")
        withExtendedLifetime(cleanup) {}
    }

    func testEvictingOnlyTheMetadataFileKeepsTheResourceInTheStorageIndex() {
        let oldest = self.writeSparseFile("resource-a", megabytes: 100)
        self.setAge(oldest, seconds: 5 * 86_400)
        let complete = self.writeSparseFile("resource-c", megabytes: 200)
        self.setAge(complete, seconds: 86_400)
        XCTAssertEqual(link(complete, self.path("resource-c_partial")), 0)
        let metadata = self.writeFile("resource-c_partial.meta", bytes: 28)
        self.setAge(metadata, seconds: 4 * 86_400)
        let middle = self.writeSparseFile("resource-b", megabytes: 900)
        self.setAge(middle, seconds: 3 * 86_400)

        let (cleanup, storageBox, _) = self.makeCleanupWithStorage()
        for id in ["resource-a", "resource-b", "resource-c"] {
            storageBox.add(reference: StorageBox.Reference(peerId: 1, messageNamespace: 0, messageId: 1), to: id.data(using: .utf8)!, contentType: 0)
        }
        XCTAssertEqual(self.storedIds(storageBox, ["resource-a", "resource-b", "resource-c"]), ["resource-a", "resource-b", "resource-c"])

        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertFalse(self.exists(oldest))
        XCTAssertFalse(self.exists(middle))
        XCTAssertFalse(self.exists(metadata))
        XCTAssertTrue(self.exists(complete))
        XCTAssertTrue(self.exists(self.path("resource-c_partial")))
        XCTAssertEqual(self.storedIds(storageBox, ["resource-a", "resource-b", "resource-c"]), ["resource-c"], "the evicted resources leave the index, the one whose data is still on disk stays")
        withExtendedLifetime(cleanup) {}
    }

    func testShortLivedFilesCountTowardsTheSizeLimit() {
        let shortLived = self.writeSparseFile("short-cache/stream", megabytes: 600)
        self.setAge(shortLived, seconds: 30 * 60)
        let older = self.writeSparseFile("resource-a", megabytes: 700)
        self.setAge(older, seconds: 20 * 60)
        let newer = self.writeSparseFile("resource-b", megabytes: 500)
        self.setAge(newer, seconds: 10 * 60)

        let cleanup = self.makeCleanup()
        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertFalse(self.exists(shortLived))
        XCTAssertFalse(self.exists(older), "1.8 GB against a 1 GB limit: evicting only the 600 MB short-lived file leaves 1.2 GB")
        XCTAssertTrue(self.exists(newer))
        withExtendedLifetime(cleanup) {}
    }

    // MARK: - Size limit with media kept forever

    func testWithMediaKeptForeverTheSizeLimitAlsoTrimsTheCacheDirectories() {
        let oldCache = self.writeSparseFile("cache/old-representation", megabytes: 700)
        self.setAge(oldCache, seconds: 3 * 86_400)
        let resource = self.writeSparseFile("resource", megabytes: 500)
        self.setAge(resource, seconds: 86_400)

        let cleanup = self.makeCleanup()
        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertFalse(self.exists(oldCache), "1.2 GB against a 1 GB limit: the oldest file is in the cache directory")
        XCTAssertTrue(self.exists(resource))
        withExtendedLifetime(cleanup) {}
    }

    func testWithMediaKeptForeverOldCacheFilesUnderTheLimitAreKept() {
        let ancientCache = self.writeFile("cache/ancient-representation", bytes: 10)
        self.setAge(ancientCache, seconds: 400 * 86_400)
        let ancientAnimation = self.writeFile("animation-cache/ancient-frames", bytes: 10)
        self.setAge(ancientAnimation, seconds: 400 * 86_400)

        let cleanup = self.makeCleanup()
        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertTrue(self.exists(ancientCache), "keeping media forever must not delete by age")
        XCTAssertTrue(self.exists(ancientAnimation))
        withExtendedLifetime(cleanup) {}
    }

    func testWithoutASizeLimitTheCacheDirectoriesAreOnlyTrimmedByAge() {
        let oldCache = self.writeSparseFile("cache/old-representation", megabytes: 700)
        self.setAge(oldCache, seconds: 3 * 86_400)
        let resource = self.writeSparseFile("resource", megabytes: 900)
        self.setAge(resource, seconds: 86_400)

        let cleanup = self.makeCleanup()
        cleanup.setMaxStoreTimes(general: 7 * 86_400, shortLived: 60 * 60, gigabytesLimit: Int32.max)
        self.waitForScan()

        XCTAssertTrue(self.exists(oldCache))
        XCTAssertTrue(self.exists(resource))
        withExtendedLifetime(cleanup) {}
    }

    // MARK: - Settings changes during a scan

    private func writeManyCacheFiles(_ count: Int) {
        let directory = self.mediaPath + "/cache/many"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for i in 0 ..< count {
            let fd = open(directory + "/f\(i)", O_CREAT | O_WRONLY, 0o644)
            close(fd)
        }
    }

    func testChangingTheSettingsStopsARunningScanBeforeItEvictsAnything() {
        self.writeManyCacheFiles(40_000)
        let oldest = self.writeSparseFile("oldest", megabytes: 700)
        self.setAge(oldest, seconds: 3 * 86_400)
        let newest = self.writeSparseFile("newest", megabytes: 500)
        self.setAge(newest, seconds: 86_400)

        let cleanup = self.makeCleanup(scanDelay: 0.0)
        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        let deadline = Date().addingTimeInterval(20.0)
        while self.scanEvents().isEmpty, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
        XCTAssertEqual(self.scanEvents().count, 1, "the first scan must be running when the settings change")
        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 100)
        self.waitForScan(count: 1)
        let _ = try? FileManager.default.removeItem(atPath: self.mediaPath + "/cache/many")
        self.waitForScan(count: 2)

        XCTAssertTrue(self.exists(oldest), "a 100 GB limit keeps everything; the stale 1 GB scan must not evict")
        XCTAssertTrue(self.exists(newest))
        let events = self.scanEvents()
        XCTAssertTrue(self.logLines.with { $0.contains(where: { $0.contains("finished (cancelled)") }) }, "\(events)")
        withExtendedLifetime(cleanup) {}
    }

    func testScansNeverOverlap() {
        self.writeManyCacheFiles(20_000)

        let cleanup = self.makeCleanup(scanDelay: 0.0)
        cleanup.setMaxStoreTimes(general: 30 * 86_400, shortLived: 60 * 60, gigabytesLimit: 1)
        let deadline = Date().addingTimeInterval(20.0)
        while self.scanEvents().isEmpty, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
        cleanup.setMaxStoreTimes(general: 31 * 86_400, shortLived: 60 * 60, gigabytesLimit: 1)
        cleanup.setMaxStoreTimes(general: 32 * 86_400, shortLived: 60 * 60, gigabytesLimit: 2)
        self.waitForScan(count: 1)
        let _ = try? FileManager.default.removeItem(atPath: self.mediaPath + "/cache/many")
        self.waitForScan(count: 2)
        Thread.sleep(forTimeInterval: 1.0)

        let events = self.scanEvents()
        var running: String?
        for event in events {
            if event.finished {
                XCTAssertEqual(running, event.id, "\(events)")
                running = nil
            } else {
                XCTAssertNil(running, "a scan started while another was running: \(events)")
                running = event.id
            }
        }
        XCTAssertNil(running, "\(events)")
        withExtendedLifetime(cleanup) {}
    }

    func testReleasingTheCleanupStopsARunningScan() {
        self.writeManyCacheFiles(40_000)
        let oldest = self.writeSparseFile("oldest", megabytes: 700)
        self.setAge(oldest, seconds: 3 * 86_400)
        let newest = self.writeSparseFile("newest", megabytes: 500)
        self.setAge(newest, seconds: 86_400)

        var cleanup: TimeBasedCleanup? = self.makeCleanup(scanDelay: 0.0)
        cleanup?.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        let deadline = Date().addingTimeInterval(20.0)
        while self.scanEvents().isEmpty, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
        cleanup = nil
        self.waitForScan()

        XCTAssertTrue(self.exists(oldest), "the account's media box is gone, its scan must not keep deleting")
        XCTAssertTrue(self.logLines.with { $0.contains(where: { $0.contains("finished (cancelled)") }) })
    }

    // MARK: - Cache index

    func testCacheFilesDeletedByAgeLeaveTheCacheIndex() {
        let oldCache = self.writeFile("cache/old-representation", bytes: 10)
        self.setAge(oldCache, seconds: 10 * 86_400)
        let freshCache = self.writeFile("cache/fresh-representation", bytes: 10)

        let (cleanup, _, cacheStorageBox) = self.makeCleanupWithStorage()
        cacheStorageBox.update(id: oldCache.data(using: .utf8)!, size: 10)
        cacheStorageBox.update(id: freshCache.data(using: .utf8)!, size: 10)
        XCTAssertEqual(self.storedIds(cacheStorageBox, [oldCache, freshCache]), [oldCache, freshCache])

        cleanup.setMaxStoreTimes(general: 7 * 86_400, shortLived: 60 * 60, gigabytesLimit: Int32.max)
        self.waitForScan()

        XCTAssertFalse(self.exists(oldCache))
        XCTAssertEqual(self.storedIds(cacheStorageBox, [oldCache, freshCache]), [freshCache])
        withExtendedLifetime(cleanup) {}
    }

    func testCacheFilesEvictedForTheSizeLimitLeaveTheCacheIndex() {
        let oldCache = self.writeSparseFile("cache/old-representation", megabytes: 700)
        self.setAge(oldCache, seconds: 3 * 86_400)
        let resource = self.writeSparseFile("resource", megabytes: 500)
        self.setAge(resource, seconds: 86_400)

        let (cleanup, _, cacheStorageBox) = self.makeCleanupWithStorage()
        cacheStorageBox.update(id: oldCache.data(using: .utf8)!, size: 700 * TimeBasedCleanupTests.megabyte)
        XCTAssertEqual(self.storedIds(cacheStorageBox, [oldCache]), [oldCache])

        cleanup.setMaxStoreTimes(general: Int32.max, shortLived: 60 * 60, gigabytesLimit: 1)
        self.waitForScan()

        XCTAssertFalse(self.exists(oldCache))
        XCTAssertEqual(self.storedIds(cacheStorageBox, [oldCache]), [])
        withExtendedLifetime(cleanup) {}
    }
}
