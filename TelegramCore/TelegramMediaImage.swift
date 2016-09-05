import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class TelegramMediaImage: Media, Equatable {
    public let imageId: MediaId
    public let representations: [TelegramMediaImageRepresentation]
    public let peerIds: [PeerId] = []
    
    public var id: MediaId? {
        return self.imageId
    }
    
    public init(imageId: MediaId, representations: [TelegramMediaImageRepresentation]) {
        self.imageId = imageId
        self.representations = representations
    }
    
    public init(decoder: Decoder) {
        self.imageId = MediaId(decoder.decodeBytesForKeyNoCopy("i"))
        self.representations = decoder.decodeObjectArrayForKey("r")
    }
    
    public func encode(_ encoder: Encoder) {
        let buffer = WriteBuffer()
        self.imageId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeObjectArray(self.representations, forKey: "r")
    }
    
    public func representationForDisplayAtSize(_ size: CGSize) -> TelegramMediaImageRepresentation? {
        if self.representations.count == 0 {
            return nil
        } else {
            var dimensions = self.representations[0].dimensions
            var index = 0
            
            for i in 0 ..< self.representations.count {
                let representationDimensions = self.representations[i].dimensions
                
                if dimensions.width >= size.width - CGFloat(FLT_EPSILON) && dimensions.height >= size.height - CGFloat(FLT_EPSILON) {
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
}

public func ==(lhs: TelegramMediaImage, rhs: TelegramMediaImage) -> Bool {
    return lhs.isEqual(rhs)
}

public final class TelegramMediaImageRepresentation: Coding, Equatable, CustomStringConvertible {
    public let dimensions: CGSize
    public let location: TelegramMediaLocation
    public let size: Int?
    
    public init(dimensions: CGSize, location: TelegramMediaLocation, size: Int?) {
        self.dimensions = dimensions
        self.location = location
        self.size = size
    }
    
    public init(decoder: Decoder) {
        self.dimensions = CGSize(width: CGFloat(decoder.decodeInt32ForKey("dx")), height: CGFloat(decoder.decodeInt32ForKey("dy")))
        self.location = decoder.decodeObjectForKey("l") as! TelegramMediaLocation
        let size: Int32? = decoder.decodeInt32ForKey("s")
        if let size = size {
            self.size = Int(size)
        } else {
            self.size = nil
        }
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(Int32(self.dimensions.width), forKey: "dx")
        encoder.encodeInt32(Int32(self.dimensions.height), forKey: "dy")
        encoder.encodeObject(self.location, forKey: "l")
        if let size = self.size {
            encoder.encodeInt32(Int32(size), forKey: "s")
        }
    }
    
    public var description: String {
        return "(\(Int(dimensions.width))x\(Int(dimensions.height)))"
    }
}

public func ==(lhs: TelegramMediaImageRepresentation, rhs: TelegramMediaImageRepresentation) -> Bool {
    if lhs.dimensions != rhs.dimensions {
        return false
    }
    if lhs.size != rhs.size {
        return false
    }
    if !lhs.location.equalsTo(rhs.location) {
        return false
    }
    return true
}

public func telegramMediaImageRepresentationsFromApiSizes(_ sizes: [Api.PhotoSize]) -> [TelegramMediaImageRepresentation] {
    var representations: [TelegramMediaImageRepresentation] = []
    for size in sizes {
        switch size {
        case let .photoCachedSize(_, location, w, h, bytes):
            if let location = telegramMediaLocationFromApiLocation(location) {
                representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), location: location, size: bytes.size))
            }
        case let .photoSize(_, location, w, h, size):
            if let location = telegramMediaLocationFromApiLocation(location) {
                representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), location: location, size: Int(size)))
            }
        case .photoSizeEmpty:
            break
        }
    }
    return representations
}

public func telegramMediaImageFromApiPhoto(_ photo: Api.Photo) -> TelegramMediaImage? {
    switch photo {
        case let .photo(id, accessHash, _, sizes):
            return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: id), representations: telegramMediaImageRepresentationsFromApiSizes(sizes))
        case .photoEmpty:
            return nil
        case .wallPhoto:
            return nil
    }
}
