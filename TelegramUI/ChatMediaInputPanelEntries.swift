import Postbox
import TelegramCore
import SwiftSignalKit
import Display

enum ChatMediaInputPanelEntryStableId: Hashable {
    case stickerPack(Int64)
    
    static func ==(lhs: ChatMediaInputPanelEntryStableId, rhs: ChatMediaInputPanelEntryStableId) -> Bool {
        switch lhs {
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
        case let .stickerPack(id):
            return id.hashValue
        }
    }
}

enum ChatMediaInputPanelEntry: Comparable, Identifiable {
    case stickerPack(index: Int, info: StickerPackCollectionInfo, topItem: StickerPackItem?)
    
    var stableId: ChatMediaInputPanelEntryStableId {
        switch self {
        case let .stickerPack(_, info, _):
            return .stickerPack(info.id.id)
        }
    }
    
    static func ==(lhs: ChatMediaInputPanelEntry, rhs: ChatMediaInputPanelEntry) -> Bool {
        switch lhs {
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
        case let .stickerPack(lhsIndex, lhsInfo, _):
            switch rhs {
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
        case let .stickerPack(index, info, topItem):
            return ChatMediaInputStickerPackItem(account: account, inputNodeInteraction: inputNodeInteraction, collectionId: info.id, stickerPackItem: topItem, index: index, selected: {
                inputNodeInteraction.navigateToCollectionId(info.id)
            })
        }
    }
}
