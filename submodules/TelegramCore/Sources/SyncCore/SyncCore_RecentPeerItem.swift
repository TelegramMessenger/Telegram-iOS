import Foundation
import Postbox

public struct RecentPeerItemId {
    public let rawValue: MemoryBuffer
    public let peerId: PeerId
    
    public init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
        assert(rawValue.length == 8)
        var idValue: Int64 = 0
        memcpy(&idValue, rawValue.memory, 8)
        self.peerId = PeerId(idValue)
    }
    
    public init(_ peerId: PeerId) {
        self.peerId = peerId
        var idValue: Int64 = peerId.toInt64()
        self.rawValue = MemoryBuffer(memory: malloc(8)!, capacity: 8, length: 8, freeWhenDone: true)
        memcpy(self.rawValue.memory, &idValue, 8)
    }
}

public final class RecentPeerItem: OrderedItemListEntryContents {
    public let rating: Double
    
    public init(rating: Double) {
        self.rating = rating
    }
    
    public init(decoder: PostboxDecoder) {
        self.rating = decoder.decodeDoubleForKey("r", orElse: 0.0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeDouble(self.rating, forKey: "r")
    }
}
