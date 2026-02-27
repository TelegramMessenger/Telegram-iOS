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

public final class EscapeNotification: NSObject {
    let deallocated: () -> Void

    public init(_ deallocated: @escaping () -> Void) {
        self.deallocated = deallocated
    }

    deinit {
        self.deallocated()
    }

    public func keep() {
    }
}
