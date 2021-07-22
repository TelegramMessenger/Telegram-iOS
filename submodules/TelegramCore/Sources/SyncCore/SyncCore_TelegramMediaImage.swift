import Foundation
import Postbox

public enum TelegramMediaImageReferenceDecodingError: Error {
    case generic
}

public enum TelegramMediaImageReference: PostboxCoding, Equatable {
    enum CodingKeys: String, CodingKey {
        case data
    }
    
    case cloud(imageId: Int64, accessHash: Int64, fileReference: Data?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
            case 0:
                self = .cloud(imageId: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0), fileReference: decoder.decodeBytesForKey("fr")?.makeData())
            default:
                self = .cloud(imageId: 0, accessHash: 0, fileReference: nil)
                assertionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .cloud(imageId, accessHash, fileReference):
                encoder.encodeInt32(0, forKey: "_v")
                encoder.encodeInt64(imageId, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
                if let fileReference = fileReference {
                    encoder.encodeBytes(MemoryBuffer(data: fileReference), forKey: "fr")
                } else {
                    encoder.encodeNil(forKey: "fr")
                }
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .data)
        let postboxDecoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
        guard let object = postboxDecoder.decodeRootObject() as? TelegramMediaImageReference else {
            throw TelegramMediaImageReferenceDecodingError.generic
        }
        self = object
    }
    
    public func encode(to encoder: Encoder) throws {
        let postboxEncoder = PostboxEncoder()
        postboxEncoder.encodeRootObject(self)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postboxEncoder.makeData(), forKey: .data)
    }
    
    public static func ==(lhs: TelegramMediaImageReference, rhs: TelegramMediaImageReference) -> Bool {
        switch lhs {
            case let .cloud(imageId, accessHash, fileReference):
                if case .cloud(imageId, accessHash, fileReference) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct TelegramMediaImageFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let hasStickers = TelegramMediaImageFlags(rawValue: 1 << 0)
}

public enum TelegramMediaImageDecodingError: Error {
    case generic
}

public final class TelegramMediaImage: Media, Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case data
    }
    
    public final class VideoRepresentation: Equatable, PostboxCoding {
        public let dimensions: PixelDimensions
        public let resource: TelegramMediaResource
        public let startTimestamp: Double?
        
        public init(dimensions: PixelDimensions, resource: TelegramMediaResource, startTimestamp: Double?) {
            self.dimensions = dimensions
            self.resource = resource
            self.startTimestamp = startTimestamp
        }
        
        public init(decoder: PostboxDecoder) {
            self.dimensions = PixelDimensions(width: decoder.decodeInt32ForKey("w", orElse: 0), height: decoder.decodeInt32ForKey("h", orElse: 0))
            self.resource = decoder.decodeObjectForKey("r") as! TelegramMediaResource
            self.startTimestamp = decoder.decodeOptionalDoubleForKey("s")
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(self.dimensions.width, forKey: "w")
            encoder.encodeInt32(self.dimensions.height, forKey: "h")
            encoder.encodeObject(self.resource, forKey: "r")
            if let startTimestamp = self.startTimestamp {
                encoder.encodeDouble(startTimestamp, forKey: "s")
            } else {
                encoder.encodeNil(forKey: "s")
            }
        }
        
        public static func ==(lhs: VideoRepresentation, rhs: VideoRepresentation) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.dimensions != rhs.dimensions {
                return false
            }
            if !lhs.resource.isEqual(to: rhs.resource) {
                return false
            }
            if lhs.startTimestamp != rhs.startTimestamp {
                return false
            }
            return true
        }
    }
    
    public let imageId: MediaId
    public let representations: [TelegramMediaImageRepresentation]
    public let videoRepresentations: [TelegramMediaImage.VideoRepresentation]
    public let immediateThumbnailData: Data?
    public let reference: TelegramMediaImageReference?
    public let partialReference: PartialMediaReference?
    public let peerIds: [PeerId] = []
    public let flags: TelegramMediaImageFlags
    
    public var id: MediaId? {
        return self.imageId
    }
    
    public init(imageId: MediaId, representations: [TelegramMediaImageRepresentation], videoRepresentations: [TelegramMediaImage.VideoRepresentation] = [], immediateThumbnailData: Data?, reference: TelegramMediaImageReference?, partialReference: PartialMediaReference?, flags: TelegramMediaImageFlags) {
        self.imageId = imageId
        self.representations = representations
        self.videoRepresentations = videoRepresentations
        self.immediateThumbnailData = immediateThumbnailData
        self.reference = reference
        self.partialReference = partialReference
        self.flags = flags
    }
    
    public init(decoder: PostboxDecoder) {
        self.imageId = MediaId(decoder.decodeBytesForKeyNoCopy("i")!)
        self.representations = decoder.decodeObjectArrayForKey("r")
        self.videoRepresentations = decoder.decodeObjectArrayForKey("vr")
        self.immediateThumbnailData = decoder.decodeDataForKey("itd")
        self.reference = decoder.decodeObjectForKey("rf", decoder: { TelegramMediaImageReference(decoder: $0) }) as? TelegramMediaImageReference
        self.partialReference = decoder.decodeAnyObjectForKey("prf", decoder: { PartialMediaReference(decoder: $0) }) as? PartialMediaReference
        self.flags = TelegramMediaImageFlags(rawValue: decoder.decodeInt32ForKey("fl", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        self.imageId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeObjectArray(self.representations, forKey: "r")
        encoder.encodeObjectArray(self.videoRepresentations, forKey: "vr")
        if let immediateThumbnailData = self.immediateThumbnailData {
            encoder.encodeData(immediateThumbnailData, forKey: "itd")
        } else {
            encoder.encodeNil(forKey: "itd")
        }
        if let reference = self.reference {
            encoder.encodeObject(reference, forKey: "rf")
        } else {
            encoder.encodeNil(forKey: "rf")
        }
        if let partialReference = self.partialReference {
            encoder.encodeObjectWithEncoder(partialReference, encoder: partialReference.encode, forKey: "prf")
        } else {
            encoder.encodeNil(forKey: "prf")
        }
        encoder.encodeInt32(self.flags.rawValue, forKey: "fl")
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .data)
        let postboxDecoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
        guard let object = postboxDecoder.decodeRootObject() as? TelegramMediaImage else {
            throw TelegramMediaImageDecodingError.generic
        }
        self.imageId = object.imageId
        self.representations = object.representations
        self.videoRepresentations = object.videoRepresentations
        self.immediateThumbnailData = object.immediateThumbnailData
        self.reference = object.reference
        self.partialReference = object.partialReference
        self.flags = object.flags
    }
    
    public func encode(to encoder: Encoder) throws {
        let postboxEncoder = PostboxEncoder()
        postboxEncoder.encodeRootObject(self)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postboxEncoder.makeData(), forKey: .data)
    }
    
    public func representationForDisplayAtSize(_ size: PixelDimensions) -> TelegramMediaImageRepresentation? {
        if self.representations.count == 0 {
            return nil
        } else {
            var dimensions = self.representations[0].dimensions
            var index = 0
            
            for i in 0 ..< self.representations.count {
                let representationDimensions = self.representations[i].dimensions
                
                if dimensions.width >= size.width && dimensions.height >= size.height {
                    if representationDimensions.width >= size.width && representationDimensions.height >= dimensions.height && representationDimensions.width < dimensions.width && representationDimensions.height < dimensions.height {
                        dimensions = representationDimensions
                        index = i
                    }
                } else {
                    if representationDimensions.width >= dimensions.width && representationDimensions.height >= dimensions.height {
                        dimensions = representationDimensions
                        index = i
                    }
                }
            }
            
            return self.representations[index]
        }
    }
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaImage {
            if other.imageId != self.imageId {
                return false
            }
            if other.representations != self.representations {
                return false
            }
            if other.videoRepresentations != self.videoRepresentations {
                return false
            }
            if other.immediateThumbnailData != self.immediateThumbnailData {
                return false
            }
            if self.partialReference != other.partialReference {
                return false
            }
            if self.flags != other.flags {
                return false
            }
            return true
        }
        return false
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaImage {
            if other.imageId != self.imageId {
                return false
            }
            if other.representations.count != self.representations.count {
                return false
            }
            if other.videoRepresentations.count != self.videoRepresentations.count {
                return false
            }
            for i in 0 ..< self.representations.count {
                if !self.representations[i].isSemanticallyEqual(to: other.representations[i]) {
                    return false
                }
            }
            
            if self.partialReference != other.partialReference {
                return false
            }
            if self.flags != other.flags {
                return false
            }
            return true
        }
        return false
    }
    
    public static func ==(lhs: TelegramMediaImage, rhs: TelegramMediaImage) -> Bool {
        return lhs.isEqual(to: rhs)
    }
    
    public func withUpdatedPartialReference(_ partialReference: PartialMediaReference?) -> TelegramMediaImage {
        return TelegramMediaImage(imageId: self.imageId, representations: self.representations, videoRepresentations: self.videoRepresentations, immediateThumbnailData: self.immediateThumbnailData, reference: self.reference, partialReference: partialReference, flags: self.flags)
    }
}

public final class TelegramMediaImageRepresentation: PostboxCoding, Equatable, CustomStringConvertible {
    public let dimensions: PixelDimensions
    public let resource: TelegramMediaResource
    public let progressiveSizes: [Int32]
    public let immediateThumbnailData: Data?
    
    public init(dimensions: PixelDimensions, resource: TelegramMediaResource, progressiveSizes: [Int32], immediateThumbnailData: Data?) {
        self.dimensions = dimensions
        self.resource = resource
        self.progressiveSizes = progressiveSizes
        self.immediateThumbnailData = immediateThumbnailData
    }
    
    public init(decoder: PostboxDecoder) {
        self.dimensions = PixelDimensions(width: decoder.decodeInt32ForKey("dx", orElse: 0), height: decoder.decodeInt32ForKey("dy", orElse: 0))
        self.resource = decoder.decodeObjectForKey("r") as? TelegramMediaResource ?? EmptyMediaResource()
        self.progressiveSizes = decoder.decodeInt32ArrayForKey("ps")
        self.immediateThumbnailData = decoder.decodeDataForKey("th")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.dimensions.width, forKey: "dx")
        encoder.encodeInt32(self.dimensions.height, forKey: "dy")
        encoder.encodeObject(self.resource, forKey: "r")
        encoder.encodeInt32Array(self.progressiveSizes, forKey: "ps")
        if let immediateThumbnailData = self.immediateThumbnailData {
            encoder.encodeData(immediateThumbnailData, forKey: "th")
        } else {
            encoder.encodeNil(forKey: "th")
        }
    }
    
    public var description: String {
        return "(\(Int(dimensions.width))x\(Int(dimensions.height)))"
    }
    
    public func isSemanticallyEqual(to other: TelegramMediaImageRepresentation) -> Bool {
        if self.dimensions != other.dimensions {
            return false
        }
        if !self.resource.id.isEqual(to: other.resource.id) {
            return false
        }
        if self.progressiveSizes != other.progressiveSizes {
            return false
        }
        if self.immediateThumbnailData != other.immediateThumbnailData {
            return false
        }
        return true
    }
}

public func ==(lhs: TelegramMediaImageRepresentation, rhs: TelegramMediaImageRepresentation) -> Bool {
    if lhs.dimensions != rhs.dimensions {
        return false
    }
    if !lhs.resource.isEqual(to: rhs.resource) {
        return false
    }
    return true
}
