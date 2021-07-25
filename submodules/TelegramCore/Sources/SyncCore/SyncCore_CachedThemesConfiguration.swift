import Postbox

public final class CachedThemesConfiguration: PostboxCoding {
    public let hash: Int64
    
    public init(hash: Int64) {
        self.hash = hash
    }
    
    public init(decoder: PostboxDecoder) {
        self.hash = decoder.decodeInt64ForKey("hash6", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.hash, forKey: "hash6")
    }
}
