import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum ReplyMarkupButtonAction: Coding, Equatable {
    case text
    case url(String)
    case callback(MemoryBuffer)
    case requestPhone
    case requestMap
    case switchInline(samePeer: Bool, query: String)
    case openWebApp
    
    public init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("v") as Int32 {
            case 0:
                self = .text
            case 1:
                self = .url(decoder.decodeStringForKey("u"))
            case 2:
                self = .callback(decoder.decodeBytesForKey("d") ?? MemoryBuffer())
            case 3:
                self = .requestPhone
            case 4:
                self = .requestMap
            case 5:
                self = .switchInline(samePeer: decoder.decodeInt32ForKey("s") != 0, query: decoder.decodeStringForKey("q"))
            case 6:
                self = .openWebApp
            default:
                self = .text
        }
    }
    
    public func encode(_ encoder: Encoder) {
        switch self {
            case .text:
                encoder.encodeInt32(0, forKey: "v")
            case let .url(url):
                encoder.encodeInt32(1, forKey: "v")
                encoder.encodeString(url, forKey: "u")
            case let .callback(data):
                encoder.encodeInt32(2, forKey: "v")
                encoder.encodeBytes(data, forKey: "d")
            case .requestPhone:
                encoder.encodeInt32(3, forKey: "v")
            case .requestMap:
                encoder.encodeInt32(4, forKey: "v")
            case let .switchInline(samePeer, query):
                encoder.encodeInt32(5, forKey: "v")
                encoder.encodeInt32(samePeer ? 1 : 0, forKey: "s")
                encoder.encodeString(query, forKey: "q")
            case .openWebApp:
                encoder.encodeInt32(6, forKey: "v")
        }
    }
    
    public static func ==(lhs: ReplyMarkupButtonAction, rhs: ReplyMarkupButtonAction) -> Bool {
        switch lhs {
            case .text:
                if case .text = rhs {
                    return true
                } else {
                    return false
                }
            case let .url(url):
                if case .url(url) = rhs {
                    return true
                } else {
                    return false
                }
            case let .callback(data):
                if case .callback(data) = rhs {
                    return true
                } else {
                    return false
                }
            case .requestPhone:
                if case .requestPhone = rhs {
                    return true
                } else {
                    return false
                }
            case .requestMap:
                if case .requestMap = rhs {
                    return true
                } else {
                    return false
                }
            case let .switchInline(samePeer, query):
                if case .switchInline(samePeer, query) = rhs {
                    return true
                } else {
                    return false
                }
            case .openWebApp:
                if case .openWebApp = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct ReplyMarkupButton: Coding, Equatable {
    public let title: String
    public let action: ReplyMarkupButtonAction
    
    init(title: String, action: ReplyMarkupButtonAction) {
        self.title = title
        self.action = action
    }
    
    public init(decoder: Decoder) {
        self.title = decoder.decodeStringForKey(".t")
        self.action = ReplyMarkupButtonAction(decoder: decoder)
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeString(self.title, forKey: ".t")
        self.action.encode(encoder)
    }
    
    public static func ==(lhs: ReplyMarkupButton, rhs: ReplyMarkupButton) -> Bool {
        return lhs.title == rhs.title && lhs.action == rhs.action
    }
}

public struct ReplyMarkupRow: Coding, Equatable {
    public let buttons: [ReplyMarkupButton]
    
    init(buttons: [ReplyMarkupButton]) {
        self.buttons = buttons
    }
    
    public init(decoder: Decoder) {
        self.buttons = decoder.decodeObjectArrayWithDecoderForKey("b")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeObjectArray(self.buttons, forKey: "b")
    }
    
    public static func ==(lhs: ReplyMarkupRow, rhs: ReplyMarkupRow) -> Bool {
        return lhs.buttons == rhs.buttons
    }
}

public struct ReplyMarkupMessageFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let once = ReplyMarkupMessageFlags(rawValue: 1 << 0)
    public static let personal = ReplyMarkupMessageFlags(rawValue: 1 << 1)
    public static let setupReply = ReplyMarkupMessageFlags(rawValue: 1 << 2)
    public static let inline = ReplyMarkupMessageFlags(rawValue: 1 << 3)
}

public class ReplyMarkupMessageAttribute: MessageAttribute, Equatable {
    public let rows: [ReplyMarkupRow]
    public let flags: ReplyMarkupMessageFlags
    
    init(rows: [ReplyMarkupRow], flags: ReplyMarkupMessageFlags) {
        self.rows = rows
        self.flags = flags
    }
    
    public required init(decoder: Decoder) {
        self.rows = decoder.decodeObjectArrayWithDecoderForKey("r")
        self.flags = ReplyMarkupMessageFlags(rawValue: decoder.decodeInt32ForKey("f"))
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeObjectArray(self.rows, forKey: "r")
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
    }
    
    public static func ==(lhs: ReplyMarkupMessageAttribute, rhs: ReplyMarkupMessageAttribute) -> Bool {
        return lhs.flags == rhs.flags && lhs.rows == rhs.rows
    }
}

extension ReplyMarkupButton {
    init(apiButton: Api.KeyboardButton) {
        switch apiButton {
            case let .keyboardButton(text):
                self.init(title: text, action: .text)
            case let .keyboardButtonCallback(text, data):
                let memory = malloc(data.size)!
                memcpy(memory, data.data, data.size)
                let dataBuffer = MemoryBuffer(memory: memory, capacity: data.size, length: data.size, freeWhenDone: true)
                self.init(title: text, action: .callback(dataBuffer))
            case let .keyboardButtonRequestGeoLocation(text):
                self.init(title: text, action: .requestMap)
            case let .keyboardButtonRequestPhone(text):
                self.init(title: text, action: .requestPhone)
            case let .keyboardButtonSwitchInline(flags, text, query):
                self.init(title: text, action: .switchInline(samePeer: (flags & (1 << 0)) != 0, query: query))
            case let .keyboardButtonUrl(text, url):
                self.init(title: text, action: .url(url))
            case let .keyboardButtonGame(text):
                self.init(title: text, action: .openWebApp)
        }
    }
}

extension ReplyMarkupRow {
    init(apiRow: Api.KeyboardButtonRow) {
        switch apiRow {
            case let .keyboardButtonRow(buttons):
                self.init(buttons: buttons.map { ReplyMarkupButton(apiButton: $0) })
        }
    }
}

extension ReplyMarkupMessageAttribute {
    convenience init(apiMarkup: Api.ReplyMarkup) {
        var rows: [ReplyMarkupRow] = []
        var flags = ReplyMarkupMessageFlags()
        switch apiMarkup {
            case let .replyKeyboardMarkup(markupFlags, apiRows):
                rows = apiRows.map { ReplyMarkupRow(apiRow: $0) }
                if (markupFlags & (1 << 1)) != 0 {
                    flags.insert(.once)
                }
                if (markupFlags & (1 << 2)) != 0 {
                    flags.insert(.personal)
                }
            case let .replyInlineMarkup(apiRows):
                rows = apiRows.map { ReplyMarkupRow(apiRow: $0) }
                flags.insert(.inline)
            case let .replyKeyboardForceReply(forceReplyFlags):
                if (forceReplyFlags & (1 << 1)) != 0 {
                    flags.insert(.once)
                }
                if (forceReplyFlags & (1 << 2)) != 0 {
                    flags.insert(.personal)
                }
            case let .replyKeyboardHide(hideFlags):
                if (hideFlags & (1 << 2)) != 0 {
                    flags.insert(.personal)
                }
        }
        self.init(rows: rows, flags: flags)
    }
}
