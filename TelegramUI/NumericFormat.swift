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

func timeIntervalString(strings: PresentationStrings, value: Int32) -> String {
    if value < 60 {
        return strings.MessageTimer_Seconds(value)
    } else if value < 60 * 60 {
        return strings.MessageTimer_Minutes(value / 60)
    } else if value < 60 * 60 * 24 {
        return strings.MessageTimer_Hours(value / (60 * 60))
    } else if value < 60 * 60 * 24 * 7 {
        return strings.MessageTimer_Days(value / (60 * 60 * 24))
    } else {
        return strings.MessageTimer_Weeks(value / (60 * 60 * 24 * 7))
    }
}

