import Postbox

public final class ThemeSettings: Codable, Equatable {
    public let currentTheme: TelegramTheme?
 
    public init(currentTheme: TelegramTheme?) {
        self.currentTheme = currentTheme
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.currentTheme = try container.decodeIfPresent(TelegramTheme.self, forKey: "t")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.currentTheme, forKey: "t")
    }
    
    public static func ==(lhs: ThemeSettings, rhs: ThemeSettings) -> Bool {
        return lhs.currentTheme == rhs.currentTheme
    }
}
