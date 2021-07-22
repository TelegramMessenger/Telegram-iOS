import Postbox
import UIKit
import TelegramCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import MergeLists
import AccountContext

enum ChatMediaInputPanelAuxiliaryNamespace: Int32 {
    case savedStickers = 2
    case recentGifs = 3
    case recentStickers = 4
    case peerSpecific = 5
    case trending = 6
    case settings = 7
}

enum ChatMediaInputPanelEntryStableId: Hashable {
    case recentGifs
    case savedStickers
    case recentPacks
    case stickerPack(Int64)
    case peerSpecific
    case trending
    case settings
    case stickersMode
    case savedGifs
    case trendingGifs
    case gifEmotion(String)
}

enum ChatMediaInputPanelEntry: Comparable, Identifiable {
    case recentGifs(PresentationTheme, Bool)
    case savedStickers(PresentationTheme, Bool)
    case recentPacks(PresentationTheme, Bool)
    case trending(Bool, PresentationTheme, Bool)
    case settings(PresentationTheme, Bool)
    case peerSpecific(theme: PresentationTheme, peer: Peer, expanded: Bool)
    case stickerPack(index: Int, info: StickerPackCollectionInfo, topItem: StickerPackItem?, theme: PresentationTheme, expanded: Bool)
    
    case stickersMode(PresentationTheme, Bool)
    case savedGifs(PresentationTheme, Bool)
    case trendingGifs(PresentationTheme, Bool)
    case gifEmotion(Int, PresentationTheme, String, Bool)
    
    var stableId: ChatMediaInputPanelEntryStableId {
        switch self {
        case .recentGifs:
            return .recentGifs
        case .savedStickers:
            return .savedStickers
        case .recentPacks:
            return .recentPacks
        case .trending:
            return .trending
        case .settings:
            return .settings
        case .peerSpecific:
            return .peerSpecific
        case let .stickerPack(_, info, _, _, _):
            return .stickerPack(info.id.id)
        case .stickersMode:
            return .stickersMode
        case .savedGifs:
            return .savedGifs
        case .trendingGifs:
            return .trendingGifs
        case let .gifEmotion(_, _, emoji, _):
            return .gifEmotion(emoji)
        }
    }
    
    static func ==(lhs: ChatMediaInputPanelEntry, rhs: ChatMediaInputPanelEntry) -> Bool {
        switch lhs {
            case let .recentGifs(lhsTheme, lhsExpanded):
                if case let .recentGifs(rhsTheme, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .savedStickers(lhsTheme, lhsExpanded):
                if case let .savedStickers(rhsTheme, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .recentPacks(lhsTheme, lhsExpanded):
                if case let .recentPacks(rhsTheme, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .trending(lhsElevated, lhsTheme, lhsExpanded):
                if case let .trending(rhsElevated, rhsTheme, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsElevated == rhsElevated, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .settings(lhsTheme, lhsExpanded):
                if case let .settings(rhsTheme, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .peerSpecific(lhsTheme, lhsPeer, lhsExpanded):
                if case let .peerSpecific(rhsTheme, rhsPeer, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsPeer.isEqual(rhsPeer), lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .stickerPack(index, info, topItem, lhsTheme, lhsExpanded):
                if case let .stickerPack(rhsIndex, rhsInfo, rhsTopItem, rhsTheme, rhsExpanded) = rhs, index == rhsIndex, info == rhsInfo, topItem == rhsTopItem, lhsTheme === rhsTheme, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .stickersMode(lhsTheme, lhsExpanded):
                if case let .stickersMode(rhsTheme, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .savedGifs(lhsTheme, lhsExpanded):
                if case let .savedGifs(rhsTheme, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .trendingGifs(lhsTheme, lhsExpanded):
                if case let .trendingGifs(rhsTheme, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .gifEmotion(lhsIndex, lhsTheme, lhsEmoji, lhsExpanded):
                if case let .gifEmotion(rhsIndex, rhsTheme, rhsEmoji, rhsExpanded) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsEmoji == rhsEmoji, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChatMediaInputPanelEntry, rhs: ChatMediaInputPanelEntry) -> Bool {
        switch lhs {
            case .recentGifs:
                switch rhs {
                    case .recentGifs:
                        return false
                    default:
                        return true
                }
            case .savedStickers:
                switch rhs {
                    case .recentGifs, savedStickers:
                        return false
                    case let .trending(elevated, _, _) where elevated:
                        return false
                    default:
                        return true
                }
            case .recentPacks:
                switch rhs {
                    case .recentGifs, .savedStickers, recentPacks:
                        return false
                    case let .trending(elevated, _, _) where elevated:
                        return false
                    default:
                        return true
                }
            case .peerSpecific:
                switch rhs {
                    case .recentGifs, .savedStickers, recentPacks, .peerSpecific:
                        return false
                    case let .trending(elevated, _, _) where elevated:
                        return false
                    default:
                        return true
                }
            case let .stickerPack(lhsIndex, lhsInfo, _, _, _):
                switch rhs {
                    case .recentGifs, .savedStickers, .recentPacks, .peerSpecific:
                        return false
                    case let .trending(elevated, _, _):
                        if elevated {
                            return false
                        } else {
                            return true
                        }
                    case .settings:
                        return true
                    case let .stickerPack(rhsIndex, rhsInfo, _, _, _):
                        if lhsIndex == rhsIndex {
                            return lhsInfo.id.id < rhsInfo.id.id
                        } else {
                            return lhsIndex <= rhsIndex
                        }
                    default:
                        return true
                }
            case let .trending(elevated, _, _):
                if elevated {
                    switch rhs {
                        case .recentGifs, .trending:
                            return false
                        default:
                            return true
                    }
                } else {
                    if case .settings = rhs {
                        return true
                    } else {
                        return false
                    }
                }
            case .stickersMode:
                return false
            case .savedGifs:
                switch rhs {
                case .savedGifs:
                    return false
                default:
                    return true
                }
            case .trendingGifs:
                switch rhs {
                case .stickersMode, .savedGifs, .trendingGifs:
                    return false
                default:
                    return true
                }
            case let .gifEmotion(lhsIndex, _, _, _):
                switch rhs {
                    case .stickersMode, .savedGifs, .trendingGifs:
                        return false
                    case let .gifEmotion(rhsIndex, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return true
                }
            case .settings:
                if case .settings = rhs {
                    return false
                } else {
                    return true
                }
        }
    }
    
    func item(context: AccountContext, inputNodeInteraction: ChatMediaInputNodeInteraction) -> ListViewItem {
        switch self {
            case let .recentGifs(theme, expanded):
                return ChatMediaInputRecentGifsItem(inputNodeInteraction: inputNodeInteraction, theme: theme, expanded: expanded, selected: {
                    let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue, id: 0)
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .savedStickers(theme, expanded):
                return ChatMediaInputMetaSectionItem(inputNodeInteraction: inputNodeInteraction, type: .savedStickers, theme: theme, expanded: expanded, selected: {
                    let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue, id: 0)
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .recentPacks(theme, expanded):
                return ChatMediaInputMetaSectionItem(inputNodeInteraction: inputNodeInteraction, type: .recentStickers, theme: theme, expanded: expanded, selected: {
                    let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue, id: 0)
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .trending(elevated, theme, expanded):
                return ChatMediaInputTrendingItem(inputNodeInteraction: inputNodeInteraction, elevated: elevated, theme: theme, expanded: expanded, selected: {
                    let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue, id: 0)
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .settings(theme, expanded):
                return ChatMediaInputSettingsItem(inputNodeInteraction: inputNodeInteraction, theme: theme, expanded: expanded, selected: {
                    inputNodeInteraction.openSettings()
                })
            case let .peerSpecific(theme, peer, expanded):
                let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue, id: 0)
                return ChatMediaInputPeerSpecificItem(context: context, inputNodeInteraction: inputNodeInteraction, collectionId: collectionId, peer: peer, theme: theme, expanded: expanded, selected: {
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .stickerPack(index, info, topItem, theme, expanded):
                return ChatMediaInputStickerPackItem(account: context.account, inputNodeInteraction: inputNodeInteraction, collectionId: info.id, collectionInfo: info, stickerPackItem: topItem, index: index, theme: theme, expanded: expanded, selected: {
                    inputNodeInteraction.navigateToCollectionId(info.id)
                })
            case let .stickersMode(theme, expanded):
                return ChatMediaInputMetaSectionItem(inputNodeInteraction: inputNodeInteraction, type: .stickersMode, theme: theme, expanded: expanded, selected: {
                    inputNodeInteraction.navigateBackToStickers()
                })
            case let .savedGifs(theme, expanded):
                return ChatMediaInputMetaSectionItem(inputNodeInteraction: inputNodeInteraction, type: .savedGifs, theme: theme, expanded: expanded, selected: {
                    inputNodeInteraction.setGifMode(.recent)
                })
            case let .trendingGifs(theme, expanded):
                return ChatMediaInputMetaSectionItem(inputNodeInteraction: inputNodeInteraction, type: .trendingGifs, theme: theme, expanded: expanded, selected: {
                    inputNodeInteraction.setGifMode(.trending)
                })
            case let .gifEmotion(_, theme, emoji, expanded):
                return ChatMediaInputMetaSectionItem(inputNodeInteraction: inputNodeInteraction, type: .gifEmoji(emoji), theme: theme, expanded: expanded, selected: {
                    inputNodeInteraction.setGifMode(.emojiSearch(emoji))
                })
        }
    }
}
