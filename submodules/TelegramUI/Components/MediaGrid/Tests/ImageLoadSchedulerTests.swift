import XCTest
import MediaGrid
@testable import MediaGridDemo

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

    func testRequestsForOneKeyShareOneLoad() {
        let scheduler = self.makeScheduler()
        var results: [Bool] = []
        _ = scheduler.request(key: "a", payload: 1, isReduced: false, completion: { image, isDegraded in
            results.append(isDegraded)
        })
        _ = scheduler.request(key: "a", payload: 1, isReduced: true, completion: { image, isDegraded in
            results.append(isDegraded)
        })
        XCTAssertEqual(self.started.map { $0.key }, ["a"])
        let job = self.started[0]
        scheduler.finish(job, attempt: job.attempt, image: TestDataSource.sampleImage)
        XCTAssertEqual(Set(results), [false, true])
        XCTAssertEqual(scheduler.localLane.running, 0)
    }

    func testLimitAndNewestFirst() {
        let scheduler = self.makeScheduler()
        for key in ["a", "b", "c", "d", "e"] {
            _ = scheduler.request(key: key, payload: 0, isReduced: false, completion: { _, _ in })
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
                _ = scheduler.request(key: key, payload: 0, isReduced: false, completion: { _, _ in })
            }
            XCTAssertTrue(self.started.isEmpty)
        }
        XCTAssertEqual(self.started.map { $0.key }, ["c", "b"])
    }

    func testCancellingQueuedRequestNeverStartsIt() {
        let scheduler = self.makeScheduler(localLimit: 1)
        _ = scheduler.request(key: "a", payload: 0, isReduced: false, completion: { _, _ in })
        let queued = scheduler.request(key: "b", payload: 0, isReduced: false, completion: { _, _ in })
        queued.cancel()
        XCTAssertTrue(self.cancelled.isEmpty)
        scheduler.finish(self.started[0], attempt: 1, image: nil)
        XCTAssertEqual(self.started.map { $0.key }, ["a"])
        XCTAssertEqual(scheduler.localLane.running, 0)
    }

    func testCancellingRunningRequestFreesItsSlot() {
        let scheduler = self.makeScheduler(localLimit: 1)
        let running = scheduler.request(key: "a", payload: 0, isReduced: false, completion: { _, _ in })
        _ = scheduler.request(key: "b", payload: 0, isReduced: false, completion: { _, _ in })
        running.cancel()
        XCTAssertEqual(self.cancelled, ["a"])
        XCTAssertEqual(self.started.map { $0.key }, ["a", "b"])
        XCTAssertEqual(scheduler.localLane.running, 1)
        scheduler.finish(self.started[0], attempt: 1, image: nil)
        XCTAssertEqual(scheduler.localLane.running, 1)
    }

    func testCancellingOneOfTwoConsumersKeepsTheLoad() {
        let scheduler = self.makeScheduler()
        let first = scheduler.request(key: "a", payload: 0, isReduced: false, completion: { _, _ in })
        var delivered = false
        _ = scheduler.request(key: "a", payload: 0, isReduced: false, completion: { image, _ in
            delivered = image != nil
        })
        first.cancel()
        XCTAssertTrue(self.cancelled.isEmpty)
        scheduler.finish(self.started[0], attempt: 1, image: TestDataSource.sampleImage)
        XCTAssertTrue(delivered)
    }

    func testPrefetchWaitsForVisibleRequests() {
        let scheduler = self.makeScheduler(localLimit: 2, prefetchLimit: 1)
        _ = scheduler.request(key: "a", payload: 0, isReduced: false, completion: { _, _ in })
        scheduler.startPrefetching([1, 2, 3])
        XCTAssertEqual(self.started.map { $0.key }, ["a"])
        scheduler.finish(self.started[0], attempt: 1, image: nil)
        XCTAssertEqual(self.started.map { $0.key }, ["a", "p1"])
        XCTAssertEqual(scheduler.localLane.running, 1)
    }

    func testPrefetchQueueStaysBoundedWhileVisibleWorkBlocksIt() {
        let scheduler = self.makeScheduler(localLimit: 1, prefetchLimit: 1)
        _ = scheduler.request(key: "busy", payload: 0, isReduced: false, completion: { _, _ in })
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
        _ = scheduler.request(key: "a", payload: 0, isReduced: false, completion: { image, _ in
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
        scheduler.finish(job, attempt: 2, image: TestDataSource.sampleImage)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(scheduler.localLane.running, 0)
    }

    func testRepeatedExternalCancelFinishesWithoutImage() {
        let scheduler = self.makeScheduler()
        var results: [UIImage?] = []
        _ = scheduler.request(key: "a", payload: 0, isReduced: false, completion: { image, _ in
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
        _ = scheduler.request(key: "a", payload: 0, isReduced: false, completion: { _, _ in })
        _ = scheduler.request(key: "b", payload: 0, isReduced: false, completion: { _, _ in })
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
            handles.append(scheduler.request(key: "k\(index)", payload: index, isReduced: false, completion: { _, _ in }))
            let job = self.started.last!
            XCTAssertTrue(scheduler.moveToNetwork(job, attempt: job.attempt))
        }
        XCTAssertEqual(scheduler.networkLane.running, 1)
        for handle in handles.dropFirst() {
            handle.cancel()
        }
        let live = 300
        for index in 0 ..< live {
            _ = scheduler.request(key: "n\(index)", payload: index, isReduced: false, completion: { _, _ in })
            let job = self.started.last!
            XCTAssertTrue(scheduler.moveToNetwork(job, attempt: job.attempt))
        }
        XCTAssertLessThanOrEqual(scheduler.networkLane.queuedCount, 2 * live + Scheduler.minimumCompactionThreshold)
    }
}
