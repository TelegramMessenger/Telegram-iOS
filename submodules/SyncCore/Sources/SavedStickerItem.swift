import Foundation
import Postbox

public final class SavedStickerItem: OrderedItemListEntryContents, Equatable {
    public let file: TelegramMediaFile
    public let stringRepresentations: [String]
    
    public init(file: TelegramMediaFile, stringRepresentations: [String]) {
        self.file = file
        self.stringRepresentations = stringRepresentations
    }
    
    public init(decoder: PostboxDecoder) {
        self.file = decoder.decodeObjectForKey("f") as! TelegramMediaFile
        self.stringRepresentations = decoder.decodeStringArrayForKey("sr")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.file, forKey: "f")
        encoder.encodeStringArray(self.stringRepresentations, forKey: "sr")
    }
    
    public static func ==(lhs: SavedStickerItem, rhs: SavedStickerItem) -> Bool {
        return lhs.file.isEqual(to: rhs.file) && lhs.stringRepresentations == rhs.stringRepresentations
    }
}
