import Foundation
import TelegramPresentationData
import TelegramStringFormatting
import NewsFeedSupport

public func newsTimeText(_ time: NewsCompactTime, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> String {
    switch time {
    case .now:
        return strings.News_Time_Now
    case let .seconds(value):
        return strings.News_Time_Seconds("\(value)").string
    case let .minutes(value):
        return strings.News_Time_Minutes("\(value)").string
    case let .hours(value):
        return strings.News_Time_Hours("\(value)").string
    case let .days(value):
        return strings.News_Time_Days("\(value)").string
    case let .date(timestamp):
        return stringForMediumCompactDate(timestamp: timestamp, strings: strings, dateTimeFormat: dateTimeFormat, withTime: false)
    }
}
