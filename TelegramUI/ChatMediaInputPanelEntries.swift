import Postbox
import TelegramCore
import SwiftSignalKit
import Display

enum ChatMediaInputPanelEntryStableId: Hashable {
    case recentPacks
    case stickerPack(Int64)
    
    static func ==(lhs: ChatMediaInputPanelEntryStableId, rhs: ChatMediaInputPanelEntryStableId) -> Bool {
        switch lhs {
            case .recentPacks:
                if case .recentPacks = rhs {
                    return true
                } else {
                    return false
                }
            case let .stickerPack(id):
                if case .stickerPack(id) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case .recentPacks:
                return 0
            case let .stickerPack(id):
                return id.hashValue
        }
    }
}

enum ChatMediaInputPanelEntry: Comparable, Identifiable {
    case recentPacks
    case stickerPack(index: Int, info: StickerPackCollectionInfo, topItem: StickerPackItem?)
    
    var stableId: ChatMediaInputPanelEntryStableId {
        switch self {
            case .recentPacks:
                return .recentPacks
            case let .stickerPack(_, info, _):
                return .stickerPack(info.id.id)
        }
    }
    
    static func ==(lhs: ChatMediaInputPanelEntry, rhs: ChatMediaInputPanelEntry) -> Bool {
        switch lhs {
            case .recentPacks:
                if case .recentPacks = rhs {
                    return true
                } else {
                    return false
                }
            case let .stickerPack(index, info, topItem):
                if case let .stickerPack(rhsIndex, rhsInfo, rhsTopItem) = rhs, index == rhsIndex, info == rhsInfo, topItem == rhsTopItem {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatMediaInputPanelEntry, rhs: ChatMediaInputPanelEntry) -> Bool {
        switch lhs {
            case .recentPacks:
                return true
            case let .stickerPack(lhsIndex, lhsInfo, _):
                switch rhs {
                    case .recentPacks:
                        return false
                    case let .stickerPack(rhsIndex, rhsInfo, _):
                        if lhsIndex == rhsIndex {
                            return lhsInfo.id.id < rhsInfo.id.id
                        } else {
                            return lhsIndex < rhsIndex
                        }
                }
        }
    }
    
    func item(account: Account, inputNodeInteraction: ChatMediaInputNodeInteraction) -> ListViewItem {
        switch self {
            case .recentPacks:
                return ChatMediaInputRecentStickerPacksItem(inputNodeInteraction: inputNodeInteraction, selected: {
                    let collectionId = ItemCollectionId(namespace: Namespaces.ItemCollection.CloudRecentStickers, id: 0)
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .stickerPack(index, info, topItem):
                return ChatMediaInputStickerPackItem(account: account, inputNodeInteraction: inputNodeInteraction, collectionId: info.id, stickerPackItem: topItem, index: index, selected: {
                    inputNodeInteraction.navigateToCollectionId(info.id)
                })
        }
    }
}
