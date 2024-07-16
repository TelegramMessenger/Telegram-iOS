import Foundation
import CoreLocation
import SwiftSignalKit
import TelegramCore
import StickerPickerScreen
import AccountContext
import DeviceLocationManager

func emojiFor(for meteocode: Int, date: Date, location: CLLocationCoordinate2D) -> String? {
    var emoji = weatherEmoji(for: meteocode)
    if ["☀️", "🌤️"].contains(emoji) && isNightTime(date: date, location: location) {
        emoji = moonPhaseEmoji(for: date)
    }
    return emoji
}

private func moonPhaseEmoji(for date: Date) -> String {
    let newMoonDate = Date(timeIntervalSince1970: 1612137600)
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

func weatherEmoji(for meteocode: Int) -> String? {
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
        return nil
    }
}

struct StoryWeather {
    let emoji: String
    let temperature: Double
}

private func getWeatherData(location: CLLocationCoordinate2D) -> Signal<StoryWeather?, NoError> {
    let latitude = "\(location.latitude)"
    let longitude = "\(location.longitude)"
    let url = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code"
    
    return Signal { subscriber in
        let disposable = fetchHttpResource(url: url).start(next: { result in
            if case let .dataPart(_, data, _, complete) = result, complete {
                guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                guard let current = dict["current"] as? [String: Any], let temperature = current["temperature_2m"] as? Double, let weatherCode = current["weather_code"] as? Int else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                if let emoji = emojiFor(for: weatherCode, date: Date(), location: location) {
                    subscriber.putNext(StoryWeather(emoji: emoji, temperature: temperature))
                } else {
                    subscriber.putNext(nil)
                }
                subscriber.putCompletion()
            }
        })
        
        return disposable
    }
}

func getWeather(context: AccountContext) -> Signal<StickerPickerScreen.Weather, NoError> {
    guard let locationManager = context.sharedContext.locationManager else {
        return .single(.none)
    }
    return .single(.fetching)
    |> then(
        currentLocationManagerCoordinate(manager: locationManager, timeout: 5.0)
        |> mapToSignal { location in
            if let location {
                return getWeatherData(location: location)
                |> mapToSignal { weather in
                    if let weather {
                        return context.animatedEmojiStickers
                        |> take(1)
                        |> mapToSignal { result in
                            if let match = result[weather.emoji.strippedEmoji]?.first {
                                return .single(.loaded(StickerPickerScreen.Weather.LoadedWeather(
                                    emoji: weather.emoji.strippedEmoji,
                                    emojiFile: match.file,
                                    temperature: weather.temperature
                                )))
                            } else {
                                return .single(.none)
                            }
                        }
                    } else {
                        return .single(.none)
                    }
                }
            } else {
                return .single(.none)
            }
        }
    )
}

private func calculateSunriseSunset(date: Date, location: CLLocationCoordinate2D) -> (sunrise: Date, sunset: Date)? {
    guard let utcTimezone = TimeZone(identifier: "UTC") else { return nil }
    
    let zenith: Double = 90.83
    
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utcTimezone
    
    guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) else {
        return nil
    }
    
    func toRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }
    
    func toDegrees(_ radians: Double) -> Double {
        return radians * 180.0 / .pi
    }
    
    func normalise(_ value: Double, maximum: Double) -> Double {
        var value = value
        if value < 0 {
            value += maximum
        }
        if value > maximum {
            value -= maximum
        }
        return value
    }
    
    func calculateTime(isSunrise: Bool) -> Date? {
        let day = Double(dayOfYear)
        let lngHour = location.longitude / 15.0
        
        let hourTime: Double = isSunrise ? 6 : 18
        let t = day + ((hourTime - lngHour) / 24)
        
        let M = (0.9856 * t) - 3.289
        
        var L = M + 1.916 * sin(toRadians(M)) + 0.020 * sin(2 * toRadians(M)) + 282.634
        L = normalise(L, maximum: 360)
        
        var RA = toDegrees(atan(0.91764 * tan(toRadians(L))))
        RA = normalise(RA, maximum: 360)
        
        let Lquadrant = floor(L / 90) * 90
        let RAquadrant = floor(RA / 90) * 90
        RA = RA + (Lquadrant - RAquadrant)
        RA = RA / 15
        
        let sinDec = 0.39782 * sin(toRadians(L))
        let cosDec = cos(asin(sinDec))
        let cosH = (cos(toRadians(zenith)) - (sinDec * sin(toRadians(location.latitude)))) / (cosDec * cos(toRadians(location.latitude)))
        guard cosH < 1 else {
            return nil
        }
        guard cosH > -1 else {
            return nil
        }
        
        let tempH = isSunrise ? 360.0 - toDegrees(acos(cosH)) : toDegrees(acos(cosH))
        let H = tempH / 15.0
        let T = H + RA - (0.06571 * t) - 6.622
        
        var UT = T - lngHour
        UT = normalise(UT, maximum: 24)
        
        let hour = floor(UT)
        let minute = floor((UT - hour) * 60.0)
        let second = (((UT - hour) * 60) - minute) * 60.0
        
        let shouldBeYesterday = lngHour > 0 && UT > 12 && isSunrise
        let shouldBeTomorrow = lngHour < 0 && UT < 12 && !isSunrise
        
        let setDate: Date
        if shouldBeYesterday {
            setDate = Date(timeInterval: -(60 * 60 * 24), since: date)
        } else if shouldBeTomorrow {
            setDate = Date(timeInterval: (60 * 60 * 24), since: date)
        } else {
            setDate = date
        }
        
        var components = calendar.dateComponents([.day, .month, .year], from: setDate)
        components.hour = Int(hour)
        components.minute = Int(minute)
        components.second = Int(second)
        
        calendar.timeZone = utcTimezone
        return calendar.date(from: components)
    }
    
    guard let sunrise = calculateTime(isSunrise: true),
          let sunset = calculateTime(isSunrise: false) else {
        return nil
    }
    
    return (sunrise, sunset)
}

private func isNightTime(date: Date, location: CLLocationCoordinate2D) -> Bool {
    let calendar = Calendar.current
    let date = calendar.startOfDay(for: date)
    guard let (sunrise, sunset) = calculateSunriseSunset(date: date, location: location) else {
        return false
    }
    return date < sunrise || date > sunset
}
