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

private final class InstalledStickerPacksControllerArguments {
    let account: Account
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let setPackIdWithRevealedOptions: (ItemCollectionId?, ItemCollectionId?) -> Void
    let removePack: (ArchivedStickerPackItem) -> Void
    let openStickersBot: () -> Void
    let openMasks: () -> Void
    let openQuickReaction: () -> Void
    let openFeatured: () -> Void
    let openArchived: ([ArchivedStickerPackItem]?) -> Void
    let openSuggestOptions: () -> Void
    let toggleAnimatedStickers: (Bool) -> Void
    let togglePackSelected: (ItemCollectionId) -> Void
    let expandTrendingPacks: () -> Void
    let addPack: (StickerPackCollectionInfo) -> Void
    
    init(account: Account, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, setPackIdWithRevealedOptions: @escaping (ItemCollectionId?, ItemCollectionId?) -> Void, removePack: @escaping (ArchivedStickerPackItem) -> Void, openStickersBot: @escaping () -> Void, openMasks: @escaping () -> Void, openQuickReaction: @escaping () -> Void, openFeatured: @escaping () -> Void, openArchived: @escaping ([ArchivedStickerPackItem]?) -> Void, openSuggestOptions: @escaping () -> Void, toggleAnimatedStickers: @escaping (Bool) -> Void, togglePackSelected: @escaping (ItemCollectionId) -> Void, expandTrendingPacks: @escaping () -> Void, addPack: @escaping (StickerPackCollectionInfo) -> Void) {
        self.account = account
        self.openStickerPack = openStickerPack
        self.setPackIdWithRevealedOptions = setPackIdWithRevealedOptions
        self.removePack = removePack
        self.openStickersBot = openStickersBot
        self.openMasks = openMasks
        self.openQuickReaction = openQuickReaction
        self.openFeatured = openFeatured
        self.openArchived = openArchived
        self.openSuggestOptions = openSuggestOptions
        self.toggleAnimatedStickers = toggleAnimatedStickers
        self.togglePackSelected = togglePackSelected
        self.expandTrendingPacks = expandTrendingPacks
        self.addPack = addPack
    }
}

private enum InstalledStickerPacksSection: Int32 {
    case service
    case trending
    case stickers
}

public enum InstalledStickerPacksEntryTag: ItemListItemTag {
    case suggestOptions
    case loopAnimatedStickers
    
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
    case trendingPack(ItemCollectionId)
    case pack(ItemCollectionId)
}

private indirect enum InstalledStickerPacksEntry: ItemListNodeEntry {
    case suggestOptions(PresentationTheme, String, String)
    case trending(PresentationTheme, String, Int32)
    case archived(PresentationTheme, String, Int32, [ArchivedStickerPackItem]?)
    case masks(PresentationTheme, String)
    case quickReaction(String, UIImage?)
    case animatedStickers(PresentationTheme, String, Bool)
    case animatedStickersInfo(PresentationTheme, String)
    case trendingPacksTitle(PresentationTheme, String)
    case trendingPack(Int32, PresentationTheme, PresentationStrings, StickerPackCollectionInfo, StickerPackItem?, String, Bool, Bool, Bool)
    case trendingExpand(PresentationTheme, String)
    case packsTitle(PresentationTheme, String)
    case pack(Int32, PresentationTheme, PresentationStrings, StickerPackCollectionInfo, StickerPackItem?, String, Bool, Bool, ItemListStickerPackItemEditing, Bool?)
    case packsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .suggestOptions, .trending, .masks, .quickReaction, .archived, .animatedStickers, .animatedStickersInfo:
                return InstalledStickerPacksSection.service.rawValue
            case .trendingPacksTitle, .trendingPack, .trendingExpand:
                return InstalledStickerPacksSection.trending.rawValue
            case .packsTitle, .pack, .packsInfo:
                return InstalledStickerPacksSection.stickers.rawValue
        }
    }
    
    var stableId: InstalledStickerPacksEntryId {
        switch self {
            case .suggestOptions:
                return .index(0)
            case .trending:
                return .index(1)
            case .archived:
                return .index(2)
            case .masks:
                return .index(3)
            case .quickReaction:
                return .index(4)
            case .animatedStickers:
                return .index(5)
            case .animatedStickersInfo:
                return .index(6)
            case .trendingPacksTitle:
                return .index(7)
            case let .trendingPack(_, _, _, info, _, _, _, _, _):
                return .trendingPack(info.id)
            case .trendingExpand:
                return .index(8)
            case .packsTitle:
                return .index(9)
            case let .pack(_, _, _, info, _, _, _, _, _, _):
                return .pack(info.id)
            case .packsInfo:
                return .index(10)
        }
    }
    
    static func ==(lhs: InstalledStickerPacksEntry, rhs: InstalledStickerPacksEntry) -> Bool {
        switch lhs {
            case let .suggestOptions(lhsTheme, lhsText, lhsValue):
                if case let .suggestOptions(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .quickReaction(lhsText, lhsImage):
                if case let .quickReaction(rhsText, rhsImage) = rhs, lhsText == rhsText, lhsImage === rhsImage {
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
            case let .animatedStickers(lhsTheme, lhsText, lhsValue):
                if case let .animatedStickers(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .animatedStickersInfo(lhsTheme, lhsText):
                if case let .animatedStickersInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .trendingPacksTitle(lhsTheme, lhsText):
                if case let .trendingPacksTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .trendingPack(lhsIndex, lhsTheme, lhsStrings, lhsInfo, lhsTopItem, lhsCount, lhsAnimatedStickers, lhsUnread, lhsInstalled):
                if case let .trendingPack(rhsIndex, rhsTheme, rhsStrings, rhsInfo, rhsTopItem, rhsCount, rhsAnimatedStickers, rhsUnread, rhsInstalled) = rhs {
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
                    if lhsUnread != rhsUnread {
                        return false
                    }
                    if lhsInstalled != rhsInstalled {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .trendingExpand(lhsTheme, lhsText):
                if case let .trendingExpand(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case .suggestOptions:
                switch rhs {
                    case  .suggestOptions:
                        return false
                    default:
                        return true
                }
            case .trending:
                switch rhs {
                    case .suggestOptions, .trending:
                        return false
                    default:
                        return true
                }
            case .archived:
                switch rhs {
                    case .suggestOptions, .trending, .archived:
                        return false
                    default:
                        return true
                }
            case .masks:
                switch rhs {
                    case .suggestOptions, .trending, .archived, .masks:
                        return false
                    default:
                        return true
                }
            case .quickReaction:
                switch rhs {
                    case .suggestOptions, .trending, .archived, .masks, .quickReaction:
                        return false
                    default:
                        return true
                }
            case .animatedStickers:
                switch rhs {
                    case .suggestOptions, .trending, .archived, .masks, .quickReaction, .animatedStickers:
                        return false
                    default:
                        return true
                }
            case .animatedStickersInfo:
                switch rhs {
                    case .suggestOptions, .trending, .archived, .masks, .quickReaction, .animatedStickers, .animatedStickersInfo:
                        return false
                    default:
                        return true
                }
            case .trendingPacksTitle:
                switch rhs {
                    case .suggestOptions, .trending, .masks, .quickReaction, .archived, .animatedStickers, .animatedStickersInfo, .trendingPacksTitle:
                        return false
                    default:
                        return true
                }
            case let .trendingPack(lhsIndex, _, _, _, _, _, _, _, _):
                switch rhs {
                    case let .trendingPack(rhsIndex, _, _, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    case .trendingExpand, .packsTitle, .pack, .packsInfo:
                        return true
                    default:
                        return false
                }
            case .trendingExpand:
                switch rhs {
                    case .suggestOptions, .trending, .masks, .quickReaction, .archived, .animatedStickers, .animatedStickersInfo, .trendingPacksTitle, .trendingPack, .trendingExpand:
                        return false
                    default:
                        return true
                }
            case .packsTitle:
                switch rhs {
                    case .suggestOptions, .trending, .masks, .quickReaction, .archived, .animatedStickers, .animatedStickersInfo, .trendingPacksTitle, .trendingPack, .trendingExpand, .packsTitle:
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
            case let .suggestOptions(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openSuggestOptions()
                }, tag: InstalledStickerPacksEntryTag.suggestOptions)
            case let .trending(theme, text, count):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: count == 0 ? "" : "\(count)", labelStyle: .badge(theme.list.itemAccentColor), sectionId: self.section, style: .blocks, action: {
                    arguments.openFeatured()
                })
            case let .masks(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openMasks()
                })
            case let .quickReaction(title, image):
                let labelStyle: ItemListDisclosureLabelStyle
                if let image = image {
                    labelStyle = .image(image: image, size: image.size.aspectFitted(CGSize(width: 30.0, height: 30.0)))
                } else {
                    labelStyle = .text
                }
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: "", labelStyle: labelStyle, sectionId: self.section, style: .blocks, action: {
                    arguments.openQuickReaction()
                })
            case let .archived(_, text, count, archived):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: count == 0 ? "" : "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.openArchived(archived)
                })
            case let .animatedStickers(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAnimatedStickers(value)
                })
            case let .animatedStickersInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .trendingPacksTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .trendingPack(_, _, _, info, topItem, count, animatedStickers, unread, installed):
                return ItemListStickerPackItem(presentationData: presentationData, account: arguments.account, packInfo: info, itemCount: count, topItem: topItem, unread: unread, control: .installation(installed: installed), editing: ItemListStickerPackItemEditing(editable: false, editing: false, revealed: false, reorderable: false, selectable: false), enabled: true, playAnimatedStickers: animatedStickers, sectionId: self.section, action: {
                    arguments.openStickerPack(info)
                }, setPackIdWithRevealedOptions: { _, _ in
                }, addPack: {
                    arguments.addPack(info)
                }, removePack: {
                }, toggleSelected: {
                })
            case let .trendingExpand(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(theme), title: text, sectionId: self.section, editing: false, action: {
                    arguments.expandTrendingPacks()
                })
            case let .packsTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .pack(_, _, _, info, topItem, count, animatedStickers, enabled, editing, selected):
                return ItemListStickerPackItem(presentationData: presentationData, account: arguments.account, packInfo: info, itemCount: count, topItem: topItem, unread: false, control: editing.editing ? .check(checked: selected ?? false) : .none, editing: editing, enabled: enabled, playAnimatedStickers: animatedStickers, sectionId: self.section, action: {
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
    }
}

private let maxTrendingPacksDisplayedLimit: Int32 = 3

private func installedStickerPacksControllerEntries(presentationData: PresentationData, state: InstalledStickerPacksControllerState, mode: InstalledStickerPacksControllerMode, view: CombinedView, temporaryPackOrder: [ItemCollectionId]?, featured: [FeaturedStickerPackItem], archived: [ArchivedStickerPackItem]?, stickerSettings: StickerSettings, quickReactionImage: UIImage?) -> [InstalledStickerPacksEntry] {
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
        
        if let archived = archived, !archived.isEmpty  {
            entries.append(.archived(presentationData.theme, presentationData.strings.StickerPacksSettings_ArchivedPacks, Int32(archived.count), archived))
        }
        entries.append(.masks(presentationData.theme, presentationData.strings.MaskStickerSettings_Title))
        
        entries.append(.quickReaction(presentationData.strings.Settings_QuickReactionSetup_NavigationTitle, quickReactionImage))
        
        entries.append(.animatedStickers(presentationData.theme, presentationData.strings.StickerPacksSettings_AnimatedStickers, stickerSettings.loopAnimatedStickers))
        entries.append(.animatedStickersInfo(presentationData.theme, presentationData.strings.StickerPacksSettings_AnimatedStickersInfo))
        
        if featured.count > 0 {
            entries.append(.trendingPacksTitle(presentationData.theme, presentationData.strings.StickerPacksSettings_FeaturedPacks.uppercased()))
            
            var index: Int32 = 0
            var featuredPacks = featured
            var effectiveExpanded = state.trendingPacksExpanded
            if featuredPacks.count > maxTrendingPacksDisplayedLimit && !effectiveExpanded {
                featuredPacks = Array(featuredPacks.prefix(Int(maxTrendingPacksDisplayedLimit)))
            } else {
                effectiveExpanded = true
            }
            
            for featuredPack in featuredPacks {
                entries.append(.trendingPack(index, presentationData.theme, presentationData.strings, featuredPack.info, featuredPack.topItems.first, presentationData.strings.StickerPack_StickerCount(featuredPack.info.count), stickerSettings.loopAnimatedStickers, featuredPack.unread, installedPacks.contains(featuredPack.info.id)))
                index += 1
            }
            
            if !effectiveExpanded {
                entries.append(.trendingExpand(presentationData.theme, presentationData.strings.Stickers_ShowMore))
            }
        }
        
        entries.append(.packsTitle(presentationData.theme, presentationData.strings.StickerPacksSettings_StickerPacksSection))
    case .masks:
        if let archived = archived, !archived.isEmpty {
            entries.append(.archived(presentationData.theme, presentationData.strings.StickerPacksSettings_ArchivedMasks, Int32(archived.count), archived))
        }
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
                    entries.append(.pack(index, presentationData.theme, presentationData.strings, info, entry.firstItem as? StickerPackItem, presentationData.strings.StickerPack_StickerCount(info.count == 0 ? entry.count : info.count), stickerSettings.loopAnimatedStickers, true, ItemListStickerPackItemEditing(editable: true, editing: state.editing, revealed: state.packIdWithRevealedOptions == entry.id, reorderable: true, selectable: true), state.selectedPackIds?.contains(info.id)))
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
    }
    let entities = generateTextEntities(markdownString, enabledTypes: [.mention])
    if let entity = entities.first {
        markdownString.insert(contentsOf: "]()", at: markdownString.index(markdownString.startIndex, offsetBy: entity.range.upperBound))
        markdownString.insert(contentsOf: "[", at: markdownString.index(markdownString.startIndex, offsetBy: entity.range.lowerBound))
    }
    entries.append(.packsInfo(presentationData.theme, markdownString))
    
    return entries
}

public enum InstalledStickerPacksControllerMode {
    case general
    case modal
    case masks
}

public func installedStickerPacksController(context: AccountContext, mode: InstalledStickerPacksControllerMode, archivedPacks: [ArchivedStickerPackItem]? = nil, updatedPacks: @escaping ([ArchivedStickerPackItem]?) -> Void = { _ in }, focusOnItemTag: InstalledStickerPacksEntryTag? = nil) -> ViewController {
    let initialState = InstalledStickerPacksControllerState().withUpdatedEditing(mode == .modal).withUpdatedSelectedPackIds(mode == .modal ? Set() : nil)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InstalledStickerPacksControllerState) -> InstalledStickerPacksControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
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
    
    let arguments = InstalledStickerPacksControllerArguments(account: context.account, openStickerPack: { info in
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
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
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
                
                navigationControllerImpl?()?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: action == .archive ? presentationData.strings.StickerPackActionInfo_ArchivedTitle : presentationData.strings.StickerPackActionInfo_RemovedTitle, text: presentationData.strings.StickerPackActionInfo_RemovedText(archivedItem.info.title).string, undo: true, info: archivedItem.info, topItem: archivedItem.topItems.first, context: context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { action in
                    if case .undo = action {
                        let _ = context.engine.stickers.addStickerPackInteractively(info: archivedItem.info, items: items, positionInList: positionInList).start()
                    }
                    return true
                }))
            })
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: presentationData.strings.StickerSettings_ContextInfo),
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
        resolveDisposable.set((context.engine.peers.resolvePeerByName(name: "stickers") |> deliverOnMainQueue).start(next: { peer in
            if let peer = peer {
                navigateToChatControllerImpl?(peer.id)
            }
        }))
    }, openMasks: {
        pushControllerImpl?(installedStickerPacksController(context: context, mode: .masks, archivedPacks: archivedPacks, updatedPacks: { _ in}))
    }, openQuickReaction: {
        pushControllerImpl?(quickReactionSetupController(
            context: context
        ))
    }, openFeatured: {
        pushControllerImpl?(featuredStickerPacksController(context: context))
    }, openArchived: { archived in
        let archivedMode: ArchivedStickerPacksControllerMode
        switch mode {
            case .masks:
                archivedMode = .masks
            default:
                archivedMode = .stickers
        }
        pushControllerImpl?(archivedStickerPacksController(context: context, mode: archivedMode, archived: archived, updatedPacks: { packs in
            archivedPromise.set(.single(packs))
            updatedPacks(packs)
        }))
    }, openSuggestOptions: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
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
    }, toggleAnimatedStickers: { value in
        let _ = updateStickerSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            return current.withUpdatedLoopAnimatedStickers(value)
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
    }, expandTrendingPacks: {
        updateState { state in
            return state.withUpdatedTrendingPacksExpanded(true)
        }
    }, addPack: { info in
        let _ = (context.engine.stickers.loadedStickerPack(reference: .id(id: info.id.id, accessHash: info.accessHash), forceActualized: false)
        |> mapToSignal { result -> Signal<Void, NoError> in
            switch result {
                case let .result(info, items, installed):
                    if installed {
                        return .complete()
                    } else {
                        return context.engine.stickers.addStickerPackInteractively(info: info, items: items)
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
    let quickReactionImage: Signal<UIImage?, NoError>

    switch mode {
        case .general, .modal:
            featured.set(context.account.viewTracker.featuredStickerPacks())
            archivedPromise.set(.single(archivedPacks) |> then(context.engine.stickers.archivedStickerPacks() |> map(Optional.init)))
            quickReactionImage = combineLatest(
                context.engine.stickers.availableReactions(),
                context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
            )
            |> map { availableReactions, preferencesView -> TelegramMediaFile? in
                guard let availableReactions = availableReactions else {
                    return nil
                }
                
                let reactionSettings: ReactionSettings
                if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
                    reactionSettings = value
                } else {
                    reactionSettings = .default
                }
                
                for reaction in availableReactions.reactions {
                    if reaction.value == reactionSettings.quickReaction {
                        return reaction.staticIcon
                    }
                }
                
                return nil
            }
            |> distinctUntilChanged
            |> mapToSignal { file -> Signal<UIImage?, NoError> in
                guard let file = file else {
                    return .single(nil)
                }
                
                return context.account.postbox.mediaBox.resourceData(file.resource)
                |> distinctUntilChanged(isEqual: { lhs, rhs in
                    return lhs.complete == rhs.complete
                })
                |> map { data -> UIImage? in
                    guard data.complete else {
                        return nil
                    }
                    guard let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                        return nil
                    }
                    guard let image = WebP.convert(fromWebP: dataValue) else {
                        return nil
                    }
                    return image
                }
            }
        case .masks:
            featured.set(.single([]))
            archivedPromise.set(.single(nil) |> then(context.engine.stickers.archivedStickerPacks(namespace: .masks) |> map(Optional.init)))
            quickReactionImage = .single(nil)
    }

    var previousPackCount: Int?
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData,
        statePromise.get(),
        stickerPacks.get(),
        temporaryPackOrder.get(),
        combineLatest(queue: .mainQueue(), featured.get(), archivedPromise.get()),
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings]),
        quickReactionImage
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, view, temporaryPackOrder, featuredAndArchived, sharedData, quickReactionImage -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
                    items.append(ActionSheetButtonItem(title: presentationData.strings.StickerPacks_DeleteStickerPacksConfirmation(selectedCount), color: .destructive, action: { [weak actionSheet] in
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
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: installedStickerPacksControllerEntries(presentationData: presentationData, state: state, mode: mode, view: view, temporaryPackOrder: temporaryPackOrder, featured: featuredAndArchived.0, archived: featuredAndArchived.1, stickerSettings: stickerSettings, quickReactionImage: quickReactionImage), style: .blocks, ensureVisibleItemTag: focusOnItemTag, toolbarItem: toolbarItem, animateChanges: previous != nil && packCount != nil && (previous! != 0 && previous! >= packCount! - 10))
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    if case .modal = mode {
        controller.navigationPresentation = .modal
    }
    
    var alreadyReadIds = Set<ItemCollectionId>()
    controller.visibleEntriesUpdated = { entries in
        var unreadIds: [ItemCollectionId] = []
        for entry in entries {
            if let entry = entry as? InstalledStickerPacksEntry {
                if case let .trendingPack(_, _, _, info, _, _, _, unread, _) = entry {
                    if unread && !alreadyReadIds.contains(info.id) {
                        unreadIds.append(info.id)
                    }
                }
            }
        }
        if !unreadIds.isEmpty {
            alreadyReadIds.formUnion(Set(unreadIds))
            
            let _ = context.engine.stickers.markFeaturedStickerPacksAsSeenInteractively(ids: unreadIds).start()
        }
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
                presentControllerImpl?(StickerPackScreen(context: context, mode: .settings, mainStickerPack: mainStickerPack, stickerPacks: packs, parentNavigationController: controller?.navigationController as? NavigationController, actionPerformed: { info, items, action in
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
                    switch action {
                    case .add:
                        navigationControllerImpl?()?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in
                            return true
                        }))
                    case let .remove(positionInList):
                        navigationControllerImpl?()?.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_RemovedTitle, text: presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: items.first, context: context), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { action in
                            if case .undo = action {
                                let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).start()
                            }
                            return true
                        }))
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
        if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId)))
        }
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}

private class StickersToolbarItem: ItemListToolbarItem {
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
