import Foundation
import Postbox
import TelegramApi

public struct CloudFileMediaResourceId: Hashable, Equatable {
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
}

public final class CloudFileMediaResource: TelegramMediaResource {
    public let datacenterId: Int
    public let volumeId: Int64
    public let localId: Int32
    public let secret: Int64
    public let size: Int64?
    public let fileReference: Data?
    
    public var id: MediaResourceId {
        return MediaResourceId(CloudFileMediaResourceId(datacenterId: self.datacenterId, volumeId: self.volumeId, localId: self.localId, secret: self.secret).uniqueId)
    }
    
    public init(datacenterId: Int, volumeId: Int64, localId: Int32, secret: Int64, size: Int64?, fileReference: Data?) {
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
        if let size = decoder.decodeOptionalInt64ForKey("n64") {
            self.size = size
        } else if let size = decoder.decodeOptionalInt32ForKey("n") {
            self.size = Int64(size)
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
            encoder.encodeInt64(size, forKey: "n64")
        } else {
            encoder.encodeNil(forKey: "n64")
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

public struct CloudPhotoSizeMediaResourceId: Hashable, Equatable {
    let datacenterId: Int32
    let photoId: Int64
    let sizeSpec: String
    
    init(datacenterId: Int32, photoId: Int64, sizeSpec: String) {
        self.datacenterId = datacenterId
        self.photoId = photoId
        self.sizeSpec = sizeSpec
    }
    
    public var uniqueId: String {
        return "telegram-cloud-photo-size-\(self.datacenterId)-\(self.photoId)-\(self.sizeSpec)"
    }
}

public final class CloudPhotoSizeMediaResource: TelegramMediaResource {
    public let datacenterId: Int
    public let photoId: Int64
    public let accessHash: Int64
    public let sizeSpec: String
    public let size: Int64?
    public let fileReference: Data?
    
    public var id: MediaResourceId {
        return MediaResourceId(CloudPhotoSizeMediaResourceId(datacenterId: Int32(self.datacenterId), photoId: self.photoId, sizeSpec: self.sizeSpec).uniqueId)
    }
    
    public init(datacenterId: Int32, photoId: Int64, accessHash: Int64, sizeSpec: String, size: Int64?, fileReference: Data?) {
        self.datacenterId = Int(datacenterId)
        self.photoId = photoId
        self.accessHash = accessHash
        self.sizeSpec = sizeSpec
        self.size = size
        self.fileReference = fileReference
    }
    
    public required init(decoder: PostboxDecoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d", orElse: 0))
        self.photoId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("h", orElse: 0)
        self.sizeSpec = decoder.decodeStringForKey("s", orElse: "")
        if let size = decoder.decodeOptionalInt64ForKey("n64") {
            self.size = size
        } else if let size = decoder.decodeOptionalInt32ForKey("n") {
            self.size = Int64(size)
        } else {
            self.size = nil
        }
        self.fileReference = decoder.decodeBytesForKey("fr")?.makeData()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeInt64(self.photoId, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "h")
        encoder.encodeString(self.sizeSpec, forKey: "s")
        if let size = self.size {
            encoder.encodeInt64(size, forKey: "n64")
        } else {
            encoder.encodeNil(forKey: "n64")
        }
        if let fileReference = self.fileReference {
            encoder.encodeBytes(MemoryBuffer(data: fileReference), forKey: "fr")
        } else {
            encoder.encodeNil(forKey: "fr")
        }
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? CloudPhotoSizeMediaResource {
            return self.datacenterId == to.datacenterId && self.photoId == to.photoId && self.accessHash == to.accessHash && self.sizeSpec == to.sizeSpec && self.size == to.size && self.fileReference == to.fileReference
        } else {
            return false
        }
    }
}

public struct CloudDocumentSizeMediaResourceId: Hashable, Equatable {
    let datacenterId: Int32
    let documentId: Int64
    let sizeSpec: String
    
    init(datacenterId: Int32, documentId: Int64, sizeSpec: String) {
        self.datacenterId = datacenterId
        self.documentId = documentId
        self.sizeSpec = sizeSpec
    }
    
    public var uniqueId: String {
        return "telegram-cloud-document-size-\(self.datacenterId)-\(self.documentId)-\(self.sizeSpec)"
    }
}

public final class CloudDocumentSizeMediaResource: TelegramMediaResource {
    public let datacenterId: Int
    public let documentId: Int64
    public let accessHash: Int64
    public let sizeSpec: String
    public let fileReference: Data?
    public var size: Int64? {
        return nil
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(CloudDocumentSizeMediaResourceId(datacenterId: Int32(self.datacenterId), documentId: self.documentId, sizeSpec: self.sizeSpec).uniqueId)
    }
    
    public init(datacenterId: Int32, documentId: Int64, accessHash: Int64, sizeSpec: String, fileReference: Data?) {
        self.datacenterId = Int(datacenterId)
        self.documentId = documentId
        self.accessHash = accessHash
        self.sizeSpec = sizeSpec
        self.fileReference = fileReference
    }
    
    public required init(decoder: PostboxDecoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d", orElse: 0))
        self.documentId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("h", orElse: 0)
        self.sizeSpec = decoder.decodeStringForKey("s", orElse: "")
        self.fileReference = decoder.decodeBytesForKey("fr")?.makeData()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeInt64(self.documentId, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "h")
        encoder.encodeString(self.sizeSpec, forKey: "s")
        if let fileReference = self.fileReference {
            encoder.encodeBytes(MemoryBuffer(data: fileReference), forKey: "fr")
        } else {
            encoder.encodeNil(forKey: "fr")
        }
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? CloudDocumentSizeMediaResource {
            return self.datacenterId == to.datacenterId && self.documentId == to.documentId && self.accessHash == to.accessHash && self.sizeSpec == to.sizeSpec && self.fileReference == to.fileReference
        } else {
            return false
        }
    }
}

public enum CloudPeerPhotoSizeSpec: Int32 {
    case small
    case fullSize
}

public struct CloudPeerPhotoSizeMediaResourceId: Hashable, Equatable {
    let datacenterId: Int32
    let photoId: Int64?
    let sizeSpec: CloudPeerPhotoSizeSpec
    let volumeId: Int64?
    let localId: Int32?
    
    init(datacenterId: Int32, photoId: Int64?, sizeSpec: CloudPeerPhotoSizeSpec, volumeId: Int64?, localId: Int32?) {
        self.datacenterId = datacenterId
        self.photoId = photoId
        self.sizeSpec = sizeSpec
        self.volumeId = volumeId
        self.localId = localId
    }
    
    public var uniqueId: String {
        if let photoId = self.photoId {
            return "telegram-peer-photo-size-\(self.datacenterId)-\(photoId)-\(self.sizeSpec.rawValue)-\(self.volumeId ?? 0)-\(self.localId ?? 0)"
        } else {
            return "telegram-peer-photo-size-\(self.datacenterId)-\(self.sizeSpec.rawValue)-\(self.volumeId ?? 0)-\(self.localId ?? 0)"
        }
    }
}

public final class CloudPeerPhotoSizeMediaResource: TelegramMediaResource {
    public let datacenterId: Int
    public let photoId: Int64?
    public let sizeSpec: CloudPeerPhotoSizeSpec
    public let volumeId: Int64?
    public let localId: Int32?
    public var size: Int64? {
        return nil
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(CloudPeerPhotoSizeMediaResourceId(datacenterId: Int32(self.datacenterId), photoId: self.photoId, sizeSpec: self.sizeSpec, volumeId: self.volumeId, localId: self.localId).uniqueId)
    }
    
    public init(datacenterId: Int32, photoId: Int64?, sizeSpec: CloudPeerPhotoSizeSpec, volumeId: Int64?, localId: Int32?) {
        self.datacenterId = Int(datacenterId)
        self.photoId = photoId
        self.sizeSpec = sizeSpec
        self.volumeId = volumeId
        self.localId = localId
    }
    
    public required init(decoder: PostboxDecoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d", orElse: 0))
        self.photoId = decoder.decodeOptionalInt64ForKey("p")
        self.sizeSpec = CloudPeerPhotoSizeSpec(rawValue: decoder.decodeInt32ForKey("s", orElse: 0)) ?? .small
        self.volumeId = decoder.decodeOptionalInt64ForKey("v")
        self.localId = decoder.decodeOptionalInt32ForKey("l")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        if let photoId = self.photoId {
            encoder.encodeInt64(photoId, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
        encoder.encodeInt32(self.sizeSpec.rawValue, forKey: "s")
        if let volumeId = self.volumeId {
            encoder.encodeInt64(volumeId, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
        if let localId = self.localId {
            encoder.encodeInt32(localId, forKey: "l")
        } else {
            encoder.encodeNil(forKey: "l")
        }
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? CloudPeerPhotoSizeMediaResource {
            return self.datacenterId == to.datacenterId && self.photoId == to.photoId && self.sizeSpec == to.sizeSpec && self.volumeId == to.volumeId && self.localId == to.localId
        } else {
            return false
        }
    }
}

public struct CloudStickerPackThumbnailMediaResourceId: Hashable, Equatable {
    let datacenterId: Int32
    let thumbVersion: Int32?
    let volumeId: Int64?
    let localId: Int32?
    
    init(datacenterId: Int32, thumbVersion: Int32?, volumeId: Int64?, localId: Int32?) {
        self.datacenterId = datacenterId
        self.thumbVersion = thumbVersion
        self.volumeId = volumeId
        self.localId = localId
    }
    
    public var uniqueId: String {
        if let thumbVersion = self.thumbVersion {
            return "telegram-stickerpackthumbnail-\(self.datacenterId)-\(thumbVersion)-\(self.volumeId ?? 0)-\(self.localId ?? 0)"
        } else {
            return "telegram-stickerpackthumbnail-\(self.datacenterId)-\(self.volumeId ?? 0)-\(self.localId ?? 0)"
        }
    }
}

public final class CloudStickerPackThumbnailMediaResource: TelegramMediaResource {
    public let datacenterId: Int
    public let thumbVersion: Int32?
    public let volumeId: Int64?
    public let localId: Int32?
    public var size: Int64? {
        return nil
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(CloudStickerPackThumbnailMediaResourceId(datacenterId: Int32(self.datacenterId), thumbVersion: self.thumbVersion, volumeId: self.volumeId, localId: self.localId).uniqueId)
    }
    
    public init(datacenterId: Int32, thumbVersion: Int32?, volumeId: Int64?, localId: Int32?) {
        self.datacenterId = Int(datacenterId)
        self.thumbVersion = thumbVersion
        self.volumeId = volumeId
        self.localId = localId
    }
    
    public required init(decoder: PostboxDecoder) {
        self.datacenterId = Int(decoder.decodeInt32ForKey("d", orElse: 0))
        self.thumbVersion = decoder.decodeOptionalInt32ForKey("t")
        self.volumeId = decoder.decodeOptionalInt64ForKey("v")
        self.localId = decoder.decodeOptionalInt32ForKey("l")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        if let thumbVersion = self.thumbVersion {
            encoder.encodeInt32(thumbVersion, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
        if let volumeId = self.volumeId {
            encoder.encodeInt64(volumeId, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
        if let localId = self.localId {
            encoder.encodeInt32(localId, forKey: "l")
        } else {
            encoder.encodeNil(forKey: "l")
        }
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? CloudStickerPackThumbnailMediaResource {
            return self.datacenterId == to.datacenterId && self.thumbVersion == to.thumbVersion && self.volumeId == to.volumeId && self.localId == to.localId
        } else {
            return false
        }
    }
}

public struct CloudDocumentMediaResourceId: Hashable, Equatable {
    public let datacenterId: Int
    public let fileId: Int64
    
    init(datacenterId: Int, fileId: Int64) {
        self.datacenterId = datacenterId
        self.fileId = fileId
    }
    
    public var uniqueId: String {
        return "telegram-cloud-document-\(self.datacenterId)-\(self.fileId)"
    }
}

public final class CloudDocumentMediaResource: TelegramMediaResource {
    public let datacenterId: Int
    public let fileId: Int64
    public let accessHash: Int64
    public let size: Int64?
    public let fileReference: Data?
    public let fileName: String?
    
    public var id: MediaResourceId {
        return MediaResourceId(CloudDocumentMediaResourceId(datacenterId: self.datacenterId, fileId: self.fileId).uniqueId)
	}
    
    public init(datacenterId: Int, fileId: Int64, accessHash: Int64, size: Int64?, fileReference: Data?, fileName: String?) {
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
        if let size = decoder.decodeOptionalInt64ForKey("n64") {
            self.size = size
        } else if let size = decoder.decodeOptionalInt32ForKey("n") {
            self.size = Int64(size)
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
            encoder.encodeInt64(size, forKey: "n64")
        } else {
            encoder.encodeNil(forKey: "n64")
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

public struct LocalFileMediaResourceId: Hashable, Equatable {
    public let fileId: Int64
    
    public var uniqueId: String {
        return "telegram-local-file-\(self.fileId)"
    }
}

public class LocalFileMediaResource: TelegramMediaResource, Codable {
    public let fileId: Int64
    public let size: Int64?
    
    public let isSecretRelated: Bool
    
    public init(fileId: Int64, size: Int64? = nil, isSecretRelated: Bool = false) {
        self.fileId = fileId
        self.size = size
        self.isSecretRelated = isSecretRelated
    }
    
    public required init(decoder: PostboxDecoder) {
        self.fileId = decoder.decodeInt64ForKey("f", orElse: 0)
        self.isSecretRelated = decoder.decodeBoolForKey("sr", orElse: false)
        if let size = decoder.decodeOptionalInt64ForKey("s64") {
            self.size = size
        } else if let size = decoder.decodeOptionalInt32ForKey("s") {
            self.size = Int64(size)
        } else {
            self.size = nil
        }
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.fileId = try container.decode(Int64.self, forKey: "f")
        self.isSecretRelated = try container.decodeIfPresent(Bool.self, forKey: "sr") ?? false
        if let size = try container.decodeIfPresent(Int64.self, forKey: "s64") {
            self.size = size
        } else {
            self.size = (try container.decodeIfPresent(Int32.self, forKey: "s")).flatMap(Int64.init)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.fileId, forKey: "f")
        encoder.encodeBool(self.isSecretRelated, forKey: "sr")
        if let size = self.size {
            encoder.encodeInt64(size, forKey: "s64")
        } else {
            encoder.encodeNil(forKey: "s64")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.fileId, forKey: "f")
        try container.encode(self.isSecretRelated, forKey: "sr")
        try container.encodeIfPresent(self.size, forKey: "s64")
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(LocalFileMediaResourceId(fileId: self.fileId).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileMediaResource {
            return self.fileId == to.fileId && self.size == to.size && self.isSecretRelated == to.isSecretRelated
        } else {
            return false
        }
    }
}

public struct LocalFileReferenceMediaResourceId: Hashable, Equatable {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "local-file-\(self.randomId)"
    }
}

public class LocalFileReferenceMediaResource: TelegramMediaResource {
    public let localFilePath: String
    public let randomId: Int64
    public let isUniquelyReferencedTemporaryFile: Bool
    public let size: Int64?
    
    public init(localFilePath: String, randomId: Int64, isUniquelyReferencedTemporaryFile: Bool = false, size: Int64? = nil) {
        self.localFilePath = localFilePath
        self.randomId = randomId
        self.isUniquelyReferencedTemporaryFile = isUniquelyReferencedTemporaryFile
        self.size = size
    }
    
    public required init(decoder: PostboxDecoder) {
        self.localFilePath = decoder.decodeStringForKey("p", orElse: "")
        self.randomId = decoder.decodeInt64ForKey("r", orElse: 0)
        self.isUniquelyReferencedTemporaryFile = decoder.decodeInt32ForKey("t", orElse: 0) != 0
        if let size = decoder.decodeOptionalInt64ForKey("s64") {
            self.size = size
        } else if let size = decoder.decodeOptionalInt32ForKey("s") {
            self.size = Int64(size)
        } else {
            self.size = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.localFilePath, forKey: "p")
        encoder.encodeInt64(self.randomId, forKey: "r")
        encoder.encodeInt32(self.isUniquelyReferencedTemporaryFile ? 1 : 0, forKey: "t")
        if let size = self.size {
            encoder.encodeInt64(size, forKey: "s64")
        } else {
            encoder.encodeNil(forKey: "s")
        }
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(LocalFileReferenceMediaResourceId(randomId: self.randomId).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileReferenceMediaResource {
            return self.localFilePath == to.localFilePath && self.randomId == to.randomId && self.size == to.size && self.isUniquelyReferencedTemporaryFile == to.isUniquelyReferencedTemporaryFile
        } else {
            return false
        }
    }
}

public struct HttpReferenceMediaResourceId: Hashable, Equatable {
    public let url: String
    
    public var uniqueId: String {
        return "http-\(persistentHash32(self.url))"
    }
}

public final class HttpReferenceMediaResource: TelegramMediaResource {
    public let url: String
    public let size: Int64?
    
    public init(url: String, size: Int64?) {
        self.url = url
        self.size = size
    }
    
    public required init(decoder: PostboxDecoder) {
        self.url = decoder.decodeStringForKey("u", orElse: "")
        if let size = decoder.decodeOptionalInt64ForKey("s64") {
            self.size = size
        } else if let size = decoder.decodeOptionalInt32ForKey("s") {
            self.size = Int64(size)
        } else {
            self.size = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.url, forKey: "u")
        if let size = self.size {
            encoder.encodeInt64(size, forKey: "s64")
        } else {
            encoder.encodeNil(forKey: "s64")
        }
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(HttpReferenceMediaResourceId(url: self.url).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? HttpReferenceMediaResource {
            return to.url == self.url
        } else {
            return false
        }
    }
}

public struct WebFileReferenceMediaResourceId: Hashable, Equatable {
    public let url: String
    public let accessHash: Int64
    public let size: Int64
    
    public var uniqueId: String {
        return "proxy-\(persistentHash32(self.url))-\(size)-\(accessHash)"
    }
}

protocol MediaResourceWithWebFileReference: TelegramMediaResource {
    var apiInputLocation: Api.InputWebFileLocation { get }
}

public final class WebFileReferenceMediaResource: TelegramMediaResource, MediaResourceWithWebFileReference {
    public let url: String
    public let actualSize: Int64
    public var size: Int64? {
        return self.actualSize
    }
    public let accessHash: Int64
    
    public init(url: String, size: Int64, accessHash: Int64) {
        self.url = url
        self.actualSize = size
        self.accessHash = accessHash
    }
    
    public required init(decoder: PostboxDecoder) {
        self.url = decoder.decodeStringForKey("u", orElse: "")
        if let size = decoder.decodeOptionalInt64ForKey("s64") {
            self.actualSize = size
        } else {
            self.actualSize = Int64(decoder.decodeInt32ForKey("s", orElse: 0))
        }
        self.accessHash = decoder.decodeInt64ForKey("h", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.url, forKey: "u")
        encoder.encodeInt64(self.actualSize, forKey: "s64")
        encoder.encodeInt64(self.accessHash, forKey: "h")
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(WebFileReferenceMediaResourceId(url: self.url, accessHash: accessHash, size: self.actualSize).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? WebFileReferenceMediaResource {
            return to.url == self.url && to.size == self.size && to.accessHash == self.accessHash
        } else {
            return false
        }
    }
    
    var apiInputLocation: Api.InputWebFileLocation {
        return .inputWebFileLocation(url: self.url, accessHash: self.accessHash)
    }
}

final class AlbumCoverResource: TelegramMediaResource, MediaResourceWithWebFileReference {
    var id: MediaResourceId {
        return MediaResourceId("AlbumCoverResource-\(self.datacenterId)-\(self.title)-\(self.performer)")
    }
    
    let datacenterId: Int
    let size: Int64? = nil
    
    func isEqual(to: MediaResource) -> Bool {
        return self === to
    }
    
    var fileReference: Data? {
        if let file = self.file, let resource = file.media.resource as? CloudDocumentMediaResource {
            return resource.fileReference
        } else {
            return nil
        }
    }
    
    let file: FileMediaReference?
    let title: String
    let performer: String
    let isThumbnail: Bool
    
    init(datacenterId: Int, file: FileMediaReference?, title: String, performer: String, isThumbnail: Bool) {
        self.datacenterId = datacenterId
        self.file = file
        self.title = title
        self.performer = performer
        self.isThumbnail = isThumbnail
    }
    
    init(decoder: PostboxDecoder) {
        preconditionFailure()
    }
    
    func encode(_ encoder: PostboxEncoder) {
    }
    
    var apiInputLocation: Api.InputWebFileLocation {
        var flags: Int32 = 0
        var document: Api.InputDocument?
        if let file = self.file, let resource = file.media.resource as? CloudDocumentMediaResource {
            document = .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data()))
            flags |= 1 << 0
        }
        var requestTitle: String?
        var requestPerformer: String?
        if !self.title.isEmpty || !self.performer.isEmpty {
            requestTitle = self.title
            requestPerformer = self.performer
            flags |= 1 << 1
        }
        if self.isThumbnail {
            flags |= 1 << 2
        }
        return .inputWebFileAudioAlbumThumbLocation(
            flags: flags,
            document: document,
            title: requestTitle,
            performer: requestPerformer
        )
    }
}

public struct SecretFileMediaResourceId: Hashable, Equatable {
    public let fileId: Int64
    public let datacenterId: Int32
    
    public var uniqueId: String {
        return "secret-file-\(self.fileId)-\(self.datacenterId)"
    }
    
    public init(fileId: Int64, datacenterId: Int32) {
        self.fileId = fileId
        self.datacenterId = datacenterId
    }
}

public final class SecretFileMediaResource: TelegramMediaResource {
    public let fileId: Int64
    public let accessHash: Int64
    public var size: Int64? {
        return self.decryptedSize
    }
    public let containerSize: Int64
    public let decryptedSize: Int64
    public let datacenterId: Int
    public let key: SecretFileEncryptionKey
    
    public init(fileId: Int64, accessHash: Int64, containerSize: Int64, decryptedSize: Int64, datacenterId: Int, key: SecretFileEncryptionKey) {
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
        
        if let containerSize = decoder.decodeOptionalInt64ForKey("s64") {
            self.containerSize = containerSize
        } else {
            self.containerSize = Int64(decoder.decodeInt32ForKey("s", orElse: 0))
        }
        if let decryptedSize = decoder.decodeOptionalInt64ForKey("ds64") {
            self.decryptedSize = decryptedSize
        } else {
            self.decryptedSize = Int64(decoder.decodeInt32ForKey("ds", orElse: 0))
        }
        self.datacenterId = Int(decoder.decodeInt32ForKey("d", orElse: 0))
        self.key = decoder.decodeObjectForKey("k", decoder: { SecretFileEncryptionKey(decoder: $0) }) as! SecretFileEncryptionKey
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.fileId, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "a")
        encoder.encodeInt64(self.containerSize, forKey: "s64")
        encoder.encodeInt64(self.decryptedSize, forKey: "ds64")
        encoder.encodeInt32(Int32(self.datacenterId), forKey: "d")
        encoder.encodeObject(self.key, forKey: "k")
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(SecretFileMediaResourceId(fileId: self.fileId, datacenterId: Int32(self.datacenterId)).uniqueId)
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

public struct EmptyMediaResourceId {
    public var uniqueId: String {
        return "empty-resource"
    }
    
    public var hashValue: Int {
        return 0
    }
}

public final class EmptyMediaResource: TelegramMediaResource {
    public var size: Int64? {
        return nil
    }
    
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(EmptyMediaResourceId().uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        return to is EmptyMediaResource
    }
}

public struct WallpaperDataResourceId {
    public var uniqueId: String {
        return "wallpaper-\(self.slug)"
    }

    public var hashValue: Int {
        return self.slug.hashValue
    }

    public var slug: String

    public init(slug: String) {
        self.slug = slug
    }
}

public final class WallpaperDataResource: TelegramMediaResource {
    public var size: Int64? {
        return nil
    }
    
    public let slug: String

    public init(slug: String) {
        self.slug = slug
    }

    public init(decoder: PostboxDecoder) {
        self.slug = decoder.decodeStringForKey("s", orElse: "")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.slug, forKey: "s")
    }

    public var id: MediaResourceId {
        return MediaResourceId(WallpaperDataResourceId(slug: self.slug).uniqueId)
    }

    public func isEqual(to: MediaResource) -> Bool {
        guard let to = to as? WallpaperDataResource else {
            return false
        }
        if self.slug != to.slug {
            return false
        }
        return true
    }
}
