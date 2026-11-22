import Foundation
import TelegramCore

public enum BirthdayRelativeDate: Equatable {
    case yesterday
    case today
    case tomorrow
}

public func relativeDateForBirthday(_ birthday: TelegramBirthday, relativeTo date: Date = Date(), timeZone: TimeZone = .current) -> BirthdayRelativeDate? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone

    if birthdayMatchesDate(birthday, date: date, calendar: calendar) {
        return .today
    }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: date), birthdayMatchesDate(birthday, date: yesterday, calendar: calendar) {
        return .yesterday
    }
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date), birthdayMatchesDate(birthday, date: tomorrow, calendar: calendar) {
        return .tomorrow
    }
    return nil
}

public func hasBirthdayToday(cachedData: CachedUserData) -> Bool {
    if let birthday = cachedData.birthday {
        return hasBirthdayToday(birthday: birthday)
    }
    return false
}

public func hasBirthdayToday(birthday: TelegramBirthday) -> Bool {
    return hasBirthdayToday(birthday: birthday, now: Date(), calendar: gregorianCalendarForBirthdayCalculations())
}

func hasBirthdayToday(birthday: TelegramBirthday, now: Date, calendar: Calendar) -> Bool {
    return birthdayMatchesDate(birthday, date: now, calendar: calendar)
}

private func birthdayMatchesDate(_ birthday: TelegramBirthday, date: Date, calendar: Calendar) -> Bool {
    let dateComponents = calendar.dateComponents(Set([.day, .month]), from: date)
    return dateComponents.day == Int(birthday.day) && dateComponents.month == Int(birthday.month)
}
