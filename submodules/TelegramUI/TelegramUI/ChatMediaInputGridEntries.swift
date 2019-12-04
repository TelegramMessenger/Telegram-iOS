import Postbox
import UIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import MergeLists

enum ChatMediaInputGridEntryStableId: Equatable, Hashable {
    case search
    case peerSpecificSetup
    case sticker(ItemCollectionId, ItemCollectionItemIndex.Id)
    case trending(ItemCollectionId)
}

enum ChatMediaInputGridEntryIndex: Equatable, Comparable {
    case search
    case peerSpecificSetup(dismissed: Bool)
    case collectionIndex(ItemCollectionViewEntryIndex)
    case trending(ItemCollectionId, Int)
    
    var stableId: ChatMediaInputGridEntryStableId {
        switch self {
        case .search:
            return .search
        case .peerSpecificSetup:
            return .peerSpecificSetup
        case let .collectionIndex(index):
            return .sticker(index.collectionId, index.itemIndex.id)
        case let .trending(id, index):
            return .trending(id)
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
        case let .peerSpecificSetup(lhsDismissed):
            switch rhs {
            case .search, .peerSpecificSetup:
                return false
            case let .collectionIndex(index):
                if lhsDismissed {
                    return false
                } else {
                    if index.collectionId.id == 0 {
                        return false
                    } else {
                        return true
                    }
                }
            case .trending:
                return true
            }
        case let .collectionIndex(lhsIndex):
            switch rhs {
            case .search:
                return false
            case let .peerSpecificSetup(dismissed):
                if dismissed {
                    return true
                } else {
                    return false
                }
            case let .collectionIndex(rhsIndex):
                return lhsIndex < rhsIndex
            case .trending:
                return true
            }
        case let .trending(_, lhsIndex):
            switch rhs {
            case .search, .peerSpecificSetup, .collectionIndex:
                return false
            case let .trending(_, rhsIndex):
                return lhsIndex < rhsIndex
            }
        }
    }
}

enum ChatMediaInputGridEntry: Equatable, Comparable, Identifiable {
    case search(theme: PresentationTheme, strings: PresentationStrings)
    case peerSpecificSetup(theme: PresentationTheme, strings: PresentationStrings, dismissed: Bool)
    case sticker(index: ItemCollectionViewEntryIndex, stickerItem: StickerPackItem, stickerPackInfo: StickerPackCollectionInfo?, canManagePeerSpecificPack: Bool?, theme: PresentationTheme)
    case trending(TrendingPaneEntry)
    
    var index: ChatMediaInputGridEntryIndex {
        switch self {
        case .search:
            return .search
        case let .peerSpecificSetup(_, _, dismissed):
            return .peerSpecificSetup(dismissed: dismissed)
        case let .sticker(index, _, _, _, _):
            return .collectionIndex(index)
        case let .trending(entry):
            return .trending(entry.info.id, entry.index)
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
        case let .peerSpecificSetup(lhsTheme, lhsStrings, lhsDismissed):
            if case let .peerSpecificSetup(rhsTheme, rhsStrings, rhsDismissed) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDismissed == rhsDismissed {
                return true
            } else {
                return false
            }
        case let .sticker(lhsIndex, lhsStickerItem, lhsStickerPackInfo, lhsCanManagePeerSpecificPack, lhsTheme):
            if case let .sticker(rhsIndex, rhsStickerItem, rhsStickerPackInfo, rhsCanManagePeerSpecificPack, rhsTheme) = rhs {
                if lhsIndex != rhsIndex {
                    return false
                }
                if lhsStickerItem != rhsStickerItem {
                    return false
                }
                if lhsStickerPackInfo != rhsStickerPackInfo {
                    return false
                }
                if lhsCanManagePeerSpecificPack != rhsCanManagePeerSpecificPack {
                    return false
                }
                if lhsTheme !== rhsTheme {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .trending(entry):
            if case .trending(entry) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: ChatMediaInputGridEntry, rhs: ChatMediaInputGridEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, interfaceInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction, trendingInteraction: TrendingPaneInteraction) -> GridItem {
        switch self {
        case let .search(theme, strings):
            return PaneSearchBarPlaceholderItem(theme: theme, strings: strings, type: .stickers, activate: {
                inputNodeInteraction.toggleSearch(true, .sticker)
            })
        case let .peerSpecificSetup(theme, strings, dismissed):
            return StickerPanePeerSpecificSetupGridItem(theme: theme, strings: strings, setup: {
                inputNodeInteraction.openPeerSpecificSettings()
            }, dismiss: dismissed ? nil : {
                inputNodeInteraction.dismissPeerSpecificSettings()
            })
        case let .sticker(index, stickerItem, stickerPackInfo, canManagePeerSpecificPack, theme):
            return ChatMediaInputStickerGridItem(account: account, collectionId: index.collectionId, stickerPackInfo: stickerPackInfo, index: index, stickerItem: stickerItem, canManagePeerSpecificPack: canManagePeerSpecificPack, interfaceInteraction: interfaceInteraction, inputNodeInteraction: inputNodeInteraction, theme: theme, selected: {  })
        case let .trending(entry):
            return entry.item(account: account, interaction: trendingInteraction, grid: false)
        }
    }
}
