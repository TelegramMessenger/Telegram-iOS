import Foundation
import Postbox

public final class TelegramMediaTodo: Media, Equatable {
    public struct Flags: OptionSet {
        public var rawValue: Int32
        
        public init() {
            self.rawValue = 0
        }
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let othersCanAppend = Flags(rawValue: 1 << 0)
        public static let othersCanComplete = Flags(rawValue: 1 << 1)
    }
    
    public struct Item: Equatable, PostboxCoding {
        public let text: String
        public let entities: [MessageTextEntity]
        public let id: Int32
        
        public init(text: String, entities: [MessageTextEntity], id: Int32) {
            self.text = text
            self.entities = entities
            self.id = id
        }
        
        public init(decoder: PostboxDecoder) {
            self.text = decoder.decodeStringForKey("t", orElse: "")
            self.entities = decoder.decodeObjectArrayWithDecoderForKey("et")
            self.id = decoder.decodeInt32ForKey("i", orElse: 0)
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeString(self.text, forKey: "t")
            encoder.encodeObjectArray(self.entities, forKey: "et")
            encoder.encodeInt32(self.id, forKey: "i")
        }
    }
    
    public struct Completion: Equatable, PostboxCoding {
        public let id: Int32
        public let date: Int32
        public let completedBy: EnginePeer.Id
        
        public init(id: Int32, date: Int32, completedBy: EnginePeer.Id) {
            self.id = id
            self.date = date
            self.completedBy = completedBy
        }
        
        public init(decoder: PostboxDecoder) {
            self.id = decoder.decodeInt32ForKey("i", orElse: 0)
            self.date = decoder.decodeInt32ForKey("d", orElse: 0)
            self.completedBy = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(self.id, forKey: "i")
            encoder.encodeInt32(self.date, forKey: "d")
            encoder.encodeInt64(self.completedBy.toInt64(), forKey: "p")
        }
    }
    
    public var id: MediaId? {
        return nil
    }
    public var peerIds: [PeerId] {
        return self.completions.map { $0.completedBy }
    }
    
    public let flags: Flags
    public let text: String
    public let textEntities: [MessageTextEntity]
    public let items: [Item]
    public let completions: [Completion]
    
    public init(flags: Flags, text: String, textEntities: [MessageTextEntity], items: [Item], completions: [Completion] = []) {
        self.flags = flags
        self.text = text
        self.textEntities = textEntities
        self.items = items
        self.completions = completions
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = Flags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.textEntities = decoder.decodeObjectArrayWithDecoderForKey("te")
        self.items = decoder.decodeObjectArrayWithDecoderForKey("is")
        self.completions = decoder.decodeObjectArrayWithDecoderForKey("cs")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeObjectArray(self.textEntities, forKey: "te")
        encoder.encodeObjectArray(self.items, forKey: "is")
        encoder.encodeObjectArray(self.completions, forKey: "cs")
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaTodo else {
            return false
        }
        return self == other
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
    
    public static func ==(lhs: TelegramMediaTodo, rhs: TelegramMediaTodo) -> Bool {
        if lhs.flags != rhs.flags {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textEntities != rhs.textEntities {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.completions != rhs.completions {
            return false
        }
        return true
    }
    
    public func withUpdated(items: [TelegramMediaTodo.Item]) -> TelegramMediaTodo {
        return TelegramMediaTodo(
            flags: self.flags,
            text: self.text,
            textEntities: self.textEntities,
            items: items,
            completions: self.completions
        )
    }
    
    func withUpdated(completions: [TelegramMediaTodo.Completion]) -> TelegramMediaTodo {
        return TelegramMediaTodo(
            flags: self.flags,
            text: self.text,
            textEntities: self.textEntities,
            items: self.items,
            completions: completions
        )
    }
}
