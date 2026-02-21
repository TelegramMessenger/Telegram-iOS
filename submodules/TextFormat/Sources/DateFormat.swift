import Foundation
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

public func stringForEntityFormattedDate(timestamp: Int32, format: MessageTextEntityType.DateTimeFormat, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> String {
    switch format {
    case .relative:
        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        let value = currentTimestamp - timestamp
        if value > 0 {
            if value < 60 {
                return strings.FormattedDate_SecondsAgo(value)
            } else if value <= 1 * 60 * 60 {
                return strings.FormattedDate_MinutesAgo(Int32(round(Float(value) / 60)))
            } else if value <= 24 * 60 * 60 {
                return strings.FormattedDate_HoursAgo(Int32(round(Float(value) / (60 * 60))))
            } else {
                return strings.FormattedDate_DaysAgo(Int32(round(Float(value) / (24 * 60 * 60))))
            }
        } else {
            let value = abs(value)
            if value < 60 {
                return strings.FormattedDate_InSeconds(value)
            } else if value <= 1 * 60 * 60 {
                return strings.FormattedDate_InMinutes(Int32(round(Float(value) / 60)))
            } else if value <= 24 * 60 * 60 {
                return strings.FormattedDate_InHours(Int32(round(Float(value) / (60 * 60))))
            } else {
                return strings.FormattedDate_InDays(Int32(round(Float(value) / (24 * 60 * 60))))
            }
        }
    case let .full(timeFormat, dateFormat, dayOfWeek):
        let _ = dayOfWeek
        var string = ""
        if dayOfWeek {
            var t: time_t = Int(timestamp)
            var timeinfo = tm()
            localtime_r(&t, &timeinfo);
            string = stringForDayOfWeek(strings: strings, day: timeinfo.tm_wday, short: dateFormat == .short)
        }
        if let dateFormat {
            if !string.isEmpty {
                string += " "
            }
            switch dateFormat {
            case .short:
                string += stringForShortDate(timestamp: timestamp, strings: strings, dateTimeFormat: dateTimeFormat)
            case .long:
                string += stringForFullDate(timestamp: timestamp, strings: strings, dateTimeFormat: dateTimeFormat)
            }
        }
        if let timeFormat {
            let timeString: String
            switch timeFormat {
            case .short:
                timeString = stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)
            case .long:
                timeString = stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat, withSeconds: true)
            }
            if !string.isEmpty {
                string = strings.Time_AtPreciseDate(string, timeString).string
            } else {
                string = timeString
            }
        }
        return string
    }
}

private func stringForDayOfWeek(strings: PresentationStrings, day: Int32, short: Bool) -> String {
    switch day {
    case 0:
        return short ? strings.Weekday_ShortSunday : strings.Weekday_Sunday
    case 1:
        return short ? strings.Weekday_ShortMonday : strings.Weekday_Monday
    case 2:
        return short ? strings.Weekday_ShortTuesday : strings.Weekday_Tuesday
    case 3:
        return short ? strings.Weekday_ShortWednesday : strings.Weekday_Wednesday
    case 4:
        return short ? strings.Weekday_ShortThursday : strings.Weekday_Thursday
    case 5:
        return short ? strings.Weekday_ShortFriday : strings.Weekday_Friday
    case 6:
        return short ? strings.Weekday_ShortSaturday : strings.Weekday_Saturday
    default:
        return ""
    }
}

public func stringForShortTimestamp(hours: Int32, minutes: Int32, seconds: Int32? = nil, dateTimeFormat: PresentationDateTimeFormat, formatAsPlainText: Bool = false) -> String {
    switch dateTimeFormat.timeFormat {
    case .regular:
        let hourString: String
        if hours == 0 {
            hourString = "12"
        } else if hours > 12 {
            hourString = "\(hours - 12)"
        } else {
            hourString = "\(hours)"
        }
        
        let periodString: String
        if hours >= 12 {
            periodString = "PM"
        } else {
            periodString = "AM"
        }
        
        let spaceCharacter: String
        if formatAsPlainText {
            spaceCharacter = " "
        } else {
            spaceCharacter = "\u{00a0}"
        }
        
        let minuteString = String(format: "%02d", arguments: [Int(minutes)])
        if let seconds {
            let secondString = String(format: "%02d", arguments: [Int(seconds)])
            return "\(hourString):\(minuteString):\(secondString)\(spaceCharacter)\(periodString)"
        } else {
            return "\(hourString):\(minuteString)\(spaceCharacter)\(periodString)"
        }
    case .military:
        if let seconds {
            return String(format: "%02d:%02d:%02d", arguments: [Int(hours), Int(minutes), Int(seconds)])
        } else {
            return String(format: "%02d:%02d", arguments: [Int(hours), Int(minutes)])
        }
    }
}

public func stringForMessageTimestamp(timestamp: Int32, dateTimeFormat: PresentationDateTimeFormat, withSeconds: Bool = false, local: Bool = true) -> String {
    var t = Int(timestamp)
    var timeinfo = tm()
    if local {
        localtime_r(&t, &timeinfo)
    } else {
        gmtime_r(&t, &timeinfo)
    }
    
    return stringForShortTimestamp(hours: timeinfo.tm_hour, minutes: timeinfo.tm_min, seconds: withSeconds ? timeinfo.tm_sec : nil, dateTimeFormat: dateTimeFormat)
}

public func stringForShortDate(timestamp: Int32, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, withTime: Bool = true) -> String {
    var t: time_t = Int(timestamp)
    var timeinfo = tm()
    localtime_r(&t, &timeinfo);
    
    let day = timeinfo.tm_mday
    let month = timeinfo.tm_mon + 1
    let year = timeinfo.tm_year
    
    let dateString: String
    let separator = dateTimeFormat.dateSeparator
    let suffix = dateTimeFormat.dateSuffix
    let displayYear = dateTimeFormat.requiresFullYear ? year - 100 + 2000 : year - 100
    switch dateTimeFormat.dateFormat {
        case .monthFirst:
            dateString = String(format: "%02d%@%02d%@%02d%@", month, separator, day, separator, displayYear, suffix)
        case .dayFirst:
            dateString = String(format: "%02d%@%02d%@%02d%@", day, separator, month, separator, displayYear, suffix)
    }
    
    return dateString
}

private func stringForFullDate(timestamp: Int32, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> String {
    var t: time_t = Int(timestamp)
    var timeinfo = tm()
    localtime_r(&t, &timeinfo);
    
    let dayString = "\(timeinfo.tm_mday)"
    let yearString = "\(2000 + timeinfo.tm_year - 100)"
    
    let monthFormat: (String, String) -> PresentationStrings.FormattedString
    switch timeinfo.tm_mon + 1 {
    case 1:
        monthFormat = strings.FormattedDate_LongDate_m1
    case 2:
        monthFormat = strings.FormattedDate_LongDate_m2
    case 3:
        monthFormat = strings.FormattedDate_LongDate_m3
    case 4:
        monthFormat = strings.FormattedDate_LongDate_m4
    case 5:
        monthFormat = strings.FormattedDate_LongDate_m5
    case 6:
        monthFormat = strings.FormattedDate_LongDate_m6
    case 7:
        monthFormat = strings.FormattedDate_LongDate_m7
    case 8:
        monthFormat = strings.FormattedDate_LongDate_m8
    case 9:
        monthFormat = strings.FormattedDate_LongDate_m9
    case 10:
        monthFormat = strings.FormattedDate_LongDate_m10
    case 11:
        monthFormat = strings.FormattedDate_LongDate_m11
    case 12:
        monthFormat = strings.FormattedDate_LongDate_m12
    default:
        return ""
    }

    return monthFormat(dayString, yearString).string
}
