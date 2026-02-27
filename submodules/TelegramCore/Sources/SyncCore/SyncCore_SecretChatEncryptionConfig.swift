import Postbox

public final class SecretChatEncryptionConfig: PostboxCoding {
    public let g: Int32
    public let p: MemoryBuffer
    public let version: Int32
    
    public init(g: Int32, p: MemoryBuffer, version: Int32) {
        self.g = g
        self.p = p
        self.version = version
    }
    
    public init(decoder: PostboxDecoder) {
        self.g = decoder.decodeInt32ForKey("g", orElse: 0)
        self.p = decoder.decodeBytesForKey("p")!
        self.version = decoder.decodeInt32ForKey("v", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.g, forKey: "g")
        encoder.encodeBytes(self.p, forKey: "p")
        encoder.encodeInt32(self.version, forKey: "v")
    }
}
