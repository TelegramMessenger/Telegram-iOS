import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences

public final class InstantPageStoredDetailsState: Codable {
    public let index: Int32
    public let expanded: Bool
    public let details: [InstantPageStoredDetailsState]
    
    public init(index: Int32, expanded: Bool, details: [InstantPageStoredDetailsState]) {
        self.index = index
        self.expanded = expanded
        self.details = details
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.index = try container.decode(Int32.self, forKey: "index")
        self.expanded = try container.decode(Bool.self, forKey: "expanded")
        self.details = try container.decode([InstantPageStoredDetailsState].self, forKey: "details")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.index, forKey: "index")
        try container.encode(self.expanded, forKey: "expanded")
        try container.encode(self.details, forKey: "details")
    }
}

public final class InstantPageStoredState: Codable {
    public let contentOffset: Double
    public let details: [InstantPageStoredDetailsState]
    
    public init(contentOffset: Double, details: [InstantPageStoredDetailsState]) {
        self.contentOffset = contentOffset
        self.details = details
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.contentOffset = try container.decode(Double.self, forKey: "offset")
        self.details = try container.decode([InstantPageStoredDetailsState].self, forKey: "details")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.contentOffset, forKey: "offset")
        try container.encode(self.details, forKey: "details")
    }
}

public func instantPageStoredState(engine: TelegramEngine, webPage: TelegramMediaWebpage) -> Signal<InstantPageStoredState?, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: webPage.webpageId.id)
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.instantPageStoredState, id: key))
    |> map { entry -> InstantPageStoredState? in
        return entry?.get(InstantPageStoredState.self)
    }
}

public func updateInstantPageStoredStateInteractively(engine: TelegramEngine, webPage: TelegramMediaWebpage, state: InstantPageStoredState?) -> Signal<Never, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: webPage.webpageId.id)
    
    if let state = state {
        return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.instantPageStoredState, id: key, item: state)
    } else {
        return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.instantPageStoredState, id: key)
    }
}
