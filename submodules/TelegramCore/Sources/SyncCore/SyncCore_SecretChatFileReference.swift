import Postbox

public final class SecretChatFileReference: PostboxCoding {
    public let id: Int64
    public let accessHash: Int64
    public let size: Int64
    public let datacenterId: Int32
    public let keyFingerprint: Int32
    
    public init(id: Int64, accessHash: Int64, size: Int64, datacenterId: Int32, keyFingerprint: Int32) {
        self.id = id
        self.accessHash = accessHash
        self.size = size
        self.datacenterId = datacenterId
        self.keyFingerprint = keyFingerprint
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("i", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("a", orElse: 0)
        if let size = decoder.decodeOptionalInt64ForKey("s64") {
            self.size = size
        } else {
            self.size = Int64(decoder.decodeInt32ForKey("s", orElse: 0))
        }
        self.datacenterId = decoder.decodeInt32ForKey("d", orElse: 0)
        self.keyFingerprint = decoder.decodeInt32ForKey("f", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "a")
        encoder.encodeInt64(self.size, forKey: "s64")
        encoder.encodeInt32(self.datacenterId, forKey: "d")
        encoder.encodeInt32(self.keyFingerprint, forKey: "f")
    }
}
