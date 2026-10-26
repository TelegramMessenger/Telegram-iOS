import XCTest
import Foundation
import Darwin
#if SSK_LEGACY
import SwiftSignalKitLegacy
#else
import SwiftSignalKit2
#endif

private func processWakeups() -> UInt64 {
    var info = task_power_info()
    var count = mach_msg_type_number_t(MemoryLayout<task_power_info>.size / MemoryLayout<natural_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_POWER_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else {
        return 0
    }
    return info.task_interrupt_wakeups + info.task_platform_idle_wakeups
}

final class IdleWakeupTests: XCTestCase {
    func testPendingSuspendAwareDelaysDoNotWakeTheProcess() {
        let queue = Queue(name: "idle.wakeups")
        let fired = Atomic<Int>(value: 0)
        var disposables: [Disposable] = []
        for _ in 0 ..< 200 {
            disposables.append((Signal<Void, NoError>.single(Void()) |> suspendAwareDelay(3600.0, granularity: 0.01, queue: queue)).start(next: { _ in
                let _ = fired.modify { $0 + 1 }
            }))
        }
        let settled = expectation(description: "settled")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 5.0)

        let before = processWakeups()
        let measured = expectation(description: "measured")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            measured.fulfill()
        }
        wait(for: [measured], timeout: 5.0)
        let wakeups = processWakeups() - before

        for disposable in disposables {
            disposable.dispose()
        }
        print("IdleWakeupTests: \(wakeups) process wakeups in 1 s with 200 pending suspendAwareDelay(3600, granularity: 0.01)")
        XCTAssertEqual(fired.with { $0 }, 0)
        #if !SSK_LEGACY
        XCTAssertLessThan(wakeups, 30)
        #endif
    }

    func testLongSuspendAwareDelayStillFiresAfterItsTimeout() {
        let queue = Queue(name: "idle.fire")
        let fired = expectation(description: "fired")
        let start = CFAbsoluteTimeGetCurrent()
        var elapsed: Double = 0.0
        let disposable = (Signal<Void, NoError>.single(Void()) |> suspendAwareDelay(0.3, granularity: 0.01, queue: queue)).start(next: { _ in
            elapsed = CFAbsoluteTimeGetCurrent() - start
            fired.fulfill()
        })
        wait(for: [fired], timeout: 5.0)
        disposable.dispose()
        XCTAssertGreaterThanOrEqual(elapsed, 0.3 - 0.005)
        XCTAssertLessThan(elapsed, 0.3 + 0.2)
    }
}
