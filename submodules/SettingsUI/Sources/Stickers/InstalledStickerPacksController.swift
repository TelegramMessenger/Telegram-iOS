import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import TextFormat
import AccountContext
import StickerPackPreviewUI
import ItemListStickerPackItem
import ItemListPeerActionItem
import UndoUI
import ShareController
import WebPBinding
import ReactionImageComponent
import FeaturedStickersScreen
import QuickReactionSetupController

private final class InstalledStickerPacksControllerArguments {
    let context: AccountContext
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let setPackIdWithRevealedOptions: (ItemCollectionId?, ItemCollectionId?) -> Void
    let removePack: (ArchivedStickerPackItem) -> Void
    let openStickersBot: () -> Void
    let openMasks: () -> Void
    let openEmoji: () -> Void
    let openQuickReaction: () -> Void
    let openFeatured: () -> Void
    let openArchived: ([ArchivedStickerPackItem]?) -> Void
    let openSuggestOptions: () -> Void
    let toggleSuggestAnimatedEmoji: (Bool) -> Void
    let togglePackSelected: (ItemCollectionId) -> Void
    let toggleLargeEmoji: (Bool) -> Void
    let toggleDynamicPackOrder: (Bool) -> Void
    let addPack: (StickerPackCollectionInfo) -> Void
    
    init(context: AccountContext, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, setPackIdWithRevealedOptions: @escaping (ItemCollectionId?, ItemCollectionId?) -> Void, removePack: @escaping (ArchivedStickerPackItem) -> Void, openStickersBot: @escaping () -> Void, openMasks: @escaping () -> Void, openEmoji: @escaping () -> Void, openQuickReaction: @escaping () -> Void, openFeatured: @escaping () -> Void, openArchived: @escaping ([ArchivedStickerPackItem]?) -> Void, openSuggestOptions: @escaping () -> Void, toggleSuggestAnimatedEmoji: @escaping (Bool) -> Void, togglePackSelected: @escaping (ItemCollectionId) -> Void, toggleLargeEmoji: @escaping (Bool) -> Void, toggleDynamicPackOrder: @escaping (Bool) -> Void, addPack: @escaping (StickerPackCollectionInfo) -> Void) {
        self.context = context
        self.openStickerPack = openStickerPack
        self.setPackIdWithRevealedOptions = setPackIdWithRevealedOptions
        self.removePack = removePack
        self.openStickersBot = openStickersBot
        self.openMasks = openMasks
        self.openEmoji = openEmoji
        self.openQuickReaction = openQuickReaction
        self.openFeatured = openFeatured
        self.openArchived = openArchived
        self.openSuggestOptions = openSuggestOptions
        self.toggleSuggestAnimatedEmoji = toggleSuggestAnimatedEmoji
        self.togglePackSelected = togglePackSelected
        self.toggleLargeEmoji = toggleLargeEmoji
        self.toggleDynamicPackOrder = toggleDynamicPackOrder
        self.addPack = addPack
    }
}

private enum InstalledStickerPacksSection: Int32 {
    case info
    case categories
    case settings
    case stickers
}

public enum InstalledStickerPacksEntryTag: ItemListItemTag {
    case suggestOptions
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? InstalledStickerPacksEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum InstalledStickerPacksEntryId: Hashable {
    case index(Int32)
    case pack(ItemCollectionId)
}

private indirect enum InstalledStickerPacksEntry: ItemListNodeEntry {
    case info(PresentationTheme, String)
    case suggestOptions(PresentationTheme, String, String)
    case largeEmoji(PresentationTheme, String, Bool)
    case trending(PresentationTheme, String, Int32)
    case archived(PresentationTheme, String, Int32, [ArchivedStickerPackItem]?)
    case masks(PresentationTheme, String)
    case emoji(PresentationTheme, String, Int32)
    case quickReaction(String, MessageReaction.Reaction, AvailableReactions)
    case packOrder(PresentationTheme, String, Bool)
    case packOrderInfo(PresentationTheme, String)
    case suggestAnimatedEmoji(String, Bool)
    case suggestAnimatedEmojiInfo(PresentationTheme, String)
    case packsTitle(PresentationTheme, String)
    case pack(Int32, PresentationTheme, PresentationStrings, StickerPackCollectionInfo, StickerPackItem?, String, Bool, Bool, ItemListStickerPackItemEditing, Bool?)
    case packsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return InstalledStickerPacksSection.info.rawValue
            case .trending, .masks, .emoji, .quickReaction, .archived:
                return InstalledStickerPacksSection.categories.rawValue
            case .suggestOptions, .largeEmoji, .suggestAnimatedEmoji, .suggestAnimatedEmojiInfo, .packOrder, .packOrderInfo:
                return InstalledStickerPacksSection.settings.rawValue
            case .packsTitle, .pack, .packsInfo:
                return InstalledStickerPacksSection.stickers.rawValue
        }
    }
    
    var stableId: InstalledStickerPacksEntryId {
        switch self {
            case .info:
                return .index(-1)
            case .trending:
                return .index(0)
            case .archived:
                return .index(1)
            case .emoji:
                return .index(2)
            case .masks:
                return .index(3)
            case .quickReaction:
                return .index(4)
            case .suggestOptions:
                return .index(5)
            case .largeEmoji:
                return .index(6)
            case .suggestAnimatedEmoji:
                return .index(7)
            case .suggestAnimatedEmojiInfo:
                return .index(8)
            case .packOrder:
                return .index(9)
            case .packOrderInfo:
                return .index(10)
            case .packsTitle:
                return .index(11)
            case let .pack(_, _, _, info, _, _, _, _, _, _):
                return .pack(info.id)
            case .packsInfo:
                return .index(12)
        }
    }
    
    static func ==(lhs: InstalledStickerPacksEntry, rhs: InstalledStickerPacksEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsText):
                if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .suggestOptions(lhsTheme, lhsText, lhsValue):
                if case let .suggestOptions(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .largeEmoji(lhsTheme, lhsText, lhsValue):
                if case let .largeEmoji(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .trending(lhsTheme, lhsText, lhsCount):
                if case let .trending(rhsTheme, rhsText, rhsCount) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .masks(lhsTheme, lhsCount):
                if case let .masks(rhsTheme, rhsCount) = rhs, lhsTheme === rhsTheme, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .emoji(lhsTheme, lhsText, lhsCount):
                if case let .emoji(rhsTheme, rhsText, rhsCount) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .quickReaction(lhsText, lhsReaction, lhsAvailableReactions):
                if case let .quickReaction(rhsText, rhsReaction, rhsAvailableReactions) = rhs, lhsText == rhsText, lhsReaction == rhsReaction, lhsAvailableReactions == rhsAvailableReactions {
                    return true
                } else {
                    return false
                }
            case let .archived(lhsTheme, lhsText, lhsCount, _):
                if case let .archived(rhsTheme, rhsText, rhsCount, _) = rhs, lhsTheme === rhsTheme, lhsCount == rhsCount, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .packOrder(lhsTheme, lhsText, lhsValue):
                if case let .packOrder(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .packOrderInfo(lhsTheme, lhsText):
                if case let .packOrderInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .suggestAnimatedEmoji(lhsText, lhsValue):
                if case let .suggestAnimatedEmoji(rhsText, rhsValue) = rhs, lhsValue == rhsValue, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .suggestAnimatedEmojiInfo(lhsTheme, lhsText):
                if case let .suggestAnimatedEmojiInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .packsTitle(lhsTheme, lhsText):
                if case let .packsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .pack(lhsIndex, lhsTheme, lhsStrings, lhsInfo, lhsTopItem, lhsCount, lhsAnimatedStickers, lhsEnabled, lhsEditing, lhsSelected):
                if case let .pack(rhsIndex, rhsTheme, rhsStrings, rhsInfo, rhsTopItem, rhsCount, rhsAnimatedStickers, rhsEnabled, rhsEditing, rhsSelected) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsInfo != rhsInfo {
                        return false
                    }
                    if lhsTopItem != rhsTopItem {
                        return false
                    }
                    if lhsCount != rhsCount {
                        return false
                    }
                    if lhsAnimatedStickers != rhsAnimatedStickers {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsSelected != rhsSelected {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .packsInfo(lhsTheme, lhsText):
                if case let .packsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: InstalledStickerPacksEntry, rhs: InstalledStickerPacksEntry) -> Bool {
        switch lhs {
        case .info:
            switch rhs {
            case .info:
                return false
            default:
                return true
            }
        case .trending:
            switch rhs {
            case .info, .trending:
                return false
            default:
                return true
            }
        case .archived:
            switch rhs {
            case .info, .trending, .archived:
                return false
            default:
                return true
            }
        case .masks:
            switch rhs {
            case .info, .trending, .archived, .masks:
                return false
            default:
                return true
            }
        case .emoji:
            switch rhs {
            case .info, .trending, .archived, .masks, .emoji:
                return false
            default:
                return true
            }
        case .quickReaction:
            switch rhs {
            case .info, .trending, .archived, .masks, .emoji, .quickReaction:
                return false
            default:
                return true
            }
        case .suggestOptions:
            switch rhs {
            case .info, .trending, .archived, .masks, .emoji, .quickReaction, .suggestOptions:
                return false
            default:
                return true
            }
        case .largeEmoji:
            switch rhs {
            case .info, .trending, .archived, .masks, .emoji, .quickReaction, .suggestOptions, .largeEmoji:
                return false
            default:
                return true
            }
        case .packOrder:
            switch rhs {
            case .info, .trending, .archived, .masks, .emoji, .quickReaction, .suggestOptions, .largeEmoji, .packOrder:
                return false
            default:
                return true
            }
        case .packOrderInfo:
            switch rhs {
            case .info, .trending, .archived, .masks, .emoji, .quickReaction, .suggestOptions, .largeEmoji, .packOrder, .packOrderInfo:
                return false
            default:
                return true
            }
        case .suggestAnimatedEmoji:
            switch rhs {
            case .info, .trending, .archived, .masks, .emoji, .quickReaction, .suggestOptions, .largeEmoji, .packOrder, .packOrderInfo, .suggestAnimatedEmoji:
                return false
            default:
                return true
            }
        case .suggestAnimatedEmojiInfo:
            switch rhs {
            case .info, .trending, .archived, .masks, .emoji, .quickReaction, .suggestOptions, .largeEmoji, .packOrder, .packOrderInfo, .suggestAnimatedEmoji, .suggestAnimatedEmojiInfo:
                return false
            default:
                return true
            }
        case .packsTitle:
            switch rhs {
            case .info, .trending, .archived, .masks, .emoji, .quickReaction, .suggestOptions, .largeEmoji, .packOrder, .packOrderInfo, .suggestAnimatedEmoji, .suggestAnimatedEmojiInfo, .packsTitle:
                return false
            default:
                return true
            }
        case let .pack(lhsIndex, _, _, _, _, _, _, _, _, _):
            switch rhs {
            case let .pack(rhsIndex, _, _, _, _, _, _, _, _, _):
                return lhsIndex < rhsIndex
            case .packsInfo:
                return true
            default:
                return false
            }
        case .packsInfo:
            switch rhs {
            case .packsInfo:
                return false
            default:
                return false
            }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! InstalledStickerPacksControllerArguments
        switch self {
            case let .info(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .suggestOptions(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openSuggestOptions()
                }, tag: InstalledStickerPacksEntryTag.suggestOptions)
            case let .largeEmoji(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleLargeEmoji(value)
                })
            case let .trending(theme, text, count):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Trending")?.precomposed(), title: text, label: count == 0 ? "" : "\(count)", labelStyle: .badge(theme.list.itemAccentColor), sectionId: self.section, style: .blocks, action: {
                    arguments.openFeatured()
                })
            case let .masks(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openMasks()
                })
            case let .emoji(_, text, count):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Emoji")?.precomposed(), title: text, label: count == 0 ? "" : "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.openEmoji()
                })
            case let .quickReaction(title, reaction, availableReactions):
                return ItemListReactionItem(context: arguments.context, presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Reactions")?.precomposed(), title: title, arrowStyle: .arrow, reaction: reaction, availableReactions: availableReactions, sectionId: self.section, style: .blocks, action: {
                    arguments.openQuickReaction()
                })
            case let .archived(_, text, count, archived):
                return ItemListDisclosureItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Archived")?.precomposed(), title: text, label: count == 0 ? "" : "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.openArchived(archived)
                })
            case let .packOrder(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleDynamicPackOrder(value)
                })
            case let .packOrderInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .suggestAnimatedEmoji(text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleSuggestAnimatedEmoji(value)
                })
            case let .suggestAnimatedEmojiInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .packsTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .pack(_, _, _, info, topItem, count, animatedStickers, enabled, editing, selected):
                return ItemListStickerPackItem(presentationData: presentationData, context: arguments.context, packInfo: StickerPackCollectionInfo.Accessor(info), itemCount: count, topItem: topItem, unread: false, control: editing.editing ? .check(checked: selected ?? false) : .none, editing: editing, enabled: enabled, playAnimatedStickers: animatedStickers, sectionId: self.section, action: {
                    arguments.openStickerPack(info)
                }, setPackIdWithRevealedOptions: { current, previous in
                    arguments.setPackIdWithRevealedOptions(current, previous)
                }, addPack: {
                }, removePack: {
                    arguments.removePack(ArchivedStickerPackItem(info: info, topItems: topItem != nil ? [topItem!] : []))
                }, toggleSelected: {
                    arguments.togglePackSelected(info.id)
                })
            case let .packsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { _ in
                    arguments.openStickersBot()
                })
        }
    }
}

private struct InstalledStickerPacksControllerState: Equatable {
    let editing: Bool
    let selectedPackIds: Set<ItemCollectionId>?
    let packIdWithRevealedOptions: ItemCollectionId?
    let trendingPacksExpanded: Bool
    
    init() {
        self.editing = false
        self.selectedPackIds = nil
        self.packIdWithRevealedOptions = nil
        self.trendingPacksExpanded = false
    }
    
    init(editing: Bool, selectedPackIds: Set<ItemCollectionId>?, packIdWithRevealedOptions: ItemCollectionId?, trendingPacksExpanded: Bool) {
        self.editing = editing
        self.selectedPackIds = selectedPackIds
        self.packIdWithRevealedOptions = packIdWithRevealedOptions
        self.trendingPacksExpanded = trendingPacksExpanded
    }
    
    static func ==(lhs: InstalledStickerPacksControllerState, rhs: InstalledStickerPacksControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.selectedPackIds != rhs.selectedPackIds {
            return false
        }
        if lhs.packIdWithRevealedOptions != rhs.packIdWithRevealedOptions {
            return false
        }
        if lhs.trendingPacksExpanded != rhs.trendingPacksExpanded {
            return false
        }
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> InstalledStickerPacksControllerState {
        return InstalledStickerPacksControllerState(editing: editing, selectedPackIds: self.selectedPackIds, packIdWithRevealedOptions: self.packIdWithRevealedOptions, trendingPacksExpanded: self.trendingPacksExpanded)
    }
    
    func withUpdatedSelectedPackIds(_ selectedPackIds: Set<ItemCollectionId>?) -> InstalledStickerPacksControllerState {
        return InstalledStickerPacksControllerState(editing: editing, selectedPackIds: selectedPackIds, packIdWithRevealedOptions: self.packIdWithRevealedOptions, trendingPacksExpanded: self.trendingPacksExpanded)
    }
    
    func withUpdatedPackIdWithRevealedOptions(_ packIdWithRevealedOptions: ItemCollectionId?) -> InstalledStickerPacksControllerState {
        return InstalledStickerPacksControllerState(editing: self.editing, selectedPackIds: self.selectedPackIds, packIdWithRevealedOptions: packIdWithRevealedOptions, trendingPacksExpanded: self.trendingPacksExpanded)
    }
    
    func withUpdatedTrendingPacksExpanded(_ trendingPacksExpanded: Bool) -> InstalledStickerPacksControllerState {
        return InstalledStickerPacksControllerState(editing: self.editing, selectedPackIds: self.selectedPackIds, packIdWithRevealedOptions: self.packIdWithRevealedOptions, trendingPacksExpanded: trendingPacksExpanded)
    }
}

private func namespaceForMode(_ mode: InstalledStickerPacksControllerMode) -> ItemCollectionId.Namespace {
    switch mode {
        case .general, .modal:
            return Namespaces.ItemCollection.CloudStickerPacks
        case .masks:
            return Namespaces.ItemCollection.CloudMaskPacks
        case .emoji:
            return Namespaces.ItemCollection.CloudEmojiPacks
    }
}

private let maxTrendingPacksDisplayedLimit: Int32 = 3

private func installedStickerPacksControllerEntries(context: AccountContext, presentationData: PresentationData, state: InstalledStickerPacksControllerState, mode: InstalledStickerPacksControllerMode, view: CombinedView, temporaryPackOrder: [ItemCollectionId]?, featured: [FeaturedStickerPackItem], archived: [ArchivedStickerPackItem]?, stickerSettings: StickerSettings, quickReaction: MessageReaction.Reaction?, availableReactions: AvailableReactions?, emojiCount: Int32) -> [InstalledStickerPacksEntry] {
    var entries: [InstalledStickerPacksEntry] = []
    
    var installedPacks = Set<ItemCollectionId>()
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] {
            var sortedPacks: [ItemCollectionInfoEntry] = []
            for entry in packsEntries {
                if let _ = entry.info as? StickerPackCollectionInfo {
                    installedPacks.insert(entry.id)
                    sortedPacks.append(entry)
                }
            }
        }
    }
    
    switch mode {
    case .general, .modal:
        if !featured.isEmpty {
            entries.append(.trending(presentationData.theme, presentationData.strings.StickerPacksSettings_TrendingStickers, Int32(featured.count)))
        }
        if let archived = archived, !archived.isEmpty  {
            entries.append(.archived(presentationData.theme, presentationData.strings.StickerPacksSettings_ArchivedPacks, Int32(archived.count), archived))
        }
        if emojiCount != 0 {
            entries.append(.emoji(presentationData.theme, presentationData.strings.StickerPacksSettings_Emoji, emojiCount))
        }
        if let quickReaction = quickReaction, let availableReactions = availableReactions {
            entries.append(.quickReaction(presentationData.strings.Settings_QuickReactionSetup_NavigationTitle, quickReaction, availableReactions))
        }
        
        let suggestString: String
        switch stickerSettings.emojiStickerSuggestionMode {
            case .none:
                suggestString = presentationData.strings.Stickers_SuggestNone
            case .all:
                suggestString = presentationData.strings.Stickers_SuggestAll
            case .installed:
                suggestString = presentationData.strings.Stickers_SuggestAdded
        }
        entries.append(.suggestOptions(presentationData.theme, presentationData.strings.Stickers_SuggestStickers, suggestString))
        entries.append(.largeEmoji(presentationData.theme, presentationData.strings.Appearance_LargeEmoji, presentationData.largeEmoji))
        entries.append(.packOrder(presentationData.theme, presentationData.strings.StickerPacksSettings_DynamicOrder, stickerSettings.dynamicPackOrder))
        entries.append(.packOrderInfo(presentationData.theme, presentationData.strings.StickerPacksSettings_DynamicOrderInfo))
        
        entries.append(.packsTitle(presentationData.theme, presentationData.strings.StickerPacksSettings_MyStickers.uppercased()))
    case .masks:
        if let archived = archived, !archived.isEmpty {
            entries.append(.archived(presentationData.theme, presentationData.strings.StickerPacksSettings_ArchivedMasks, Int32(archived.count), archived))
        }
    case .emoji:
        if let archived = archived, !archived.isEmpty {
            entries.append(.archived(presentationData.theme, presentationData.strings.StickersList_ArchivedEmojiItem, Int32(archived.count), archived))
        }
        
        entries.append(.suggestAnimatedEmoji(presentationData.strings.StickerPacksSettings_SuggestAnimatedEmoji, stickerSettings.suggestAnimatedEmoji))
        entries.append(.suggestAnimatedEmojiInfo(presentationData.theme, presentationData.strings.StickerPacksSettings_SuggestAnimatedEmojiInfo))
    }
    
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] {
            var sortedPacks: [ItemCollectionInfoEntry] = []
            for entry in packsEntries {
                if let _ = entry.info as? StickerPackCollectionInfo {
                    sortedPacks.append(entry)
                }
            }
            if let temporaryPackOrder = temporaryPackOrder {
                var packDict: [ItemCollectionId: Int] = [:]
                for i in 0 ..< sortedPacks.count {
                    packDict[sortedPacks[i].id] = i
                }
                var tempSortedPacks: [ItemCollectionInfoEntry] = []
                var processedPacks = Set<ItemCollectionId>()
                for id in temporaryPackOrder {
                    if let index = packDict[id] {
                        tempSortedPacks.append(sortedPacks[index])
                        processedPacks.insert(id)
                    }
                }
                let restPacks = sortedPacks.filter { !processedPacks.contains($0.id) }
                sortedPacks = restPacks + tempSortedPacks
            }
            var index: Int32 = 0
            for entry in sortedPacks {
                if let info = entry.info as? StickerPackCollectionInfo {
                    let countTitle: String
                    if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                        countTitle = presentationData.strings.StickerPack_EmojiCount(info.count == 0 ? entry.count : info.count)
                    } else if info.id.namespace == Namespaces.ItemCollection.CloudMaskPacks {
                        countTitle = presentationData.strings.StickerPack_MaskCount(info.count == 0 ? entry.count : info.count)
                    } else {
                        countTitle = presentationData.strings.StickerPack_StickerCount(info.count == 0 ? entry.count : info.count)
                    }
                    
                    entries.append(.pack(index, presentationData.theme, presentationData.strings, info, entry.firstItem as? StickerPackItem, countTitle, context.sharedContext.energyUsageSettings.loopStickers, true, ItemListStickerPackItemEditing(editable: true, editing: state.editing, revealed: state.packIdWithRevealedOptions == entry.id, reorderable: true, selectable: true), state.selectedPackIds?.contains(info.id)))
                    index += 1
                }
            }
        }
    }
    
    var markdownString: String
    switch mode {
    case .general, .modal:
        markdownString = presentationData.strings.StickerPacksSettings_ManagingHelp
    case .masks:
        markdownString = presentationData.strings.MaskStickerSettings_Info
    case .emoji:
        markdownString = presentationData.strings.EmojiStickerSettings_Info
    }
    let entities = generateTextEntities(markdownString, enabledTypes: [.mention])
    if let entity = entities.first {
        markdownString.insert(contentsOf: "]()", at: markdownString.index(markdownString.startIndex, offsetBy: entity.range.upperBound))
        markdownString.insert(contentsOf: "[", at: markdownString.index(markdownString.startIndex, offsetBy: entity.range.lowerBound))
    }
    entries.append(.packsInfo(presentationData.theme, markdownString))
    
    return entries
}

public func installedStickerPacksController(context: AccountContext, mode: InstalledStickerPacksControllerMode, archivedPacks: [ArchivedStickerPackItem]? = nil, updatedPacks: @escaping ([ArchivedStickerPackItem]?) -> Void = { _ in }, focusOnItemTag: InstalledStickerPacksEntryTag? = nil, forceTheme: PresentationTheme? = nil) -> ViewController {
    var initialEditing = false
    if case .modal = mode {
        initialEditing = true
    }
    
    let initialState = InstalledStickerPacksControllerState().withUpdatedEditing(initialEditing).withUpdatedSelectedPackIds(initialEditing ? Set() : nil)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InstalledStickerPacksControllerState) -> InstalledStickerPacksControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentationData = context.sharedContext.currentPresentationData.with { $0 }
    if let forceTheme {
        presentationData = presentationData.withUpdated(theme: forceTheme)
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var navigateToChatControllerImpl: ((PeerId) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let resolveDisposable = MetaDisposable()
    actionsDisposable.add(resolveDisposable)
    
    let archivedPromise = Promise<[ArchivedStickerPackItem]?>()

    var presentStickerPackController: ((StickerPackCollectionInfo) -> Void)?
    var navigationControllerImpl: (() -> NavigationController?)?
    
    let arguments = InstalledStickerPacksControllerArguments(context: context, openStickerPack: { info in
        presentStickerPackController?(info)
    }, setPackIdWithRevealedOptions: { packId, fromPackId in
        updateState { state in
            if (packId == nil && fromPackId == state.packIdWithRevealedOptions) || (packId != nil && fromPackId == nil) {
                return state.withUpdatedPackIdWithRevealedOptions(packId)
            } else {
                return state
            }
        }
    }, removePack: { archivedItem in
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let removeAction: (RemoveStickerPackOption) -> Void = { action in
            let _ = (context.engine.stickers.removeStickerPackInteractively(id: archivedItem.info.id, option: action)
            |> deliverOnMainQueue).start(next: { indexAndItems in
                guard let (positionInList, items) = indexAndItems else {
                    return
                }
                
                var animateInAsReplacement = false
                if let navigationController = navigationControllerImpl?() {
                    for controller in navigationController.overlayControllers {
                        if let controller = controller as? UndoOverlayController {
                            controller.dismissWithCommitActionAndReplacementAnimation()
                            animateInAsReplacement = true
                        }
                    }
                }
                
                let removedTitle: String
                let removedText: String
                if archivedItem.info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                    removedTitle = action == .archive ? presentationData.strings.EmojiPackActionInfo_ArchivedTitle : presentationData.strings.EmojiPackActionInfo_RemovedTitle
                    removedText = presentationData.strings.EmojiPackActionInfo_RemovedText(archivedItem.info.title).string
                } else if archivedItem.info.id.namespace == Namespaces.ItemCollection.CloudMaskPacks {
                    removedTitle = action == .archive ? presentationData.strings.MaskPackActionInfo_ArchivedTitle : presentationData.strings.MaskPackActionInfo_RemovedTitle
                    removedText = presentationData.strings.MaskPackActionInfo_RemovedText(archivedItem.info.title).string
                } else {
                    removedTitle = action == .archive ? presentationData.strings.StickerPackActionInfo_ArchivedTitle : presentationData.strings.StickerPackActionInfo_RemovedTitle
                    removedText = presentationData.strings.StickerPackActionInfo_RemovedText(archivedItem.info.title).string
                }
                
                navigationControllerImpl?()?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: removedTitle, text: removedText, undo: true, info: archivedItem.info, topItem: archivedItem.topItems.first, context: context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { action in
                    if case .undo = action {
                        let _ = context.engine.stickers.addStickerPackInteractively(info: archivedItem.info, items: items.compactMap({ $0 as? StickerPackItem }), positionInList: positionInList).start()
                    }
                    return true
                }))
            })
        }
        
        let title: String
        if archivedItem.info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
            title = presentationData.strings.StickerSettings_EmojiContextInfo
        } else if archivedItem.info.id.namespace == Namespaces.ItemCollection.CloudMaskPacks {
            title = presentationData.strings.StickerSettings_MaskContextInfo
        } else {
            title = presentationData.strings.StickerSettings_ContextInfo
        }
        
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: title),
                ActionSheetButtonItem(title: presentationData.strings.StickerSettings_ContextHide, color: .accent, action: {
                    dismissAction()
                    
                    let archivedSignal = archivedPromise.get() |> take(1) |> map { packs -> [ArchivedStickerPackItem]? in
                        return (packs ?? []) + [archivedItem]
                    }
                    _ = archivedSignal.start(next: { packs in
                        archivedPromise.set(.single(packs))
                        updatedPacks(packs)
                    })
                    
                    removeAction(.archive)
                }),
                ActionSheetButtonItem(title: presentationData.strings.Common_Delete, color: .destructive, action: {
                    dismissAction()
                    removeAction(.delete)
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openStickersBot: {
        resolveDisposable.set((context.engine.peers.resolvePeerByName(name: "stickers", referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(result) = result else {
                return .complete()
            }
            return .single(result)
        }
        |> deliverOnMainQueue).start(next: { peer in
            if let peer = peer {
                navigateToChatControllerImpl?(peer.id)
            }
        }))
    }, openMasks: {
        pushControllerImpl?(installedStickerPacksController(context: context, mode: .masks, archivedPacks: archivedPacks, updatedPacks: { _ in }, forceTheme: forceTheme))
    }, openEmoji: {
        pushControllerImpl?(installedStickerPacksController(context: context, mode: .emoji, archivedPacks: archivedPacks, updatedPacks: { _ in }, forceTheme: forceTheme))
    }, openQuickReaction: {
        pushControllerImpl?(quickReactionSetupController(
            context: context
        ))
    }, openFeatured: {
        pushControllerImpl?(FeaturedStickersScreen(context: context, highlightedPackId: nil, forceTheme: forceTheme))
    }, openArchived: { archived in
        let archivedMode: ArchivedStickerPacksControllerMode
        switch mode {
            case .masks:
                archivedMode = .masks
            case .emoji:
                archivedMode = .emoji
            default:
                archivedMode = .stickers
        }
        pushControllerImpl?(archivedStickerPacksController(context: context, mode: archivedMode, archived: archived, forceTheme: forceTheme, updatedPacks: { packs in
            archivedPromise.set(.single(packs))
            updatedPacks(packs)
        }))
    }, openSuggestOptions: {
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let options: [(EmojiStickerSuggestionMode, String)] = [
            (.all, presentationData.strings.Stickers_SuggestAll),
            (.installed, presentationData.strings.Stickers_SuggestAdded),
            (.none, presentationData.strings.Stickers_SuggestNone)
        ]
        var items: [ActionSheetItem] = []
        items.append(ActionSheetTextItem(title: presentationData.strings.Stickers_SuggestStickers))
        for (option, title) in options {
            items.append(ActionSheetButtonItem(title: title, color: .accent, action: {
                dismissAction()
                let _ = updateStickerSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                    return current.withUpdatedEmojiStickerSuggestionMode(option)
                }).start()
            }))
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, toggleSuggestAnimatedEmoji: { value in
        let _ = updateStickerSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedSuggestAnimatedEmoji(value)
        }).start()
    }, togglePackSelected: { packId in
        updateState { state in
            if var selectedPackIds = state.selectedPackIds {
                if selectedPackIds.contains(packId) {
                    selectedPackIds.remove(packId)
                } else {
                    selectedPackIds.insert(packId)
                }
                return state.withUpdatedSelectedPackIds(selectedPackIds)
            } else {
                return state
            }
        }
    }, toggleLargeEmoji: { value in
        let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedLargeEmoji(value)
        }).start()
    }, toggleDynamicPackOrder: { value in
        let _ = updateStickerSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedDynamicPackOrder(value)
        }).start()
    }, addPack: { info in
        let _ = (context.engine.stickers.loadedStickerPack(reference: .id(id: info.id.id, accessHash: info.accessHash), forceActualized: false)
        |> mapToSignal { result -> Signal<Void, NoError> in
            switch result {
                case let .result(info, items, installed):
                    if installed {
                        return .complete()
                    } else {
                        return context.engine.stickers.addStickerPackInteractively(info: info._parse(), items: items)
                    }
                case .fetching:
                    break
                case .none:
                    break
            }
            return .complete()
        } |> deliverOnMainQueue).start()
    })
    let stickerPacks = Promise<CombinedView>()
    stickerPacks.set(context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [namespaceForMode(mode)])]))
    let temporaryPackOrder = Promise<[ItemCollectionId]?>(nil)
    
    let featured = Promise<[FeaturedStickerPackItem]>()
    let quickReaction: Signal<MessageReaction.Reaction?, NoError>
    let emojiCount = Promise<Int32>()
    
    switch mode {
        case .general, .modal:
            featured.set(context.account.viewTracker.featuredStickerPacks())
            archivedPromise.set(.single(archivedPacks) |> then(context.engine.stickers.archivedStickerPacks() |> map(Optional.init)))
            quickReaction = combineLatest(
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
                context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
            )
            |> map { peer, preferencesView -> MessageReaction.Reaction? in
                let reactionSettings: ReactionSettings
                if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
                    reactionSettings = value
                } else {
                    reactionSettings = .default
                }
                var hasPremium = false
                if case let .user(user) = peer {
                    hasPremium = user.isPremium
                }
                return reactionSettings.effectiveQuickReaction(hasPremium: hasPremium)
            }
            |> distinctUntilChanged
            emojiCount.set(context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudEmojiPacks])])
            |> map { view in
                if let info = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudEmojiPacks])] as? ItemCollectionInfosView, let entries = info.entriesByNamespace[Namespaces.ItemCollection.CloudEmojiPacks] {
                    return Int32(entries.count)
                } else {
                    return 0
                }
            })        
        case .masks:
            featured.set(.single([]))
            archivedPromise.set(.single(nil) |> then(context.engine.stickers.archivedStickerPacks(namespace: .masks) |> map(Optional.init)))
            quickReaction = .single(nil)
            emojiCount.set(.single(0))
        case .emoji:
            featured.set(.single([]))
            archivedPromise.set(.single(nil) |> then(context.engine.stickers.archivedStickerPacks(namespace: .emoji) |> map(Optional.init)))
            quickReaction = .single(nil)
            emojiCount.set(.single(0))
    }

    var previousPackCount: Int?
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData,
        statePromise.get(),
        stickerPacks.get(),
        temporaryPackOrder.get(),
        combineLatest(queue: .mainQueue(), featured.get(), archivedPromise.get()),
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings]),
        quickReaction,
        context.engine.stickers.availableReactions(),
        emojiCount.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, view, temporaryPackOrder, featuredAndArchived, sharedData, quickReaction, availableReactions, emojiCount -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        if let forceTheme {
            presentationData = presentationData.withUpdated(theme: forceTheme)
        }
        
        var stickerSettings = StickerSettings.defaultSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
           stickerSettings = value
        }
        
        var packCount: Int? = nil
        var stickerPacks: [ItemCollectionInfoEntry] = []
        if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView, let entries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] {
            packCount = entries.count
            stickerPacks = entries
        }
        
        let leftNavigationButton: ItemListNavigationButton? = nil
        var rightNavigationButton: ItemListNavigationButton?
        var toolbarItem: ItemListToolbarItem?
        if let packCount = packCount, packCount != 0 {
            if state.editing {
                if case .modal = mode {
                    rightNavigationButton = nil
                } else {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                        updateState {
                            $0.withUpdatedEditing(false).withUpdatedSelectedPackIds(nil)
                        }
                        if case .modal = mode {
                            dismissImpl?()
                        }
                    })
                }
                
                let selectedCount = Int32(state.selectedPackIds?.count ?? 0)
                toolbarItem = StickersToolbarItem(selectedCount: selectedCount, actions: [.init(title: presentationData.strings.StickerPacks_ActionDelete, isEnabled: selectedCount > 0, action: {
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    var items: [ActionSheetItem] = []
                    
                    let title: String
                    switch mode {
                    case .emoji:
                        title = presentationData.strings.StickerPacks_DeleteEmojiPacksConfirmation(selectedCount)
                    default:
                        title = presentationData.strings.StickerPacks_DeleteStickerPacksConfirmation(selectedCount)
                    }
                    
                    items.append(ActionSheetButtonItem(title: title, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                       
                        if case .modal = mode {
                            updateState {
                                $0.withUpdatedEditing(true).withUpdatedSelectedPackIds(nil)
                            }
                        } else {
                            updateState {
                                $0.withUpdatedEditing(false).withUpdatedSelectedPackIds(nil)
                            }
                        }
                        
                        var packIds: [ItemCollectionId] = []
                        for entry in stickerPacks {
                            if let selectedPackIds = state.selectedPackIds, selectedPackIds.contains(entry.id) {
                                packIds.append(entry.id)
                            }
                        }
                                                    
                        let _ = context.engine.stickers.removeStickerPacksInteractively(ids: packIds, option: .delete).start()
                    }))
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    presentControllerImpl?(actionSheet, nil)
                }), .init(title: presentationData.strings.StickerPacks_ActionArchive, isEnabled: selectedCount > 0, action: {
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    var items: [ActionSheetItem] = []
                    items.append(ActionSheetButtonItem(title: presentationData.strings.StickerPacks_ArchiveStickerPacksConfirmation(selectedCount), color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                       
                        if case .modal = mode {
                            updateState {
                                $0.withUpdatedEditing(true).withUpdatedSelectedPackIds(nil)
                            }
                        } else {
                            updateState {
                                $0.withUpdatedEditing(false).withUpdatedSelectedPackIds(nil)
                            }
                        }
                        
                        var packIds: [ItemCollectionId] = []
                        for entry in stickerPacks {
                            if let selectedPackIds = state.selectedPackIds, selectedPackIds.contains(entry.id) {
                                packIds.append(entry.id)
                            }
                        }
                                                    
                        let _ = context.engine.stickers.removeStickerPacksInteractively(ids: packIds, option: .archive).start()
                    }))
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    presentControllerImpl?(actionSheet, nil)
                }), .init(title: presentationData.strings.StickerPacks_ActionShare, isEnabled: selectedCount > 0, action: {
                    if case .modal = mode {
                        updateState {
                            $0.withUpdatedEditing(true).withUpdatedSelectedPackIds(nil)
                        }
                    } else {
                        updateState {
                            $0.withUpdatedEditing(false).withUpdatedSelectedPackIds(nil)
                        }
                    }
                    
                    var packNames: [String] = []
                    for entry in stickerPacks {
                        if let selectedPackIds = state.selectedPackIds, selectedPackIds.contains(entry.id) {
                            if let info = entry.info as? StickerPackCollectionInfo {
                                packNames.append(info.shortName)
                            }
                        }
                    }
                    let text = packNames.map { "https://t.me/addstickers/\($0)" }.joined(separator: "\n")
                    let shareController = ShareController(context: context, subject: .text(text), externalShare: true)
                    presentControllerImpl?(shareController, nil)
                })])
            } else {
                if case .modal = mode {
                    rightNavigationButton = nil
                } else {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                        updateState {
                            $0.withUpdatedEditing(true).withUpdatedSelectedPackIds(Set())
                        }
                    })
                }
            }
        }
        
        let previous = previousPackCount
        previousPackCount = packCount
        
        let title: String
        switch mode {
            case .general, .modal:
                title = presentationData.strings.StickerPacksSettings_Title
            case .masks:
                title = presentationData.strings.MaskStickerSettings_Title
            case .emoji:
                title = presentationData.strings.EmojiPacksSettings_Title
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: installedStickerPacksControllerEntries(context: context, presentationData: presentationData, state: state, mode: mode, view: view, temporaryPackOrder: temporaryPackOrder, featured: featuredAndArchived.0, archived: featuredAndArchived.1, stickerSettings: stickerSettings, quickReaction: quickReaction, availableReactions: availableReactions, emojiCount: emojiCount), style: .blocks, ensureVisibleItemTag: focusOnItemTag, toolbarItem: toolbarItem, animateChanges: previous != nil && packCount != nil && (previous! != 0 && previous! >= packCount! - 10))
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    if case .modal = mode {
        controller.navigationPresentation = .modal
    }
        
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [InstalledStickerPacksEntry]) -> Signal<Bool, NoError> in
        let fromEntry = entries[fromIndex]
        guard case let .pack(_, _, _, fromPackInfo, _, _, _, _, _, _) = fromEntry else {
            return .single(false)
        }
        var referenceId: ItemCollectionId?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .pack(_, _, _, toPackInfo, _, _, _, _, _, _):
                    referenceId = toPackInfo.id
                default:
                    if entries[toIndex] < fromEntry {
                        beforeAll = true
                    } else {
                        afterAll = true
                    }
            }
        } else {
            afterAll = true
        }
        
        var currentIds: [ItemCollectionId] = []
        for entry in entries {
            switch entry {
            case let .pack(_, _, _, info, _, _, _, _, _, _):
                currentIds.append(info.id)
            default:
                break
            }
        }
        
        var previousIndex: Int?
        for i in 0 ..< currentIds.count {
            if currentIds[i] == fromPackInfo.id {
                previousIndex = i
                currentIds.remove(at: i)
                break
            }
        }
        
        var didReorder = false
        
        if let referenceId = referenceId {
            var inserted = false
            for i in 0 ..< currentIds.count {
                if currentIds[i] == referenceId {
                    if fromIndex < toIndex {
                        didReorder = previousIndex != i + 1
                        currentIds.insert(fromPackInfo.id, at: i + 1)
                    } else {
                        didReorder = previousIndex != i
                        currentIds.insert(fromPackInfo.id, at: i)
                    }
                    inserted = true
                    break
                }
            }
            if !inserted {
                didReorder = previousIndex != currentIds.count
                currentIds.append(fromPackInfo.id)
            }
        } else if beforeAll {
            didReorder = previousIndex != 0
            currentIds.insert(fromPackInfo.id, at: 0)
        } else if afterAll {
            didReorder = previousIndex != currentIds.count
            currentIds.append(fromPackInfo.id)
        }
        
        temporaryPackOrder.set(.single(currentIds))
        
        return .single(didReorder)
    })
    
    controller.setReorderCompleted({ (entries: [InstalledStickerPacksEntry]) -> Void in
        var currentIds: [ItemCollectionId] = []
        for entry in entries {
            switch entry {
            case let .pack(_, _, _, info, _, _, _, _, _, _):
                currentIds.append(info.id)
            default:
                break
            }
        }
        let _ = (context.engine.stickers.reorderStickerPacks(namespace: namespaceForMode(mode), itemIds: currentIds)
        |> deliverOnMainQueue).start(completed: {
            temporaryPackOrder.set(.single(nil))
        })
        
        let _ = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings])
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedData in
            var stickerSettings = StickerSettings.defaultSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
               stickerSettings = value
            }
            
            if stickerSettings.dynamicPackOrder {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_reorder", scale: 0.05, colors: [:], title: presentationData.strings.StickerPacksSettings_DynamicOrderOff, text: presentationData.strings.StickerPacksSettings_DynamicOrderOffInfo, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                    return false }), nil)
                
                arguments.toggleDynamicPackOrder(false)
            }
        })
    })
    
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    presentStickerPackController = { [weak controller] info in
        let _ = (stickerPacks.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { view in
            guard let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView, let entries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] else {
                return
            }
            var mainStickerPack: StickerPackReference?
            var packs: [StickerPackReference] = []
            for entry in entries {
                if let listInfo = entry.info as? StickerPackCollectionInfo {
                    let packReference: StickerPackReference = .id(id: listInfo.id.id, accessHash: listInfo.accessHash)
                    if listInfo.id == info.id {
                        mainStickerPack = packReference
                    }
                    packs.append(packReference)
                }
            }
            if mainStickerPack == nil {
                let packReference: StickerPackReference = .id(id: info.id.id, accessHash: info.accessHash)
                mainStickerPack = packReference
                packs.insert(packReference, at: 0)
            }
            if let mainStickerPack = mainStickerPack {
                presentControllerImpl?(StickerPackScreen(context: context, mode: .settings, mainStickerPack: mainStickerPack, stickerPacks: [mainStickerPack], parentNavigationController: controller?.navigationController as? NavigationController, actionPerformed: { actions in
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    var animateInAsReplacement = false
                    if let navigationController = navigationControllerImpl?() {
                        for controller in navigationController.overlayControllers {
                            if let controller = controller as? UndoOverlayController {
                                controller.dismissWithCommitActionAndReplacementAnimation()
                                animateInAsReplacement = true
                            }
                        }
                    }
                    if let (info, items, action) = actions.first {
                        switch action {
                        case .add:
                            navigationControllerImpl?()?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in
                                return true
                            }))
                        case let .remove(positionInList):
                            let removedTitle: String
                            let removedText: String
                            if info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                                removedTitle = presentationData.strings.EmojiPackActionInfo_RemovedTitle
                                removedText = presentationData.strings.EmojiPackActionInfo_RemovedText(info.title).string
                            } else if info.id.namespace == Namespaces.ItemCollection.CloudMaskPacks {
                                removedTitle = presentationData.strings.MaskPackActionInfo_RemovedTitle
                                removedText = presentationData.strings.MaskPackActionInfo_RemovedText(info.title).string
                            } else {
                                removedTitle = presentationData.strings.StickerPackActionInfo_RemovedTitle
                                removedText = presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string
                            }
                            
                            navigationControllerImpl?()?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: removedTitle, text: removedText, undo: true, info: info, topItem: items.first, context: context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { action in
                                if case .undo = action {
                                    let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).start()
                                }
                                return true
                            }))
                        }
                    }
                }), nil)
            }
        })
    }
    navigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    navigateToChatControllerImpl = { [weak controller] peerId in
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            
            if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
            }
        })
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}

class StickersToolbarItem: ItemListToolbarItem {
    private let selectedCount: Int32
    
    init(selectedCount: Int32, actions: [Action]) {
        self.selectedCount = selectedCount
        super.init(actions: actions)
    }
    
    override func isEqual(to: ItemListToolbarItem) -> Bool {
        if let other = to as? StickersToolbarItem {
            return self.selectedCount == other.selectedCount
        } else {
            return false
        }
    }
}
