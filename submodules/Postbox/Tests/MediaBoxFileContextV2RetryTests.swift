import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A fetch error terminates the fetch signal. The file context must forget that fetch
/// so a later request starts a new one, and its status subscribers must be told the
/// resource is back to Remote rather than left on a Fetching status that never changes.
final class MediaBoxFileContextV2RetryTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    private var manager: MediaBoxFileManager!
    private var context: MediaBoxFileContextV2Impl!

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "MediaBoxFileContextV2RetryTests")
        self.basePath = NSTemporaryDirectory() + "MediaBoxFileContextV2RetryTests-" + UUID().uuidString
        try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)
        self.manager = MediaBoxFileManager(queue: self.queue)
        self.queue.sync {
            self.context = MediaBoxFileContextV2Impl(
                queue: self.queue,
                manager: self.manager,
                storageBox: nil,
                resourceId: "resource".data(using: .utf8)!,
                path: self.basePath + "/resource",
                partialPath: self.basePath + "/resource_partial",
                metaPath: self.basePath + "/resource_partial.meta"
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

    /// A fetch that fails. Synchronously, the error is processed re-entrantly from
    /// inside the context's request update (the queue runs inline when current);
    /// asynchronously, it arrives later like a real network failure does.
    private func failingFetch(asynchronously: Bool = false) -> Fetch {
        return { _ in
            return Signal { subscriber in
                if asynchronously {
                    DispatchQueue.global().async {
                        subscriber.putError(.generic)
                    }
                } else {
                    subscriber.putError(.generic)
                }
                return EmptyDisposable
            }
        }
    }

    private func succeedingFetch(payload: Data) -> Fetch {
        return { _ in
            return Signal { subscriber in
                subscriber.putNext(.dataPart(resourceOffset: 0, data: payload, range: 0 ..< Int64(payload.count), complete: true))
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }
    }

    /// Issues a full-range fetch that fails and waits until the error has been delivered.
    private func performFailingFetch(asynchronously: Bool = false) {
        let errored = self.expectation(description: "fetch error delivered")
        self.queue.sync {
            let _ = self.context.fetchedFullRange(fetch: self.failingFetch(asynchronously: asynchronously), error: { _ in
                errored.fulfill()
            }, completed: {
                XCTFail("a failing fetch must not complete")
            })
        }
        self.wait(for: [errored], timeout: 5.0)
        self.queue.sync {}
    }

    // MARK: - Tests

    func testFullRangeFetchCanBeRetriedAfterAnError() {
        self.performFailingFetch()

        let payload = Data(repeating: 0x42, count: 10)
        var retryFetchStarted = false
        let completed = self.expectation(description: "retry completed")
        self.queue.sync {
            let _ = self.context.fetchedFullRange(fetch: { ranges in
                retryFetchStarted = true
                return self.succeedingFetch(payload: payload)(ranges)
            }, error: { _ in
                XCTFail("retry must not fail")
            }, completed: {
                completed.fulfill()
            })
        }

        self.wait(for: [completed], timeout: 5.0)
        XCTAssertTrue(retryFetchStarted, "the retry must start a new fetch instead of waiting on the failed one")
        XCTAssertEqual(try? Data(contentsOf: URL(fileURLWithPath: self.basePath + "/resource")), payload)
    }

    func testStatusReturnsToRemoteAfterAFetchError() {
        var statuses: [MediaResourceStatus] = []
        self.queue.sync {
            let _ = self.context.status(next: { status in
                statuses.append(status)
            }, completed: {}, size: 10)
        }

        self.performFailingFetch(asynchronously: true)

        XCTAssertTrue(statuses.contains(.Fetching(isActive: true, progress: 0.0)), "the fetch must have been reported while it ran: \(statuses)")
        XCTAssertEqual(statuses.last, .Remote(progress: 0.0), "after the error the status must return to Remote: \(statuses)")
    }

    func testStatusSubscriberAddedAfterAnErrorSeesRemote() {
        self.performFailingFetch()

        var statuses: [MediaResourceStatus] = []
        self.queue.sync {
            let _ = self.context.status(next: { status in
                statuses.append(status)
            }, completed: {}, size: 10)
        }

        XCTAssertEqual(statuses, [.Remote(progress: 0.0)])
    }
}
