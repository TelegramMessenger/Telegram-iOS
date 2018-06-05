import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum TelegramMediaImageReference: PostboxCoding, Equatable {
    case cloud(imageId: Int64, accessHash: Int64)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
            case 0:
                self = .cloud(imageId: decoder.decodeInt64ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            default:
                self = .cloud(imageId: 0, accessHash: 0)
                assertionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .cloud(imageId, accessHash):
                encoder.encodeInt32(0, forKey: "_v")
                encoder.encodeInt64(imageId, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
        }
    }
    
    public static func ==(lhs: TelegramMediaImageReference, rhs: TelegramMediaImageReference) -> Bool {
        switch lhs {
            case let .cloud(imageId, accessHash):
                if case .cloud(imageId, accessHash) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class TelegramMediaImage: Media, Equatable {
    public let imageId: MediaId
    public let representations: [TelegramMediaImageRepresentation]
    public let reference: TelegramMediaImageReference?
    public let peerIds: [PeerId] = []
    
    public var id: MediaId? {
        return self.imageId
    }
    
    public init(imageId: MediaId, representations: [TelegramMediaImageRepresentation], reference: TelegramMediaImageReference?) {
        self.imageId = imageId
        self.representations = representations
        self.reference = reference
    }
    
    public init(decoder: PostboxDecoder) {
        self.imageId = MediaId(decoder.decodeBytesForKeyNoCopy("i")!)
        self.representations = decoder.decodeObjectArrayForKey("r")
        self.reference = decoder.decodeObjectForKey("rf", decoder: { TelegramMediaImageReference(decoder: $0) }) as? TelegramMediaImageReference
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        self.imageId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeObjectArray(self.representations, forKey: "r")
        if let reference = self.reference {
            encoder.encodeObject(reference, forKey: "rf")
        } else {
            encoder.encodeNil(forKey: "rf")
        }
    }
    
    public func representationForDisplayAtSize(_ size: CGSize) -> TelegramMediaImageRepresentation? {
        if self.representations.count == 0 {
            return nil
        } else {
            var dimensions = self.representations[0].dimensions
            var index = 0
            
            for i in 0 ..< self.representations.count {
                let representationDimensions = self.representations[i].dimensions
                
                if dimensions.width >= size.width - CGFloat.ulpOfOne && dimensions.height >= size.height - CGFloat.ulpOfOne {
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
    
    public func isEqual(_ other: Media) -> Bool {
        if let other = other as? TelegramMediaImage {
            if other.imageId != self.imageId {
                return false
            }
            if other.representations != self.representations {
                return false
            }
            return true
        }
        return false
    }
    
    public static func ==(lhs: TelegramMediaImage, rhs: TelegramMediaImage) -> Bool {
        return lhs.isEqual(rhs)
    }
}

public final class TelegramMediaImageRepresentation: PostboxCoding, Equatable, CustomStringConvertible {
    public let dimensions: CGSize
    public let resource: TelegramMediaResource
    
    public init(dimensions: CGSize, resource: TelegramMediaResource) {
        self.dimensions = dimensions
        self.resource = resource
    }
    
    public init(decoder: PostboxDecoder) {
        self.dimensions = CGSize(width: CGFloat(decoder.decodeInt32ForKey("dx", orElse: 0)), height: CGFloat(decoder.decodeInt32ForKey("dy", orElse: 0)))
        self.resource = decoder.decodeObjectForKey("r") as! TelegramMediaResource
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.dimensions.width), forKey: "dx")
        encoder.encodeInt32(Int32(self.dimensions.height), forKey: "dy")
        encoder.encodeObject(self.resource, forKey: "r")
    }
    
    public var description: String {
        return "(\(Int(dimensions.width))x\(Int(dimensions.height)))"
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

func telegramMediaImageRepresentationsFromApiSizes(_ sizes: [Api.PhotoSize]) -> [TelegramMediaImageRepresentation] {
    var representations: [TelegramMediaImageRepresentation] = []
    for size in sizes {
        switch size {
        case let .photoCachedSize(_, location, w, h, bytes):
            if let resource = mediaResourceFromApiFileLocation(location, size: bytes.size) {
                representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
            }
        case let .photoSize(_, location, w, h, size):
            if let resource = mediaResourceFromApiFileLocation(location, size: Int(size)) {
                representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
            }
        case .photoSizeEmpty:
            break
        }
    }
    return representations
}

func telegramMediaImageFromApiPhoto(_ photo: Api.Photo) -> TelegramMediaImage? {
    switch photo {
        case let .photo(_, id, accessHash, _, sizes):
            return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: id), representations: telegramMediaImageRepresentationsFromApiSizes(sizes), reference: .cloud(imageId: id, accessHash: accessHash))
        case .photoEmpty:
            return nil
    }
}
