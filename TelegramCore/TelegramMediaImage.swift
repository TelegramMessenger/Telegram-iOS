import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
    import UIKit
#endif

public enum TelegramMediaImageReference: PostboxCoding, Equatable {
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

public final class TelegramMediaImage: Media, Equatable {
    public let imageId: MediaId
    public let representations: [TelegramMediaImageRepresentation]
    public let immediateThumbnailData: Data?
    public let reference: TelegramMediaImageReference?
    public let partialReference: PartialMediaReference?
    public let peerIds: [PeerId] = []
    
    public var id: MediaId? {
        return self.imageId
    }
    
    public init(imageId: MediaId, representations: [TelegramMediaImageRepresentation], immediateThumbnailData: Data?, reference: TelegramMediaImageReference?, partialReference: PartialMediaReference?) {
        self.imageId = imageId
        self.representations = representations
        self.immediateThumbnailData = immediateThumbnailData
        self.reference = reference
        self.partialReference = partialReference
    }
    
    public init(decoder: PostboxDecoder) {
        self.imageId = MediaId(decoder.decodeBytesForKeyNoCopy("i")!)
        self.representations = decoder.decodeObjectArrayForKey("r")
        self.immediateThumbnailData = decoder.decodeDataForKey("itd")
        self.reference = decoder.decodeObjectForKey("rf", decoder: { TelegramMediaImageReference(decoder: $0) }) as? TelegramMediaImageReference
        self.partialReference = decoder.decodeAnyObjectForKey("prf", decoder: { PartialMediaReference(decoder: $0) }) as? PartialMediaReference
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        self.imageId.encodeToBuffer(buffer)
        encoder.encodeBytes(buffer, forKey: "i")
        encoder.encodeObjectArray(self.representations, forKey: "r")
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
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaImage {
            if other.imageId != self.imageId {
                return false
            }
            if other.representations != self.representations {
                return false
            }
            if other.immediateThumbnailData != self.immediateThumbnailData {
                return false
            }
            if self.partialReference != other.partialReference {
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
            for i in 0 ..< self.representations.count {
                if !self.representations[i].isSemanticallyEqual(to: other.representations[i]) {
                    return false
                }
            }
            
            if self.partialReference != other.partialReference {
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
        return TelegramMediaImage(imageId: self.imageId, representations: self.representations, immediateThumbnailData: self.immediateThumbnailData, reference: self.reference, partialReference: partialReference)
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
        self.resource = decoder.decodeObjectForKey("r") as? TelegramMediaResource ?? EmptyMediaResource()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.dimensions.width), forKey: "dx")
        encoder.encodeInt32(Int32(self.dimensions.height), forKey: "dy")
        encoder.encodeObject(self.resource, forKey: "r")
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

func telegramMediaImageRepresentationsFromApiSizes(datacenterId: Int32, photoId: Int64, accessHash: Int64, fileReference: Data?, sizes: [Api.PhotoSize]) -> (immediateThumbnail: Data?, representations:  [TelegramMediaImageRepresentation]) {
    var immediateThumbnailData: Data?
    var representations: [TelegramMediaImageRepresentation] = []
    for size in sizes {
        switch size {
            case let .photoCachedSize(type, location, w, h, _):
                switch location {
                    case let .fileLocationToBeDeprecated(volumeId, localId):
                        let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, volumeId: volumeId, localId: localId, fileReference: fileReference)
                        representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
                }
            case let .photoSize(type, location, w, h, _):
                switch location {
                    case let .fileLocationToBeDeprecated(volumeId, localId):
                        let resource = CloudPhotoSizeMediaResource(datacenterId: datacenterId, photoId: photoId, accessHash: accessHash, sizeSpec: type, volumeId: volumeId, localId: localId, fileReference: fileReference)
                        representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
                }
            case let .photoStrippedSize(_, data):
                immediateThumbnailData = data.makeData()
            case .photoSizeEmpty:
                break
        }
    }
    return (immediateThumbnailData, representations)
}

func telegramMediaImageFromApiPhoto(_ photo: Api.Photo) -> TelegramMediaImage? {
    switch photo {
        case let .photo(_, id, accessHash, fileReference, _, sizes, dcId):
            let (immediateThumbnailData, representations) = telegramMediaImageRepresentationsFromApiSizes(datacenterId: dcId, photoId: id, accessHash: accessHash, fileReference: fileReference.makeData(), sizes: sizes)
            return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: id), representations: representations, immediateThumbnailData: immediateThumbnailData, reference: .cloud(imageId: id, accessHash: accessHash, fileReference: fileReference.makeData()), partialReference: nil)
        case .photoEmpty:
            return nil
    }
}
