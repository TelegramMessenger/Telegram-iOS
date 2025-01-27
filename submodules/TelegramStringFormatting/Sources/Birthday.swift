import Foundation
import TelegramCore

public func hasBirthdayToday(cachedData: CachedUserData) -> Bool {
    if let birthday = cachedData.birthday {
        return hasBirthdayToday(birthday: birthday)
        
    }
    return false
}

public func hasBirthdayToday(birthday: TelegramBirthday) -> Bool {
    let today = Calendar.current.dateComponents(Set([.day, .month]), from: Date())
    if today.day == Int(birthday.day) && today.month == Int(birthday.month) {
        return true
    }
    return false
}
