import Foundation
import XCTest
import SwiftSignalKit
import RangeSet
@testable import Postbox

/// Some fetchers deliver a whole file at once (`.moveLocalFile`, `.moveTempFile`,
/// `.copyLocalItem`) instead of streaming data parts. After such a result the context is
/// complete, and every kind of request must observe that: range requests complete,
/// range status completes, status is Local, and the leftover partial files are gone.
final class MediaBoxFileContextV2MovedFileTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    private var manager: MediaBoxFileManager!
    private var context: MediaBoxFileContextV2Impl!

    private var fullPath: String { return self.basePath + "/resource" }
    private var partialPath: String { return self.basePath + "/resource_partial" }
    private var metaPath: String { return self.basePath + "/resource_partial.meta" }

    private static let tempBoxInitialized: Bool = {
        TempBox.initializeShared(basePath: NSTemporaryDirectory() + "MediaBoxFileContextV2MovedFileTests-TempBox", processType: "tests", launchSpecificId: Int64(Date().timeIntervalSince1970 * 1000))
        return true
    }()

    override func setUp() {
        super.setUp()
        XCTAssertTrue(MediaBoxFileContextV2MovedFileTests.tempBoxInitialized)
        self.queue = Queue(name: "MediaBoxFileContextV2MovedFileTests")
        self.basePath = NSTemporaryDirectory() + "MediaBoxFileContextV2MovedFileTests-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)
        self.manager = MediaBoxFileManager(queue: self.queue)
        self.queue.sync {
            self.context = MediaBoxFileContextV2Impl(
                queue: self.queue,
                manager: self.manager,
                storageBox: nil,
                resourceId: "resource".data(using: .utf8)!,
                path: self.fullPath,
                partialPath: self.partialPath,
                metaPath: self.metaPath
            )
        }
        XCTAssertNotNil(self.context)
    }

    override func tearDown() {
        self.queue.sync {
            self.context = nil
        }
        self.manager = nil
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    // MARK: - Helpers

    private typealias Fetch = (Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>

    private func fetchDelivering(_ result: MediaResourceDataFetchResult) -> Fetch {
        return { _ in
            return Signal { subscriber in
                subscriber.putNext(result)
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }
    }

    private func writeSourceFile(named name: String, payload: Data) -> String {
        let path = self.basePath + "/" + name
        XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: payload))
        return path
    }

    private enum Outcome {
        case completed
        case failed(MediaResourceDataFetchError)
        case hung
    }

    /// Issues a ranged fetch and returns once the completion or error fired.
    private func fetch(range: Range<Int64>, with fetch: @escaping Fetch) -> Outcome {
        let finished = self.expectation(description: "fetch finished")
        var outcome: Outcome = .hung
        self.queue.sync {
            let _ = self.context.fetched(range: range, priority: .default, fetch: fetch, error: { error in
                outcome = .failed(error)
                finished.fulfill()
            }, completed: {
                outcome = .completed
                finished.fulfill()
            })
        }
        self.wait(for: [finished], timeout: 5.0)
        self.queue.sync {}
        return outcome
    }

    // MARK: - Tests

    func testRangeRequestCompletesAfterAMovedLocalFile() {
        let payload = Data(repeating: 0x11, count: 20)
        let source = self.writeSourceFile(named: "download.tmp", payload: payload)

        let outcome = self.fetch(range: 0 ..< 20, with: self.fetchDelivering(.moveLocalFile(path: source)))

        guard case .completed = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertEqual(try? Data(contentsOf: URL(fileURLWithPath: self.fullPath)), payload)
    }

    func testRangeRequestCompletesAfterAMovedTempFile() {
        let payload = Data(repeating: 0x22, count: 20)
        let tempFile = TempBox.shared.tempFile(fileName: "download.bin")
        XCTAssertTrue(FileManager.default.createFile(atPath: tempFile.path, contents: payload))

        let outcome = self.fetch(range: 0 ..< 20, with: self.fetchDelivering(.moveTempFile(file: tempFile)))

        guard case .completed = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertEqual(try? Data(contentsOf: URL(fileURLWithPath: self.fullPath)), payload)
    }

    func testRangeStatusCompletesAndStatusIsLocalAfterAMovedFile() {
        let payload = Data(repeating: 0x33, count: 20)
        let source = self.writeSourceFile(named: "download.tmp", payload: payload)

        var rangeStatuses: [RangeSet<Int64>] = []
        let rangeStatusCompleted = self.expectation(description: "range status completed")
        var statuses: [MediaResourceStatus] = []
        self.queue.sync {
            let _ = self.context.rangeStatus(next: { ranges in
                rangeStatuses.append(ranges)
            }, completed: {
                rangeStatusCompleted.fulfill()
            })
            let _ = self.context.status(next: { status in
                statuses.append(status)
            }, completed: {}, size: 20)
        }

        let _ = self.fetch(range: 0 ..< 20, with: self.fetchDelivering(.moveLocalFile(path: source)))

        self.wait(for: [rangeStatusCompleted], timeout: 5.0)
        XCTAssertEqual(rangeStatuses.last, RangeSet(0 ..< 20))
        XCTAssertEqual(statuses.last, .Local)
    }

    func testPartialAndMetaFilesAreRemovedAfterAMovedFile() {
        let payload = Data(repeating: 0x44, count: 20)
        let source = self.writeSourceFile(named: "download.tmp", payload: payload)

        let _ = self.fetch(range: 0 ..< 20, with: self.fetchDelivering(.moveLocalFile(path: source)))

        XCTAssertTrue(FileManager.default.fileExists(atPath: self.fullPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.partialPath), "partial file must not linger next to the complete file")
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.metaPath), "meta file must not linger next to the complete file")
    }

    func testTrailingSizeUpdateAfterAMoveDoesNotRecreateTheMetaFile() {
        let payload = Data(repeating: 0x55, count: 20)
        let source = self.writeSourceFile(named: "download.tmp", payload: payload)

        // Some fetchers report the size after handing over the file; that trailing
        // event must not write a map describing a partial file that no longer exists.
        let outcome = self.fetch(range: 0 ..< 20, with: { _ in
            return Signal { subscriber in
                subscriber.putNext(.moveLocalFile(path: source))
                subscriber.putNext(.resourceSizeUpdated(20))
                subscriber.putCompletion()
                return EmptyDisposable
            }
        })

        guard case .completed = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: self.fullPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.metaPath), "meta file must not be recreated after the move")
    }

    func testFailedMoveReportsAnErrorInsteadOfHanging() {
        let missingSource = self.basePath + "/does-not-exist.tmp"

        let outcome = self.fetch(range: 0 ..< 20, with: self.fetchDelivering(.moveLocalFile(path: missingSource)))

        guard case .failed = outcome else {
            return XCTFail("expected an error, got \(outcome)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.fullPath))
    }
}
