import Foundation

final class Weak<T: AnyObject> {
    private weak var _value: T?
    var value: T? {
        return self._value
    }
    
    init(_ value: T) {
        self._value = value
    }
}
