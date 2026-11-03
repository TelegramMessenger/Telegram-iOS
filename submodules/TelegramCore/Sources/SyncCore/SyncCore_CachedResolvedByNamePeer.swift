import Foundation
import Postbox

public final class CachedResolvedByNamePeer: Codable {
    public let peerId: PeerId?
    public let timestamp: Int32
    
    public static func key(name: String) -> ValueBoxKey {
        let key: ValueBoxKey
        if let nameData = name.data(using: .utf8) {
            key = ValueBoxKey(length: nameData.count)
            nameData.withUnsafeBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)

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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerId = (try container.decodeIfPresent(Int64.self, forKey: "p")).flatMap(PeerId.init)
        self.timestamp = try container.decode(Int32.self, forKey: "t")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.peerId?.toInt64(), forKey: "p")
        try container.encode(self.timestamp, forKey: "t")
    }
}
