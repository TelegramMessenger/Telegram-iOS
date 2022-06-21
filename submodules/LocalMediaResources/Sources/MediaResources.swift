import Foundation
import UIKit
import Postbox
import TelegramCore
import PersistentStringHash

public final class VideoMediaResourceAdjustments: PostboxCoding, Equatable {
    public let data: MemoryBuffer
    public let digest: MemoryBuffer
    
    public init(data: MemoryBuffer, digest: MemoryBuffer) {
        self.data = data
        self.digest = digest
    }
    
    public init(decoder: PostboxDecoder) {
        self.data = decoder.decodeBytesForKey("d")!
        self.digest = decoder.decodeBytesForKey("h")!
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBytes(self.data, forKey: "d")
        encoder.encodeBytes(self.digest, forKey: "h")
    }
    
    public static func ==(lhs: VideoMediaResourceAdjustments, rhs: VideoMediaResourceAdjustments) -> Bool {
        return lhs.data == rhs.data && lhs.digest == rhs.digest
    }
}

public struct VideoLibraryMediaResourceId {
    public let localIdentifier: String
    public let adjustmentsDigest: MemoryBuffer?
    
    public var uniqueId: String {
        if let adjustmentsDigest = self.adjustmentsDigest {
            return "vi-\(self.localIdentifier.replacingOccurrences(of: "/", with: "_"))-\(adjustmentsDigest.description)"
        } else {
            return "vi-\(self.localIdentifier.replacingOccurrences(of: "/", with: "_"))"
        }
    }
    
    public var hashValue: Int {
        return self.localIdentifier.hashValue
    }
}

public enum VideoLibraryMediaResourceConversion: PostboxCoding, Equatable {
    case passthrough
    case compress(VideoMediaResourceAdjustments?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .passthrough
            case 1:
                self = .compress(decoder.decodeObjectForKey("adj", decoder: { VideoMediaResourceAdjustments(decoder: $0) }) as? VideoMediaResourceAdjustments)
            default:
                self = .compress(nil)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .passthrough:
                encoder.encodeInt32(0, forKey: "v")
            case let .compress(adjustments):
                encoder.encodeInt32(1, forKey: "v")
                if let adjustments = adjustments {
                    encoder.encodeObject(adjustments, forKey: "adj")
                } else {
                    encoder.encodeNil(forKey: "adj")
                }
        }
    }
    
    public static func ==(lhs: VideoLibraryMediaResourceConversion, rhs: VideoLibraryMediaResourceConversion) -> Bool {
        switch lhs {
            case .passthrough:
                if case .passthrough = rhs {
                    return true
                } else {
                    return false
                }
            case let .compress(lhsAdjustments):
                if case let .compress(rhsAdjustments) = rhs, lhsAdjustments == rhsAdjustments {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class VideoLibraryMediaResource: TelegramMediaResource {
    public let localIdentifier: String
    public let conversion: VideoLibraryMediaResourceConversion
    
    public var headerSize: Int32 {
        return 32 * 1024
    }
    
    public init(localIdentifier: String, conversion: VideoLibraryMediaResourceConversion) {
        self.localIdentifier = localIdentifier
        self.conversion = conversion
    }
    
    public required init(decoder: PostboxDecoder) {
        self.localIdentifier = decoder.decodeStringForKey("i", orElse: "")
        self.conversion = (decoder.decodeObjectForKey("conv", decoder: { VideoLibraryMediaResourceConversion(decoder: $0) }) as? VideoLibraryMediaResourceConversion) ?? .compress(nil)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.localIdentifier, forKey: "i")
        encoder.encodeObject(self.conversion, forKey: "conv")
    }
    
    public var id: MediaResourceId {
        var adjustmentsDigest: MemoryBuffer?
        switch self.conversion {
            case .passthrough:
                break
            case let .compress(adjustments):
                adjustmentsDigest = adjustments?.digest
        }
        return MediaResourceId(VideoLibraryMediaResourceId(localIdentifier: self.localIdentifier, adjustmentsDigest: adjustmentsDigest).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? VideoLibraryMediaResource {
            return self.localIdentifier == to.localIdentifier && self.conversion == to.conversion
        } else {
            return false
        }
    }
}

public struct LocalFileVideoMediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "lvi-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
}

public final class LocalFileVideoMediaResource: TelegramMediaResource {
    public let randomId: Int64
    public let path: String
    public let adjustments: VideoMediaResourceAdjustments?
    
    public var headerSize: Int32 {
        return 32 * 1024
    }
    
    public init(randomId: Int64, path: String, adjustments: VideoMediaResourceAdjustments?) {
        self.randomId = randomId
        self.path = path
        self.adjustments = adjustments
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
        self.adjustments = decoder.decodeObjectForKey("a", decoder: { VideoMediaResourceAdjustments(decoder: $0) }) as? VideoMediaResourceAdjustments
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeString(self.path, forKey: "p")
        if let adjustments = self.adjustments {
            encoder.encodeObject(adjustments, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(LocalFileVideoMediaResourceId(randomId: self.randomId).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileVideoMediaResource {
            return self.randomId == to.randomId && self.path == to.path && self.adjustments == to.adjustments
        } else {
            return false
        }
    }
}

public struct PhotoLibraryMediaResourceId {
    public let localIdentifier: String
    public let resourceId: Int64
    
    public var uniqueId: String {
        if self.resourceId != 0 {
            return "ph-\(self.localIdentifier.replacingOccurrences(of: "/", with: "_"))-\(self.resourceId)"
        } else {
            return "ph-\(self.localIdentifier.replacingOccurrences(of: "/", with: "_"))"
        }
    }
    
    public var hashValue: Int {
        return self.localIdentifier.hashValue
    }
}

public class PhotoLibraryMediaResource: TelegramMediaResource {
    public let localIdentifier: String
    public let uniqueId: Int64
    
    public init(localIdentifier: String, uniqueId: Int64) {
        self.localIdentifier = localIdentifier
        self.uniqueId = uniqueId
    }
    
    public required init(decoder: PostboxDecoder) {
        self.localIdentifier = decoder.decodeStringForKey("i", orElse: "")
        self.uniqueId = decoder.decodeInt64ForKey("uid", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.localIdentifier, forKey: "i")
        encoder.encodeInt64(self.uniqueId, forKey: "uid")
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(PhotoLibraryMediaResourceId(localIdentifier: self.localIdentifier, resourceId: self.uniqueId).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? PhotoLibraryMediaResource {
            return self.localIdentifier == to.localIdentifier && self.uniqueId == to.uniqueId
        } else {
            return false
        }
    }
}

public struct LocalFileGifMediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "lgi-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
}

public final class LocalFileGifMediaResource: TelegramMediaResource {
    public let randomId: Int64
    public let path: String
    
    public var headerSize: Int32 {
        return 32 * 1024
    }
    
    public init(randomId: Int64, path: String) {
        self.randomId = randomId
        self.path = path
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeString(self.path, forKey: "p")
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(LocalFileGifMediaResourceId(randomId: self.randomId).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileGifMediaResource {
            return self.randomId == to.randomId && self.path == to.path
        } else {
            return false
        }
    }
}


public struct BundleResourceId {
    public let nameHash: Int64
    
    public var uniqueId: String {
        return "bundle-\(nameHash)"
    }
    
    public var hashValue: Int {
        return self.nameHash.hashValue
    }
}

public class BundleResource: TelegramMediaResource {
    public let nameHash: Int64
    public let path: String
    
    public init(name: String, path: String) {
        self.nameHash = Int64(bitPattern: name.persistentHashValue)
        self.path = path
    }
    
    public required init(decoder: PostboxDecoder) {
        self.nameHash = decoder.decodeInt64ForKey("h", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.nameHash, forKey: "h")
        encoder.encodeString(self.path, forKey: "p")
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(BundleResourceId(nameHash: self.nameHash).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? BundleResource {
            return self.nameHash == to.nameHash
        } else {
            return false
        }
    }
}
