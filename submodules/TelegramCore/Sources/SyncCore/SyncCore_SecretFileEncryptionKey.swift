import Foundation
import Postbox

public final class SecretFileEncryptionKey: PostboxCoding, Equatable {
    public let aesKey: Data
    public let aesIv: Data
    
    public init(aesKey: Data, aesIv: Data) {
        self.aesKey = aesKey
        self.aesIv = aesIv
    }
    
    public init(decoder: PostboxDecoder) {
        self.aesKey = decoder.decodeBytesForKey("k")!.makeData()
        self.aesIv = decoder.decodeBytesForKey("i")!.makeData()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBytes(MemoryBuffer(data: self.aesKey), forKey: "k")
        encoder.encodeBytes(MemoryBuffer(data: self.aesIv), forKey: "i")
    }
    
    public static func ==(lhs: SecretFileEncryptionKey, rhs: SecretFileEncryptionKey) -> Bool {
        return lhs.aesKey == rhs.aesKey && lhs.aesIv == rhs.aesIv
    }
}
