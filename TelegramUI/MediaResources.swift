import Foundation
import Postbox
import TelegramCore

public final class VideoMediaResourceAdjustments: Coding, Equatable {
    let data: MemoryBuffer
    let digest: MemoryBuffer
    
    init(data: MemoryBuffer, digest: MemoryBuffer) {
        self.data = data
        self.digest = digest
    }
    
    public init(decoder: Decoder) {
        self.data = decoder.decodeBytesForKey("d")!
        self.digest = decoder.decodeBytesForKey("h")!
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeBytes(self.data, forKey: "d")
        encoder.encodeBytes(self.digest, forKey: "h")
    }
    
    public static func ==(lhs: VideoMediaResourceAdjustments, rhs: VideoMediaResourceAdjustments) -> Bool {
        return lhs.data == rhs.data && lhs.digest == rhs.digest
    }
}

public struct VideoLibraryMediaResourceId: MediaResourceId {
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
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? VideoLibraryMediaResourceId {
            return self.localIdentifier == to.localIdentifier
        } else {
            return false
        }
    }
}

public final class VideoLibraryMediaResource: TelegramMediaResource {
    public let localIdentifier: String
    public let adjustments: VideoMediaResourceAdjustments?
    
    public var headerSize: Int32 {
        return 32 * 1024
    }
    
    public init(localIdentifier: String, adjustments: VideoMediaResourceAdjustments?) {
        self.localIdentifier = localIdentifier
        self.adjustments = adjustments
    }
    
    public required init(decoder: Decoder) {
        self.localIdentifier = decoder.decodeStringForKey("i", orElse: "")
        self.adjustments = decoder.decodeObjectForKey("a", decoder: { VideoMediaResourceAdjustments(decoder: $0) }) as? VideoMediaResourceAdjustments
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeString(self.localIdentifier, forKey: "i")
        if let adjustments = self.adjustments {
            encoder.encodeObject(adjustments, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
    }
    
    public var id: MediaResourceId {
        return VideoLibraryMediaResourceId(localIdentifier: self.localIdentifier, adjustmentsDigest: self.adjustments?.digest)
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? VideoLibraryMediaResource {
            return self.localIdentifier == to.localIdentifier && self.adjustments == to.adjustments
        } else {
            return false
        }
    }
}

public struct LocalFileVideoMediaResourceId: MediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "lvi-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LocalFileVideoMediaResourceId {
            return self.randomId == to.randomId
        } else {
            return false
        }
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
    
    public required init(decoder: Decoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
        self.adjustments = decoder.decodeObjectForKey("a", decoder: { VideoMediaResourceAdjustments(decoder: $0) }) as? VideoMediaResourceAdjustments
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeString(self.path, forKey: "p")
        if let adjustments = self.adjustments {
            encoder.encodeObject(adjustments, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
    }
    
    public var id: MediaResourceId {
        return LocalFileVideoMediaResourceId(randomId: self.randomId)
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? LocalFileVideoMediaResource {
            return self.randomId == to.randomId && self.path == to.path && self.adjustments == to.adjustments
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
        self.localIdentifier = decoder.decodeStringForKey("i", orElse: "")
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

