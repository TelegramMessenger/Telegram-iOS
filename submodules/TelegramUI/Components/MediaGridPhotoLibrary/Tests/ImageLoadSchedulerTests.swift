import XCTest
import MediaGrid
@testable import MediaGridPhotoLibrary

final class ImageLoadSchedulerTests: XCTestCase {
    private typealias Scheduler = ImageLoadScheduler<String, Int, Int>

    private var started: [Scheduler.Job] = []
    private var cancelled: [String] = []
    private var flushes: [() -> Void] = []

    private func makeScheduler(localLimit: Int = 2, prefetchLimit: Int = 1, networkLimit: Int = 1) -> Scheduler {
        let scheduler = Scheduler(localLimit: localLimit, localPrefetchLimit: prefetchLimit, networkLimit: networkLimit)
        scheduler.startJob = { [unowned self] job in
            self.started.append(job)
        }
        scheduler.cancelJob = { [unowned self] job in
            self.cancelled.append(job.key)
        }
        scheduler.resolvePrefetch = { key in
            return ("p\(key)", key)
        }
        scheduler.scheduleFlush = { [unowned self] flush in
            self.flushes.append(flush)
        }
        return scheduler
    }

    private func runFlushes() {
        let flushes = self.flushes
        self.flushes = []
        for flush in flushes {
            flush()
        }
    }

    override func tearDown() {
        self.started = []
        self.cancelled = []
        self.flushes = []
        super.tearDown()
    }

    func testSynchronousDeliveryDoesNotNestStarts() {
        let scheduler = Scheduler(localLimit: 1, localPrefetchLimit: 1, networkLimit: 1)
        var depth = 0
        var maxDepth = 0
        var delivered: [String] = []
        scheduler.startJob = { [unowned scheduler] job in
            depth += 1
            maxDepth = max(maxDepth, depth)
            scheduler.finish(job, attempt: job.attempt, image: PhotoLibraryTestImages.sampleImage)
            depth -= 1
        }
        scheduler.batch {
            for index in 0 ..< 200 {
                let key = "k\(index)"
                _ = scheduler.request(key: key, payload: index, completion: { _, _ in
                    delivered.append(key)
                })
            }
        }
        XCTAssertEqual(delivered.count, 200)
        XCTAssertEqual(maxDepth, 1)
    }

    func testNetworkLaneChangesAreReported() {
        let scheduler = self.makeScheduler()
        var changes = 0
        scheduler.networkLaneDidChange = { changes += 1 }
        XCTAssertTrue(scheduler.isNetworkLaneIdle)
        _ = scheduler.request(key: "a", payload: 1, completion: { _, _ in })
        XCTAssertEqual(changes, 0)
        let job = self.started[0]
        XCTAssertTrue(scheduler.moveToNetwork(job, attempt: job.attempt))
        XCTAssertGreaterThan(changes, 0)
        XCTAssertFalse(scheduler.isNetworkLaneIdle)
        let moved = changes
        let networkJob = self.started.last!
        scheduler.finish(networkJob, attempt: networkJob.attempt, image: PhotoLibraryTestImages.sampleImage)
        XCTAssertGreaterThan(changes, moved)
        XCTAssertTrue(scheduler.isNetworkLaneIdle)
    }

    func testCancelledNetworkJobLeavesLaneIdle() {
        let scheduler = self.makeScheduler()
        var changes = 0
        scheduler.networkLaneDidChange = { changes += 1 }
        let handle = scheduler.request(key: "a", payload: 1, completion: { _, _ in })
        let job = self.started[0]
        XCTAssertTrue(scheduler.moveToNetwork(job, attempt: job.attempt))
        let moved = changes
        handle.cancel()
        XCTAssertGreaterThan(changes, moved)
        XCTAssertTrue(scheduler.isNetworkLaneIdle)
    }

    func testRequestsForOneKeyShareOneLoad() {
        let scheduler = self.makeScheduler()
        var results: [Bool] = []
        _ = scheduler.request(key: "a", payload: 1, completion: { image, isDegraded in
            results.append(isDegraded)
        })
        _ = scheduler.request(key: "a", payload: 1, completion: { image, isDegraded in
            results.append(isDegraded)
        })
        XCTAssertEqual(self.started.map { $0.key }, ["a"])
        let job = self.started[0]
        scheduler.finish(job, attempt: job.attempt, image: PhotoLibraryTestImages.sampleImage)
        XCTAssertEqual(results, [false, false])
        XCTAssertEqual(scheduler.localLane.running, 0)
    }

    func testLimitAndNewestFirst() {
        let scheduler = self.makeScheduler()
        for key in ["a", "b", "c", "d", "e"] {
            _ = scheduler.request(key: key, payload: 0, completion: { _, _ in })
        }
        XCTAssertEqual(self.started.map { $0.key }, ["a", "b"])
        XCTAssertEqual(scheduler.localLane.running, 2)
        scheduler.finish(self.started[0], attempt: 1, image: nil)
        XCTAssertEqual(self.started.map { $0.key }, ["a", "b", "e"])
        XCTAssertEqual(scheduler.localLane.running, 2)
    }

    func testBatchStartsNewestFirst() {
        let scheduler = self.makeScheduler(localLimit: 2)
        scheduler.batch {
            for key in ["a", "b", "c"] {
                _ = scheduler.request(key: key, payload: 0, completion: { _, _ in })
            }
            XCTAssertTrue(self.started.isEmpty)
        }
        XCTAssertEqual(self.started.map { $0.key }, ["c", "b"])
    }

    func testCancellingQueuedRequestNeverStartsIt() {
        let scheduler = self.makeScheduler(localLimit: 1)
        _ = scheduler.request(key: "a", payload: 0, completion: { _, _ in })
        let queued = scheduler.request(key: "b", payload: 0, completion: { _, _ in })
        queued.cancel()
        XCTAssertTrue(self.cancelled.isEmpty)
        scheduler.finish(self.started[0], attempt: 1, image: nil)
        XCTAssertEqual(self.started.map { $0.key }, ["a"])
        XCTAssertEqual(scheduler.localLane.running, 0)
    }

    func testCancellingRunningRequestFreesItsSlot() {
        let scheduler = self.makeScheduler(localLimit: 1)
        let running = scheduler.request(key: "a", payload: 0, completion: { _, _ in })
        _ = scheduler.request(key: "b", payload: 0, completion: { _, _ in })
        running.cancel()
        XCTAssertEqual(self.cancelled, ["a"])
        XCTAssertEqual(self.started.map { $0.key }, ["a", "b"])
        XCTAssertEqual(scheduler.localLane.running, 1)
        scheduler.finish(self.started[0], attempt: 1, image: nil)
        XCTAssertEqual(scheduler.localLane.running, 1)
    }

    func testCancellingOneOfTwoConsumersKeepsTheLoad() {
        let scheduler = self.makeScheduler()
        let first = scheduler.request(key: "a", payload: 0, completion: { _, _ in })
        var delivered = false
        _ = scheduler.request(key: "a", payload: 0, completion: { image, _ in
            delivered = image != nil
        })
        first.cancel()
        XCTAssertTrue(self.cancelled.isEmpty)
        scheduler.finish(self.started[0], attempt: 1, image: PhotoLibraryTestImages.sampleImage)
        XCTAssertTrue(delivered)
    }

    func testPrefetchWaitsForVisibleRequests() {
        let scheduler = self.makeScheduler(localLimit: 2, prefetchLimit: 1)
        _ = scheduler.request(key: "a", payload: 0, completion: { _, _ in })
        scheduler.startPrefetching([1, 2, 3])
        XCTAssertEqual(self.started.map { $0.key }, ["a"])
        scheduler.finish(self.started[0], attempt: 1, image: nil)
        XCTAssertEqual(self.started.map { $0.key }, ["a", "p1"])
        XCTAssertEqual(scheduler.localLane.running, 1)
    }

    func testPrefetchQueueStaysBoundedWhileVisibleWorkBlocksIt() {
        let scheduler = self.makeScheduler(localLimit: 1, prefetchLimit: 1)
        _ = scheduler.request(key: "busy", payload: 0, completion: { _, _ in })
        let window = 100
        var previous: [Int] = []
        for frame in 0 ..< 200 {
            let keys = Array(frame * 10 ..< frame * 10 + window)
            scheduler.stopPrefetching(previous.filter { !keys.contains($0) })
            scheduler.startPrefetching(keys)
            previous = keys
            XCTAssertLessThanOrEqual(scheduler.queuedPrefetchCount, 2 * scheduler.wantedPrefetchCount + Scheduler.minimumCompactionThreshold + window)
        }
        XCTAssertEqual(scheduler.wantedPrefetchCount, window)
        XCTAssertLessThan(scheduler.queuedPrefetchCount, 2 * window + Scheduler.minimumCompactionThreshold + window)
    }

    func testStopThenStartInOneTurnKeepsRunningPrefetch() {
        let scheduler = self.makeScheduler(localLimit: 2, prefetchLimit: 2)
        scheduler.startPrefetching([1, 2])
        XCTAssertEqual(self.started.map { $0.key }, ["p1", "p2"])
        scheduler.stopPrefetching([1, 2])
        scheduler.startPrefetching([1])
        self.runFlushes()
        XCTAssertEqual(self.cancelled, ["p2"])
        XCTAssertEqual(scheduler.localLane.running, 1)
        XCTAssertEqual(self.started.map { $0.key }, ["p1", "p2"])
    }

    func testRemapPrefetchingMovesKeysAndDropsRemoved() {
        let scheduler = self.makeScheduler(localLimit: 2, prefetchLimit: 2)
        scheduler.startPrefetching([1, 2, 3, 4])
        XCTAssertEqual(self.started.map { $0.key }, ["p1", "p2"])
        scheduler.remapPrefetching({ key in
            return key == 2 || key == 4 ? nil : key + 10
        }, update: {})
        XCTAssertEqual(self.cancelled, ["p2"])
        XCTAssertEqual(scheduler.wantedPrefetchCount, 2)
        XCTAssertEqual(self.started.map { $0.key }, ["p1", "p2", "p13"])
        scheduler.stopPrefetching([11])
        self.runFlushes()
        XCTAssertEqual(self.cancelled, ["p2", "p1"])
        scheduler.startPrefetching([13])
        XCTAssertEqual(self.started.count, 3)
        XCTAssertEqual(scheduler.wantedPrefetchCount, 1)
    }

    func testRemapResolvesPrefetchOnlyAfterUpdate() {
        let scheduler = self.makeScheduler(localLimit: 2, prefetchLimit: 2)
        var swapped = false
        var resolvedBeforeSwap: [Int] = []
        scheduler.resolvePrefetch = { key in
            if !swapped {
                resolvedBeforeSwap.append(key)
            }
            return ("p\(key)", key)
        }
        scheduler.startPrefetching([1, 2, 3])
        resolvedBeforeSwap = []
        scheduler.remapPrefetching({ key in
            return key == 1 ? nil : key + 10
        }, update: {
            swapped = true
        })
        XCTAssertTrue(swapped)
        XCTAssertEqual(resolvedBeforeSwap, [])
        XCTAssertEqual(self.cancelled, ["p1"])
        XCTAssertEqual(self.started.map { $0.key }, ["p1", "p2", "p13"])
    }

    func testStoppedPrefetchIsCancelledAtFlush() {
        let scheduler = self.makeScheduler(localLimit: 2, prefetchLimit: 2)
        scheduler.startPrefetching([1])
        scheduler.stopPrefetching([1])
        XCTAssertTrue(self.cancelled.isEmpty)
        self.runFlushes()
        XCTAssertEqual(self.cancelled, ["p1"])
        XCTAssertEqual(scheduler.localLane.running, 0)
    }

    func testExternallyCancelledJobRestartsAndIgnoresStaleResults() {
        let scheduler = self.makeScheduler()
        var results: [UIImage?] = []
        _ = scheduler.request(key: "a", payload: 0, completion: { image, _ in
            results.append(image)
        })
        let job = self.started[0]
        scheduler.cancelledExternally(job, attempt: 1)
        XCTAssertEqual(self.started.count, 2)
        XCTAssertTrue(self.started[1] === job)
        XCTAssertEqual(job.attempt, 2)
        XCTAssertEqual(scheduler.localLane.running, 1)
        scheduler.finish(job, attempt: 1, image: nil)
        XCTAssertTrue(results.isEmpty)
        scheduler.finish(job, attempt: 2, image: PhotoLibraryTestImages.sampleImage)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(scheduler.localLane.running, 0)
    }

    func testRepeatedExternalCancelFinishesWithoutImage() {
        let scheduler = self.makeScheduler()
        var results: [UIImage?] = []
        _ = scheduler.request(key: "a", payload: 0, completion: { image, _ in
            results.append(image)
        })
        let job = self.started[0]
        for _ in 0 ... Scheduler.maximumRestarts {
            scheduler.cancelledExternally(job, attempt: job.attempt)
        }
        XCTAssertEqual(results.count, 1)
        XCTAssertNil(results[0] ?? nil)
        XCTAssertEqual(scheduler.localLane.running, 0)
    }

    func testCloudJobMovesToNetworkLane() {
        let scheduler = self.makeScheduler(localLimit: 1, networkLimit: 1)
        _ = scheduler.request(key: "a", payload: 0, completion: { _, _ in })
        _ = scheduler.request(key: "b", payload: 0, completion: { _, _ in })
        let job = self.started[0]
        XCTAssertTrue(scheduler.moveToNetwork(job, attempt: 1))
        XCTAssertTrue(job.usesNetwork)
        XCTAssertEqual(scheduler.localLane.running, 1)
        XCTAssertEqual(scheduler.networkLane.running, 1)
        XCTAssertEqual(Set(self.started.map { $0.key }), ["a", "b"])
        scheduler.finish(job, attempt: job.attempt, image: nil)
        XCTAssertEqual(scheduler.networkLane.running, 0)
    }

    func testNetworkQueueIsCompacted() {
        let scheduler = self.makeScheduler(localLimit: 1, networkLimit: 1)
        var handles: [MediaGridImageRequest] = []
        for index in 0 ..< 600 {
            handles.append(scheduler.request(key: "k\(index)", payload: index, completion: { _, _ in }))
            let job = self.started.last!
            XCTAssertTrue(scheduler.moveToNetwork(job, attempt: job.attempt))
        }
        XCTAssertEqual(scheduler.networkLane.running, 1)
        for handle in handles.dropFirst() {
            handle.cancel()
        }
        let live = 300
        for index in 0 ..< live {
            _ = scheduler.request(key: "n\(index)", payload: index, completion: { _, _ in })
            let job = self.started.last!
            XCTAssertTrue(scheduler.moveToNetwork(job, attempt: job.attempt))
        }
        XCTAssertLessThanOrEqual(scheduler.networkLane.queuedCount, 2 * live + Scheduler.minimumCompactionThreshold)
    }

    private func runPreparation(_ job: Scheduler.Job, attempt: Int, before: () -> Void) -> (prepared: Int, delivered: UIImage?) {
        let queue = DispatchQueue(label: "ImageLoadSchedulerTests.preparation")
        queue.suspend()
        let source = PhotoLibraryTestImages.distinctImage(1)
        let output = PhotoLibraryTestImages.distinctImage(2)
        var prepared = 0
        let lock = NSLock()
        var delivered: UIImage?
        let expectation = self.expectation(description: "delivered")
        MediaGridPhotoLibraryDataSource.enqueuePreparation(source, job: job, attempt: attempt, queue: queue, prepare: { _ in
            lock.lock()
            prepared += 1
            lock.unlock()
            return output
        }, deliver: { image in
            delivered = image
            expectation.fulfill()
        })
        before()
        queue.resume()
        self.wait(for: [expectation], timeout: 5.0)
        lock.lock()
        defer {
            lock.unlock()
        }
        return (prepared, delivered === output ? output : (delivered === source ? source : nil))
    }

    func testPreparationRunsForWantedJob() {
        let scheduler = self.makeScheduler()
        let handle = scheduler.request(key: "a", payload: 1, completion: { _, _ in })
        let job = self.started[0]
        let result = self.runPreparation(job, attempt: job.attempt, before: {})
        XCTAssertEqual(result.prepared, 1)
        XCTAssertNotNil(result.delivered)
        withExtendedLifetime(handle) {}
    }

    func testPreparationSkippedAfterCancelWhileQueued() {
        let scheduler = self.makeScheduler()
        let handle = scheduler.request(key: "a", payload: 1, completion: { _, _ in })
        let job = self.started[0]
        let result = self.runPreparation(job, attempt: job.attempt, before: {
            handle.cancel()
        })
        XCTAssertEqual(result.prepared, 0)
        XCTAssertEqual(job.state, .finished)
    }

    func testPreparationSkippedForStaleAttempt() {
        let scheduler = self.makeScheduler()
        let handle = scheduler.request(key: "a", payload: 1, completion: { _, _ in })
        let job = self.started[0]
        let attempt = job.attempt
        let result = self.runPreparation(job, attempt: attempt, before: {
            scheduler.cancelledExternally(job, attempt: attempt)
        })
        XCTAssertEqual(job.state, .running)
        XCTAssertGreaterThan(job.attempt, attempt)
        XCTAssertEqual(result.prepared, 0)
        withExtendedLifetime(handle) {}
    }

    func testPreparationSkippedWhenOnlyPrefetchWantsTheJob() {
        let scheduler = self.makeScheduler()
        scheduler.startPrefetching([7])
        let handle = scheduler.request(key: "p7", payload: 7, completion: { _, _ in })
        let job = self.started[0]
        XCTAssertEqual(job.key, "p7")
        let result = self.runPreparation(job, attempt: job.attempt, before: {
            handle.cancel()
        })
        XCTAssertEqual(job.state, .running)
        XCTAssertEqual(result.prepared, 0)
        XCTAssertNotNil(result.delivered)
    }
}
