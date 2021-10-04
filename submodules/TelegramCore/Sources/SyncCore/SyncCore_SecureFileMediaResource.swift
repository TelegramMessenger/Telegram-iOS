import Foundation
import Postbox

public struct SecureFileMediaResourceId {
    public let fileId: Int64
    
    public init(fileId: Int64) {
        self.fileId = fileId
    }
    
    public var uniqueId: String {
        return "telegram-secure-file-\(self.fileId)"
    }
    
    public var hashValue: Int {
        return self.fileId.hashValue
    }
}

public final class SecureFileMediaResource: TelegramMediaResource {
    public let file: SecureIdFileReference
    
    public var id: MediaResourceId {
        return MediaResourceId(SecureFileMediaResourceId(fileId: self.file.id).uniqueId)
    }
    
    public var datacenterId: Int {
        return Int(self.file.datacenterId)
    }
    
    public var size: Int? {
        return Int(self.file.size)
    }
    
    public init(file: SecureIdFileReference) {
        self.file = file
    }
    
    public required init(decoder: PostboxDecoder) {
        self.file = SecureIdFileReference(id: decoder.decodeInt64ForKey("f", orElse: 0), accessHash: decoder.decodeInt64ForKey("a", orElse: 0), size: decoder.decodeInt32ForKey("n", orElse: 0), datacenterId: decoder.decodeInt32ForKey("d", orElse: 0), timestamp: decoder.decodeInt32ForKey("t", orElse: 0), fileHash: decoder.decodeBytesForKey("h")?.makeData() ?? Data(), encryptedSecret: decoder.decodeBytesForKey("s")?.makeData() ?? Data())
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.file.id, forKey: "f")
        encoder.encodeInt64(self.file.accessHash, forKey: "a")
        encoder.encodeInt32(self.file.size, forKey: "n")
        encoder.encodeInt32(self.file.datacenterId, forKey: "d")
        encoder.encodeInt32(self.file.timestamp, forKey: "t")
        encoder.encodeBytes(MemoryBuffer(data: self.file.fileHash), forKey: "h")
        encoder.encodeBytes(MemoryBuffer(data: self.file.encryptedSecret), forKey: "s")
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? SecureFileMediaResource {
            return self.file == to.file
        } else {
            return false
        }
    }
}
