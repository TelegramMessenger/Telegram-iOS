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

func shortTimeIntervalString(strings: PresentationStrings, value: Int32) -> String {
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

func muteForIntervalString(strings: PresentationStrings, value: Int32) -> String {
    if value < 60 * 60 * 24 {
        return strings.MuteFor_Hours(max(1, value / (60 * 60)))
    } else {
        return strings.MuteFor_Days(max(1, value / (60 * 60 * 24)))
    }
}

func unmuteIntervalString(strings: PresentationStrings, value: Int32) -> String {
    if value < 60 * 60 {
        return strings.MuteExpires_Minutes(max(1, value / 60))
    } else if value < 60 * 60 * 24 {
        return strings.MuteExpires_Hours(max(1, value / (60 * 60)))
    } else {
        return strings.MuteExpires_Days(max(1, value / (60 * 60 * 24)))
    }
}
