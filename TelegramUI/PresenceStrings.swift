import Foundation
import Postbox
import TelegramCore

func stringForTimestamp(day: Int32, month: Int32, year: Int32) -> String {
    return String(format: "%d.%02d.%02d", day, month, year - 100)
}

func stringForTimestamp(day: Int32, month: Int32) -> String {
    return String(format: "%d.%02d", day, month)
}

func shortStringForDayOfWeek(_ day: Int32) -> String {
    switch day {
        case 0:
            return "Sun"
        case 1:
            return "Mon"
        case 2:
            return "Tue"
        case 3:
            return "Wed"
        case 4:
            return "Thu"
        case 5:
            return "Fri"
        case 6:
            return "Sat"
        default:
            return ""
    }
}

func stringForMonth(_ month: Int32) -> String {
    switch month {
        case 0:
            return "January"
        case 1:
            return "February"
        case 2:
            return "March"
        case 3:
            return "April"
        case 4:
            return "May"
        case 5:
            return "June"
        case 6:
            return "July"
        case 7:
            return "August"
        case 8:
            return "September"
        case 9:
            return "October"
        case 10:
            return "November"
        case 11:
            return "December"
        default:
            return ""
    }
}

func stringForMonth(_ month: Int32, ofYear year: Int32) -> String {
    return stringForMonth(month) + " \(1900 + year)"
}

func stringForTime(hours: Int32, minutes: Int32) -> String {
    return String(format: "%d:%02d", hours, minutes)
}

enum RelativeTimestampFormatDay {
    case today
    case yesterday
}

func stringForUserPresence(day: RelativeTimestampFormatDay, hours: Int32, minutes: Int32) -> String {
    let dayString: String
    switch day {
        case .today:
            dayString = "today"
        case .yesterday:
            dayString = "yesterday"
    }
    return "last seen \(dayString) at \(stringForTime(hours: hours, minutes: minutes))"
}

private func humanReadableStringForTimestamp(day: RelativeTimestampFormatDay, hours: Int32, minutes: Int32) -> String {
    let dayString: String
    switch day {
        case .today:
            dayString = "today"
        case .yesterday:
            dayString = "yesterday"
    }
    return "\(dayString) at \(stringForTime(hours: hours, minutes: minutes))"
}

func humanReadableStringForTimestamp(timestamp: Int32) -> String {
    var t: time_t = time_t(timestamp)
    var timeinfo: tm = tm()
    localtime_r(&t, &timeinfo)
    
    let timestampNow = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(timestampNow)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    
    if timeinfo.tm_year != timeinfoNow.tm_year {
        return "\(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))"
    }
    
    let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
    if dayDifference == 0 || dayDifference == -1 {
        let day: RelativeTimestampFormatDay
        if dayDifference == 0 {
            day = .today
        } else {
            day = .yesterday
        }
        return humanReadableStringForTimestamp(day: day, hours: timeinfo.tm_hour, minutes: timeinfo.tm_min)
    } else {
        return "\(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))"
    }
}

enum RelativeUserPresenceLastSeen {
    case justNow
    case minutesAgo(Int32)
    case hoursAgo(Int32)
    case todayAt(hours: Int32, minutes: Int32)
    case yesterdayAt(hours: Int32, minutes: Int32)
    case thisYear(month: Int32, day: Int32)
    case atDate(year: Int32, month: Int32)
}

enum RelativeUserPresenceStatus {
    case offline
    case online(at: Int32)
    case lastSeen(at: Int32)
    case recently
    case lastWeek
    case lastMonth
}

func relativeUserPresenceStatus(_ presence: TelegramUserPresence, relativeTo timestamp: Int32) -> RelativeUserPresenceStatus {
    switch presence.status {
        case .none:
            return .offline
        case let .present(statusTimestamp):
            if statusTimestamp >= timestamp {
                return .online(at: statusTimestamp)
            } else {
                return .lastSeen(at: statusTimestamp)
            }
        case .recently:
            return .recently
        case .lastWeek:
            return .lastWeek
        case .lastMonth:
            return .lastMonth
    }
}

func stringForRelativeTimestamp(_ relativeTimestamp: Int32, relativeTo timestamp: Int32) -> String {
    var t: time_t = time_t(relativeTimestamp)
    var timeinfo: tm = tm()
    localtime_r(&t, &timeinfo)
    
    var now: time_t = time_t(timestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    
    if timeinfo.tm_year != timeinfoNow.tm_year {
        return stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year)
    }
    
    let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
    if dayDifference > -7 {
        if dayDifference == 0 {
            return stringForTime(hours: timeinfo.tm_hour, minutes: timeinfo.tm_min)
        } else {
            return shortStringForDayOfWeek(timeinfo.tm_wday)
        }
    } else {
        return stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1)
    }
}

func stringAndActivityForUserPresence(_ presence: TelegramUserPresence, relativeTo timestamp: Int32) -> (String, Bool) {
    switch presence.status {
        case .none:
            return ("offline", false)
        case let .present(statusTimestamp):
            if statusTimestamp >= timestamp {
                return ("online", true)
            } else {
                let difference = timestamp - statusTimestamp
                if difference < 30 {
                    return ("last seen just now", false)
                } else if difference < 60 * 60 {
                    let minutes = difference / 60
                    if minutes <= 1 {
                        return ("last seen 1 minute ago", false)
                    } else {
                        return ("last seen \(minutes) minutes ago", false)
                    }
                } else {
                    var t: time_t = time_t(statusTimestamp)
                    var timeinfo: tm = tm()
                    localtime_r(&t, &timeinfo)
                    
                    var now: time_t = time_t(timestamp)
                    var timeinfoNow: tm = tm()
                    localtime_r(&now, &timeinfoNow)
                    
                    if timeinfo.tm_year != timeinfoNow.tm_year {
                        return ("last seen \(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))", false)
                    }
                    
                    let dayDifference = timeinfo.tm_yday - timeinfoNow.tm_yday
                    if dayDifference == 0 || dayDifference == -1 {
                        let day: RelativeTimestampFormatDay
                        if dayDifference == 0 {
                            day = .today
                        } else {
                            day = .yesterday
                        }
                        return (stringForUserPresence(day: day, hours: timeinfo.tm_hour, minutes: timeinfo.tm_min), false)
                    } else {
                        return ("last seen \(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year))", false)
                    }
                }
            }
        case .recently:
            return ("last seen recently", false)
        case .lastWeek:
            return ("last seen last week", false)
        case .lastMonth:
            return ("last seen last month", false)
    }
}

func userPresenceStringRefreshTimeout(_ presence: TelegramUserPresence, relativeTo timestamp: Int32) -> Double {
    switch presence.status {
        case let .present(statusTimestamp):
            if statusTimestamp >= timestamp {
                return Double(statusTimestamp - timestamp)
            } else {
                let difference = timestamp - statusTimestamp
                if difference < 30 {
                    return Double((30 - difference) + 1)
                } else if difference < 60 * 60 {
                    return Double((difference % 60) + 1)
                } else {
                    return Double.infinity
                }
                return Double.infinity
            }
        case .recently, .none, .lastWeek, .lastMonth:
            return Double.infinity
    }
}
