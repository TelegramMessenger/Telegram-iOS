import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

final class InstantPageStoredDetailsState: PostboxCoding {
    let index: Int32
    let expanded: Bool
    let details: [InstantPageStoredDetailsState]
    
    init(index: Int32, expanded: Bool, details: [InstantPageStoredDetailsState]) {
        self.index = index
        self.expanded = expanded
        self.details = details
    }
    
    init(decoder: PostboxDecoder) {
        self.index = decoder.decodeInt32ForKey("index", orElse: 0)
        self.expanded = decoder.decodeBoolForKey("expanded", orElse: false)
        self.details = decoder.decodeObjectArrayForKey("details")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.index, forKey: "index")
        encoder.encodeBool(self.expanded, forKey: "expanded")
        encoder.encodeObjectArray(self.details, forKey: "details")
    }
}

final class InstantPageStoredState: PostboxCoding {
    let contentOffset: Double
    let details: [InstantPageStoredDetailsState]
    
    init(contentOffset: Double, details: [InstantPageStoredDetailsState]) {
        self.contentOffset = contentOffset
        self.details = details
    }
    
    init(decoder: PostboxDecoder) {
        self.contentOffset = decoder.decodeDoubleForKey("offset", orElse: 0.0)
        self.details = decoder.decodeObjectArrayForKey("details")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeDouble(self.contentOffset, forKey: "offset")
        encoder.encodeObjectArray(self.details, forKey: "details")
    }
}

func instantPageStoredState(postbox: Postbox, webPage: TelegramMediaWebpage) -> Signal<InstantPageStoredState?, NoError> {
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

func updateInstantPageStoredStateInteractively(postbox: Postbox, webPage: TelegramMediaWebpage, state: InstantPageStoredState?) -> Signal<Void, NoError> {
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
