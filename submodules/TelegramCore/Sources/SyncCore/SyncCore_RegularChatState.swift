import Postbox

public final class RegularChatState: PeerChatState, Equatable {
    public let invalidatedPts: Int32?
    
    public init(invalidatedPts: Int32?) {
        self.invalidatedPts = invalidatedPts
    }
    
    public init(decoder: PostboxDecoder) {
        self.invalidatedPts = decoder.decodeOptionalInt32ForKey("ipts")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let invalidatedPts = self.invalidatedPts {
            encoder.encodeInt32(invalidatedPts, forKey: "ipts")
        } else {
            encoder.encodeNil(forKey: "ipts")
        }
    }
    
    public func withUpdatedInvalidatedPts(_ invalidatedPts: Int32?) -> RegularChatState {
        return RegularChatState(invalidatedPts: invalidatedPts)
    }
    
    public func equals(_ other: PeerChatState) -> Bool {
        if let other = other as? RegularChatState, other == self {
            return true
        }
        return false
    }

    public static func ==(lhs: RegularChatState, rhs: RegularChatState) -> Bool {
        return lhs.invalidatedPts == rhs.invalidatedPts
    }
}
