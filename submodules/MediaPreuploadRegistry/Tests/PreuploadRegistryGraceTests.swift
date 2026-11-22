import XCTest
import SwiftSignalKit
import MediaPreuploadRegistry

final class PreuploadRegistryGraceTests: XCTestCase {
    private func makeRegistry() -> (PreuploadRegistry<Int, String>, ManualPreuploadScheduler) {
        let scheduler = ManualPreuploadScheduler()
        return (PreuploadRegistry<Int, String>(scheduler: scheduler, graceDelay: 1.0), scheduler)
    }

    func testLastReleaseEvictsAfterTheGraceWindow() {
        let (registry, scheduler) = self.makeRegistry()
        let producer = FakeProducer()
        let need = registry.hold(1, produce: { producer.signal })

        var latest: PreuploadState<String>?? = nil
        let d = registry.observe(1).start(next: { latest = $0 })
        producer.send(.progress(0.5))

        need.dispose()
        scheduler.advance(by: 0.5)
        XCTAssertNotNil(latest ?? nil, "still alive inside the grace window")

        scheduler.advance(by: 0.6)
        XCTAssertNil(latest ?? nil, "eviction must notify observers with nil")
        d.dispose()
    }

    func testReholdingInsideTheWindowCancelsEviction() {
        let (registry, scheduler) = self.makeRegistry()
        let producer = FakeProducer()

        let first = registry.hold(1, produce: { producer.signal })
        first.dispose()
        scheduler.advance(by: 0.5)

        let second = registry.hold(1, produce: { producer.signal })
        XCTAssertEqual(producer.startCount, 1, "reviving from grace must not restart the producer")

        scheduler.advance(by: 2.0)

        var latest: PreuploadState<String>?? = nil
        let d = registry.observe(1).start(next: { latest = $0 })
        XCTAssertNotNil(latest ?? nil, "the revived context must survive the original deadline")

        d.dispose()
        second.dispose()
    }

    func testAnObserverAloneDoesNotKeepTheContextAlive() {
        let (registry, scheduler) = self.makeRegistry()
        let producer = FakeProducer()
        let need = registry.hold(1, produce: { producer.signal })

        var latest: PreuploadState<String>?? = nil
        let d = registry.observe(1).start(next: { latest = $0 })

        need.dispose()
        scheduler.advance(by: 1.5)

        XCTAssertNil(latest ?? nil, "observing is not wanting — an observer must not pin an orphaned upload")
        d.dispose()
    }

    func testEvictionCancelsTheGraceTimer() {
        let (registry, scheduler) = self.makeRegistry()
        let producer = FakeProducer()
        let need = registry.hold(1, produce: { producer.signal })

        need.dispose()
        scheduler.advance(by: 1.5)

        XCTAssertEqual(scheduler.pendingCount, 0, "no timer may outlive the eviction it scheduled")
    }
}
