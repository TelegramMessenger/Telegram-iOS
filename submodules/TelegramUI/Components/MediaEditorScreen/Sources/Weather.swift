import Foundation
import CoreLocation
import SwiftSignalKit
import TelegramCore
import StickerPickerScreen
import AccountContext
import DeviceLocationManager

struct StoryWeather {
    let emoji: String
    let temperature: Double
}

private func getWeatherData(context: AccountContext, location: CLLocationCoordinate2D) -> Signal<StoryWeather?, NoError> {
    let appConfiguration = context.currentAppConfiguration.with { $0 }
    let botConfiguration = WeatherBotConfiguration.with(appConfiguration: appConfiguration)
    
    if let botUsername = botConfiguration.botName {
        return context.engine.peers.resolvePeerByName(name: botUsername)
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

func getWeather(context: AccountContext) -> Signal<StickerPickerScreen.Weather, NoError> {
    guard let locationManager = context.sharedContext.locationManager else {
        return .single(.none)
    }
    return .single(.fetching)
    |> then(
        currentLocationManagerCoordinate(manager: locationManager, timeout: 5.0)
        |> mapToSignal { location in
            if let location {
                return getWeatherData(context: context, location: location)
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
