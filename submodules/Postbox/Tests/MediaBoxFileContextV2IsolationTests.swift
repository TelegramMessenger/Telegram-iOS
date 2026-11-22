import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A fetch's failure must only ever affect that fetch. Two ways it could leak:
/// an error from a fetch that has already been replaced must not tear down its
/// replacement, and a failed *local* write (storeResourceData) must not fail an
/// unrelated in-flight network fetch.
final class MediaBoxFileContextV2IsolationTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    private var manager: MediaBoxFileManager!
    private var context: MediaBoxFileContextV2Impl!

    private var fullPath: String { return self.basePath + "/resource" }
    private var partialPath: String { return self.basePath + "/resource_partial" }
    private var metaPath: String { return self.basePath + "/resource_partial.meta" }

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "MediaBoxFileContextV2IsolationTests")
        self.basePath = NSTemporaryDirectory() + "MediaBoxFileContextV2IsolationTests-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)
        self.manager = MediaBoxFileManager(queue: self.queue)
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

    private func makeContext() {
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

    /// A fetch that never emits on its own; the test drives its subscriber directly.
    private func heldFetch(onStart: @escaping (Subscriber<MediaResourceDataFetchResult, MediaResourceDataFetchError>) -> Void) -> Fetch {
        return { _ in
            return Signal { subscriber in
                onStart(subscriber)
                return EmptyDisposable
            }
        }
    }

    private func currentStatus() -> MediaResourceStatus? {
        var status: MediaResourceStatus?
        self.queue.sync {
            let _ = self.context.status(next: { status = $0 }, completed: {}, size: 64)
        }
        return status
    }

    // MARK: - Tests

    func testErrorFromAReplacedFetchDoesNotDisposeItsReplacement() {
        self.makeContext()

        // Fetch A: started, then cancelled by the consumer.
        var subscriberA: Subscriber<MediaResourceDataFetchResult, MediaResourceDataFetchError>?
        var disposableA: Disposable?
        self.queue.sync {
            disposableA = self.context.fetchedFullRange(fetch: self.heldFetch(onStart: { subscriberA = $0 }), error: { _ in
                XCTFail("the cancelled fetch's error callback must not fire")
            }, completed: {})
        }
        XCTAssertNotNil(subscriberA)

        // Reproduce the race: a block on the data queue is mid-way through
        // cancel-and-retry when A's error arrives from a network thread. The error's
        // queue.async lands behind that block, so it runs after B has been started.
        let midway = DispatchSemaphore(value: 0)
        var fetchBStarted = false
        var fetchBFailed = false
        let retried = self.expectation(description: "B started")
        self.queue.async {
            midway.wait()
            disposableA?.dispose()
            let _ = self.context.fetchedFullRange(fetch: self.heldFetch(onStart: { _ in fetchBStarted = true }), error: { _ in
                fetchBFailed = true
            }, completed: {})
            retried.fulfill()
        }
        // A's error, delivered from off-queue while the block above holds the queue.
        subscriberA?.putError(.generic)
        midway.signal()
        self.wait(for: [retried], timeout: 5.0)
        self.queue.sync {}

        XCTAssertTrue(fetchBStarted)
        XCTAssertFalse(fetchBFailed, "A's stale error must not be delivered to B's request")
        XCTAssertEqual(self.currentStatus(), .Fetching(isActive: true, progress: 0.0), "B must still be the pending fetch")
    }

    func testFailedLocalStoreDoesNotFailAnUnrelatedNetworkFetch() {
        // A read-only partial file makes every write fail.
        XCTAssertTrue(FileManager.default.createFile(atPath: self.partialPath, contents: Data(), attributes: [.posixPermissions: 0o444]))
        self.makeContext()

        var fetchFailed = false
        self.queue.sync {
            let _ = self.context.fetchedFullRange(fetch: self.heldFetch(onStart: { _ in }), error: { _ in
                fetchFailed = true
            }, completed: {})
        }
        XCTAssertEqual(self.currentStatus(), .Fetching(isActive: true, progress: 0.0))

        // A local store for the same resource whose write cannot succeed.
        self.queue.sync {
            self.context.internalStore(data: Data(repeating: 0x01, count: 8), range: 0 ..< 8)
        }

        XCTAssertFalse(fetchFailed, "a failed local write must not error the in-flight network fetch")
        XCTAssertEqual(self.currentStatus(), .Fetching(isActive: true, progress: 0.0), "the network fetch must still be pending")
    }
}
