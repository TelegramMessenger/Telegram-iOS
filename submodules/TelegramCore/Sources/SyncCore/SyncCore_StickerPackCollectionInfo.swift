import Foundation
import Postbox
import FlatBuffers
import FlatSerialization

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
        if flags.contains(StickerPackCollectionInfoFlags.isEmoji) {
            rawValue |= StickerPackCollectionInfoFlags.isEmoji.rawValue
        }
        if flags.contains(StickerPackCollectionInfoFlags.isAvailableAsChannelStatus) {
            rawValue |= StickerPackCollectionInfoFlags.isAvailableAsChannelStatus.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let isMasks = StickerPackCollectionInfoFlags(rawValue: 1 << 0)
    public static let isOfficial = StickerPackCollectionInfoFlags(rawValue: 1 << 1)
    public static let isEmoji = StickerPackCollectionInfoFlags(rawValue: 1 << 4)
    public static let isAvailableAsChannelStatus = StickerPackCollectionInfoFlags(rawValue: 1 << 5)
    public static let isCustomTemplateEmoji = StickerPackCollectionInfoFlags(rawValue: 1 << 6)
    public static let isCreator = StickerPackCollectionInfoFlags(rawValue: 1 << 7)
}

public final class StickerPackCollectionInfo: ItemCollectionInfo, Equatable {
    public let id: ItemCollectionId
    public let flags: StickerPackCollectionInfoFlags
    public let accessHash: Int64
    public let title: String
    public let shortName: String
    public let thumbnail: TelegramMediaImageRepresentation?
    public let thumbnailFileId: Int64?
    public let immediateThumbnailData: Data?
    public let hash: Int32
    public let count: Int32
    
    public init(id: ItemCollectionId, flags: StickerPackCollectionInfoFlags, accessHash: Int64, title: String, shortName: String, thumbnail: TelegramMediaImageRepresentation?, thumbnailFileId: Int64?, immediateThumbnailData: Data?, hash: Int32, count: Int32) {
        self.id = id
        self.flags = flags
        self.accessHash = accessHash
        self.title = title
        self.shortName = shortName
        self.thumbnail = thumbnail
        self.thumbnailFileId = thumbnailFileId
        self.immediateThumbnailData = immediateThumbnailData
        self.hash = hash
        self.count = count
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = ItemCollectionId(namespace: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0))
        self.accessHash = decoder.decodeInt64ForKey("a", orElse: 0)
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.shortName = decoder.decodeStringForKey("s", orElse: "")
        self.thumbnail = decoder.decodeObjectForKey("th", decoder: { TelegramMediaImageRepresentation(decoder: $0) }) as? TelegramMediaImageRepresentation
        self.thumbnailFileId = decoder.decodeOptionalInt64ForKey("tfi")
        self.immediateThumbnailData = decoder.decodeDataForKey("itd")
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
        if let thumbnailFileId = self.thumbnailFileId {
            encoder.encodeInt64(thumbnailFileId, forKey: "tfi")
        } else {
            encoder.encodeNil(forKey: "tfi")
        }
        if let immediateThumbnailData = self.immediateThumbnailData {
            encoder.encodeData(immediateThumbnailData, forKey: "itd")
        } else {
            encoder.encodeNil(forKey: "itd")
        }
        encoder.encodeInt32(self.hash, forKey: "h")
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        encoder.encodeInt32(self.count, forKey: "n")
        
        #if DEBUG
        var builder = FlatBufferBuilder(initialSize: 1024)
        let offset = self.encodeToFlatBuffers(builder: &builder)
        builder.finish(offset: offset)
        let serializedData = builder.data
        var byteBuffer = ByteBuffer(data: serializedData)
        let deserializedValue = FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_StickerPackCollectionInfo
        let parsedValue = try! StickerPackCollectionInfo(flatBuffersObject: deserializedValue)
        assert(self == parsedValue)
        #endif
    }
    
    public init(flatBuffersObject: TelegramCore_StickerPackCollectionInfo) throws {
        self.id = ItemCollectionId(flatBuffersObject.id)
        self.flags = StickerPackCollectionInfoFlags(rawValue: flatBuffersObject.flags)
        self.accessHash = flatBuffersObject.accessHash
        self.title = flatBuffersObject.title
        self.shortName = flatBuffersObject.shortName
        self.thumbnail = try flatBuffersObject.thumbnail.flatMap(TelegramMediaImageRepresentation.init(flatBuffersObject:))
        self.thumbnailFileId = flatBuffersObject.thumbnailFileId == Int64.min ? nil : flatBuffersObject.thumbnailFileId
        self.immediateThumbnailData = flatBuffersObject.immediateThumbnailData.isEmpty ? nil : Data(flatBuffersObject.immediateThumbnailData)
        self.hash = flatBuffersObject.hash
        self.count = flatBuffersObject.count
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let titleOffset = builder.create(string: self.title)
        let shortNameOffset = builder.create(string: self.shortName)
        let thumbnailOffset = self.thumbnail.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        let immediateThumbnailDataOffset = self.immediateThumbnailData.flatMap { builder.createVector(bytes: $0) }
        
        let start = TelegramCore_StickerPackCollectionInfo.startStickerPackCollectionInfo(&builder)
        
        TelegramCore_StickerPackCollectionInfo.add(id: self.id.asFlatBuffersObject(), &builder)
        TelegramCore_StickerPackCollectionInfo.add(flags: self.flags.rawValue, &builder)
        TelegramCore_StickerPackCollectionInfo.add(accessHash: self.accessHash, &builder)
        TelegramCore_StickerPackCollectionInfo.add(title: titleOffset, &builder)
        TelegramCore_StickerPackCollectionInfo.add(shortName: shortNameOffset, &builder)
        if let thumbnailOffset {
            TelegramCore_StickerPackCollectionInfo.add(thumbnail: thumbnailOffset, &builder)
        }
        TelegramCore_StickerPackCollectionInfo.add(thumbnailFileId: self.thumbnailFileId ?? Int64.min, &builder)
        if let immediateThumbnailDataOffset {
            TelegramCore_StickerPackCollectionInfo.addVectorOf(immediateThumbnailData: immediateThumbnailDataOffset, &builder)
        }
        TelegramCore_StickerPackCollectionInfo.add(hash: self.hash, &builder)
        TelegramCore_StickerPackCollectionInfo.add(count: self.count, &builder)
        
        return TelegramCore_StickerPackCollectionInfo.endStickerPackCollectionInfo(&builder, start: start)
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
        if lhs.immediateThumbnailData != rhs.immediateThumbnailData {
            return false
        }
        if lhs.thumbnailFileId != rhs.thumbnailFileId {
            return false
        }
        if lhs.flags != rhs.flags {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if lhs.thumbnail != rhs.thumbnail {
            return false
        }
        return true
    }
}

public extension StickerPackCollectionInfo {
    struct Accessor: Equatable {
        let _wrappedObject: StickerPackCollectionInfo?
        let _wrapped: TelegramCore_StickerPackCollectionInfo?
        let _wrappedData: Data?
        
        public init(_ wrapped: TelegramCore_StickerPackCollectionInfo, _ _wrappedData: Data) {
            self._wrapped = wrapped
            self._wrappedData = _wrappedData
            self._wrappedObject = nil
        }
        
        public init(_ wrapped: StickerPackCollectionInfo) {
            self._wrapped = nil
            self._wrappedData = nil
            self._wrappedObject = wrapped
        }
        
        public func _parse() -> StickerPackCollectionInfo {
            if let _wrappedObject = self._wrappedObject {
                return _wrappedObject
            } else {
                return try! StickerPackCollectionInfo(flatBuffersObject: self._wrapped!)
            }
        }
        
        public static func ==(lhs: StickerPackCollectionInfo.Accessor, rhs: StickerPackCollectionInfo.Accessor) -> Bool {
            if let lhsWrappedObject = lhs._wrappedObject, let rhsWrappedObject = rhs._wrappedObject {
                return lhsWrappedObject == rhsWrappedObject
            } else if let lhsWrappedData = lhs._wrappedData, let rhsWrappedData = rhs._wrappedData {
                return lhsWrappedData == rhsWrappedData
            } else {
                return lhs._parse() == rhs._parse()
            }
        }
    }
}

public extension StickerPackCollectionInfo.Accessor {
    var id: ItemCollectionId {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.id
        }
        
        return ItemCollectionId(self._wrapped!.id)
    }
    
    var accessHash: Int64 {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.accessHash
        }
        
        return self._wrapped!.accessHash
    }
    
    var flags: StickerPackCollectionInfoFlags {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.flags
        }
        
        return StickerPackCollectionInfoFlags(rawValue: self._wrapped!.flags)
    }
    
    var title: String {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.title
        }
        
        return self._wrapped!.title
    }
    
    var shortName: String {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.shortName
        }
        
        return self._wrapped!.shortName
    }
    
    var hash: Int32 {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.hash
        }
        
        return self._wrapped!.hash
    }
    
    var immediateThumbnailData: Data? {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.immediateThumbnailData
        }
        
        return self._wrapped!.immediateThumbnailData.isEmpty ? nil : Data(self._wrapped!.immediateThumbnailData)
    }
    
    var thumbnailFileId: Int64? {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.thumbnailFileId
        }
        
        return self._wrapped!.thumbnailFileId == Int64.min ? nil : self._wrapped!.thumbnailFileId
    }
    
    var count: Int32 {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.count
        }
        
        return self._wrapped!.count
    }
    
    var hasThumbnail: Bool {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.thumbnail != nil
        }
        
        return self._wrapped!.thumbnail != nil
    }
    
    var thumbnailDimensions: PixelDimensions? {
        if let _wrappedObject = self._wrappedObject {
            return _wrappedObject.thumbnail?.dimensions
        }
        
        if let thumbnail = self._wrapped!.thumbnail {
            return PixelDimensions(width: thumbnail.width, height: thumbnail.height)
        } else {
            return nil
        }
    }
}
