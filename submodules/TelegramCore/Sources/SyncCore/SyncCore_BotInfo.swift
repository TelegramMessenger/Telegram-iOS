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

public final class BotInfo: PostboxCoding, Equatable {
    public let description: String
    public let commands: [BotCommand]
    
    public init(description: String, commands: [BotCommand]) {
        self.description = description
        self.commands = commands
    }
    
    public init(decoder: PostboxDecoder) {
        self.description = decoder.decodeStringForKey("d", orElse: "")
        self.commands = decoder.decodeObjectArrayWithDecoderForKey("c")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.description, forKey: "d")
        encoder.encodeObjectArray(self.commands, forKey: "c")
    }
    
    public static func ==(lhs: BotInfo, rhs: BotInfo) -> Bool {
        return lhs.description == rhs.description && lhs.commands == rhs.commands
    }
}
