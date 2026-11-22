import Foundation
import Postbox
import FlatBuffers
import FlatSerialization

public final class StickerPackItem: ItemCollectionItem, Equatable {
    public let index: ItemCollectionItemIndex
    public let file: TelegramMediaFile.Accessor
    public let indexKeys: [MemoryBuffer]
    
    public init(index: ItemCollectionItemIndex, file: TelegramMediaFile, indexKeys: [MemoryBuffer]) {
        self.index = index
        self.file = TelegramMediaFile.Accessor(file)
        self.indexKeys = indexKeys
    }
    
    public init?(index: ItemCollectionItemIndex, serializedFile: Data, indexKeys: [MemoryBuffer]) {
        self.index = index
        
        var byteBuffer = ByteBuffer(data: serializedFile)
        let accessor = FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_TelegramMediaFile
        self.file = TelegramMediaFile.Accessor(accessor, serializedFile)
        
        self.indexKeys = indexKeys
    }
    
    public init(decoder: PostboxDecoder) {
        self.index = ItemCollectionItemIndex(index: decoder.decodeInt32ForKey("i.n", orElse: 0), id: decoder.decodeInt64ForKey("i.i", orElse: 0))
        
        if let serializedFileData = decoder.decodeDataForKey("fd") {
            var byteBuffer = ByteBuffer(data: serializedFileData)
            self.file = TelegramMediaFile.Accessor(FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_TelegramMediaFile, serializedFileData)
        } else {
            let file = decoder.decodeObjectForKey("f") as! TelegramMediaFile
            self.file = TelegramMediaFile.Accessor(file)
        }
        
        self.indexKeys = decoder.decodeBytesArrayForKey("s")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.index.index, forKey: "i.n")
        encoder.encodeInt64(self.index.id, forKey: "i.i")
        if let serializedFile = self.file._wrappedData {
            encoder.encodeData(serializedFile, forKey: "fd")
        } else if let file = self.file._wrappedFile {
            var builder = FlatBufferBuilder(initialSize: 1024)
            let value = file.encodeToFlatBuffers(builder: &builder)
            builder.finish(offset: value)
            let serializedFile = builder.data
            encoder.encodeData(serializedFile, forKey: "fd")
        } else {
            preconditionFailure()
        }
        encoder.encodeBytesArray(self.indexKeys, forKey: "s")
    }
    
    public static func ==(lhs: StickerPackItem, rhs: StickerPackItem) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if lhs.indexKeys != rhs.indexKeys {
            return false
        }
        if lhs.file != rhs.file {
            return false
        }
        return true
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
