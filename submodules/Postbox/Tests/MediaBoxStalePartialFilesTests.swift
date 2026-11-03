import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A download that is cancelled before its first byte leaves `<id>_partial` (empty) and
/// `<id>_partial.meta` behind. `removeStaleEmptyPartialFiles` deletes such leftovers once
/// they are old, and never touches a resource whose file context is open or kept.
final class MediaBoxStalePartialFilesTests: XCTestCase {
    private final class TestResource: MediaResource {
        let id: MediaResourceId

        init(_ id: String) {
            self.id = MediaResourceId(id)
        }

        var size: Int64? {
            return nil
        }

        var streamable: Bool {
            return false
        }

        var headerSize: Int32 {
            return 0
        }

        func isEqual(to: MediaResource) -> Bool {
            return (to as? TestResource)?.id == self.id
        }
    }

    private static let tempBoxInitialized: Bool = {
        TempBox.initializeShared(basePath: NSTemporaryDirectory() + "MediaBoxStalePartialFilesTests-TempBox", processType: "tests", launchSpecificId: Int64(Date().timeIntervalSince1970 * 1000))
        return true
    }()

    private var basePath: String!
    private var mediaBox: MediaBox!

    private static let day = 24 * 60 * 60

    override func setUp() {
        super.setUp()
        XCTAssertTrue(MediaBoxStalePartialFilesTests.tempBoxInitialized)
        self.basePath = NSTemporaryDirectory() + "MediaBoxStalePartialFilesTests-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)
        self.mediaBox = MediaBox(basePath: self.basePath, isMainProcess: false)
    }

    override func tearDown() {
        self.drainDataQueue()
        for storageBox in [self.mediaBox.storageBox, self.mediaBox.cacheStorageBox] {
            let semaphore = DispatchSemaphore(value: 0)
            let disposable = storageBox.get(ids: []).start(completed: {
                semaphore.signal()
            })
            let _ = semaphore.wait(timeout: .now() + 10.0)
            disposable.dispose()
        }
        self.mediaBox = nil
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    // MARK: - Helpers

    private func path(_ name: String) -> String {
        return self.basePath + "/" + name
    }

    private func exists(_ path: String) -> Bool {
        var value = stat()
        return lstat(path, &value) == 0
    }

    private func setAge(_ path: String, seconds: Int) {
        let time = Int(Date().timeIntervalSince1970) - seconds
        var times = [timeval(tv_sec: time, tv_usec: 0), timeval(tv_sec: time, tv_usec: 0)]
        XCTAssertEqual(lutimes(path, &times), 0, "lutimes failed: \(String(cString: strerror(errno)))")
    }

    /// What a download cancelled before its first byte leaves behind: an empty partial
    /// file and an empty, valid file map.
    private func leaveCancelledDownload(_ id: String) {
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path(id + "_partial"), contents: nil))
        MediaBoxFileMap().serialize(manager: MediaBoxFileManager(queue: nil), to: self.path(id + "_partial.meta"))
        XCTAssertTrue(self.exists(self.path(id + "_partial.meta")))
    }

    private func waitUntil(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(10.0)
        while !condition(), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertTrue(condition())
    }

    private func drainDataQueue() {
        self.mediaBox.dataQueue.sync {}
    }

    @discardableResult
    private func runCleanup() -> Int {
        let semaphore = DispatchSemaphore(value: 0)
        var removed = -1
        self.mediaBox.removeStaleEmptyPartialFiles(olderThan: Int(Date().timeIntervalSince1970) - MediaBoxStalePartialFilesTests.day, completion: { count in
            removed = count
            semaphore.signal()
        })
        XCTAssertEqual(semaphore.wait(timeout: .now() + 20.0), .success)
        return removed
    }

    private func age(_ id: String, seconds: Int) {
        self.setAge(self.path(id + "_partial"), seconds: seconds)
        self.setAge(self.path(id + "_partial.meta"), seconds: seconds)
    }

    // MARK: - Removed

    func testAnOldEmptyPartialAndItsMetadataAreRemoved() {
        self.leaveCancelledDownload("cancelled")
        XCTAssertEqual(fileSize(self.path("cancelled_partial")), 0)
        self.age("cancelled", seconds: 2 * MediaBoxStalePartialFilesTests.day)

        XCTAssertEqual(self.runCleanup(), 1)

        XCTAssertFalse(self.exists(self.path("cancelled_partial")))
        XCTAssertFalse(self.exists(self.path("cancelled_partial.meta")))
    }

    func testAnOldEmptyPartialWithoutMetadataIsRemoved() {
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("bare_partial"), contents: nil))
        self.setAge(self.path("bare_partial"), seconds: 2 * MediaBoxStalePartialFilesTests.day)

        XCTAssertEqual(self.runCleanup(), 1)

        XCTAssertFalse(self.exists(self.path("bare_partial")))
    }

    func testAnOldOrphanedMetadataFileIsRemoved() {
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("orphan_partial.meta"), contents: Data(count: 20)))
        self.setAge(self.path("orphan_partial.meta"), seconds: 2 * MediaBoxStalePartialFilesTests.day)

        XCTAssertEqual(self.runCleanup(), 1)

        XCTAssertFalse(self.exists(self.path("orphan_partial.meta")))
    }

    func testAnEmptyPartialNextToACompleteFileIsRemovedAndTheCompleteFileIsKept() {
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("done"), contents: Data(repeating: 1, count: 100)))
        self.setAge(self.path("done"), seconds: 2 * MediaBoxStalePartialFilesTests.day)
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("done_partial"), contents: nil))
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("done_partial.meta"), contents: Data(count: 20)))
        self.age("done", seconds: 2 * MediaBoxStalePartialFilesTests.day)

        XCTAssertEqual(self.runCleanup(), 1)

        XCTAssertTrue(self.exists(self.path("done")))
        XCTAssertEqual(fileSize(self.path("done")), 100)
        XCTAssertFalse(self.exists(self.path("done_partial")))
        XCTAssertFalse(self.exists(self.path("done_partial.meta")))
    }

    func testManyLeftoversAreRemovedAcrossBatches() {
        for i in 0 ..< 300 {
            let name = "bulk-\(i)_partial"
            XCTAssertTrue(FileManager.default.createFile(atPath: self.path(name), contents: nil))
            XCTAssertTrue(FileManager.default.createFile(atPath: self.path(name + ".meta"), contents: Data(count: 20)))
            self.setAge(self.path(name), seconds: 2 * MediaBoxStalePartialFilesTests.day)
            self.setAge(self.path(name + ".meta"), seconds: 2 * MediaBoxStalePartialFilesTests.day)
        }

        XCTAssertEqual(self.runCleanup(), 300)

        let remaining = (try? FileManager.default.contentsOfDirectory(atPath: self.basePath))?.filter { $0.hasPrefix("bulk-") } ?? []
        XCTAssertEqual(remaining, [])
    }

    func testTheSweepLetsOtherDataQueueWorkRunBetweenBatches() {
        let total = 2_000
        for i in 0 ..< total {
            let name = "yield-\(i)_partial"
            XCTAssertTrue(FileManager.default.createFile(atPath: self.path(name), contents: nil))
            XCTAssertTrue(FileManager.default.createFile(atPath: self.path(name + ".meta"), contents: Data(count: 20)))
            self.setAge(self.path(name), seconds: 2 * MediaBoxStalePartialFilesTests.day)
            self.setAge(self.path(name + ".meta"), seconds: 2 * MediaBoxStalePartialFilesTests.day)
        }
        let countRemaining: () -> Int = {
            return ((try? FileManager.default.contentsOfDirectory(atPath: self.basePath)) ?? []).filter { $0.hasPrefix("yield-") && $0.hasSuffix("_partial") }.count
        }

        let blocker = DispatchSemaphore(value: 0)
        self.mediaBox.dataQueue.justDispatch {
            blocker.wait()
        }
        let done = DispatchSemaphore(value: 0)
        var removed = -1
        self.mediaBox.removeStaleEmptyPartialFiles(olderThan: Int(Date().timeIntervalSince1970) - MediaBoxStalePartialFilesTests.day, completion: { count in
            removed = count
            done.signal()
        })
        Thread.sleep(forTimeInterval: 3.0)
        var remainingWhenOtherWorkRan = -1
        self.mediaBox.dataQueue.justDispatch {
            remainingWhenOtherWorkRan = countRemaining()
        }
        blocker.signal()

        XCTAssertEqual(done.wait(timeout: .now() + 60.0), .success)
        XCTAssertEqual(removed, total)
        XCTAssertLessThan(remainingWhenOtherWorkRan, total, "the first batch runs before work queued after it")
        XCTAssertGreaterThan(remainingWhenOtherWorkRan, 0, "the whole sweep ran in one data queue turn")
        XCTAssertEqual(countRemaining(), 0)
    }

    // MARK: - Kept

    func testARecentEmptyPartialIsKept() {
        self.leaveCancelledDownload("recent")
        self.age("recent", seconds: 60 * 60)

        XCTAssertEqual(self.runCleanup(), 0)

        XCTAssertTrue(self.exists(self.path("recent_partial")))
        XCTAssertTrue(self.exists(self.path("recent_partial.meta")))
    }

    func testAnOldEmptyPartialWhoseMetadataWasTouchedRecentlyIsKept() {
        self.leaveCancelledDownload("touched")
        self.setAge(self.path("touched_partial"), seconds: 2 * MediaBoxStalePartialFilesTests.day)
        self.setAge(self.path("touched_partial.meta"), seconds: 60)

        XCTAssertEqual(self.runCleanup(), 0)

        XCTAssertTrue(self.exists(self.path("touched_partial")))
        XCTAssertTrue(self.exists(self.path("touched_partial.meta")))
    }

    func testAnOldPartialWithDataIsKept() {
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("started_partial"), contents: Data(repeating: 1, count: 1)))
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("started_partial.meta"), contents: Data(count: 20)))
        self.age("started", seconds: 2 * MediaBoxStalePartialFilesTests.day)

        XCTAssertEqual(self.runCleanup(), 0)

        XCTAssertTrue(self.exists(self.path("started_partial")))
        XCTAssertTrue(self.exists(self.path("started_partial.meta")))
    }

    func testAnEmptyPartialThatIsAHardLinkOfTheCompleteFileIsKept() {
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("empty"), contents: nil))
        XCTAssertEqual(link(self.path("empty"), self.path("empty_partial")), 0)
        self.setAge(self.path("empty"), seconds: 2 * MediaBoxStalePartialFilesTests.day)

        XCTAssertEqual(self.runCleanup(), 0)

        XCTAssertTrue(self.exists(self.path("empty")))
        XCTAssertTrue(self.exists(self.path("empty_partial")))
    }

    func testTheFilesOfADownloadInProgressAreKeptAndRemovedOnceItIsCancelled() {
        self.leaveCancelledDownload("active")
        self.age("active", seconds: 2 * MediaBoxStalePartialFilesTests.day)

        let disposable = self.mediaBox.fetchedResource(TestResource("active"), parameters: nil).start()
        self.drainDataQueue()
        XCTAssertTrue(self.exists(self.path("active_partial")))
        self.age("active", seconds: 2 * MediaBoxStalePartialFilesTests.day)

        XCTAssertEqual(self.runCleanup(), 0, "the download's file context is open")
        XCTAssertTrue(self.exists(self.path("active_partial")))
        XCTAssertTrue(self.exists(self.path("active_partial.meta")))

        disposable.dispose()
        self.drainDataQueue()

        XCTAssertEqual(self.runCleanup(), 1)
        XCTAssertFalse(self.exists(self.path("active_partial")))
        XCTAssertFalse(self.exists(self.path("active_partial.meta")))
    }

    func testTheFilesOfAKeptResourceAreKept() {
        self.leaveCancelledDownload("kept")
        self.age("kept", seconds: 2 * MediaBoxStalePartialFilesTests.day)

        let disposable = self.mediaBox.keepResource(id: MediaResourceId("kept")).start()
        self.drainDataQueue()

        XCTAssertEqual(self.runCleanup(), 0)
        XCTAssertTrue(self.exists(self.path("kept_partial")))

        disposable.dispose()
        self.drainDataQueue()
    }

    func testSymlinksAndDirectoriesNamedLikePartialsAreKept() {
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("target"), contents: nil))
        XCTAssertEqual(symlink(self.path("target"), self.path("linked_partial")), 0)
        try? FileManager.default.createDirectory(atPath: self.path("folder_partial"), withIntermediateDirectories: true)
        for name in ["target", "linked_partial", "folder_partial"] {
            self.setAge(self.path(name), seconds: 2 * MediaBoxStalePartialFilesTests.day)
        }

        XCTAssertEqual(self.runCleanup(), 0)

        XCTAssertTrue(self.exists(self.path("linked_partial")))
        XCTAssertTrue(self.exists(self.path("folder_partial")))
        XCTAssertTrue(self.exists(self.path("target")))
    }

    func testPartialsInTheCacheDirectoryAreKept() {
        let cachePartial = self.basePath + "/cache/representation_partial"
        XCTAssertTrue(FileManager.default.createFile(atPath: cachePartial, contents: nil))
        self.setAge(cachePartial, seconds: 2 * MediaBoxStalePartialFilesTests.day)

        XCTAssertEqual(self.runCleanup(), 0)

        XCTAssertTrue(self.exists(cachePartial))
    }

    func testARecentOrphanedMetadataFileIsKept() {
        XCTAssertTrue(FileManager.default.createFile(atPath: self.path("fresh_partial.meta"), contents: Data(count: 20)))

        XCTAssertEqual(self.runCleanup(), 0)

        XCTAssertTrue(self.exists(self.path("fresh_partial.meta")))
    }

    func testARemovedLeftoverDownloadsAgainFromScratch() {
        self.leaveCancelledDownload("again")
        self.age("again", seconds: 2 * MediaBoxStalePartialFilesTests.day)
        XCTAssertEqual(self.runCleanup(), 1)

        let disposable = self.mediaBox.fetchedResource(TestResource("again"), parameters: nil).start()
        self.drainDataQueue()

        XCTAssertTrue(self.exists(self.path("again_partial.meta")), "a new file context starts a fresh map")
        disposable.dispose()
        self.drainDataQueue()
    }
}
