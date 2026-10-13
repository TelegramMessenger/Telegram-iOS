import Foundation

protocol Scheduler: AnyObject {
    func schedule(_ work: @escaping () -> Void)
}

final class MainQueueScheduler: Scheduler {
    func schedule(_ work: @escaping () -> Void) {
        DispatchQueue.main.async { work() }
    }
}
