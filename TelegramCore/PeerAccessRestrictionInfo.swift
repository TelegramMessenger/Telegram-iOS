import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class PeerAccessRestrictionInfo: PostboxCoding, Equatable {
    public let reason: String
    
    init(reason: String) {
        self.reason = reason
    }
    
    public init(decoder: PostboxDecoder) {
        self.reason = decoder.decodeStringForKey("rsn", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.reason, forKey: "rsn")
    }
    
    public static func ==(lhs: PeerAccessRestrictionInfo, rhs: PeerAccessRestrictionInfo) -> Bool {
        return lhs.reason == rhs.reason
    }
}
