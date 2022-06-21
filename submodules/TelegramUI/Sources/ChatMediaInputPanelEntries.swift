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
    case recentGifs(PresentationTheme, PresentationStrings, Bool)
    case savedStickers(PresentationTheme, PresentationStrings, Bool)
    case recentPacks(PresentationTheme, PresentationStrings, Bool)
    case trending(Bool, PresentationTheme, PresentationStrings, Bool)
    case settings(PresentationTheme, PresentationStrings, Bool)
    case peerSpecific(theme: PresentationTheme, peer: Peer, expanded: Bool)
    case stickerPack(index: Int, info: StickerPackCollectionInfo, topItem: StickerPackItem?, theme: PresentationTheme, expanded: Bool, reorderable: Bool)
    
    case stickersMode(PresentationTheme, PresentationStrings, Bool)
    case savedGifs(PresentationTheme, PresentationStrings, Bool)
    case trendingGifs(PresentationTheme, PresentationStrings, Bool)
    case gifEmotion(Int, PresentationTheme, PresentationStrings, String, TelegramMediaFile?, Bool)
    
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
        case let .stickerPack(_, info, _, _, _, _):
            return .stickerPack(info.id.id)
        case .stickersMode:
            return .stickersMode
        case .savedGifs:
            return .savedGifs
        case .trendingGifs:
            return .trendingGifs
        case let .gifEmotion(_, _, _, emoji, _, _):
            return .gifEmotion(emoji)
        }
    }
    
    static func ==(lhs: ChatMediaInputPanelEntry, rhs: ChatMediaInputPanelEntry) -> Bool {
        switch lhs {
            case let .recentGifs(lhsTheme, lhsStrings, lhsExpanded):
                if case let .recentGifs(rhsTheme, rhsStrings, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .savedStickers(lhsTheme, lhsStrings, lhsExpanded):
                if case let .savedStickers(rhsTheme, rhsStrings, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .recentPacks(lhsTheme, lhsStrings, lhsExpanded):
                if case let .recentPacks(rhsTheme, rhsStrings, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .trending(lhsElevated, lhsTheme, lhsStrings, lhsExpanded):
                if case let .trending(rhsElevated, rhsTheme, rhsStrings, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsElevated == rhsElevated, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .settings(lhsTheme, lhsStrings, lhsExpanded):
                if case let .settings(rhsTheme, rhsStrings, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsExpanded == rhsExpanded {
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
            case let .stickerPack(index, info, topItem, lhsTheme, lhsExpanded, lhsReorderable):
                if case let .stickerPack(rhsIndex, rhsInfo, rhsTopItem, rhsTheme, rhsExpanded, rhsReorderable) = rhs, index == rhsIndex, info == rhsInfo, topItem == rhsTopItem, lhsTheme === rhsTheme, lhsExpanded == rhsExpanded, lhsReorderable == rhsReorderable {
                    return true
                } else {
                    return false
                }
            case let .stickersMode(lhsTheme, lhsStrings, lhsExpanded):
                if case let .stickersMode(rhsTheme, rhsStrings, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .savedGifs(lhsTheme, lhsStrings, lhsExpanded):
                if case let .savedGifs(rhsTheme, rhsStrings, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .trendingGifs(lhsTheme, lhsStrings, lhsExpanded):
                if case let .trendingGifs(rhsTheme, rhsStrings, rhsExpanded) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsExpanded == rhsExpanded {
                    return true
                } else {
                    return false
                }
            case let .gifEmotion(lhsIndex, lhsTheme, lhsStrings, lhsEmoji, lhsFile, lhsExpanded):
                if case let .gifEmotion(rhsIndex, rhsTheme, rhsStrings, rhsEmoji, rhsFile, rhsExpanded) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsEmoji == rhsEmoji, lhsExpanded == rhsExpanded {
                    if let lhsFile = lhsFile, let rhsFile = rhsFile {
                        if !lhsFile.isEqual(to: rhsFile) {
                            return false
                        }
                    } else if (lhsFile != nil) != (rhsFile != nil) {
                        return false
                    }
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
                    case let .trending(elevated, _, _, _) where elevated:
                        return false
                    default:
                        return true
                }
            case .recentPacks:
                switch rhs {
                    case .recentGifs, .savedStickers, recentPacks:
                        return false
                    case let .trending(elevated, _, _, _) where elevated:
                        return false
                    default:
                        return true
                }
            case .peerSpecific:
                switch rhs {
                    case .recentGifs, .savedStickers, recentPacks, .peerSpecific:
                        return false
                    case let .trending(elevated, _, _, _) where elevated:
                        return false
                    default:
                        return true
                }
            case let .stickerPack(lhsIndex, lhsInfo, _, _, _, _):
                switch rhs {
                    case .recentGifs, .savedStickers, .recentPacks, .peerSpecific:
                        return false
                    case let .trending(elevated, _, _, _):
                        if elevated {
                            return false
                        } else {
                            return true
                        }
                    case .settings:
                        return true
                    case let .stickerPack(rhsIndex, rhsInfo, _, _, _, _):
                        if lhsIndex == rhsIndex {
                            return lhsInfo.id.id < rhsInfo.id.id
                        } else {
                            return lhsIndex <= rhsIndex
                        }
                    default:
                        return true
                }
            case let .trending(elevated, _, _, _):
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
            case let .gifEmotion(lhsIndex, _, _, _, _, _):
                switch rhs {
                    case .stickersMode, .savedGifs, .trendingGifs:
                        return false
                    case let .gifEmotion(rhsIndex, _, _, _, _, _):
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
            case let .recentGifs(theme, strings, expanded):
                return ChatMediaInputRecentGifsItem(inputNodeInteraction: inputNodeInteraction, theme: theme, strings: strings, expanded: expanded, selected: {
                    let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue, id: 0)
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .savedStickers(theme, strings, expanded):
                return ChatMediaInputMetaSectionItem(account: context.account, inputNodeInteraction: inputNodeInteraction, type: .savedStickers, theme: theme, strings: strings, expanded: expanded, selected: {
                    let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue, id: 0)
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .recentPacks(theme, strings, expanded):
                return ChatMediaInputMetaSectionItem(account: context.account, inputNodeInteraction: inputNodeInteraction, type: .recentStickers, theme: theme, strings: strings, expanded: expanded, selected: {
                    let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue, id: 0)
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .trending(elevated, theme, strings, expanded):
                return ChatMediaInputTrendingItem(inputNodeInteraction: inputNodeInteraction, elevated: elevated, theme: theme, strings: strings, expanded: expanded, selected: {
                    let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue, id: 0)
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .settings(theme, strings, expanded):
                return ChatMediaInputSettingsItem(inputNodeInteraction: inputNodeInteraction, theme: theme, strings: strings, expanded: expanded, selected: {
                    inputNodeInteraction.openSettings()
                })
            case let .peerSpecific(theme, peer, expanded):
                let collectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue, id: 0)
                return ChatMediaInputPeerSpecificItem(context: context, inputNodeInteraction: inputNodeInteraction, collectionId: collectionId, peer: peer, theme: theme, expanded: expanded, selected: {
                    inputNodeInteraction.navigateToCollectionId(collectionId)
                })
            case let .stickerPack(index, info, topItem, theme, expanded, reorderable):
                return ChatMediaInputStickerPackItem(account: context.account, inputNodeInteraction: inputNodeInteraction, collectionId: info.id, collectionInfo: info, stickerPackItem: topItem, index: index, theme: theme, expanded: expanded, reorderable: reorderable, selected: {
                    inputNodeInteraction.navigateToCollectionId(info.id)
                })
            case let .stickersMode(theme, strings, expanded):
                return ChatMediaInputMetaSectionItem(account: context.account, inputNodeInteraction: inputNodeInteraction, type: .stickersMode, theme: theme, strings: strings, expanded: expanded, selected: {
                    inputNodeInteraction.navigateBackToStickers()
                })
            case let .savedGifs(theme, strings, expanded):
                return ChatMediaInputMetaSectionItem(account: context.account, inputNodeInteraction: inputNodeInteraction, type: .savedGifs, theme: theme, strings: strings, expanded: expanded, selected: {
                    inputNodeInteraction.setGifMode(.recent)
                })
            case let .trendingGifs(theme, strings, expanded):
                return ChatMediaInputMetaSectionItem(account: context.account, inputNodeInteraction: inputNodeInteraction, type: .trendingGifs, theme: theme, strings: strings, expanded: expanded, selected: {
                    inputNodeInteraction.setGifMode(.trending)
                })
            case let .gifEmotion(_, theme, strings, emoji, file, expanded):
                return ChatMediaInputMetaSectionItem(account: context.account, inputNodeInteraction: inputNodeInteraction, type: .gifEmoji(emoji, file), theme: theme, strings: strings, expanded: expanded, selected: {
                    inputNodeInteraction.setGifMode(.emojiSearch(emoji))
                })
        }
    }
}
