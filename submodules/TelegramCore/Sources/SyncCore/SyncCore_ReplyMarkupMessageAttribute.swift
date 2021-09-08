import Postbox

public enum ReplyMarkupButtonAction: PostboxCoding, Equatable {
    case text
    case url(String)
    case callback(requiresPassword: Bool, data: MemoryBuffer)
    case requestPhone
    case requestMap
    case switchInline(samePeer: Bool, query: String)
    case openWebApp
    case payment
    case urlAuth(url: String, buttonId: Int32)
    case setupPoll(isQuiz: Bool?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .text
            case 1:
                self = .url(decoder.decodeStringForKey("u", orElse: ""))
            case 2:
                self = .callback(requiresPassword: decoder.decodeInt32ForKey("p", orElse: 0) != 0, data: decoder.decodeBytesForKey("d") ?? MemoryBuffer())
            case 3:
                self = .requestPhone
            case 4:
                self = .requestMap
            case 5:
                self = .switchInline(samePeer: decoder.decodeInt32ForKey("s", orElse: 0) != 0, query: decoder.decodeStringForKey("q", orElse: ""))
            case 6:
                self = .openWebApp
            case 7:
                self = .payment
            case 8:
                self = .urlAuth(url: decoder.decodeStringForKey("u", orElse: ""), buttonId: decoder.decodeInt32ForKey("b", orElse: 0))
            case 9:
                self = .setupPoll(isQuiz: decoder.decodeOptionalInt32ForKey("isq").flatMap { $0 != 0 })
            default:
                self = .text
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .text:
            encoder.encodeInt32(0, forKey: "v")
        case let .url(url):
            encoder.encodeInt32(1, forKey: "v")
            encoder.encodeString(url, forKey: "u")
        case let .callback(requiresPassword, data):
            encoder.encodeInt32(2, forKey: "v")
            encoder.encodeInt32(requiresPassword ? 1 : 0, forKey: "p")
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
        case .payment:
            encoder.encodeInt32(7, forKey: "v")
        case let .urlAuth(url, buttonId):
            encoder.encodeInt32(8, forKey: "v")
            encoder.encodeString(url, forKey: "u")
            encoder.encodeInt32(buttonId, forKey: "b")
        case let .setupPoll(isQuiz):
            encoder.encodeInt32(9, forKey: "v")
            if let isQuiz = isQuiz {
                encoder.encodeInt32(isQuiz ? 1 : 0, forKey: "isq")
            } else {
                encoder.encodeNil(forKey: "isq")
            }
        }
    }
}

public struct ReplyMarkupButton: PostboxCoding, Equatable {
    public let title: String
    public let titleWhenForwarded: String?
    public let action: ReplyMarkupButtonAction
    
    public init(title: String, titleWhenForwarded: String?, action: ReplyMarkupButtonAction) {
        self.title = title
        self.titleWhenForwarded = titleWhenForwarded
        self.action = action
    }
    
    public init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey(".t", orElse: "")
        self.titleWhenForwarded = decoder.decodeOptionalStringForKey(".tf")
        self.action = ReplyMarkupButtonAction(decoder: decoder)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: ".t")
        if let titleWhenForwarded = self.titleWhenForwarded {
            encoder.encodeString(titleWhenForwarded, forKey: ".tf")
        } else {
            encoder.encodeNil(forKey: ".tf")
        }
        self.action.encode(encoder)
    }
    
    public static func ==(lhs: ReplyMarkupButton, rhs: ReplyMarkupButton) -> Bool {
        return lhs.title == rhs.title && lhs.action == rhs.action
    }
}

public struct ReplyMarkupRow: PostboxCoding, Equatable {
    public let buttons: [ReplyMarkupButton]
    
    public init(buttons: [ReplyMarkupButton]) {
        self.buttons = buttons
    }
    
    public init(decoder: PostboxDecoder) {
        self.buttons = decoder.decodeObjectArrayWithDecoderForKey("b")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
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
    public static let fit = ReplyMarkupMessageFlags(rawValue: 1 << 4)
}

public class ReplyMarkupMessageAttribute: MessageAttribute, Equatable {
    public let rows: [ReplyMarkupRow]
    public let flags: ReplyMarkupMessageFlags
    public let placeholder: String?
    
    public init(rows: [ReplyMarkupRow], flags: ReplyMarkupMessageFlags, placeholder: String?) {
        self.rows = rows
        self.flags = flags
        self.placeholder = placeholder
    }
    
    public required init(decoder: PostboxDecoder) {
        self.rows = decoder.decodeObjectArrayWithDecoderForKey("r")
        self.flags = ReplyMarkupMessageFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.placeholder = decoder.decodeOptionalStringForKey("pl")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.rows, forKey: "r")
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        if let placeholder = self.placeholder {
            encoder.encodeString(placeholder, forKey: "pl")
        } else {
            encoder.encodeNil(forKey: "pl")
        }
    }
    
    public static func ==(lhs: ReplyMarkupMessageAttribute, rhs: ReplyMarkupMessageAttribute) -> Bool {
        return lhs.flags == rhs.flags && lhs.rows == rhs.rows && lhs.placeholder == rhs.placeholder
    }
}
