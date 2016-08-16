import Foundation
import Postbox

enum MessageTextEntityType {
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
}

struct MessageTextEntity: Coding {
    let range: Range<Int>
    let type: MessageTextEntityType
    
    init(range: Range<Int>, type: MessageTextEntityType) {
        self.range = range
        self.type = type
    }
    
    init(decoder: Decoder) {
        self.range = Int(decoder.decodeInt32ForKey("start")) ..< Int(decoder.decodeInt32ForKey("end"))
        let type: Int32 = decoder.decodeInt32ForKey("_rawValue")
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
                self.type = .TextUrl(url: decoder.decodeStringForKey("url"))
            case 11:
                self.type = .TextMention(peerId: PeerId(decoder.decodeInt64ForKey("peerId")))
            default:
                self.type = .Unknown
        }
    }
    
    func encode(_ encoder: Encoder) {
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
        }
    }
}

class TextEntitiesMessageAttribute: MessageAttribute {
    let entities: [MessageTextEntity]
    
    var associatedPeerIds: [PeerId] {
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
    
    init(entities: [MessageTextEntity]) {
        self.entities = entities
    }
    
    required init(decoder: Decoder) {
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("entities")
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeObjectArray(self.entities, forKey: "entities")
    }
}
