import Foundation

public func stringForDuration(_ duration: Int32, position: Int32? = nil) -> String {
    var duration = duration
    if let position = position {
        duration = max(0, duration - position)
    }
    let hours = duration / 3600
    let minutes = duration / 60 % 60
    let seconds = duration % 60
    let durationString: String
    if hours > 0 {
        durationString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        durationString = String(format: "%d:%02d", minutes, seconds)
    }
    return durationString
}
