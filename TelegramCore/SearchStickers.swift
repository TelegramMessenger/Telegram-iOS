import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func searchStickers(postbox: Postbox, query: String) -> Signal<[StickerPackItem], NoError> {
    return postbox.modify { modifier -> [StickerPackItem] in
        var result: [StickerPackItem] = []
        for item in modifier.searchItemCollection(namespace: Namespaces.ItemCollection.CloudStickerPacks, key: ValueBoxKey(query).toMemoryBuffer()) {
            if let item = item as? StickerPackItem {
                result.append(item)
            }
        }
        return result
    }
}
