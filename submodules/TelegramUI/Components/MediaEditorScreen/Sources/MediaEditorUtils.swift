import Foundation

func emojiFor(for meteocode: Int, timestamp: Int32) -> String {
    var emoji = weatherEmoji(for: meteocode)
    if ["☀️", "🌤️"].contains(emoji) {
        emoji = moonPhaseEmoji(for: timestamp)
    }
    return emoji
}

func moonPhaseEmoji(for timestamp: Int32) -> String {
    let newMoonDate = Date(timeIntervalSince1970: 1612137600)
    let date = Date(timeIntervalSince1970: Double(timestamp))
    let lunarMonth: TimeInterval = 29.53058867 * 24 * 60 * 60
    
    let daysSinceNewMoon = date.timeIntervalSince(newMoonDate) / (24 * 60 * 60)
    let currentMoonPhase = daysSinceNewMoon.truncatingRemainder(dividingBy: lunarMonth) / lunarMonth
    
    switch currentMoonPhase {
    case 0..<0.03:
        return "🌑"
    case 0.03..<0.22:
        return "🌒"
    case 0.22..<0.28:
        return "🌓"
    case 0.28..<0.47:
        return "🌔"
    case 0.47..<0.53:
        return "🌕"
    case 0.53..<0.72:
        return "🌖"
    case 0.72..<0.78:
        return "🌗"
    case 0.78..<0.97:
        return "🌘"
    default:
        return "🌑"
    }
}

func weatherEmoji(for meteocode: Int) -> String {
    switch meteocode {
    case 0:
        return "☀️"
    case 1, 2, 3:
        return "🌤️"
    case 45, 48:
        return "🌫️"
    case 51, 53, 55:
        return "🌧️" // Drizzle: Light, moderate, and dense intensity
    case 56, 57:
        return "🌧️" // Freezing Drizzle: Light and dense intensity
    case 61, 63, 65:
        return "🌧️" // Rain: Slight, moderate, and heavy intensity
    case 66, 67:
        return "🌧️" // Freezing Rain: Light and heavy intensity
    case 71, 73, 75:
        return "🌨️" // Snow fall: Slight, moderate, and heavy intensity
    case 77:
        return "🌨️" // Snow grains
    case 80, 81, 82:
        return "🌦️" // Rain showers: Slight, moderate, and violent
    case 85, 86:
        return "🌨️"
    case 95, 96, 99:
        return "⛈️" // Thunderstorm: Slight or moderate
    default:
        return "❓"
    }
}
