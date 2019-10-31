import Postbox

public final class ChannelState: PeerChatState, Equatable, CustomStringConvertible {
    public let pts: Int32
    public let invalidatedPts: Int32?
    
    public init(pts: Int32, invalidatedPts: Int32?) {
        self.pts = pts
        self.invalidatedPts = invalidatedPts
    }
    
    public init(decoder: PostboxDecoder) {
        self.pts = decoder.decodeInt32ForKey("pts", orElse: 0)
        self.invalidatedPts = decoder.decodeOptionalInt32ForKey("ipts")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.pts, forKey: "pts")
        if let invalidatedPts = self.invalidatedPts {
            encoder.encodeInt32(invalidatedPts, forKey: "ipts")
        } else {
            encoder.encodeNil(forKey: "ipts")
        }
    }
    
    public func withUpdatedPts(_ pts: Int32) -> ChannelState {
        return ChannelState(pts: pts, invalidatedPts: self.invalidatedPts)
    }
    
    public func withUpdatedInvalidatedPts(_ invalidatedPts: Int32?) -> ChannelState {
        return ChannelState(pts: self.pts, invalidatedPts: invalidatedPts)
    }
    
    public func equals(_ other: PeerChatState) -> Bool {
        if let other = other as? ChannelState, other == self {
            return true
        }
        return false
    }
    
    public var description: String {
        return "(pts: \(self.pts))"
    }

    public static func ==(lhs: ChannelState, rhs: ChannelState) -> Bool {
	    return lhs.pts == rhs.pts && lhs.invalidatedPts == rhs.invalidatedPts
	}
}
