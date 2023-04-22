import Foundation
import Postbox


public final class TelegramMediaUnsupported: Media, Equatable {
    public let id: MediaId? = nil
    public let peerIds: [PeerId] = []
    
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public static func ==(lhs: TelegramMediaUnsupported, rhs: TelegramMediaUnsupported) -> Bool {
        return lhs.isEqual(to: rhs)
    }
    
    public func isEqual(to other: Media) -> Bool {
        if other is TelegramMediaUnsupported {
            return true
        }
        return false
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
