import Foundation
import Postbox

public struct SearchBotsConfiguration: Equatable, PreferencesEntry {
    public let imageBotUsername: String?
    public let gifBotUsername: String?
    public let venueBotUsername: String?
    
    public static var defaultValue: SearchBotsConfiguration {
        return SearchBotsConfiguration(imageBotUsername: "bing", gifBotUsername: "gif", venueBotUsername: "foursquare")
    }
    
    public init(imageBotUsername: String?, gifBotUsername: String?, venueBotUsername: String?) {
        self.imageBotUsername = imageBotUsername
        self.gifBotUsername = gifBotUsername
        self.venueBotUsername = venueBotUsername
    }
    
    public init(decoder: PostboxDecoder) {
        self.imageBotUsername = decoder.decodeOptionalStringForKey("img")
        self.gifBotUsername = decoder.decodeOptionalStringForKey("gif")
        self.venueBotUsername = decoder.decodeOptionalStringForKey("venue")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let imageBotUsername = self.imageBotUsername {
            encoder.encodeString(imageBotUsername, forKey: "img")
        } else {
            encoder.encodeNil(forKey: "img")
        }
        if let gifBotUsername = self.gifBotUsername {
            encoder.encodeString(gifBotUsername, forKey: "gif")
        } else {
            encoder.encodeNil(forKey: "gif")
        }
        if let venueBotUsername = self.venueBotUsername {
            encoder.encodeString(venueBotUsername, forKey: "venue")
        } else {
            encoder.encodeNil(forKey: "venue")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? SearchBotsConfiguration else {
            return false
        }
        return self == to
    }
}

public func currentSearchBotsConfiguration(transaction: Transaction) -> SearchBotsConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.searchBotsConfiguration) as? SearchBotsConfiguration {
        return entry
    } else {
        return SearchBotsConfiguration.defaultValue
    }
}

public func updateSearchBotsConfiguration(transaction: Transaction, configuration: SearchBotsConfiguration) {
    if !currentSearchBotsConfiguration(transaction: transaction).isEqual(to: configuration) {
        transaction.setPreferencesEntry(key: PreferencesKeys.searchBotsConfiguration, value: configuration)
    }
}
