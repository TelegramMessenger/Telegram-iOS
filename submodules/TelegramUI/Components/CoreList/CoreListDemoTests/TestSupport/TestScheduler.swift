import Foundation
@testable import CoreListDemo

final class TestScheduler: Scheduler {
    private(set) var pending: [() -> Void] = []

    func schedule(_ work: @escaping () -> Void) {
        pending.append(work)
    }

    func flush() {
        let work = pending
        pending.removeAll()
        for fn in work { fn() }
    }
}
