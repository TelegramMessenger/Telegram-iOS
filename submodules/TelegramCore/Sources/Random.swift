import Foundation

public func arc4random64() -> Int64 {
    var value: Int64 = 0
    arc4random_buf(&value, 8)
    return value
}
