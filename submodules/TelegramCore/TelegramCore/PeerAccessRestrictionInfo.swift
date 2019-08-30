import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

public final class RestrictionRule: PostboxCoding, Equatable {
    public let platform: String
    public let reason: String
    public let text: String
    
    public init(platform: String, reason: String, text: String) {
        self.platform = platform
        self.reason = reason
        self.text = text
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
}

public final class PeerAccessRestrictionInfo: PostboxCoding, Equatable {
    public let rules: [RestrictionRule]
    
    init(rules: [RestrictionRule]) {
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
}

extension RestrictionRule {
    convenience init(apiReason: Api.RestrictionReason) {
        switch apiReason {
        case let .restrictionReason(platform, reason, text):
            self.init(platform: platform, reason: reason, text: text)
        }
    }
}

extension PeerAccessRestrictionInfo {
    convenience init(apiReasons: [Api.RestrictionReason]) {
        self.init(rules: apiReasons.map(RestrictionRule.init(apiReason:)))
    }
}
