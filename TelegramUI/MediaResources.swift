import Foundation
import Postbox
import TelegramCore

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
            return self.localIdentifier == to.localIdentifier && self.adjustmentsDigest == to.adjustmentsDigest
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
    
    public required init(decoder: PostboxDecoder) {
        self.localIdentifier = decoder.decodeStringForKey("i", orElse: "")
        self.adjustments = decoder.decodeObjectForKey("a", decoder: { VideoMediaResourceAdjustments(decoder: $0) }) as? VideoMediaResourceAdjustments
    }
    
    public func encode(_ encoder: PostboxEncoder) {
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
    
    public required init(decoder: PostboxDecoder) {
        self.localIdentifier = decoder.decodeStringForKey("i", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
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

public struct ExternalMusicAlbumArtResourceId: MediaResourceId {
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public var uniqueId: String {
        return "ext-album-art-\(isThumbnail ? "thump" : "full")-\(self.title.replacingOccurrences(of: "/", with: "_"))-\(self.performer.replacingOccurrences(of: "/", with: "_"))"
    }
    
    public var hashValue: Int {
        return self.title.hashValue &* 31 &+ self.performer.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? ExternalMusicAlbumArtResourceId {
            return self.title == to.title && self.performer == to.performer && self.isThumbnail == to.isThumbnail
        } else {
            return false
        }
    }
}

public class ExternalMusicAlbumArtResource: TelegramMediaResource {
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public init(title: String, performer: String, isThumbnail: Bool) {
        self.title = title
        self.performer = performer
        self.isThumbnail = isThumbnail
    }
    
    public required init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.performer = decoder.decodeStringForKey("p", orElse: "")
        self.isThumbnail = decoder.decodeInt32ForKey("th", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.performer, forKey: "p")
        encoder.encodeInt32(self.isThumbnail ? 1 : 0, forKey: "th")
    }
    
    public var id: MediaResourceId {
        return ExternalMusicAlbumArtResourceId(title: self.title, performer: self.performer, isThumbnail: self.isThumbnail)
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? ExternalMusicAlbumArtResource {
            return self.title == to.title && self.performer == to.performer && self.isThumbnail == to.isThumbnail
        } else {
            return false
        }
    }
}
