import Foundation

protocol AutoLoadResponseScheduling: AnyObject {
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void)
}

final class MainQueueAutoLoadResponseScheduler: AutoLoadResponseScheduling {
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
