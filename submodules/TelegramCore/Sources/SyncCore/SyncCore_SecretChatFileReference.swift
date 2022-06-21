import Postbox

public final class SecretChatFileReference: PostboxCoding {
    public let id: Int64
    public let accessHash: Int64
    public let size: Int32
    public let datacenterId: Int32
    public let keyFingerprint: Int32
    
    public init(id: Int64, accessHash: Int64, size: Int32, datacenterId: Int32, keyFingerprint: Int32) {
        self.id = id
        self.accessHash = accessHash
        self.size = size
        self.datacenterId = datacenterId
        self.keyFingerprint = keyFingerprint
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("i", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("a", orElse: 0)
        self.size = decoder.decodeInt32ForKey("s", orElse: 0)
        self.datacenterId = decoder.decodeInt32ForKey("d", orElse: 0)
        self.keyFingerprint = decoder.decodeInt32ForKey("f", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "a")
        encoder.encodeInt32(self.size, forKey: "s")
        encoder.encodeInt32(self.datacenterId, forKey: "d")
        encoder.encodeInt32(self.keyFingerprint, forKey: "f")
    }
}
