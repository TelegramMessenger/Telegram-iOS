import Foundation

public func compactNumericCountString(_ count: Int) -> String {
    if count >= 1000 * 1000 {
        let remainder = (count % (1000 * 1000)) / (1000 * 100)
        if remainder != 0 {
            return "\(count / (1000 * 1000)),\(remainder)M"
        } else {
            return "\(count / (1000 * 1000))M"
        }
    } else if count >= 1000 {
        let remainder = (count % (1000)) / (100)
        if remainder != 0 {
            return "\(count / 1000),\(remainder)K"
        } else {
            return "\(count / 1000)K"
        }
    } else {
        return "\(count)"
    }
}

