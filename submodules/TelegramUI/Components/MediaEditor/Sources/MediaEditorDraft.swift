import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import PersistentStringHash
import Postbox

public final class MediaEditorDraft: Codable, Equatable {
    public static func == (lhs: MediaEditorDraft, rhs: MediaEditorDraft) -> Bool {
        return lhs.path == rhs.path
    }
    
    private enum CodingKeys: String, CodingKey {
        case path
        case isVideo
        case thumbnail
        case dimensionsWidth
        case dimensionsHeight
        case values
    }
    
    public let path: String
    public let isVideo: Bool
    public let thumbnail: UIImage
    public let dimensions: PixelDimensions
    public let values: MediaEditorValues
        
    public init(path: String, isVideo: Bool, thumbnail: UIImage, dimensions: PixelDimensions, values: MediaEditorValues) {
        self.path = path
        self.isVideo = isVideo
        self.thumbnail = thumbnail
        self.dimensions = dimensions
        self.values = values
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.path = try container.decode(String.self, forKey: .path)
        self.isVideo = try container.decode(Bool.self, forKey: .isVideo)
        let thumbnailData = try container.decode(Data.self, forKey: .thumbnail)
        if let thumbnail = UIImage(data: thumbnailData) {
            self.thumbnail = thumbnail
        } else {
            fatalError()
        }
        self.dimensions = PixelDimensions(
            width: try container.decode(Int32.self, forKey: .dimensionsWidth),
            height: try container.decode(Int32.self, forKey: .dimensionsHeight)
        )
        let valuesData = try container.decode(Data.self, forKey: .values)
        if let values = try? JSONDecoder().decode(MediaEditorValues.self, from: valuesData) {
            self.values = values
        } else {
            fatalError()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.path, forKey: .path)
        try container.encode(self.isVideo, forKey: .isVideo)
        if let thumbnailData = self.thumbnail.jpegData(compressionQuality: 0.8) {
            try container.encode(thumbnailData, forKey: .thumbnail)
        }
        try container.encode(self.dimensions.width, forKey: .dimensionsWidth)
        try container.encode(self.dimensions.height, forKey: .dimensionsHeight)
        if let valuesData = try? JSONEncoder().encode(self.values) {
            try container.encode(valuesData, forKey: .values)
        } else {
            fatalError()
        }
    }
}

private struct MediaEditorDraftItemId {
    public let rawValue: MemoryBuffer
    
    var value: Int64 {
        return self.rawValue.makeData().withUnsafeBytes { buffer -> Int64 in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: Int64.self) else {
                return 0
            }
            return bytes.pointee
        }
    }
    
    init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
    }
    
    init(_ value: Int64) {
        var value = value
        self.rawValue = MemoryBuffer(data: Data(bytes: &value, count: MemoryLayout.size(ofValue: value)))
    }
    
    init(_ value: UInt64) {
        var value = Int64(bitPattern: value)
        self.rawValue = MemoryBuffer(data: Data(bytes: &value, count: MemoryLayout.size(ofValue: value)))
    }
}

public func addStoryDraft(engine: TelegramEngine, item: MediaEditorDraft) {
    let itemId = MediaEditorDraftItemId(item.path.persistentHashValue)
    let _ = engine.orderedLists.addOrMoveToFirstPosition(collectionId: ApplicationSpecificOrderedItemListCollectionId.storyDrafts, id: itemId.rawValue, item: item, removeTailIfCountExceeds: 50).start()
}

public func removeStoryDraft(engine: TelegramEngine, path: String, delete: Bool) {
    if delete {
        try? FileManager.default.removeItem(atPath: path)
    }
    let itemId = MediaEditorDraftItemId(path.persistentHashValue)
    let _ = engine.orderedLists.removeItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.storyDrafts, id: itemId.rawValue).start()
}

public func clearStoryDrafts(engine: TelegramEngine) {
    let _ = engine.orderedLists.clear(collectionId: ApplicationSpecificOrderedItemListCollectionId.storyDrafts).start()
}

public func storyDrafts(engine: TelegramEngine) -> Signal<[MediaEditorDraft], NoError> {
    return engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.storyDrafts))
    |> map { items -> [MediaEditorDraft] in
        var result: [MediaEditorDraft] = []
        for item in items {
            if let draft = item.contents.get(MediaEditorDraft.self) {
                result.append(draft)
            }
        }
        return result
    }
}

public func saveStorySource(engine: TelegramEngine, item: MediaEditorDraft, id: Int64) {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: id)
    let _ = engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: key, item: item).start()
}

public func removeStorySource(engine: TelegramEngine, id: Int64) {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: id)
    let _ = engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: key)
}

public func moveStorySource(engine: TelegramEngine, from fromId: Int64, to toId: Int64) {
    let fromKey = EngineDataBuffer(length: 8)
    fromKey.setInt64(0, value: fromId)
    
    let toKey = EngineDataBuffer(length: 8)
    toKey.setInt64(0, value: toId)
    
    let _ = engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: fromKey))
    |> mapToSignal { item -> Signal<Never, NoError> in
        if let item = item?.get(MediaEditorDraft.self) {
            return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: toKey, item: item)
            |> then(
                engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: fromKey)
            )
        } else {
            return .complete()
        }
    }
}
