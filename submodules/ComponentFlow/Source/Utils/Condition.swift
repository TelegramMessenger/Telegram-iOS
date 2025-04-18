import Foundation

public func Condition<R>(_ f: @autoclosure () -> Bool, _ pass: () -> R) -> R? {
    if f() {
        return pass()
    } else {
        return nil
    }
}
