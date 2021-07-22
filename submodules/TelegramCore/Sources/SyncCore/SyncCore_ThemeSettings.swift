import Postbox

public final class ThemeSettings: PreferencesEntry, Equatable {
    public let currentTheme: TelegramTheme?
 
    public init(currentTheme: TelegramTheme?) {
        self.currentTheme = currentTheme
    }
    
    public init(decoder: PostboxDecoder) {
        self.currentTheme = decoder.decodeObjectForKey("t", decoder: { TelegramTheme(decoder: $0) }) as? TelegramTheme
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let currentTheme = currentTheme {
            encoder.encodeObject(currentTheme, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ThemeSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: ThemeSettings, rhs: ThemeSettings) -> Bool {
        return lhs.currentTheme == rhs.currentTheme
    }
}
