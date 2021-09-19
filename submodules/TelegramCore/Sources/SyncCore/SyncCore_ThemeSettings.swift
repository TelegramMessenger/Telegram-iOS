import Postbox

public final class ThemeSettings: Codable, Equatable {
    public let currentTheme: TelegramTheme?
 
    public init(currentTheme: TelegramTheme?) {
        self.currentTheme = currentTheme
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.currentTheme = (try container.decodeIfPresent(TelegramThemeNativeCodable.self, forKey: "t"))?.value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        if let currentTheme = self.currentTheme {
            try container.encode(TelegramThemeNativeCodable(currentTheme), forKey: "t")
        } else {
            try container.encodeNil(forKey: "t")
        }
    }
    
    public static func ==(lhs: ThemeSettings, rhs: ThemeSettings) -> Bool {
        return lhs.currentTheme == rhs.currentTheme
    }
}
