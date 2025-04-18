import Foundation
import Postbox

public struct SearchBotsConfiguration: Equatable, Codable {
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.imageBotUsername = try container.decodeIfPresent(String.self, forKey: "img")
        self.gifBotUsername = try container.decodeIfPresent(String.self, forKey: "gif")
        self.venueBotUsername = try container.decodeIfPresent(String.self, forKey: "venue")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.imageBotUsername, forKey: "img")
        try container.encodeIfPresent(self.gifBotUsername, forKey: "gif")
        try container.encodeIfPresent(self.venueBotUsername, forKey: "venue")
    }
}

public func currentSearchBotsConfiguration(transaction: Transaction) -> SearchBotsConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.searchBotsConfiguration)?.get(SearchBotsConfiguration.self) {
        return entry
    } else {
        return SearchBotsConfiguration.defaultValue
    }
}

public func updateSearchBotsConfiguration(transaction: Transaction, configuration: SearchBotsConfiguration) {
    if currentSearchBotsConfiguration(transaction: transaction) != configuration {
        transaction.setPreferencesEntry(key: PreferencesKeys.searchBotsConfiguration, value: PreferencesEntry(configuration))
    }
}
