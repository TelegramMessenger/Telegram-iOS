import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import UIKit
    import TelegramApi
#endif

public struct StickerPackCollectionInfoFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public init(_ flags: StickerPackCollectionInfoFlags) {
        var rawValue: Int32 = 0
        
        if flags.contains(StickerPackCollectionInfoFlags.isMasks) {
            rawValue |= StickerPackCollectionInfoFlags.isMasks.rawValue
        }
        if flags.contains(StickerPackCollectionInfoFlags.isOfficial) {
            rawValue |= StickerPackCollectionInfoFlags.isOfficial.rawValue
        }
        if flags.contains(StickerPackCollectionInfoFlags.isAnimated) {
            rawValue |= StickerPackCollectionInfoFlags.isAnimated.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let isMasks = StickerPackCollectionInfoFlags(rawValue: 1 << 0)
    public static let isOfficial = StickerPackCollectionInfoFlags(rawValue: 1 << 1)
    public static let isAnimated = StickerPackCollectionInfoFlags(rawValue: 1 << 2)
}


public final class StickerPackCollectionInfo: ItemCollectionInfo, Equatable {
    public let id: ItemCollectionId
    public let flags: StickerPackCollectionInfoFlags
    public let accessHash: Int64
    public let title: String
    public let shortName: String
    public let thumbnail: TelegramMediaImageRepresentation?
    public let hash: Int32
    public let count: Int32
    
    public init(id: ItemCollectionId, flags: StickerPackCollectionInfoFlags, accessHash: Int64, title: String, shortName: String, thumbnail: TelegramMediaImageRepresentation?, hash: Int32, count: Int32) {
        self.id = id
        self.flags = flags
        self.accessHash = accessHash
        self.title = title
        self.shortName = shortName
        self.thumbnail = thumbnail
        self.hash = hash
        self.count = count
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = ItemCollectionId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0))
        self.accessHash = decoder.decodeInt64ForKey("a", orElse: 0)
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.shortName = decoder.decodeStringForKey("s", orElse: "")
        self.thumbnail = decoder.decodeObjectForKey("th", decoder: { TelegramMediaImageRepresentation(decoder: $0) }) as? TelegramMediaImageRepresentation
        self.hash = decoder.decodeInt32ForKey("h", orElse: 0)
        self.flags = StickerPackCollectionInfoFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.count = decoder.decodeInt32ForKey("n", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.id.namespace, forKey: "i.n")
        encoder.encodeInt64(self.id.id, forKey: "i.i")
        encoder.encodeInt64(self.accessHash, forKey: "a")
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.shortName, forKey: "s")
        if let thumbnail = self.thumbnail {
            encoder.encodeObject(thumbnail, forKey: "th")
        } else {
            encoder.encodeNil(forKey: "th")
        }
        encoder.encodeInt32(self.hash, forKey: "h")
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        encoder.encodeInt32(self.count, forKey: "n")
    }
    
    public static func ==(lhs: StickerPackCollectionInfo, rhs: StickerPackCollectionInfo) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        
        if lhs.title != rhs.title {
            return false
        }
        
        if lhs.shortName != rhs.shortName {
            return false
        }
        
        if lhs.hash != rhs.hash {
            return false
        }
        
        if lhs.flags != rhs.flags {
            return false
        }
        
        if lhs.count != rhs.count {
            return false
        }
        
        return true
    }
}

public final class StickerPackItem: ItemCollectionItem, Equatable {
    public let index: ItemCollectionItemIndex
    public let file: TelegramMediaFile
    public let indexKeys: [MemoryBuffer]
    
    public init(index: ItemCollectionItemIndex, file: TelegramMediaFile, indexKeys: [MemoryBuffer]) {
        self.index = index
        self.file = file
        self.indexKeys = indexKeys
    }
    
    public init(decoder: PostboxDecoder) {
        self.index = ItemCollectionItemIndex(index: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0))
        self.file = decoder.decodeObjectForKey("f") as! TelegramMediaFile
        self.indexKeys = decoder.decodeBytesArrayForKey("s")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.index.index, forKey: "i.n")
        encoder.encodeInt64(self.index.id, forKey: "i.i")
        encoder.encodeObject(self.file, forKey: "f")
        encoder.encodeBytesArray(self.indexKeys, forKey: "s")
    }
    
    public static func ==(lhs: StickerPackItem, rhs: StickerPackItem) -> Bool {
        return lhs.index == rhs.index && lhs.file == rhs.file && lhs.indexKeys == rhs.indexKeys
    }
    
    public func getStringRepresentationsOfIndexKeys() -> [String] {
        var stringRepresentations: [String] = []
        for key in self.indexKeys {
            key.withDataNoCopy { data in
                if let string = String(data: data, encoding: .utf8) {
                    stringRepresentations.append(string)
                }
            }
        }
        return stringRepresentations
    }
}

func telegramStickerPachThumbnailRepresentationFromApiSize(datacenterId: Int32, size: Api.PhotoSize) -> TelegramMediaImageRepresentation? {
    switch size {
        case let .photoCachedSize(_, location, w, h, _):
            switch location {
                case let .fileLocationToBeDeprecated(volumeId, localId):
                    let resource = CloudStickerPackThumbnailMediaResource(datacenterId: datacenterId, volumeId: volumeId, localId: localId)
                    return TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource)
            }
        case let .photoSize(_, location, w, h, _):
            switch location {
                case let .fileLocationToBeDeprecated(volumeId, localId):
                    let resource = CloudStickerPackThumbnailMediaResource(datacenterId: datacenterId, volumeId: volumeId, localId: localId)
                    return TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource)
            }
        case .photoStrippedSize:
            return nil
        case .photoSizeEmpty:
            return nil
    }
}

extension StickerPackCollectionInfo {
    convenience init(apiSet: Api.StickerSet, namespace: ItemCollectionId.Namespace) {
        switch apiSet {
            case let .stickerSet(flags, _, id, accessHash, title, shortName, thumb, thumbDcId, count, nHash):
                var setFlags: StickerPackCollectionInfoFlags = StickerPackCollectionInfoFlags()
                if (flags & (1 << 2)) != 0 {
                    setFlags.insert(.isOfficial)
                }
                if (flags & (1 << 3)) != 0 {
                    setFlags.insert(.isMasks)
                }
                if (flags & (1 << 5)) != 0 {
                    setFlags.insert(.isAnimated)
                }
                
                var thumbnailRepresentation: TelegramMediaImageRepresentation?
                if let thumb = thumb, let thumbDcId = thumbDcId {
                    thumbnailRepresentation = telegramStickerPachThumbnailRepresentationFromApiSize(datacenterId: thumbDcId, size: thumb)
                }
                
                self.init(id: ItemCollectionId(namespace: namespace, id: id), flags: setFlags, accessHash: accessHash, title: title, shortName: shortName, thumbnail: thumbnailRepresentation, hash: nHash, count: count)
        }
    }
}
