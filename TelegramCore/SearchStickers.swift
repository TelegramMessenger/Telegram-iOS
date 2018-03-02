import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public final class FoundStickerItem: Equatable {
    public let file: TelegramMediaFile
    public let stringRepresentations: [String]
    
    public init(file: TelegramMediaFile, stringRepresentations: [String]) {
        self.file = file
        self.stringRepresentations = stringRepresentations
    }
    
    public static func ==(lhs: FoundStickerItem, rhs: FoundStickerItem) -> Bool {
        if !lhs.file.isEqual(rhs.file) {
            return false
        }
        if lhs.stringRepresentations != rhs.stringRepresentations {
            return false
        }
        return true
    }
}

public func searchStickers(postbox: Postbox, query: String) -> Signal<[FoundStickerItem], NoError> {
    return postbox.modify { modifier -> [FoundStickerItem] in
        var result: [FoundStickerItem] = []
        var idsSet = Set<MediaId>()
        
        for item in modifier.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers) {
            if let stickerItem = item.contents as? SavedStickerItem {
                for string in stickerItem.stringRepresentations {
                    if string == query {
                        idsSet.insert(stickerItem.file.fileId)
                        result.append(FoundStickerItem(file: stickerItem.file, stringRepresentations: stickerItem.stringRepresentations))
                    }
                }
            }
        }
        
        for item in modifier.searchItemCollection(namespace: Namespaces.ItemCollection.CloudStickerPacks, key: ValueBoxKey(query).toMemoryBuffer()) {
            if let item = item as? StickerPackItem {
                if !idsSet.contains(item.file.fileId) {
                    idsSet.insert(item.file.fileId)
                    var stringRepresentations: [String] = []
                    for key in item.indexKeys {
                        key.withDataNoCopy { data in
                            if let string = String(data: data, encoding: .utf8) {
                                stringRepresentations.append(string)
                            }
                        }
                    }
                    result.append(FoundStickerItem(file: item.file, stringRepresentations: stringRepresentations))
                }
            }
        }
        return result
    }
}
