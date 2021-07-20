import Foundation
import TelegramPresentationData
import TelegramUIPreferences

public func stringForShortTimestamp(hours: Int32, minutes: Int32, dateTimeFormat: PresentationDateTimeFormat) -> String {
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
        if minutes >= 10 {
            return "\(hourString):\(minutes) \(periodString)"
        } else {
            return "\(hourString):0\(minutes) \(periodString)"
        }
    case .military:
        return String(format: "%02d:%02d", arguments: [Int(hours), Int(minutes)])
    }
}

public func stringForMessageTimestamp(timestamp: Int32, dateTimeFormat: PresentationDateTimeFormat, local: Bool = true) -> String {
    var t = Int(timestamp)
    var timeinfo = tm()
    if local {
        localtime_r(&t, &timeinfo)
    } else {
        gmtime_r(&t, &timeinfo)
    }
    
    return stringForShortTimestamp(hours: timeinfo.tm_hour, minutes: timeinfo.tm_min, dateTimeFormat: dateTimeFormat)
}

public func stringForMediumDate(timestamp: Int32, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> String {
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
    
    let timeString = stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min), dateTimeFormat: dateTimeFormat)
    
    return strings.Time_MediumDate(dateString, timeString).string
}

public func stringForFullDate(timestamp: Int32, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> String {
    var t: time_t = Int(timestamp)
    var timeinfo = tm()
    localtime_r(&t, &timeinfo);
    
    let dayString = "\(timeinfo.tm_mday)"
    let yearString = "\(2000 + timeinfo.tm_year - 100)"
    let timeString = stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min), dateTimeFormat: dateTimeFormat)
    
    let monthFormat: (String, String, String) -> PresentationStrings.FormattedString
    switch timeinfo.tm_mon + 1 {
    case 1:
        monthFormat = strings.Time_PreciseDate_m1
    case 2:
        monthFormat = strings.Time_PreciseDate_m2
    case 3:
        monthFormat = strings.Time_PreciseDate_m3
    case 4:
        monthFormat = strings.Time_PreciseDate_m4
    case 5:
        monthFormat = strings.Time_PreciseDate_m5
    case 6:
        monthFormat = strings.Time_PreciseDate_m6
    case 7:
        monthFormat = strings.Time_PreciseDate_m7
    case 8:
        monthFormat = strings.Time_PreciseDate_m8
    case 9:
        monthFormat = strings.Time_PreciseDate_m9
    case 10:
        monthFormat = strings.Time_PreciseDate_m10
    case 11:
        monthFormat = strings.Time_PreciseDate_m11
    case 12:
        monthFormat = strings.Time_PreciseDate_m12
    default:
        return ""
    }

    return monthFormat(dayString, yearString, timeString).string
}

public func stringForDate(timestamp: Int32, strings: PresentationStrings) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .none
    formatter.dateStyle = .medium
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = localeWithStrings(strings)
    return formatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
}

public func stringForDate(date: Date, timeZone: TimeZone? = TimeZone(secondsFromGMT: 0), strings: PresentationStrings) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .none
    formatter.dateStyle = .medium
    formatter.timeZone = timeZone
    formatter.locale = localeWithStrings(strings)
    return formatter.string(from: date)
}

public func stringForDateWithoutYear(date: Date, timeZone: TimeZone? = TimeZone(secondsFromGMT: 0), strings: PresentationStrings) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .none
    formatter.timeZone = timeZone
    formatter.locale = localeWithStrings(strings)
    formatter.setLocalizedDateFormatFromTemplate("MMMMd")
    return formatter.string(from: date)
}

public func roundDateToDays(_ timestamp: Int32) -> Int32 {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var components = calendar.dateComponents(Set([.era, .year, .month, .day]), from: Date(timeIntervalSince1970: Double(timestamp)))
    components.hour = 0
    components.minute = 0
    components.second = 0
    
    guard let date = calendar.date(from: components) else {
        assertionFailure()
        return timestamp
    }
    return Int32(date.timeIntervalSince1970)
}
