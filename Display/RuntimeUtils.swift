import Foundation
import UIKit

private let systemVersion = { () -> (Int, Int) in
    let string = UIDevice.currentDevice().systemVersion as NSString
    var minor = 0
    let range = string.rangeOfString(".")
    if range.location != NSNotFound {
        minor = Int((string.substringFromIndex(range.location + 1) as NSString).intValue)
    }
    return (Int(string.intValue), minor)
}()

public func matchMinimumSystemVersion(major: Int, minor: Int = 0) -> Bool {
    let version = systemVersion
    if version.0 == major {
        return version.1 >= minor
    } else if version.0 < major {
        return false
    } else {
        return true
    }
}
