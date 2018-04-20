import Postbox
import TelegramCore
import SwiftSignalKit
import Display

enum ChatMediaInputGridEntryStableId: Equatable, Hashable {
    case search
    case sticker(ItemCollectionId, ItemCollectionItemIndex.Id)
}

enum ChatMediaInputGridEntryIndex: Equatable, Comparable {
    case search
    case collectionIndex(ItemCollectionViewEntryIndex)
    
    var stableId: ChatMediaInputGridEntryStableId {
        switch self {
            case .search:
                return .search
            case let .collectionIndex(index):
                return .sticker(index.collectionId, index.itemIndex.id)
        }
    }
    
    static func <(lhs: ChatMediaInputGridEntryIndex, rhs: ChatMediaInputGridEntryIndex) -> Bool {
        switch lhs {
            case .search:
                if case .search = rhs {
                    return false
                } else {
                    return true
                }
            case let .collectionIndex(lhsIndex):
                switch rhs {
                    case .search:
                        return false
                    case let .collectionIndex(rhsIndex):
                        return lhsIndex < rhsIndex
                }
        }
    }
}

enum ChatMediaInputGridEntry: Equatable, Comparable, Identifiable {
    case search(theme: PresentationTheme, strings: PresentationStrings)
    case sticker(index: ItemCollectionViewEntryIndex, stickerItem: StickerPackItem, stickerPackInfo: StickerPackCollectionInfo?, theme: PresentationTheme)
    
    var index: ChatMediaInputGridEntryIndex {
        switch self {
            case .search:
                return .search
            case let .sticker(index, _, _, _):
                return .collectionIndex(index)
        }
    }
    
    var stableId: ChatMediaInputGridEntryStableId {
        return self.index.stableId
    }
    
    static func ==(lhs: ChatMediaInputGridEntry, rhs: ChatMediaInputGridEntry) -> Bool {
        switch lhs {
            case let .search(lhsTheme, lhsStrings):
                if case let .search(rhsTheme, rhsStrings) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .sticker(lhsIndex, lhsStickerItem, lhsStickerPackInfo, lhsTheme):
                if case let .sticker(rhsIndex, rhsStickerItem, rhsStickerPackInfo, rhsTheme) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsStickerItem != rhsStickerItem {
                        return false
                    }
                    if lhsStickerPackInfo != rhsStickerPackInfo {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatMediaInputGridEntry, rhs: ChatMediaInputGridEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, interfaceInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction) -> GridItem {
        switch self {
            case let .search(theme, strings):
                return StickerPaneSearchBarPlaceholderItem(theme: theme, strings: strings, activate: {
                    inputNodeInteraction.toggleSearch(true)
                })
            case let .sticker(index, stickerItem, stickerPackInfo, theme):
                return ChatMediaInputStickerGridItem(account: account, collectionId: index.collectionId, stickerPackInfo: stickerPackInfo, index: index, stickerItem: stickerItem, interfaceInteraction: interfaceInteraction, inputNodeInteraction: inputNodeInteraction, theme: theme, selected: {  })
        }
    }
}
