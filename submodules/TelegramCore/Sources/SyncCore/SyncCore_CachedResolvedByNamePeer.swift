import Foundation
import Postbox

public final class CachedResolvedByNamePeer: PostboxCoding {
    public let peerId: PeerId?
    public let timestamp: Int32
    
    public static func key(name: String) -> ValueBoxKey {
        let key: ValueBoxKey
        if let nameData = name.data(using: .utf8) {
            key = ValueBoxKey(length: nameData.count)
            nameData.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                memcpy(key.memory, bytes, nameData.count)
            }
        } else {
            key = ValueBoxKey(length: 0)
        }
        return key
    }
    
    public init(peerId: PeerId?, timestamp: Int32) {
        self.peerId = peerId
        self.timestamp = timestamp
    }
    
    public init(decoder: PostboxDecoder) {
        if let peerId = decoder.decodeOptionalInt64ForKey("p") {
            self.peerId = PeerId(peerId)
        } else {
            self.peerId = nil
        }
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let peerId = self.peerId {
            encoder.encodeInt64(peerId.toInt64(), forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
        encoder.encodeInt32(self.timestamp, forKey: "t")
    }
}
