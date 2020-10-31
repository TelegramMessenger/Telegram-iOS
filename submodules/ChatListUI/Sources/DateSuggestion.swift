import Foundation
import TelegramPresentationData
import TelegramStringFormatting

private let telegramReleaseDate = Date(timeIntervalSince1970: 1376438400.0)

func suggestDates(for string: String, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat) -> [(minDate: Date?, maxDate: Date, string: String?)] {
    let string = string.folding(options: .diacriticInsensitive, locale: .current).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if string.count < 3 {
        return []
    }
    
    let months: [Int: (String, String)] = [
        1:  (strings.Month_GenJanuary, strings.Month_ShortJanuary),
        2:  (strings.Month_GenFebruary, strings.Month_ShortFebruary),
        3:  (strings.Month_GenMarch, strings.Month_ShortMarch),
        4:  (strings.Month_GenApril, strings.Month_ShortApril),
        5:  (strings.Month_GenMay, strings.Month_ShortMay),
        6:  (strings.Month_GenJune, strings.Month_ShortJune),
        7:  (strings.Month_GenJuly, strings.Month_ShortJuly),
        8:  (strings.Month_GenAugust, strings.Month_ShortAugust),
        9:  (strings.Month_GenSeptember, strings.Month_ShortSeptember),
        10: (strings.Month_GenOctober, strings.Month_ShortOctober),
        11: (strings.Month_GenNovember, strings.Month_ShortNovember),
        12: (strings.Month_GenDecember, strings.Month_ShortDecember)
    ]
    
    let weekDays: [Int: (String, String)] = [
        1:  (strings.Weekday_Monday, strings.Weekday_ShortMonday),
        2:  (strings.Weekday_Tuesday, strings.Weekday_ShortTuesday),
        3:  (strings.Weekday_Wednesday, strings.Weekday_ShortWednesday),
        4:  (strings.Weekday_Thursday, strings.Weekday_ShortThursday),
        5:  (strings.Weekday_Friday, strings.Weekday_ShortFriday),
        6:  (strings.Weekday_Saturday, strings.Weekday_ShortSaturday),
        7:  (strings.Weekday_Sunday, strings.Weekday_ShortSunday.lowercased()),
    ]
   
    let today = strings.Weekday_Today
    let yesterday = strings.Weekday_Yesterday
    let dateSeparator = dateTimeFormat.dateSeparator
    
    var result: [(Date?, Date, String?)] = []
    
    let calendar = Calendar.current
    func getLowerDate(for date: Date) -> Date {
        let components = calendar.dateComponents(in: .current, from: date)
        let upperComponents = DateComponents(year: components.year, month: components.month, day: components.day, hour: 0, minute: 0, second: 0)
        return calendar.date(from: upperComponents)!
    }
    func getUpperDate(for date: Date) -> Date {
        let components = calendar.dateComponents(in: .current, from: date)
        let upperComponents = DateComponents(year: components.year, month: components.month, day: components.day, hour: 23, minute: 59, second: 59)
        return calendar.date(from: upperComponents)!
    }
    
    let now = Date()
    let nowComponents = calendar.dateComponents(in: .current, from: now)
    guard let year = nowComponents.year else {
        return []
    }
    
    let midnightDate = calendar.startOfDay(for: now)
    if today.lowercased().hasPrefix(string) {
        let todayDate = getUpperDate(for: midnightDate)
        result.append((midnightDate, todayDate, today))
    }
    if yesterday.lowercased().hasPrefix(string) {
        let yesterdayMidnight = calendar.date(byAdding: .day, value: -1, to: midnightDate)!
        let yesterdayDate = getUpperDate(for: yesterdayMidnight)
        result.append((yesterdayMidnight, yesterdayDate, yesterday))
    }
    
    func getLowerMonthDate(month: Int, year: Int) -> Date {
        let upperComponents = DateComponents(year: year, month: month, day: 1, hour: 0, minute: 0, second: 0)
        return calendar.date(from: upperComponents)!
    }
    
    func getUpperMonthDate(month: Int, year: Int) -> Date {
        let monthComponents = DateComponents(year: year, month: month)
        let date = calendar.date(from: monthComponents)!
        let range = calendar.range(of: .day, in: .month, for: date)!
        let numDays = range.count
        let upperComponents = DateComponents(year: year, month: month, day: numDays, hour: 23, minute: 59, second: 59)
        return calendar.date(from: upperComponents)!
    }
        
    let decimalRange = string.rangeOfCharacter(from: .decimalDigits)
    if decimalRange != nil {
        if string.count == 4, let value = Int(string), value <= year {
            let minDate = getLowerMonthDate(month: 1, year: value)
            let maxDate = getUpperMonthDate(month: 12, year: value)
            if maxDate > telegramReleaseDate {
                result.append((minDate, maxDate, "\(value)"))
            }
        } else {
            do {
                func process(_ date: Date) {
                    var resultDate = date
                    if resultDate > now && !calendar.isDate(resultDate, equalTo: now, toGranularity: .year) {
                        if let date = calendar.date(byAdding: .year, value: -1, to: resultDate) {
                            resultDate = date
                        }
                    }
                    
                    let stringComponents = string.components(separatedBy: dateSeparator)
                    if stringComponents.count < 3 {
                        for i in 0..<8 {
                            if let date = calendar.date(byAdding: .year, value: -i, to: resultDate), date < now, date > telegramReleaseDate {
                                let lowerDate = getLowerDate(for: resultDate)
                                result.append((lowerDate, date, nil))
                            }
                        }
                    } else if resultDate < now, date > telegramReleaseDate {
                        let lowerDate = getLowerDate(for: resultDate)
                        result.append((lowerDate, resultDate, nil))
                    }
                }
                let dd = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
                if let match = dd.firstMatch(in: string, options: [], range: NSMakeRange(0, string.utf16.count)), let date = match.date, date > telegramReleaseDate {
                    process(date)
                } else if let match = dd.firstMatch(in: string.replacingOccurrences(of: ".", with: "/"), options: [], range: NSMakeRange(0, string.utf16.count)), let date = match.date, date > telegramReleaseDate {
                    process(date)
                }
            } catch {
                
            }
        }
    }
    
    for (day, value) in weekDays {
        let dayName = value.0.lowercased()
        let shortDayName = value.1.lowercased()
        if string == shortDayName || (string.count >= shortDayName.count && dayName.hasPrefix(string)) {
            var nextDateComponent = calendar.dateComponents([.hour, .minute, .second], from: now)
            nextDateComponent.weekday = day + calendar.firstWeekday
            if let date = calendar.nextDate(after: now, matching: nextDateComponent, matchingPolicy: .nextTime, direction: .backward) {
                let lowerAnchorDate = getLowerDate(for: date)
                let upperAnchorDate = getUpperDate(for: date)
                for i in 0..<5 {
                    if let lowerDate = calendar.date(byAdding: .hour, value: -24 * 7 * i, to: lowerAnchorDate), let upperDate = calendar.date(byAdding: .hour, value: -24 * 7 * i, to: upperAnchorDate) {
                        if calendar.isDate(upperDate, equalTo: now, toGranularity: .weekOfYear) {
                            result.append((lowerDate, upperDate, value.0))
                        } else {
                            result.append((lowerDate, upperDate, nil))
                        }
                    }
                }
            }
        }
    }
    
    let cleanString = string.trimmingCharacters(in: .decimalDigits).trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanDigits = string.trimmingCharacters(in: .letters).trimmingCharacters(in: .whitespacesAndNewlines)
    
    for (month, value) in months {
        let monthName = value.0.lowercased()
        let shortMonthName = value.1.lowercased()
        if cleanString == shortMonthName || (cleanString.count >= shortMonthName.count && monthName.hasPrefix(cleanString)) {
            if cleanDigits.count == 4, let year = Int(cleanDigits) {
                let lowerDate = getLowerMonthDate(month: month, year: year)
                let upperDate = getUpperMonthDate(month: month, year: year)
                if upperDate <= now && upperDate > telegramReleaseDate {
                    result.append((lowerDate, upperDate, stringForMonth(strings: strings, month: Int32(month - 1), ofYear: Int32(year - 1900))))
                }
            } else if cleanDigits.isEmpty {
                for i in (year - 7 ... year).reversed() {
                    let lowerDate = getUpperMonthDate(month: month, year: i)
                    let upperDate = getUpperMonthDate(month: month, year: i)
                    if upperDate <= now && upperDate > telegramReleaseDate {
                        result.append((lowerDate, upperDate, stringForMonth(strings: strings, month: Int32(month - 1), ofYear: Int32(i - 1900))))
                    }
                }
            }
        }
    }
    
    return result
}
