import Foundation

/// Formats a chat-list row's last-message timestamp, Telegram-style. Pure: the caller passes
/// `now` (the view passes `Date()`), so the result is deterministic in tests.
///
/// - same calendar day as `now` (or future) → locale short time ("9:45 AM" / "09:45")
/// - yesterday → "Yesterday"
/// - 2–6 days ago → short weekday ("Mon")
/// - 7+ days ago → locale short date ("5/12/26")
func chatListTimestamp(_ unixSeconds: Int, now: Date, calendar: Calendar = .current) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(unixSeconds))
    let startOfDate = calendar.startOfDay(for: date)
    let startOfNow = calendar.startOfDay(for: now)
    let dayDiff = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day ?? 0

    switch dayDiff {
    case ...0:
        return formatted(date, calendar: calendar) { $0.dateStyle = .none; $0.timeStyle = .short }
    case 1:
        return "Yesterday"
    case 2...6:
        return formatted(date, calendar: calendar) { $0.setLocalizedDateFormatFromTemplate("EEE") }
    default:
        return formatted(date, calendar: calendar) { $0.dateStyle = .short; $0.timeStyle = .none }
    }
}

private func formatted(_ date: Date, calendar: Calendar, _ configure: (DateFormatter) -> Void) -> String {
    let f = DateFormatter()
    f.calendar = calendar
    f.locale = calendar.locale ?? .current
    f.timeZone = calendar.timeZone
    configure(f)
    return f.string(from: date)
}
