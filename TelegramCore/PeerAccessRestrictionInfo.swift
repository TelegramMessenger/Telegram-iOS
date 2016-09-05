import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class PeerAccessRestrictionInfo: Coding, Equatable {
    public let reason: String
    
    init(reason: String) {
        self.reason = reason
    }
    
    public init(decoder: Decoder) {
        self.reason = decoder.decodeStringForKey("rsn")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeString(self.reason, forKey: "rsn")
    }
    
    public static func ==(lhs: PeerAccessRestrictionInfo, rhs: PeerAccessRestrictionInfo) -> Bool {
        return lhs.reason == rhs.reason
    }
}
