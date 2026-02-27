import Foundation
import Postbox

public final class TelegramMediaLiveStream: Media, Equatable {
    public enum Kind: Int32 {
        case rtmp = 0
        case rtc = 1
    }
    
    public let peerIds: [PeerId] = []

    public var id: MediaId? {
        return nil
    }

    public let call: GroupCallReference
    public let kind: Kind
        
    public init(call: GroupCallReference, kind: Kind) {
        self.call = call
        self.kind = kind
    }
    
    public init(decoder: PostboxDecoder) {
        self.call = decoder.decodeCodable(GroupCallReference.self, forKey: "call")!
        self.kind = Kind(rawValue: decoder.decodeInt32ForKey("k", orElse: 0)) ?? .rtmp
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeCodable(self.call, forKey: "call")
        encoder.encodeInt32(self.kind.rawValue, forKey: "k")
    }
    
    public static func ==(lhs: TelegramMediaLiveStream, rhs: TelegramMediaLiveStream) -> Bool {
        return lhs.isEqual(to: rhs)
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaLiveStream else {
            return false
        }
        
        if self.call != other.call {
            return false
        }
        if self.kind != other.kind {
            return false
        }
        
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
