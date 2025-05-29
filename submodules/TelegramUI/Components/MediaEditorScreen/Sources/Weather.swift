import Foundation
import CoreLocation
import SwiftSignalKit
import TelegramCore
import StickerPickerScreen
import AccountContext
import DeviceLocationManager
import DeviceAccess

struct StoryWeather {
    let emoji: String
    let temperature: Double
}

private func getWeatherData(context: AccountContext, location: CLLocationCoordinate2D) -> Signal<StoryWeather?, NoError> {
    let appConfiguration = context.currentAppConfiguration.with { $0 }
    let botConfiguration = WeatherBotConfiguration.with(appConfiguration: appConfiguration)
    
    if let botUsername = botConfiguration.botName {
        return context.engine.peers.resolvePeerByName(name: botUsername, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(result) = result else {
                return .complete()
            }
            return .single(result)
        }
        |> mapToSignal { peer -> Signal<ChatContextResultCollection?, NoError> in
            guard let peer = peer else {
                return .single(nil)
            }
            return context.engine.messages.requestChatContextResults(botId: peer.id, peerId: context.account.peerId, query: "", location: .single((location.latitude, location.longitude)), offset: "")
            |> map { results -> ChatContextResultCollection? in
                return results?.results
            }
            |> `catch` { error -> Signal<ChatContextResultCollection?, NoError> in
                return .single(nil)
            }
        }
        |> map { contextResult -> StoryWeather? in
            guard let contextResult, let result = contextResult.results.first, let emoji = result.title, let temperature = result.description.flatMap(Double.init) else {
                return nil
            }
            return StoryWeather(emoji: emoji, temperature: temperature)
        }
    } else {
        return .single(nil)
    }
}

func getWeather(context: AccountContext, load: Bool) -> Signal<StickerPickerScreen.Weather, NoError> {
    guard let locationManager = context.sharedContext.locationManager else {
        return .single(.none)
    }
    
    return DeviceAccess.authorizationStatus(subject: .location(.send))
    |> mapToSignal { status in
        switch status {
        case .notDetermined:
            return .single(.notDetermined)
        case .denied, .restricted, .unreachable, .limited:
            return .single(.notAllowed)
        case .allowed:
            if load {
                return .single(.fetching)
                |> then(
                    currentLocationManagerCoordinate(manager: locationManager, timeout: 5.0)
                    |> mapToSignal { location in
                        if let location {
                            return getWeatherData(context: context, location: location)
                            |> mapToSignal { weather in
                                if let weather {
                                    let effectiveEmoji = emojiFor(for: weather.emoji.strippedEmoji, date: Date(), location: location)
                                    if let match = context.animatedEmojiStickersValue[effectiveEmoji]?.first {
                                        return .single(.loaded(StickerPickerScreen.Weather.LoadedWeather(
                                            emoji: effectiveEmoji,
                                            emojiFile: match.file._parse(),
                                            temperature: weather.temperature
                                        )))
                                    } else {
                                        return .single(.none)
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
            } else {
                return .single(.notPreloaded)
            }
        }
    }
}

private struct WeatherBotConfiguration {
    static var defaultValue: WeatherBotConfiguration {
        return WeatherBotConfiguration(botName: "izweatherbot")
    }
    
    let botName: String?
    
    fileprivate init(botName: String?) {
        self.botName = botName
    }
    
    public static func with(appConfiguration: AppConfiguration) -> WeatherBotConfiguration {
        if let data = appConfiguration.data, let botName = data["weather_search_username"] as? String {
            return WeatherBotConfiguration(botName: botName)
        } else {
            return .defaultValue
        }
    }
}

private let J1970: Double = 2440588.0
private let moonEmojis = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘", "🌑"]

private func emojiFor(for emoji: String, date: Date, location: CLLocationCoordinate2D) -> String {
    var emoji = emoji
    if !"".isEmpty, ["☀️", "🌤️"].contains(emoji) && !isDay(latitude: location.latitude, longitude: location.longitude, dateTime: date) {
        emoji = moonPhaseEmoji(for: date)
    }
    return emoji
}

private func moonPhaseEmoji(for date: Date) -> String {
    let julianDate = toJulianDate(date: date)

    let referenceNewMoon: Double = 2451550.1
    let synodicMonth: Double = 29.53058867

    let daysSinceNewMoon = julianDate - referenceNewMoon
    let newMoons = daysSinceNewMoon / synodicMonth
    let currentMoonPhase = (newMoons - floor(newMoons)) * synodicMonth

    switch currentMoonPhase {
    case 0..<1.84566:
        return moonEmojis[0]
    case 1.84566..<5.53699:
        return moonEmojis[1]
    case 5.53699..<9.22831:
        return moonEmojis[2]
    case 9.22831..<12.91963:
        return moonEmojis[3]
    case 12.91963..<16.61096:
        return moonEmojis[4]
    case 16.61096..<20.30228:
        return moonEmojis[5]
    case 20.30228..<23.99361:
        return moonEmojis[6]
    case 23.99361..<27.68493:
        return moonEmojis[7]
    default:
        return moonEmojis[8]
    }
}

private func isDay(latitude: Double, longitude: Double, dateTime: Date) -> Bool {
    let calendar = Calendar.current
    let date = calendar.startOfDay(for: dateTime)
    let time = dateTime.timeIntervalSince(date)

    let sunrise = calculateSunrise(latitude: latitude, longitude: longitude, date: date)
    let sunset = calculateSunset(latitude: latitude, longitude: longitude, date: date)

    return time >= sunrise * 3600 && time <= sunset * 3600
}

private func calculateSunrise(latitude: Double, longitude: Double, date: Date) -> Double {
    return calculateSunTime(latitude: latitude, longitude: longitude, date: date, isSunrise: true)
}

private func calculateSunset(latitude: Double, longitude: Double, date: Date) -> Double {
    return calculateSunTime(latitude: latitude, longitude: longitude, date: date, isSunrise: false)
}

private func calculateSunTime(latitude: Double, longitude: Double, date: Date, isSunrise: Bool) -> Double {
    let calendar = Calendar.current
    let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date)!
    let zenith = 90.833

    let D2R = Double.pi / 180.0
    let R2D = 180.0 / Double.pi

    let lngHour = longitude / 15.0
    let t = Double(dayOfYear) + ((isSunrise ? 6.0 : 18.0) - lngHour) / 24.0

    let M = (0.9856 * t) - 3.289
    var L = M + (1.916 * sin(M * D2R)) + (0.020 * sin(2 * M * D2R)) + 282.634

    if L > 360.0 {
        L -= 360.0
    } else if L < 0.0 {
        L += 360.0
    }

    var RA = R2D * atan(0.91764 * tan(L * D2R))
    if RA > 360.0 {
        RA -= 360.0
    } else if RA < 0.0 {
        RA += 360.0
    }

    let Lquadrant = (floor(L / 90.0)) * 90.0
    let RAquadrant = (floor(RA / 90.0)) * 90.0
    RA += (Lquadrant - RAquadrant)
    RA /= 15.0

    let sinDec = 0.39782 * sin(L * D2R)
    let cosDec = cos(asin(sinDec))

    let cosH = (cos(zenith * D2R) - (sinDec * sin(latitude * D2R))) / (cosDec * cos(latitude * D2R))
    if cosH > 1.0 || cosH < -1.0 {
        return -1
    }

    var H = isSunrise ? (360.0 - R2D * acos(cosH)) : R2D * acos(cosH)
    H /= 15.0

    let T = H + RA - (0.06571 * t) - 6.622
    var UT = T - lngHour

    if UT > 24.0 {
        UT -= 24.0
    } else if UT < 0.0 {
        UT += 24.0
    }
    return UT
}

private func toJulianDate(date: Date) -> Double {
    return date.timeIntervalSince1970 / 86400.0 + J1970 - 0.5
}
