import XCTest
import SwiftSignalKit
import MediaPreuploadRegistry

/// Drives a registry by hand: the test decides when an "upload" reports progress or finishes.
final class FakeProducer {
    private let pipe = ValuePipe<PreuploadState<String>>()
    private(set) var startCount: Int = 0

    var signal: Signal<PreuploadState<String>, NoError> {
        return Signal { subscriber in
            self.startCount += 1
            return self.pipe.signal().start(next: { subscriber.putNext($0) })
        }
    }

    func send(_ state: PreuploadState<String>) {
        self.pipe.putNext(state)
    }
}

final class PreuploadRegistryHoldTests: XCTestCase {
    func testHoldStartsTheProducerOnce() {
        let registry = PreuploadRegistry<Int, String>(scheduler: ManualPreuploadScheduler())
        let producer = FakeProducer()

        let a = registry.hold(1, produce: { producer.signal })
        XCTAssertEqual(producer.startCount, 1)

        let b = registry.hold(1, produce: { producer.signal })
        XCTAssertEqual(producer.startCount, 1, "a second need must reuse the live context, not restart it")

        a.dispose()
        b.dispose()
    }

    func testObserveEmitsNilForAnUnknownKey() {
        let registry = PreuploadRegistry<Int, String>(scheduler: ManualPreuploadScheduler())
        var received: [PreuploadState<String>?] = []
        let d = registry.observe(1).start(next: { received.append($0) })

        XCTAssertEqual(received.count, 1)
        XCTAssertNil(received[0])
        d.dispose()
    }

    func testObserveReceivesProgressThenDone() {
        let registry = PreuploadRegistry<Int, String>(scheduler: ManualPreuploadScheduler())
        let producer = FakeProducer()
        let need = registry.hold(1, produce: { producer.signal })

        var progressValues: [Float] = []
        var doneValue: String?
        let d = registry.observe(1).start(next: { state in
            switch state {
            case let .progress(value): progressValues.append(value)
            case let .done(value): doneValue = value
            default: break
            }
        })

        producer.send(.progress(0.4))
        producer.send(.done("cloud"))

        XCTAssertEqual(progressValues, [0.0, 0.4], "a fresh context starts parked at 0")
        XCTAssertEqual(doneValue, "cloud")
        d.dispose()
        need.dispose()
    }

    func testDoneIsParkedForLateObservers() {
        let registry = PreuploadRegistry<Int, String>(scheduler: ManualPreuploadScheduler())
        let producer = FakeProducer()
        let need = registry.hold(1, produce: { producer.signal })
        producer.send(.done("cloud"))

        var doneValue: String?
        let d = registry.observe(1).start(next: { state in
            if case let .done(value) = state { doneValue = value }
        })

        XCTAssertEqual(doneValue, "cloud", "a late observer must get the parked result immediately")
        d.dispose()
        need.dispose()
    }
}
