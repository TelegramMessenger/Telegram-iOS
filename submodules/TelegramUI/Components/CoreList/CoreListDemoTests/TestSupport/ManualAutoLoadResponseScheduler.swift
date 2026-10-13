import Foundation
@testable import CoreListDemo

final class ManualAutoLoadResponseScheduler: AutoLoadResponseScheduling {
    private struct Entry {
        let deadline: TimeInterval
        let order: Int
        let work: () -> Void
    }

    private(set) var now: TimeInterval = 0
    private var nextOrder = 0
    private var entries: [Entry] = []

    var pendingCount: Int { entries.count }

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        entries.append(Entry(
            deadline: now + delay,
            order: nextOrder,
            work: work
        ))
        nextOrder += 1
    }

    func advance(by delta: TimeInterval) {
        let target = now + delta
        while let index = entries.indices
            .filter({ entries[$0].deadline <= target })
            .min(by: {
                let lhs = entries[$0]
                let rhs = entries[$1]
                return (lhs.deadline, lhs.order) < (rhs.deadline, rhs.order)
            }) {
            let entry = entries.remove(at: index)
            now = entry.deadline
            entry.work()
        }
        now = target
    }
}
