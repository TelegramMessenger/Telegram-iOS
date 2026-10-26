import Foundation

/// A post's age as the feed shows it: "now", "30s", "6m", "1h", "3d", then a date.
public enum NewsCompactTime: Equatable {
    /// Under a second, or a timestamp ahead of the clock.
    case now
    case seconds(Int32)
    case minutes(Int32)
    case hours(Int32)
    case days(Int32)
    /// Older than a week: the date of `timestamp`.
    case date(Int32)
}

public func newsCompactTime(timestamp: Int32, now: Int32) -> NewsCompactTime {
    let delta = max(0, now - timestamp)
    if delta == 0 {
        return .now
    }
    if delta < 60 {
        return .seconds(delta)
    }
    if delta < 60 * 60 {
        return .minutes(delta / 60)
    }
    if delta < 24 * 60 * 60 {
        return .hours(delta / (60 * 60))
    }
    if delta < 7 * 24 * 60 * 60 {
        return .days(delta / (24 * 60 * 60))
    }
    return .date(timestamp)
}
