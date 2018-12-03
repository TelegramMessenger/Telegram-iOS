import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

protocol TelegramCloudMediaResource: TelegramMediaResource {
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation?
}

protocol TelegramMultipartFetchableResource: TelegramMediaResource {
    var datacenterId: Int { get }
}

public struct CloudFileMediaResourceId: MediaResourceId {
    let datacenterId: Int
    let volumeId: Int64
    let localId: Int32
    let secret: Int64
    
    init(datacenterId: Int, volumeId: Int64, localId: Int32, secret: Int64) {
        self.datacenterId = datacenterId
        self.volumeId = volumeId
        self.localId = localId
        self.secret = secret
    }
    
    public var uniqueId: String {
        return "telegram-cloud-file-\(self.datacenterId)-\(self.volumeId)-\(self.localId)-\(self.secret)"
    }
    
    public var hashValue: Int {
        return self.secret.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? CloudFileMediaResourceId {
            return self.datacenterId == to.datacenterId && self.volumeId == to.volumeId && self.localId == to.localId && self.secret == to.secret
        } else {
            return false
        }
    }
}

public class CloudFileMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource {
    public let datacenterId: Int
    public let volumeId: Int64
    public let localId: Int32
    public let secret: Int64
    public let size: Int?
    public let fileReference: Data?
    
    public var id: MediaResourceId {
        return CloudFileMediaResourceId(datacenterId: self.datacenterId, volumeId: self.volumeId, localId: self.localId, secret: self.secret)
    }
    
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation? {
        if let fileReference = fileReference {
            return Api.InputFileLocation.inputFileLocation(volumeId: self.volumeId, localId: self.localId, secret: self.secret, fileReference: Buffer(data: fileReference))
        } else {
            return nil
        }
    }
    
    public init(datacenterId: Int, volumeId: Int64, localId: Int32, secret: Int64, size: Int?, fileReference: Data?) {
        self.datacenterId = datacenterId
        self.volumeId = volumeId
        self.localId = localId
        self.secret = secret
        self.size = size
        self.fileReference = fileReference
    }
    
    public required init(decoder: PostboxDecoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d", orElse: 0))
        self.volumeId = decoder.decodeInt64ForKey("v", orElse: 0)
        self.localId = decoder.decodeInt32ForKey("l", orElse: 0)
        self.secret = decoder.decodeInt64ForKey("s", orElse: 0)
        if let size = decoder.decodeOptionalInt32ForKey("n") {
            self.size = Int(size)
        } else {
            self.size = nil
        }
        self.fileReference = decoder.decodeBytesForKey("fr")?.makeData()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeInt64(self.volumeId, forKey: "v")
        encoder.encodeInt32(self.localId, forKey: "l")
        encoder.encodeInt64(self.secret, forKey: "s")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "n")
        } else {
            encoder.encodeNil(forKey: "n")
        }
        if let fileReference = self.fileReference {
            encoder.encodeBytes(MemoryBuffer(data: fileReference), forKey: "fr")
        } else {
            encoder.encodeNil(forKey: "fr")
        }
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? CloudFileMediaResource {
            return self.datacenterId == to.datacenterId && self.volumeId == to.volumeId && self.localId == to.localId && self.secret == to.secret && self.size == to.size && self.fileReference == to.fileReference
        } else {
            return false
        }
    }
}

public struct CloudDocumentMediaResourceId: MediaResourceId {
    let datacenterId: Int
    let fileId: Int64
    
    init(datacenterId: Int, fileId: Int64) {
        self.datacenterId = datacenterId
        self.fileId = fileId
    }
    
    public var uniqueId: String {
        return "telegram-cloud-document-\(self.datacenterId)-\(self.fileId)"
    }
    
    public var hashValue: Int {
        return self.fileId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? CloudDocumentMediaResourceId {
            return self.datacenterId == to.datacenterId && self.fileId == to.fileId
        } else {
            return false
        }
    }
}

public class CloudDocumentMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource {
    public let datacenterId: Int
    public let fileId: Int64
    public let accessHash: Int64
    public let size: Int?
    public let fileReference: Data?
    public let fileName: String?
    
    public var id: MediaResourceId {
        return CloudDocumentMediaResourceId(datacenterId: self.datacenterId, fileId: self.fileId)
    }
    
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation? {
        if let fileReference = fileReference {
            return Api.InputFileLocation.inputDocumentFileLocation(id: self.fileId, accessHash: self.accessHash, fileReference: Buffer(data: fileReference))
        } else {
            return nil
        }
    }
    
    public init(datacenterId: Int, fileId: Int64, accessHash: Int64, size: Int?, fileReference: Data?, fileName: String?) {
        self.datacenterId = datacenterId
        self.fileId = fileId
        self.accessHash = accessHash
        self.size = size
        self.fileReference = fileReference
        self.fileName = fileName
    }
    
    public required init(decoder: PostboxDecoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d", orElse: 0))
        self.fileId = decoder.decodeInt64ForKey("f", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("a", orElse: 0)
        if let size = decoder.decodeOptionalInt32ForKey("n") {
            self.size = Int(size)
        } else {
            self.size = nil
        }
        self.fileReference = decoder.decodeBytesForKey("fr")?.makeData()
        self.fileName = decoder.decodeOptionalStringForKey("fn")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeInt64(self.fileId, forKey: "f")
        encoder.encodeInt64(self.accessHash, forKey: "a")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "n")
        } else {
            encoder.encodeNil(forKey: "n")
        }
        if let fileReference = self.fileReference {
            encoder.encodeBytes(MemoryBuffer(data: fileReference), forKey: "fr")
        } else {
            encoder.encodeNil(forKey: "fr")
        }
        if let fileName = self.fileName {
            encoder.encodeString(fileName, forKey: "fn")
        } else {
            encoder.encodeNil(forKey: "fn")
        }
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? CloudDocumentMediaResource {
            return self.datacenterId == to.datacenterId && self.fileId == to.fileId && self.accessHash == to.accessHash && self.size == to.size && self.fileReference == to.fileReference
        } else {
            return false
        }
    }
}

public struct LocalFileMediaResourceId: MediaResourceId {
    public let fileId: Int64
    
    public var uniqueId: String {
        return "telegram-local-file-\(self.fileId)"
    }
    
    public var hashValue: Int {
        return self.fileId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LocalFileMediaResourceId {
            return self.fileId == to.fileId
        } else {
            return false
        }
    }
}

public class LocalFileMediaResource: TelegramMediaResource {
    public let fileId: Int64
    public let size: Int?
    
    public init(fileId: Int64, size: Int? = nil) {
        self.fileId = fileId
        self.size = size
    }
    
    public required init(decoder: PostboxDecoder) {
        self.fileId = decoder.decodeInt64ForKey("f", orElse: 0)
        if let size = decoder.decodeOptionalInt32ForKey("s") {
            self.size = Int(size)
        } else {
            self.size = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.fileId, forKey: "f")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
    }
    
    public var id: MediaResourceId {
        return LocalFileMediaResourceId(fileId: self.fileId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileMediaResource {
            return self.fileId == to.fileId && self.size == to.size
        } else {
            return false
        }
    }
}

public struct LocalFileReferenceMediaResourceId: MediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "local-file-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LocalFileReferenceMediaResourceId {
            return self.randomId == to.randomId
        } else {
            return false
        }
    }
}

public class LocalFileReferenceMediaResource: TelegramMediaResource {
    public let localFilePath: String
    let randomId: Int64
    let isUniquelyReferencedTemporaryFile: Bool
    public let size: Int32?
    
    public init(localFilePath: String, randomId: Int64, isUniquelyReferencedTemporaryFile: Bool = false, size: Int32? = nil) {
        self.localFilePath = localFilePath
        self.randomId = randomId
        self.isUniquelyReferencedTemporaryFile = isUniquelyReferencedTemporaryFile
        self.size = size
    }
    
    public required init(decoder: PostboxDecoder) {
        self.localFilePath = decoder.decodeStringForKey("p", orElse: "")
        self.randomId = decoder.decodeInt64ForKey("r", orElse: 0)
        self.isUniquelyReferencedTemporaryFile = decoder.decodeInt32ForKey("t", orElse: 0) != 0
        self.size = decoder.decodeOptionalInt32ForKey("s")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.localFilePath, forKey: "p")
        encoder.encodeInt64(self.randomId, forKey: "r")
        encoder.encodeInt32(self.isUniquelyReferencedTemporaryFile ? 1 : 0, forKey: "t")
        if let size = self.size {
            encoder.encodeInt32(size, forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
    }
    
    public var id: MediaResourceId {
        return LocalFileReferenceMediaResourceId(randomId: self.randomId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileReferenceMediaResource {
            return self.localFilePath == to.localFilePath && self.randomId == to.randomId && self.size == to.size && self.isUniquelyReferencedTemporaryFile == to.isUniquelyReferencedTemporaryFile
        } else {
            return false
        }
    }
}

public struct HttpReferenceMediaResourceId: MediaResourceId {
    public let url: String
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? HttpReferenceMediaResourceId {
            return self.url == to.url
        } else {
            return false
        }
    }
    
    public var hashValue: Int {
        return self.url.hashValue
    }
    
    public var uniqueId: String {
        return "http-\(persistentHash32(self.url))"
    }
}

public final class HttpReferenceMediaResource: TelegramMediaResource {
    public let url: String
    public let size: Int?
    
    public init(url: String, size: Int?) {
        self.url = url
        self.size = size
    }
    
    public required init(decoder: PostboxDecoder) {
        self.url = decoder.decodeStringForKey("u", orElse: "")
        if let size = decoder.decodeOptionalInt32ForKey("s") {
            self.size = Int(size)
        } else {
            self.size = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.url, forKey: "u")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
    }
    
    public var id: MediaResourceId {
        return HttpReferenceMediaResourceId(url: self.url)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? HttpReferenceMediaResource {
            return to.url == self.url
        } else {
            return false
        }
    }
}

public struct WebFileReferenceMediaResourceId: MediaResourceId {
    public let url: String
    public let accessHash: Int64
    public let size: Int32
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? WebFileReferenceMediaResourceId {
            return self.url == to.url && size == to.size && accessHash == to.accessHash
        } else {
            return false
        }
    }
    
    public var hashValue: Int {
        return self.url.hashValue
    }
    
    public var uniqueId: String {
        return "proxy-\(persistentHash32(self.url))-\(size)-\(accessHash)"
    }
}

public final class WebFileReferenceMediaResource: TelegramMediaResource {
    public let url: String
    public let size: Int32
    public let accessHash: Int64
    
    public init(url: String, size: Int32, accessHash: Int64) {
        self.url = url
        self.size = size
        self.accessHash = accessHash
    }
    
    var apiInputLocation: Api.InputWebFileLocation {
        return Api.InputWebFileLocation.inputWebFileLocation(url: url, accessHash: accessHash)
    }
    
    public required init(decoder: PostboxDecoder) {
        self.url = decoder.decodeStringForKey("u", orElse: "")
        self.size = decoder.decodeInt32ForKey("s", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("h", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.url, forKey: "u")
        encoder.encodeInt32(self.size, forKey: "s")
        encoder.encodeInt64(self.accessHash, forKey: "h")
    }
    
    public var id: MediaResourceId {
        return WebFileReferenceMediaResourceId(url: self.url, accessHash: accessHash, size: self.size)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? WebFileReferenceMediaResource {
            return to.url == self.url && to.size == self.size && to.accessHash == self.accessHash
        } else {
            return false
        }
    }
}


public struct SecretFileMediaResourceId: MediaResourceId {
    public let fileId: Int64
    public let datacenterId: Int32
    
    public var uniqueId: String {
        return "secret-file-\(self.fileId)-\(self.datacenterId)"
    }
    
    public init(fileId: Int64, datacenterId: Int32) {
        self.fileId = fileId
        self.datacenterId = datacenterId
    }
    
    public var hashValue: Int {
        return self.fileId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? SecretFileMediaResourceId {
            return self.fileId == to.fileId && self.datacenterId == to.datacenterId
        } else {
            return false
        }
    }
}

public struct SecretFileMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource {
    public let fileId: Int64
    public let accessHash: Int64
    public var size: Int? {
        return Int(self.decryptedSize)
    }
    public let containerSize: Int32
    public let decryptedSize: Int32
    public let datacenterId: Int
    public let key: SecretFileEncryptionKey
    
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation? {
        return .inputEncryptedFileLocation(id: self.fileId, accessHash: self.accessHash)
    }
    
    public init(fileId: Int64, accessHash: Int64, containerSize: Int32, decryptedSize: Int32, datacenterId: Int, key: SecretFileEncryptionKey) {
        self.fileId = fileId
        self.accessHash = accessHash
        self.containerSize = containerSize
        self.decryptedSize = decryptedSize
        self.datacenterId = datacenterId
        self.key = key
    }
    
    public init(decoder: PostboxDecoder) {
        self.fileId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("a", orElse: 0)
        self.containerSize = decoder.decodeInt32ForKey("s", orElse: 0)
        self.decryptedSize = decoder.decodeInt32ForKey("ds", orElse: 0)
        self.datacenterId = Int(decoder.decodeInt32ForKey("d", orElse: 0))
        self.key = decoder.decodeObjectForKey("k", decoder: { SecretFileEncryptionKey(decoder: $0) }) as! SecretFileEncryptionKey
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.fileId, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "a")
        encoder.encodeInt32(self.containerSize, forKey: "s")
        encoder.encodeInt32(self.decryptedSize, forKey: "ds")
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeObject(self.key, forKey: "k")
    }
    
    public var id: MediaResourceId {
        return SecretFileMediaResourceId(fileId: self.fileId, datacenterId: Int32(self.datacenterId))
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? SecretFileMediaResource {
            if self.fileId != to.fileId {
                return false
            }
            if self.accessHash != to.accessHash {
                return false
            }
            if self.containerSize != to.containerSize {
                return false
            }
            if self.decryptedSize != to.decryptedSize {
                return false
            }
            if self.datacenterId != to.datacenterId {
                return false
            }
            if self.key != to.key {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

public struct EmptyMediaResourceId: MediaResourceId {
    public var uniqueId: String {
        return "empty-resource"
    }
    
    public var hashValue: Int {
        return 0
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        return to is EmptyMediaResourceId
    }
}

public final class EmptyMediaResource: TelegramMediaResource {
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public var id: MediaResourceId {
        return EmptyMediaResourceId()
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        return to is EmptyMediaResource
    }
}

func mediaResourceFromApiFileLocation(_ fileLocation: Api.FileLocation, size: Int?) -> TelegramMediaResource? {
    switch fileLocation {
        case let .fileLocation(dcId, volumeId, localId, secret, fileReference):
            return CloudFileMediaResource(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret, size: size, fileReference: fileReference.makeData())
        case .fileLocationUnavailable:
            return nil
    }
}
