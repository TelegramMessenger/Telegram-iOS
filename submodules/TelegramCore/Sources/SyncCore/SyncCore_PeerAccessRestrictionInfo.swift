import Postbox
import FlatBuffers
import FlatSerialization

public final class RestrictionRule: PostboxCoding, Equatable {
    public let platform: String
    public let reason: String
    public let text: String
    
    public init(platform: String, reason: String, text: String) {
        self.platform = platform
        self.reason = reason
        self.text = text
    }
    
    public init(platform: String) {
        self.platform = platform
        self.reason = ""
        self.text = ""
    }
    
    public init(decoder: PostboxDecoder) {
        self.platform = decoder.decodeStringForKey("p", orElse: "all")
        self.reason = decoder.decodeStringForKey("r", orElse: "")
        self.text = decoder.decodeStringForKey("t", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.platform, forKey: "p")
        encoder.encodeString(self.reason, forKey: "r")
        encoder.encodeString(self.text, forKey: "t")
    }
    
    public static func ==(lhs: RestrictionRule, rhs: RestrictionRule) -> Bool {
        if lhs.platform != rhs.platform {
            return false
        }
        if lhs.reason != rhs.reason {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    public init(flatBuffersObject: TelegramCore_RestrictionRule) throws {
        self.platform = flatBuffersObject.platform
        self.reason = flatBuffersObject.reason
        self.text = flatBuffersObject.text
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let platformOffset = builder.create(string: self.platform)
        let reasonOffset = builder.create(string: self.reason)
        let textOffset = builder.create(string: self.text)
        
        let start = TelegramCore_RestrictionRule.startRestrictionRule(&builder)
        TelegramCore_RestrictionRule.add(platform: platformOffset, &builder)
        TelegramCore_RestrictionRule.add(reason: reasonOffset, &builder)
        TelegramCore_RestrictionRule.add(text: textOffset, &builder)
        return TelegramCore_RestrictionRule.endRestrictionRule(&builder, start: start)
    }
}

public final class PeerAccessRestrictionInfo: PostboxCoding, Equatable {
    public let rules: [RestrictionRule]
    
    public init(rules: [RestrictionRule]) {
        self.rules = rules
    }
    
    public init(decoder: PostboxDecoder) {
        if let value = decoder.decodeOptionalStringForKey("rsn") {
            self.rules = [RestrictionRule(platform: "all", reason: "", text: value)]
        } else {
            self.rules = decoder.decodeObjectArrayWithDecoderForKey("rs")
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.rules, forKey: "rs")
    }
    
    public static func ==(lhs: PeerAccessRestrictionInfo, rhs: PeerAccessRestrictionInfo) -> Bool {
        return lhs.rules == rhs.rules
    }
    
    public init(flatBuffersObject: TelegramCore_PeerAccessRestrictionInfo) throws {
        self.rules = try (0 ..< flatBuffersObject.rulesCount).map { try RestrictionRule(flatBuffersObject: flatBuffersObject.rules(at: $0)!) }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let rulesOffsets = self.rules.map { $0.encodeToFlatBuffers(builder: &builder) }
        let rulesOffset = builder.createVector(ofOffsets: rulesOffsets, len: rulesOffsets.count)
        
        let start = TelegramCore_PeerAccessRestrictionInfo.startPeerAccessRestrictionInfo(&builder)
        TelegramCore_PeerAccessRestrictionInfo.addVectorOf(rules: rulesOffset, &builder)
        return TelegramCore_PeerAccessRestrictionInfo.endPeerAccessRestrictionInfo(&builder, start: start)
    }
}
