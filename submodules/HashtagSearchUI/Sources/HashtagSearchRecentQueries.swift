import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences

private struct HashtagSearchRecentQueryItemId {
    public let rawValue: MemoryBuffer
    
    var value: String {
        return String(data: self.rawValue.makeData(), encoding: .utf8) ?? ""
    }
    
    init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
    }
    
    init?(_ value: String) {
        if let data = value.data(using: .utf8) {
            self.rawValue = MemoryBuffer(data: data)
        } else {
            return nil
        }
    }
}

public final class RecentHashtagSearchQueryItem: Codable {
    public init() {
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public func encode(to encoder: Encoder) throws {
    }
}

func addRecentHashtagSearchQuery(engine: TelegramEngine, string: String) -> Signal<Never, NoError> {
    if let itemId = HashtagSearchRecentQueryItemId(string) {
        return engine.orderedLists.addOrMoveToFirstPosition(collectionId: ApplicationSpecificOrderedItemListCollectionId.hashtagSearchRecentQueries, id: itemId.rawValue, item: RecentHashtagSearchQueryItem(), removeTailIfCountExceeds: 100)
    } else {
        return .complete()
    }
}

func removeRecentHashtagSearchQuery(engine: TelegramEngine, string: String) -> Signal<Never, NoError> {
    if let itemId = HashtagSearchRecentQueryItemId(string) {
        return engine.orderedLists.removeItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.hashtagSearchRecentQueries, id: itemId.rawValue)
    } else {
        return .complete()
    }
}

func clearRecentHashtagSearchQueries(engine: TelegramEngine) -> Signal<Never, NoError> {
    return engine.orderedLists.clear(collectionId: ApplicationSpecificOrderedItemListCollectionId.hashtagSearchRecentQueries)
}

func hashtagSearchRecentQueries(engine: TelegramEngine) -> Signal<[String], NoError> {
    return engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.hashtagSearchRecentQueries))
    |> map { items -> [String] in
        var result: [String] = []
        for item in items {
            let value = HashtagSearchRecentQueryItemId(item.id).value
            result.append(value)
        }
        return result
    }
}
