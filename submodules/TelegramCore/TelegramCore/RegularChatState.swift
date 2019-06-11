import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

final class RegularChatState: PeerChatState, Equatable {
    let invalidatedPts: Int32?
    
    init(invalidatedPts: Int32?) {
        self.invalidatedPts = invalidatedPts
    }
    
    init(decoder: PostboxDecoder) {
        self.invalidatedPts = decoder.decodeOptionalInt32ForKey("ipts")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let invalidatedPts = self.invalidatedPts {
            encoder.encodeInt32(invalidatedPts, forKey: "ipts")
        } else {
            encoder.encodeNil(forKey: "ipts")
        }
    }
    
    func withUpdatedInvalidatedPts(_ invalidatedPts: Int32?) -> RegularChatState {
        return RegularChatState(invalidatedPts: invalidatedPts)
    }
    
    func equals(_ other: PeerChatState) -> Bool {
        if let other = other as? RegularChatState, other == self {
            return true
        }
        return false
    }

    static func ==(lhs: RegularChatState, rhs: RegularChatState) -> Bool {
        return lhs.invalidatedPts == rhs.invalidatedPts
    }
}
