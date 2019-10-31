import Postbox

public final class CachedThemesConfiguration: PostboxCoding {
    public let hash: Int32
    
    public init(hash: Int32) {
        self.hash = hash
    }
    
    public init(decoder: PostboxDecoder) {
        self.hash = decoder.decodeInt32ForKey("hash", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.hash, forKey: "hash")
    }
}
