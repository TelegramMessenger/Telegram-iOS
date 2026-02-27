import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences

private struct SettingsSearchRecentQueryItemId {
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
}

public final class RecentSettingsSearchQueryItem: Codable {
    public init() {
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public func encode(to encoder: Encoder) throws {
    }
}

func addRecentSettingsSearchItem(engine: TelegramEngine, item: AnyHashable) {
    guard let id = item.base as? String, let data = id.data(using: .ascii) else {
        return
    }
    let itemId = MemoryBuffer(data: data)
    let _ = engine.orderedLists.addOrMoveToFirstPosition(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, id: itemId, item: RecentSettingsSearchQueryItem(), removeTailIfCountExceeds: 100).start()
}

func removeRecentSettingsSearchItem(engine: TelegramEngine, item: AnyHashable) {
    guard let id = item.base as? String, let data = id.data(using: .ascii) else {
        return
    }
    let itemId = MemoryBuffer(data: data)
    let _ = engine.orderedLists.removeItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems, id: itemId).start()
}

func clearRecentSettingsSearchItems(engine: TelegramEngine) {
    let _ = engine.orderedLists.clear(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems).start()
}

func settingsSearchRecentItems(engine: TelegramEngine) -> Signal<[AnyHashable], NoError> {
    return engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.settingsSearchRecentItems))
    |> map { items -> [AnyHashable] in
        var result: [AnyHashable] = []
        for item in items {
            let data = item.id.makeData()
            if let id = String(data: data, encoding: .utf8) {
                result.append(id)
            }
        }
        return result
    }
}
