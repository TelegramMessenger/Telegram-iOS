import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct SecureFileMediaResourceId: MediaResourceId {
    let fileId: Int64
    
    init(fileId: Int64) {
        self.fileId = fileId
    }
    
    public var uniqueId: String {
        return "telegram-secure-file-\(self.fileId)"
    }
    
    public var hashValue: Int {
        return self.fileId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? SecureFileMediaResourceId {
            return self.fileId == to.fileId
        } else {
            return false
        }
    }
}

public class SecureFileMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource, EncryptedMediaResource {
    public let file: SecureIdFileReference
    
    public var id: MediaResourceId {
        return SecureFileMediaResourceId(fileId: self.file.id)
    }
    
    public var datacenterId: Int {
        return Int(self.file.datacenterId)
    }
    
    public var size: Int? {
        return Int(self.file.size)
    }
    
    var apiInputLocation: Api.InputFileLocation {
        return Api.InputFileLocation.inputSecureFileLocation(id: self.file.id, accessHash: self.file.accessHash)
    }
    
    public init(file: SecureIdFileReference) {
        self.file = file
    }
    
    public required init(decoder: PostboxDecoder) {
        self.file = SecureIdFileReference(id: decoder.decodeInt64ForKey("f", orElse: 0), accessHash: decoder.decodeInt64ForKey("a", orElse: 0), size: decoder.decodeInt32ForKey("n", orElse: 0), datacenterId: decoder.decodeInt32ForKey("d", orElse: 0), fileHash: decoder.decodeBytesForKey("h")?.makeData() ?? Data())
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.file.id, forKey: "f")
        encoder.encodeInt64(self.file.accessHash, forKey: "a")
        encoder.encodeInt32(self.file.size, forKey: "n")
        encoder.encodeInt32(self.file.datacenterId, forKey: "d")
        encoder.encodeBytes(MemoryBuffer(data: self.file.fileHash), forKey: "h")
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? SecureFileMediaResource {
            return self.file == to.file
        } else {
            return false
        }
    }
    
    public func decrypt(data: Data, params: Any) -> Data? {
        guard let valueContext = params as? SecureIdValueAccessContext else {
            return nil
        }
        return decryptedSecureIdFile(valueContext: valueContext, encryptedData: data, fileHash: self.file.fileHash)
    }
}
