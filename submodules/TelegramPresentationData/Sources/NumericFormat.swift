import Foundation

public func compactNumericCountString(_ count: Int, decimalSeparator: String = ".") -> String {
    if count >= 1000 * 1000 {
        let remainder = (count % (1000 * 1000)) / (1000 * 100)
        if remainder != 0 {
            return "\(count / (1000 * 1000))\(decimalSeparator)\(remainder)M"
        } else {
            return "\(count / (1000 * 1000))M"
        }
    } else if count >= 1000 {
        let remainder = (count % (1000)) / (100)
        if remainder != 0 {
            return "\(count / 1000)\(decimalSeparator)\(remainder)K"
        } else {
            return "\(count / 1000)K"
        }
    } else {
        return "\(count)"
    }
}

public func presentationStringsFormattedNumber(_ count: Int32, _ groupingSeparator: String = "") -> String {
    let string = "\(count)"
    if groupingSeparator.isEmpty || abs(count) < 1000 {
        return string
    } else {
        var groupedString: String = ""
        for i in 0 ..< Int(ceil(Double(string.count) / 3.0)) {
            let index = string.count - Int(i + 1) * 3
            if !groupedString.isEmpty {
                groupedString = groupingSeparator + groupedString
            }
            groupedString = String(string[string.index(string.startIndex, offsetBy: max(0, index)) ..< string.index(string.startIndex, offsetBy: index + 3)]) + groupedString
        }
        return groupedString
    }
}

public func timeIntervalString(strings: PresentationStrings, value: Int32) -> String {
    if value < 60 {
        return strings.MessageTimer_Seconds(max(1, value))
    } else if value < 60 * 60 {
        return strings.MessageTimer_Minutes(max(1, value / 60))
    } else if value < 60 * 60 * 24 {
        return strings.MessageTimer_Hours(max(1, value / (60 * 60)))
    } else if value < 60 * 60 * 24 * 7 {
        return strings.MessageTimer_Days(max(1, value / (60 * 60 * 24)))
    } else if value < 60 * 60 * 24 * 30 {
        return strings.MessageTimer_Weeks(max(1, value / (60 * 60 * 24 * 7)))
    } else {
        return strings.MessageTimer_Months(max(1, value / (60 * 60 * 24 * 30)))
    }
}

public func shortTimeIntervalString(strings: PresentationStrings, value: Int32) -> String {
    if value < 60 {
        return strings.MessageTimer_ShortSeconds(max(1, value))
    } else if value < 60 * 60 {
        return strings.MessageTimer_ShortMinutes(max(1, value / 60))
    } else if value < 60 * 60 * 24 {
        return strings.MessageTimer_ShortHours(max(1, value / (60 * 60)))
    } else if value < 60 * 60 * 24 * 7 {
        return strings.MessageTimer_ShortDays(max(1, value / (60 * 60 * 24)))
    } else {
        return strings.MessageTimer_ShortWeeks(max(1, value / (60 * 60 * 24 * 7)))
    }
}

public func muteForIntervalString(strings: PresentationStrings, value: Int32) -> String {
    if value < 60 * 60 * 24 {
        return strings.MuteFor_Hours(max(1, value / (60 * 60)))
    } else {
        return strings.MuteFor_Days(max(1, value / (60 * 60 * 24)))
    }
}

public func unmuteIntervalString(strings: PresentationStrings, value: Int32) -> String {
    if value < 60 * 60 {
        return strings.MuteExpires_Minutes(max(1, value / 60))
    } else if value < 60 * 60 * 24 {
        return strings.MuteExpires_Hours(max(1, value / (60 * 60)))
    } else {
        return strings.MuteExpires_Days(max(1, value / (60 * 60 * 24)))
    }
}

public func callDurationString(strings: PresentationStrings, value: Int32) -> String {
    if value < 60 {
        return strings.Call_Seconds(max(1, value))
    } else {
        return strings.Call_Minutes(max(1, value / 60))
    }
}
