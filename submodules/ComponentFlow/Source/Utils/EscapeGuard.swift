import Foundation

final class EscapeGuard {
    final class Status {
        fileprivate(set) var isDeallocated: Bool = false
    }

    let status = Status()

    deinit {
        self.status.isDeallocated = true
    }
}
