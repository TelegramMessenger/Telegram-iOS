import Postbox

public final class ChannelState: PeerChatState, Equatable, CustomStringConvertible {
    public let pts: Int32
    public let invalidatedPts: Int32?
    public let synchronizedUntilMessageId: Int32?
    
    public init(pts: Int32, invalidatedPts: Int32?, synchronizedUntilMessageId: Int32?) {
        self.pts = pts
        self.invalidatedPts = invalidatedPts
        self.synchronizedUntilMessageId = synchronizedUntilMessageId
    }
    
    public init(decoder: PostboxDecoder) {
        self.pts = decoder.decodeInt32ForKey("pts", orElse: 0)
        self.invalidatedPts = decoder.decodeOptionalInt32ForKey("ipts")
        self.synchronizedUntilMessageId = decoder.decodeOptionalInt32ForKey("sumi")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.pts, forKey: "pts")
        if let invalidatedPts = self.invalidatedPts {
            encoder.encodeInt32(invalidatedPts, forKey: "ipts")
        } else {
            encoder.encodeNil(forKey: "ipts")
        }
        if let synchronizedUntilMessageId = self.synchronizedUntilMessageId {
            encoder.encodeInt32(synchronizedUntilMessageId, forKey: "sumi")
        } else {
            encoder.encodeNil(forKey: "sumi")
        }
    }
    
    public func withUpdatedPts(_ pts: Int32) -> ChannelState {
        return ChannelState(pts: pts, invalidatedPts: self.invalidatedPts, synchronizedUntilMessageId: self.synchronizedUntilMessageId)
    }
    
    public func withUpdatedInvalidatedPts(_ invalidatedPts: Int32?) -> ChannelState {
        return ChannelState(pts: self.pts, invalidatedPts: invalidatedPts, synchronizedUntilMessageId: self.synchronizedUntilMessageId)
    }
    
    public func withUpdatedSynchronizedUntilMessageId(_ synchronizedUntilMessageId: Int32?) -> ChannelState {
        return ChannelState(pts: self.pts, invalidatedPts: self.invalidatedPts, synchronizedUntilMessageId: synchronizedUntilMessageId)
    }
    
    public func equals(_ other: PeerChatState) -> Bool {
        if let other = other as? ChannelState, other == self {
            return true
        }
        return false
    }
    
    public var description: String {
        return "(pts: \(self.pts), invalidatedPts: \(String(describing: self.invalidatedPts)), synchronizedUntilMessageId: \(String(describing: self.synchronizedUntilMessageId))"
    }

    public static func ==(lhs: ChannelState, rhs: ChannelState) -> Bool {
        return lhs.pts == rhs.pts && lhs.invalidatedPts == rhs.invalidatedPts && lhs.synchronizedUntilMessageId == rhs.synchronizedUntilMessageId
	}
}
