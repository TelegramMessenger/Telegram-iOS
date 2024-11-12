import Foundation
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

public struct BotAppSettings: PostboxCoding, Equatable {
    public let placeholderData: Data?
    public let backgroundColor: Int32?
    public let backgroundDarkColor: Int32?
    public let headerColor: Int32?
    public let headerDarkColor: Int32?
    
    public init(placeholderData: Data?, backgroundColor: Int32?, backgroundDarkColor: Int32?, headerColor: Int32?, headerDarkColor: Int32?) {
        self.placeholderData = placeholderData
        self.backgroundColor = backgroundColor
        self.backgroundDarkColor = backgroundDarkColor
        self.headerColor = headerColor
        self.headerDarkColor = headerDarkColor
    }
    
    public init(decoder: PostboxDecoder) {
        self.placeholderData = decoder.decodeDataForKey("pd")
        self.backgroundColor = decoder.decodeOptionalInt32ForKey("b")
        self.backgroundDarkColor = decoder.decodeOptionalInt32ForKey("bd")
        self.headerColor = decoder.decodeOptionalInt32ForKey("h")
        self.headerDarkColor = decoder.decodeOptionalInt32ForKey("hd")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let placeholderData = self.placeholderData {
            encoder.encodeData(placeholderData, forKey: "pd")
        } else {
            encoder.encodeNil(forKey: "pd")
        }
        if let backgroundColor = self.backgroundColor {
            encoder.encodeInt32(backgroundColor, forKey: "b")
        } else {
            encoder.encodeNil(forKey: "b")
        }
        if let backgroundDarkColor = self.backgroundDarkColor {
            encoder.encodeInt32(backgroundDarkColor, forKey: "bd")
        } else {
            encoder.encodeNil(forKey: "bd")
        }
        if let headerColor = self.headerColor {
            encoder.encodeInt32(headerColor, forKey: "h")
        } else {
            encoder.encodeNil(forKey: "h")
        }
        if let headerDarkColor = self.headerDarkColor {
            encoder.encodeInt32(headerDarkColor, forKey: "hd")
        } else {
            encoder.encodeNil(forKey: "hd")
        }
    }
}

public final class BotInfo: PostboxCoding, Equatable {
    public let description: String
    public let photo: TelegramMediaImage?
    public let video: TelegramMediaFile?
    public let commands: [BotCommand]
    public let menuButton: BotMenuButton
    public let privacyPolicyUrl: String?
    public let appSettings: BotAppSettings?
    
    public init(description: String, photo: TelegramMediaImage?, video: TelegramMediaFile?, commands: [BotCommand], menuButton: BotMenuButton, privacyPolicyUrl: String?, appSettings: BotAppSettings?) {
        self.description = description
        self.photo = photo
        self.video = video
        self.commands = commands
        self.menuButton = menuButton
        self.privacyPolicyUrl = privacyPolicyUrl
        self.appSettings = appSettings
    }
    
    public init(decoder: PostboxDecoder) {
        self.description = decoder.decodeStringForKey("d", orElse: "")
        if let photo = decoder.decodeObjectForKey("ph", decoder: { TelegramMediaImage(decoder: $0) }) as? TelegramMediaImage {
            self.photo = photo
        } else {
            self.photo = nil
        }
        if let video = decoder.decodeObjectForKey("vid", decoder: { TelegramMediaFile(decoder: $0) }) as? TelegramMediaFile {
            self.video = video
        } else {
            self.video = nil
        }
        self.commands = decoder.decodeObjectArrayWithDecoderForKey("c")
        self.menuButton = (decoder.decodeObjectForKey("b", decoder: { BotMenuButton(decoder: $0) }) as? BotMenuButton) ?? .commands
        self.privacyPolicyUrl = decoder.decodeOptionalStringForKey("pp")
        if let appSettings = decoder.decodeObjectForKey("as", decoder: { BotAppSettings(decoder: $0) }) as? BotAppSettings {
            self.appSettings = appSettings
        } else {
            self.appSettings = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.description, forKey: "d")
        if let photo = self.photo {
            encoder.encodeObject(photo, forKey: "ph")
        } else {
            encoder.encodeNil(forKey: "ph")
        }
        if let video = self.video {
            encoder.encodeObject(video, forKey: "vid")
        } else {
            encoder.encodeNil(forKey: "vid")
        }
        encoder.encodeObjectArray(self.commands, forKey: "c")
        encoder.encodeObject(self.menuButton, forKey: "b")
        if let privacyPolicyUrl = self.privacyPolicyUrl {
            encoder.encodeString(privacyPolicyUrl, forKey: "pp")
        } else {
            encoder.encodeNil(forKey: "pp")
        }
        if let appSettings = self.appSettings {
            encoder.encodeObject(appSettings, forKey: "as")
        } else {
            encoder.encodeNil(forKey: "as")
        }
    }
    
    public static func ==(lhs: BotInfo, rhs: BotInfo) -> Bool {
        return lhs.description == rhs.description && lhs.commands == rhs.commands && lhs.menuButton == rhs.menuButton && lhs.photo == rhs.photo && lhs.privacyPolicyUrl == rhs.privacyPolicyUrl && lhs.appSettings == rhs.appSettings
    }
}
