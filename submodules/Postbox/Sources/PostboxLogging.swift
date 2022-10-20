import Foundation

private var postboxLogger: (String) -> Void = { _ in }

public func setPostboxLogger(_ f: @escaping (String) -> Void) {
    postboxLogger = f
}

public func postboxLog(_ what: @autoclosure () -> String) {
    postboxLogger(what())
}
