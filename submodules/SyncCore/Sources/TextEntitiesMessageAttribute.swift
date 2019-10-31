import Postbox

public enum MessageTextEntityType: Equatable {
    public typealias CustomEntityType = Int32
    
    case Unknown
    case Mention
    case Hashtag
    case BotCommand
    case Url
    case Email
    case Bold
    case Italic
    case Code
    case Pre
    case TextUrl(url: String)
    case TextMention(peerId: PeerId)
    case PhoneNumber
    case Strikethrough
    case BlockQuote
    case Underline
    case Custom(type: CustomEntityType)
}

public struct MessageTextEntity: PostboxCoding, Equatable {
    public let range: Range<Int>
    public let type: MessageTextEntityType
    
    public init(range: Range<Int>, type: MessageTextEntityType) {
        self.range = range
        self.type = type
    }
    
    public init(decoder: PostboxDecoder) {
        self.range = Int(decoder.decodeInt32ForKey("start", orElse: 0)) ..< Int(decoder.decodeInt32ForKey("end", orElse: 0))
        let type: Int32 = decoder.decodeInt32ForKey("_rawValue", orElse: 0)
        switch type {
            case 1:
                self.type = .Mention
            case 2:
                self.type = .Hashtag
            case 3:
                self.type = .BotCommand
            case 4:
                self.type = .Url
            case 5:
                self.type = .Email
            case 6:
                self.type = .Bold
            case 7:
                self.type = .Italic
            case 8:
                self.type = .Code
            case 9:
                self.type = .Pre
            case 10:
                self.type = .TextUrl(url: decoder.decodeStringForKey("url", orElse: ""))
            case 11:
                self.type = .TextMention(peerId: PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0)))
            case 12:
                self.type = .PhoneNumber
            case 13:
                self.type = .Strikethrough
            case 14:
                self.type = .BlockQuote
            case 15:
                self.type = .Underline
            case Int32.max:
                self.type = .Custom(type: decoder.decodeInt32ForKey("type", orElse: 0))
            default:
                self.type = .Unknown
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.range.lowerBound), forKey: "start")
        encoder.encodeInt32(Int32(self.range.upperBound), forKey: "end")
        switch self.type {
            case .Unknown:
                encoder.encodeInt32(0, forKey: "_rawValue")
            case .Mention:
                encoder.encodeInt32(1, forKey: "_rawValue")
            case .Hashtag:
                encoder.encodeInt32(2, forKey: "_rawValue")
            case .BotCommand:
                encoder.encodeInt32(3, forKey: "_rawValue")
            case .Url:
                encoder.encodeInt32(4, forKey: "_rawValue")
            case .Email:
                encoder.encodeInt32(5, forKey: "_rawValue")
            case .Bold:
                encoder.encodeInt32(6, forKey: "_rawValue")
            case .Italic:
                encoder.encodeInt32(7, forKey: "_rawValue")
            case .Code:
                encoder.encodeInt32(8, forKey: "_rawValue")
            case .Pre:
                encoder.encodeInt32(9, forKey: "_rawValue")
            case let .TextUrl(url):
                encoder.encodeInt32(10, forKey: "_rawValue")
                encoder.encodeString(url, forKey: "url")
            case let .TextMention(peerId):
                encoder.encodeInt32(11, forKey: "_rawValue")
                encoder.encodeInt64(peerId.toInt64(), forKey: "peerId")
            case .PhoneNumber:
                encoder.encodeInt32(12, forKey: "_rawValue")
            case .Strikethrough:
                encoder.encodeInt32(13, forKey: "_rawValue")
            case .BlockQuote:
                encoder.encodeInt32(14, forKey: "_rawValue")
            case .Underline:
                encoder.encodeInt32(15, forKey: "_rawValue")
            case let .Custom(type):
                encoder.encodeInt32(Int32.max, forKey: "_rawValue")
                encoder.encodeInt32(type, forKey: "type")
        }
    }
    
    public static func ==(lhs: MessageTextEntity, rhs: MessageTextEntity) -> Bool {
        return lhs.range == rhs.range && lhs.type == rhs.type
    }
}

public class TextEntitiesMessageAttribute: MessageAttribute, Equatable {
    public let entities: [MessageTextEntity]
    
    public var associatedPeerIds: [PeerId] {
        var result: [PeerId] = []
        for entity in entities {
            switch entity.type {
                case let .TextMention(peerId):
                    result.append(peerId)
                default:
                    break
            }
        }
        return result
    }
    
    public init(entities: [MessageTextEntity]) {
        self.entities = entities
    }
    
    required public init(decoder: PostboxDecoder) {
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("entities")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.entities, forKey: "entities")
    }
    
    public static func ==(lhs: TextEntitiesMessageAttribute, rhs: TextEntitiesMessageAttribute) -> Bool {
        return lhs.entities == rhs.entities
    }
}
