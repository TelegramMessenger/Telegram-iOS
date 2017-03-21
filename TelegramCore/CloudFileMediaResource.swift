import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public protocol TelegramMediaResource: MediaResource, Coding {
    func isEqual(to: TelegramMediaResource) -> Bool
}

protocol TelegramCloudMediaResource: TelegramMediaResource {
    var datacenterId: Int { get }
    var apiInputLocation: Api.InputFileLocation { get }
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

public class CloudFileMediaResource: TelegramCloudMediaResource {
    public let datacenterId: Int
    let volumeId: Int64
    let localId: Int32
    let secret: Int64
    public let size: Int?
    
    public var id: MediaResourceId {
        return CloudFileMediaResourceId(datacenterId: self.datacenterId, volumeId: self.volumeId, localId: self.localId, secret: self.secret)
    }
    
    var apiInputLocation: Api.InputFileLocation {
        return Api.InputFileLocation.inputFileLocation(volumeId: self.volumeId, localId: self.localId, secret: self.secret)
    }
    
    public init(datacenterId: Int, volumeId: Int64, localId: Int32, secret: Int64, size: Int?) {
        self.datacenterId = datacenterId
        self.volumeId = volumeId
        self.localId = localId
        self.secret = secret
        self.size = size
    }
    
    public required init(decoder: Decoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d") as Int32)
        self.volumeId = decoder.decodeInt64ForKey("v")
        self.localId = decoder.decodeInt32ForKey("l")
        self.secret = decoder.decodeInt64ForKey("s")
        if let size = decoder.decodeInt32ForKey("n") as Int32? {
            self.size = Int(size)
        } else {
            self.size = nil
        }
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeInt64(self.volumeId, forKey: "v")
        encoder.encodeInt32(self.localId, forKey: "l")
        encoder.encodeInt64(self.secret, forKey: "s")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "n")
        } else {
            encoder.encodeNil(forKey: "n")
        }
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? CloudFileMediaResource {
            return self.datacenterId == to.datacenterId && self.volumeId == to.volumeId && self.localId == to.localId && self.secret == to.secret && self.size == to.size
        } else {
            return false
        }
    }
}

public struct CloudDocumentMediaResourceId: MediaResourceId {
    let datacenterId: Int
    let fileId: Int64
    let accessHash: Int64
    
    init(datacenterId: Int, fileId: Int64, accessHash: Int64) {
        self.datacenterId = datacenterId
        self.fileId = fileId
        self.accessHash = accessHash
    }
    
    public var uniqueId: String {
        return "telegram-cloud-document-\(self.datacenterId)-\(self.fileId)-\(self.accessHash)"
    }
    
    public var hashValue: Int {
        return self.fileId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? CloudDocumentMediaResourceId {
            return self.datacenterId == to.datacenterId && self.fileId == to.fileId && self.accessHash == to.accessHash
        } else {
            return false
        }
    }
}

public class CloudDocumentMediaResource: TelegramCloudMediaResource {
    public let datacenterId: Int
    let fileId: Int64
    let accessHash: Int64
    public let size: Int?
    
    public var id: MediaResourceId {
        return CloudDocumentMediaResourceId(datacenterId: self.datacenterId, fileId: self.fileId, accessHash: self.accessHash)
    }
    
    var apiInputLocation: Api.InputFileLocation {
        return Api.InputFileLocation.inputDocumentFileLocation(id: self.fileId, accessHash: self.accessHash, version: 0)
    }
    
    public init(datacenterId: Int, fileId: Int64, accessHash: Int64, size: Int?) {
        self.datacenterId = datacenterId
        self.fileId = fileId
        self.accessHash = accessHash
        self.size = size
    }
    
    public required init(decoder: Decoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d") as Int32)
        self.fileId = decoder.decodeInt64ForKey("f")
        self.accessHash = decoder.decodeInt64ForKey("a")
        if let size = (decoder.decodeInt32ForKey("n") as Int32?) {
            self.size = Int(size)
        } else {
            self.size = nil
        }
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeInt64(self.fileId, forKey: "f")
        encoder.encodeInt64(self.accessHash, forKey: "a")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "n")
        } else {
            encoder.encodeNil(forKey: "n")
        }
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? CloudDocumentMediaResource {
            return self.datacenterId == to.datacenterId && self.fileId == to.fileId && self.accessHash == to.accessHash && self.size == to.size
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
    let fileId: Int64
    
    public init(fileId: Int64) {
        self.fileId = fileId
    }
    
    public required init(decoder: Decoder) {
        self.fileId = decoder.decodeInt64ForKey("f")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.fileId, forKey: "f")
    }
    
    public var id: MediaResourceId {
        return LocalFileMediaResourceId(fileId: self.fileId)
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? LocalFileMediaResource {
            return self.fileId == to.fileId
        } else {
            return false
        }
    }
}

public struct PhotoLibraryMediaResourceId: MediaResourceId {
    public let localIdentifier: String
    
    public var uniqueId: String {
        return "ph-\(self.localIdentifier.replacingOccurrences(of: "/", with: "_"))"
    }
    
    public var hashValue: Int {
        return self.localIdentifier.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? PhotoLibraryMediaResourceId {
            return self.localIdentifier == to.localIdentifier
        } else {
            return false
        }
    }
}

public class PhotoLibraryMediaResource: TelegramMediaResource {
    let localIdentifier: String
    
    public init(localIdentifier: String) {
        self.localIdentifier = localIdentifier
    }
    
    public required init(decoder: Decoder) {
        self.localIdentifier = decoder.decodeStringForKey("i")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeString(self.localIdentifier, forKey: "i")
    }
    
    public var id: MediaResourceId {
        return PhotoLibraryMediaResourceId(localIdentifier: self.localIdentifier)
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? PhotoLibraryMediaResource {
            return self.localIdentifier == to.localIdentifier
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
    let localFilePath: String
    let randomId: Int64
    let size: Int32?
    
    public init(localFilePath: String, randomId: Int64, size: Int32? = nil) {
        self.localFilePath = localFilePath
        self.randomId = randomId
        self.size = size
    }
    
    public required init(decoder: Decoder) {
        self.localFilePath = decoder.decodeStringForKey("p")
        self.randomId = decoder.decodeInt64ForKey("r")
        self.size = decoder.decodeInt32ForKey("s")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeString(self.localFilePath, forKey: "p")
        encoder.encodeInt64(self.randomId, forKey: "r")
        if let size = self.size {
            encoder.encodeInt32(size, forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
    }
    
    public var id: MediaResourceId {
        return LocalFileReferenceMediaResourceId(randomId: self.randomId)
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? LocalFileReferenceMediaResource {
            return self.localFilePath == to.localFilePath && self.randomId == to.randomId && self.size == size
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
    
    public required init(decoder: Decoder) {
        self.url = decoder.decodeStringForKey("u")
        if let size = (decoder.decodeInt32ForKey("s") as Int32?) {
            self.size = Int(size)
        } else {
            self.size = nil
        }
    }
    
    public func encode(_ encoder: Encoder) {
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
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? HttpReferenceMediaResource {
            return to.url == self.url
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

public struct SecretFileMediaResource: TelegramCloudMediaResource {
    public let fileId: Int64
    public let accessHash: Int64
    public let size: Int?
    public let decryptedSize: Int32
    public let datacenterId: Int
    public let key: SecretFileEncryptionKey
    
    var apiInputLocation: Api.InputFileLocation {
        return .inputEncryptedFileLocation(id: self.fileId, accessHash: self.accessHash)
    }
    
    public init(fileId: Int64, accessHash: Int64, size: Int?, decryptedSize: Int32, datacenterId: Int, key: SecretFileEncryptionKey) {
        self.fileId = fileId
        self.accessHash = accessHash
        self.size = size
        self.decryptedSize = decryptedSize
        self.datacenterId = datacenterId
        self.key = key
    }
    
    public init(decoder: Decoder) {
        self.fileId = decoder.decodeInt64ForKey("i")
        self.accessHash = decoder.decodeInt64ForKey("a")
        if let size = decoder.decodeInt32ForKey("s") as Int32? {
            self.size = Int(size)
        } else {
            self.size = nil
        }
        self.decryptedSize = decoder.decodeInt32ForKey("ds")
        self.datacenterId = Int(decoder.decodeInt32ForKey("d"))
        self.key = decoder.decodeObjectForKey("k", decoder: { SecretFileEncryptionKey(decoder: $0) }) as! SecretFileEncryptionKey
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.fileId, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "a")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
        encoder.encodeInt32(self.decryptedSize, forKey: "ds")
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeObject(self.key, forKey: "k")
    }
    
    public var id: MediaResourceId {
        return SecretFileMediaResourceId(fileId: self.fileId, datacenterId: Int32(self.datacenterId))
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? SecretFileMediaResource {
            if self.fileId != to.fileId {
                return false
            }
            if self.accessHash != to.accessHash {
                return false
            }
            if self.size != to.size {
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
    
    public init(decoder: Decoder) {
    }
    
    public func encode(_ encoder: Encoder) {
    }
    
    public var id: MediaResourceId {
        return EmptyMediaResourceId()
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        return to is EmptyMediaResource
    }
}

func mediaResourceFromApiFileLocation(_ fileLocation: Api.FileLocation, size: Int?) -> TelegramMediaResource? {
    switch fileLocation {
        case let .fileLocation(dcId, volumeId, localId, secret):
            return CloudFileMediaResource(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret, size: size)
        case .fileLocationUnavailable:
            return nil
    }
}
