import Postbox

public struct BotCommand: PostboxCoding, Hashable {
    public let text: String
    public let description: String
    
    public init(text: String, description: String) {
        self.text = text
        self.description = description
    }
    
    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.description = decoder.decodeStringForKey("d", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeString(self.description, forKey: "d")
    }
}

public enum BotMenuButton: PostboxCoding, Hashable {
    case commands
    case webView(text: String, url: String)
        
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 1:
                self = .webView(text: decoder.decodeStringForKey("t", orElse: ""), url: decoder.decodeStringForKey("u", orElse: ""))
            default:
                self = .commands
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .commands:
                encoder.encodeInt32(0, forKey: "v")
            case let .webView(text, url):
                encoder.encodeInt32(1, forKey: "v")
                encoder.encodeString(text, forKey: "t")
                encoder.encodeString(url, forKey: "u")
        }
    }
}

public final class BotInfo: PostboxCoding, Equatable {
    public let description: String
    public let photo: TelegramMediaImage?
    public let commands: [BotCommand]
    public let menuButton: BotMenuButton
    
    public init(description: String, photo: TelegramMediaImage?, commands: [BotCommand], menuButton: BotMenuButton) {
        self.description = description
        self.photo = photo
        self.commands = commands
        self.menuButton = menuButton
    }
    
    public init(decoder: PostboxDecoder) {
        self.description = decoder.decodeStringForKey("d", orElse: "")
        if let photo = decoder.decodeObjectForKey("ph", decoder: { TelegramMediaImage(decoder: $0) }) as? TelegramMediaImage {
            self.photo = photo
        } else {
            self.photo = nil
        }
        self.commands = decoder.decodeObjectArrayWithDecoderForKey("c")
        self.menuButton = (decoder.decodeObjectForKey("b", decoder: { BotMenuButton(decoder: $0) }) as? BotMenuButton) ?? .commands
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.description, forKey: "d")
        if let photo = self.photo {
            encoder.encodeObject(photo, forKey: "ph")
        } else {
            encoder.encodeNil(forKey: "ph")
        }
        encoder.encodeObjectArray(self.commands, forKey: "c")
        encoder.encodeObject(self.menuButton, forKey: "b")
    }
    
    public static func ==(lhs: BotInfo, rhs: BotInfo) -> Bool {
        return lhs.description == rhs.description && lhs.commands == rhs.commands && lhs.menuButton == rhs.menuButton
    }
}
