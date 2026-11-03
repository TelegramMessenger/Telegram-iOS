import Foundation
import Postbox
import FlatBuffers
import FlatSerialization

public final class SavedStickerItem: Codable, Equatable {
    public let file: TelegramMediaFile.Accessor
    public let stringRepresentations: [String]
    
    public init(file: TelegramMediaFile, stringRepresentations: [String]) {
        self.file = TelegramMediaFile.Accessor(file)
        self.stringRepresentations = stringRepresentations
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let serializedFileData = try container.decodeIfPresent(Data.self, forKey: "fd") {
            var byteBuffer = ByteBuffer(data: serializedFileData)
            self.file = TelegramMediaFile.Accessor(FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_TelegramMediaFile, serializedFileData)
        } else {
            let file = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: (try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: "f")).data)))
            self.file = TelegramMediaFile.Accessor(file)
        }
        
        self.stringRepresentations = try container.decode([String].self, forKey: "sr")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        if let serializedFile = self.file._wrappedData {
            try container.encode(serializedFile, forKey: "fd")
        } else if let file = self.file._wrappedFile {
            var builder = FlatBufferBuilder(initialSize: 1024)
            let value = file.encodeToFlatBuffers(builder: &builder)
            builder.finish(offset: value)
            let serializedFile = builder.data
            try container.encode(serializedFile, forKey: "fd")
        } else {
            preconditionFailure()
        }
        
        try container.encode(self.stringRepresentations, forKey: "sr")
    }
    
    public static func ==(lhs: SavedStickerItem, rhs: SavedStickerItem) -> Bool {
        return lhs.file == rhs.file && lhs.stringRepresentations == rhs.stringRepresentations
    }
}
