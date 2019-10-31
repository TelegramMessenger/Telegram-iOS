import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramUIPreferences

public final class InstantPageStoredDetailsState: PostboxCoding {
    public let index: Int32
    public let expanded: Bool
    public let details: [InstantPageStoredDetailsState]
    
    public init(index: Int32, expanded: Bool, details: [InstantPageStoredDetailsState]) {
        self.index = index
        self.expanded = expanded
        self.details = details
    }
    
    public init(decoder: PostboxDecoder) {
        self.index = decoder.decodeInt32ForKey("index", orElse: 0)
        self.expanded = decoder.decodeBoolForKey("expanded", orElse: false)
        self.details = decoder.decodeObjectArrayForKey("details")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.index, forKey: "index")
        encoder.encodeBool(self.expanded, forKey: "expanded")
        encoder.encodeObjectArray(self.details, forKey: "details")
    }
}

public final class InstantPageStoredState: PostboxCoding {
    public let contentOffset: Double
    public let details: [InstantPageStoredDetailsState]
    
    public init(contentOffset: Double, details: [InstantPageStoredDetailsState]) {
        self.contentOffset = contentOffset
        self.details = details
    }
    
    public init(decoder: PostboxDecoder) {
        self.contentOffset = decoder.decodeDoubleForKey("offset", orElse: 0.0)
        self.details = decoder.decodeObjectArrayForKey("details")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeDouble(self.contentOffset, forKey: "offset")
        encoder.encodeObjectArray(self.details, forKey: "details")
    }
}

public func instantPageStoredState(postbox: Postbox, webPage: TelegramMediaWebpage) -> Signal<InstantPageStoredState?, NoError> {
    return postbox.transaction { transaction -> InstantPageStoredState? in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: webPage.webpageId.id)
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.instantPageStoredState, key: key)) as? InstantPageStoredState {
            return entry
        } else {
            return nil
        }
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 100, highWaterItemCount: 200)

public func updateInstantPageStoredStateInteractively(postbox: Postbox, webPage: TelegramMediaWebpage, state: InstantPageStoredState?) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: webPage.webpageId.id)
        let id = ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.instantPageStoredState, key: key)
        if let state = state {
            transaction.putItemCacheEntry(id: id, entry: state, collectionSpec: collectionSpec)
        } else {
            transaction.removeItemCacheEntry(id: id)
        }
    }
}
