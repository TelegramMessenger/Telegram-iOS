import Postbox
import TelegramCore
import SwiftSignalKit
import Display

struct ChatMediaInputGridEntryStableId: Hashable {
    let collectionId: ItemCollectionId
    let itemId: ItemCollectionItemIndex.Id
    
    static func ==(lhs: ChatMediaInputGridEntryStableId, rhs: ChatMediaInputGridEntryStableId) -> Bool {
        return lhs.collectionId == rhs.collectionId && lhs.itemId == rhs.itemId
    }
    
    var hashValue: Int {
        return self.itemId.hashValue
    }
}

struct ChatMediaInputGridEntry: Comparable, Identifiable {
    let index: ItemCollectionViewEntryIndex
    let stickerItem: StickerPackItem
    let stickerPackInfo: StickerPackCollectionInfo?
    let theme: PresentationTheme
    
    var stableId: ChatMediaInputGridEntryStableId {
        return ChatMediaInputGridEntryStableId(collectionId: self.index.collectionId, itemId: self.stickerItem.index.id)
    }
    
    static func ==(lhs: ChatMediaInputGridEntry, rhs: ChatMediaInputGridEntry) -> Bool {
        return lhs.index == rhs.index && lhs.stickerItem == rhs.stickerItem && lhs.stickerPackInfo?.id == rhs.stickerPackInfo?.id && lhs.theme === rhs.theme
    }
    
    static func <(lhs: ChatMediaInputGridEntry, rhs: ChatMediaInputGridEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, interfaceInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction) -> GridItem {
        return ChatMediaInputStickerGridItem(account: account, collectionId: self.index.collectionId, stickerPackInfo: self.stickerPackInfo, index: self.index, stickerItem: self.stickerItem, interfaceInteraction: interfaceInteraction, inputNodeInteraction: inputNodeInteraction, theme: self.theme, selected: {  })
    }
}
