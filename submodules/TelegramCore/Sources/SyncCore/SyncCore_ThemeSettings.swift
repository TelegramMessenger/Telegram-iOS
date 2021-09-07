import Postbox

public final class ThemeSettings: Codable, Equatable {
    public let currentTheme: TelegramTheme?
 
    public init(currentTheme: TelegramTheme?) {
        self.currentTheme = currentTheme
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let currentThemeData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "t") {
            self.currentTheme = TelegramTheme(decoder: PostboxDecoder(buffer: MemoryBuffer(data: currentThemeData.data)))
        } else {
            self.currentTheme = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        if let currentTheme = self.currentTheme {
            let currentThemeData = PostboxEncoder().encodeObjectToRawData(currentTheme)
            try container.encode(currentThemeData, forKey: "t")
        } else {
            try container.encodeNil(forKey: "t")
        }
    }
    
    public static func ==(lhs: ThemeSettings, rhs: ThemeSettings) -> Bool {
        return lhs.currentTheme == rhs.currentTheme
    }
}
