import Foundation
import Postbox

public final class SavedStickerItem: Codable, Equatable {
    public let file: TelegramMediaFile
    public let stringRepresentations: [String]
    
    public init(file: TelegramMediaFile, stringRepresentations: [String]) {
        self.file = file
        self.stringRepresentations = stringRepresentations
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.file = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: (try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: "f")).data)))
        self.stringRepresentations = try container.decode([String].self, forKey: "sr")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(PostboxEncoder().encodeObjectToRawData(self.file), forKey: "f")
        try container.encode(self.stringRepresentations, forKey: "sr")
    }
    
    public static func ==(lhs: SavedStickerItem, rhs: SavedStickerItem) -> Bool {
        return lhs.file.isEqual(to: rhs.file) && lhs.stringRepresentations == rhs.stringRepresentations
    }
}
