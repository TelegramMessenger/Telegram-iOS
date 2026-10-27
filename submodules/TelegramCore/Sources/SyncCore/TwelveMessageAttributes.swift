import Foundation
import Postbox

/// Marks a message that was deleted on the server while "Save deleted messages" (Настройки Twelve) was on:
/// the message is kept locally instead of being removed.
public class TwelveDeletedMessageAttribute: MessageAttribute {
    public let date: Int32
    
    public init(date: Int32) {
        self.date = date
    }
    
    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

/// The previous versions of an edited message's text, oldest first, kept while "Save edit history"
/// (Настройки Twelve) is on.
public class TwelveEditHistoryMessageAttribute: MessageAttribute {
    public struct Entry: Equatable {
        public let text: String
        public let date: Int32
        
        public init(text: String, date: Int32) {
            self.text = text
            self.date = date
        }
    }
    
    public let entries: [Entry]
    
    public init(entries: [Entry]) {
        self.entries = entries
    }
    
    required public init(decoder: PostboxDecoder) {
        let texts = decoder.decodeStringArrayForKey("t")
        let dates = decoder.decodeInt32ArrayForKey("d")
        var entries: [Entry] = []
        for i in 0 ..< min(texts.count, dates.count) {
            entries.append(Entry(text: texts[i], date: dates[i]))
        }
        self.entries = entries
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(self.entries.map(\.text), forKey: "t")
        encoder.encodeInt32Array(self.entries.map(\.date), forKey: "d")
    }
}

public extension Message {
    var twelveDeletedAttribute: TwelveDeletedMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? TwelveDeletedMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var twelveEditHistory: [TwelveEditHistoryMessageAttribute.Entry] {
        for attribute in self.attributes {
            if let attribute = attribute as? TwelveEditHistoryMessageAttribute {
                return attribute.entries
            }
        }
        return []
    }
}

public extension EngineMessage {
    var isTwelveDeleted: Bool {
        for attribute in self.attributes {
            if attribute is TwelveDeletedMessageAttribute {
                return true
            }
        }
        return false
    }
    
    var twelveEditHistory: [TwelveEditHistoryMessageAttribute.Entry] {
        for attribute in self.attributes {
            if let attribute = attribute as? TwelveEditHistoryMessageAttribute {
                return attribute.entries
            }
        }
        return []
    }
}
