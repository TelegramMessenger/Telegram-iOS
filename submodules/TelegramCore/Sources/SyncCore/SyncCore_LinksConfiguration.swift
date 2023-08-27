import Foundation
import Postbox

public struct LinksConfiguration: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case autologinToken
    }
    
    public let autologinToken: String?
    
    public static var defaultValue: LinksConfiguration {
        return LinksConfiguration(autologinToken: nil)
    }
    
    public init(autologinToken: String?) {
        self.autologinToken = autologinToken
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.autologinToken = try container.decodeIfPresent(String.self, forKey: .autologinToken)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(self.autologinToken, forKey: .autologinToken)
    }
}

public func currentLinksConfiguration(transaction: Transaction) -> LinksConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.linksConfiguration)?.get(LinksConfiguration.self) {
        return entry
    } else {
        return LinksConfiguration.defaultValue
    }
}

func updateLinksConfiguration(transaction: Transaction, configuration: LinksConfiguration) {
    if currentLinksConfiguration(transaction: transaction) != configuration {
        transaction.setPreferencesEntry(key: PreferencesKeys.linksConfiguration, value: PreferencesEntry(configuration))
    }
}
