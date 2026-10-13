import XCTest
import SwiftSignalKit
import MediaPreuploadRegistry

final class PreuploadRegistryJoinTests: XCTestCase {
    func testJoinInheritsProgressAndCompletesOnDone() {
        let scheduler = ManualPreuploadScheduler()
        let registry = PreuploadRegistry<Int, String>(scheduler: scheduler, graceDelay: 1.0)
        let producer = FakeProducer()
        let need = registry.hold(1, produce: { producer.signal })
        producer.send(.progress(0.4))

        var seen: [PreuploadState<String>] = []
        var completed = false
        let d = registry.join(1, produce: { producer.signal }).start(next: { seen.append($0) }, completed: { completed = true })

        XCTAssertEqual(producer.startCount, 1, "join must not start a second producer")
        if case let .progress(value) = seen.first {
            XCTAssertEqual(value, 0.4, accuracy: 0.0001, "join inherits the context's current progress")
        } else {
            XCTFail("expected an inherited progress value, got \(String(describing: seen.first))")
        }

        producer.send(.done("cloud"))
        XCTAssertTrue(completed)
        d.dispose()
        need.dispose()
    }

    func testJoinHoldsANeed() {
        let scheduler = ManualPreuploadScheduler()
        let registry = PreuploadRegistry<Int, String>(scheduler: scheduler, graceDelay: 1.0)
        let producer = FakeProducer()

        let editorNeed = registry.hold(1, produce: { producer.signal })
        let d = registry.join(1, produce: { producer.signal }).start(next: { _ in })

        // The editor closes while the send is still in flight.
        editorNeed.dispose()
        scheduler.advance(by: 2.0)

        var latest: PreuploadState<String>?? = nil
        let observer = registry.observe(1).start(next: { latest = $0 })
        XCTAssertNotNil(latest ?? nil, "an active join must keep the context alive past the grace window")

        observer.dispose()
        d.dispose()
    }

    func testJoinCreatesWhenNothingIsRunning() {
        let registry = PreuploadRegistry<Int, String>(scheduler: ManualPreuploadScheduler())
        let producer = FakeProducer()

        let d = registry.join(1, produce: { producer.signal }).start(next: { _ in })
        XCTAssertEqual(producer.startCount, 1, "join must create a context when none exists")
        d.dispose()
    }

    func testJoinIgnoresTheBackoffWindow() {
        let registry = PreuploadRegistry<Int, String>(scheduler: ManualPreuploadScheduler())
        let first = FakeProducer()
        let need = registry.hold(1, produce: { first.signal })
        first.send(.failed)
        need.dispose()

        let second = FakeProducer()
        let d = registry.join(1, produce: { second.signal }).start(next: { _ in })
        XCTAssertEqual(second.startCount, 1, "a user-initiated send ignores a background failure's backoff")
        d.dispose()
    }

    func testJoinOnAParkedResultCompletesImmediately() {
        let registry = PreuploadRegistry<Int, String>(scheduler: ManualPreuploadScheduler())
        let producer = FakeProducer()
        let need = registry.hold(1, produce: { producer.signal })
        producer.send(.done("cloud"))

        var doneValue: String?
        var completed = false
        let d = registry.join(1, produce: { producer.signal }).start(next: { state in
            if case let .done(value) = state { doneValue = value }
        }, completed: { completed = true })

        XCTAssertEqual(doneValue, "cloud")
        XCTAssertTrue(completed)
        d.dispose()
        need.dispose()
    }
}
