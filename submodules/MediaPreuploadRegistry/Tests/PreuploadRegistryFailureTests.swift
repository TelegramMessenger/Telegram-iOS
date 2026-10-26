import XCTest
import SwiftSignalKit
import MediaPreuploadRegistry

final class PreuploadRegistryFailureTests: XCTestCase {
    private func makeRegistry() -> (PreuploadRegistry<Int, String>, ManualPreuploadScheduler) {
        let scheduler = ManualPreuploadScheduler()
        return (PreuploadRegistry<Int, String>(scheduler: scheduler, graceDelay: 1.0, failureBackoff: 30.0), scheduler)
    }

    func testFailureNotifiesObserversThenEvicts() {
        let (registry, _) = self.makeRegistry()
        let producer = FakeProducer()
        let need = registry.hold(1, produce: { producer.signal })

        var seen: [PreuploadState<String>?] = []
        let d = registry.observe(1).start(next: { seen.append($0) })

        producer.send(.failed)

        XCTAssertTrue(seen.contains(where: { if case .failed = $0 { return true } else { return false } }),
                      "observers must see .failed before the context disappears")
        d.dispose()
        need.dispose()
    }

    func testHoldIsSuppressedInsideTheBackoffWindow() {
        let (registry, scheduler) = self.makeRegistry()
        let first = FakeProducer()
        let need = registry.hold(1, produce: { first.signal })
        first.send(.failed)
        need.dispose()

        let second = FakeProducer()
        let retry = registry.hold(1, produce: { second.signal })
        XCTAssertEqual(second.startCount, 0, "a need must not restart a just-failed upload")

        scheduler.advance(by: 31.0)
        let later = registry.hold(1, produce: { second.signal })
        XCTAssertEqual(second.startCount, 1, "after the window, a need restarts it")

        retry.dispose()
        later.dispose()
    }

    func testIgnoringBackoffRestartsImmediately() {
        let (registry, _) = self.makeRegistry()
        let first = FakeProducer()
        let need = registry.hold(1, produce: { first.signal })
        first.send(.failed)
        need.dispose()

        let second = FakeProducer()
        let send = registry.hold(1, ignoringBackoff: true, produce: { second.signal })
        XCTAssertEqual(second.startCount, 1, "an explicit send must never be blocked by a background failure")
        send.dispose()
    }

    func testEvictClearsContextAndBackoff() {
        let (registry, _) = self.makeRegistry()
        let first = FakeProducer()
        let need = registry.hold(1, produce: { first.signal })
        first.send(.failed)
        need.dispose()

        registry.evict(1)

        let second = FakeProducer()
        let retry = registry.hold(1, produce: { second.signal })
        XCTAssertEqual(second.startCount, 1, "evict must clear the suppression window too")
        retry.dispose()
    }

    func testEvictNotifiesObservers() {
        let (registry, _) = self.makeRegistry()
        let producer = FakeProducer()
        let need = registry.hold(1, produce: { producer.signal })

        var latest: PreuploadState<String>?? = nil
        let d = registry.observe(1).start(next: { latest = $0 })
        producer.send(.progress(0.5))

        registry.evict(1)

        XCTAssertNil(latest ?? nil)
        d.dispose()
        need.dispose()
    }
}
