import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import TextFormat
import AccountContext
import StickerPackPreviewUI
import ItemListStickerPackItem

private final class InstalledStickerPacksControllerArguments {
    let account: Account
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let setPackIdWithRevealedOptions: (ItemCollectionId?, ItemCollectionId?) -> Void
    let removePack: (ArchivedStickerPackItem) -> Void
    let openStickersBot: () -> Void
    let openMasks: () -> Void
    let openFeatured: () -> Void
    let openArchived: ([ArchivedStickerPackItem]?) -> Void
    let openSuggestOptions: () -> Void
    let toggleAnimatedStickers: (Bool) -> Void
    
    init(account: Account, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, setPackIdWithRevealedOptions: @escaping (ItemCollectionId?, ItemCollectionId?) -> Void, removePack: @escaping (ArchivedStickerPackItem) -> Void, openStickersBot: @escaping () -> Void, openMasks: @escaping () -> Void, openFeatured: @escaping () -> Void, openArchived: @escaping ([ArchivedStickerPackItem]?) -> Void, openSuggestOptions: @escaping () -> Void, toggleAnimatedStickers: @escaping (Bool) -> Void) {
        self.account = account
        self.openStickerPack = openStickerPack
        self.setPackIdWithRevealedOptions = setPackIdWithRevealedOptions
        self.removePack = removePack
        self.openStickersBot = openStickersBot
        self.openMasks = openMasks
        self.openFeatured = openFeatured
        self.openArchived = openArchived
        self.openSuggestOptions = openSuggestOptions
        self.toggleAnimatedStickers = toggleAnimatedStickers
    }
}

private enum InstalledStickerPacksSection: Int32 {
    case service
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
    case pack(ItemCollectionId)
    
    var hashValue: Int {
        switch self {
            case let .index(index):
                return index.hashValue
            case let .pack(id):
                return id.hashValue
        }
    }
    
    static func ==(lhs: InstalledStickerPacksEntryId, rhs: InstalledStickerPacksEntryId) -> Bool {
        switch lhs {
            case let .index(index):
                if case .index(index) = rhs {
                    return true
                } else {
                    return false
                }
            case let .pack(id):
                if case .pack(id) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum InstalledStickerPacksEntry: ItemListNodeEntry {
    case suggestOptions(PresentationTheme, String, String)
    case trending(PresentationTheme, String, Int32)
    case archived(PresentationTheme, String, Int32, [ArchivedStickerPackItem]?)
    case masks(PresentationTheme, String)
    case animatedStickers(PresentationTheme, String, Bool)
    case animatedStickersInfo(PresentationTheme, String)
    case packsTitle(PresentationTheme, String)
    case pack(Int32, PresentationTheme, PresentationStrings, StickerPackCollectionInfo, StickerPackItem?, String, Bool, Bool, ItemListStickerPackItemEditing)
    case packsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .suggestOptions, .trending, .masks, .archived, .animatedStickers, .animatedStickersInfo:
                return InstalledStickerPacksSection.service.rawValue
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
            case .animatedStickers:
                return .index(4)
            case .animatedStickersInfo:
                return .index(5)
            case .packsTitle:
                return .index(6)
            case let .pack(_, _, _, info, _, _, _, _, _):
                return .pack(info.id)
            case .packsInfo:
                return .index(7)
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
            case let .packsTitle(lhsTheme, lhsText):
                if case let .packsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .pack(lhsIndex, lhsTheme, lhsStrings, lhsInfo, lhsTopItem, lhsCount, lhsAnimatedStickers, lhsEnabled, lhsEditing):
                if case let .pack(rhsIndex, rhsTheme, rhsStrings, rhsInfo, rhsTopItem, rhsCount, rhsAnimatedStickers, rhsEnabled, rhsEditing) = rhs {
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
            case .animatedStickers:
                switch rhs {
                    case .suggestOptions, .trending, .archived, .masks, .animatedStickers:
                        return false
                    default:
                        return true
                }
            case .animatedStickersInfo:
                switch rhs {
                    case .suggestOptions, .trending, .archived, .masks, .animatedStickers, .animatedStickersInfo:
                        return false
                    default:
                        return true
                }
            case .packsTitle:
                switch rhs {
                    case .suggestOptions, .trending, .masks, .archived, .animatedStickers, .animatedStickersInfo, .packsTitle:
                        return false
                    default:
                        return true
                }
            case let .pack(lhsIndex, _, _, _, _, _, _, _, _):
                switch rhs {
                    case let .pack(rhsIndex, _, _, _, _, _, _, _, _):
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
    
    func item(_ arguments: InstalledStickerPacksControllerArguments) -> ListViewItem {
        switch self {
            case let .suggestOptions(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openSuggestOptions()
                }, tag: InstalledStickerPacksEntryTag.suggestOptions)
            case let .trending(theme, text, count):
                return ItemListDisclosureItem(theme: theme, title: text, label: count == 0 ? "" : "\(count)", labelStyle: .badge(theme.list.itemAccentColor), sectionId: self.section, style: .blocks, action: {
                    arguments.openFeatured()
                })
            case let .masks(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openMasks()
                })
            case let .archived(theme, text, count, archived):
                return ItemListDisclosureItem(theme: theme, title: text, label: count == 0 ? "" : "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.openArchived(archived)
                })
            case let .animatedStickers(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleAnimatedStickers(value)
                })
            case let .animatedStickersInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .packsTitle(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .pack(_, theme, strings, info, topItem, count, animatedStickers, enabled, editing):
                return ItemListStickerPackItem(theme: theme, strings: strings, account: arguments.account, packInfo: info, itemCount: count, topItem: topItem, unread: false, control: .none, editing: editing, enabled: enabled, playAnimatedStickers: animatedStickers, sectionId: self.section, action: {
                    arguments.openStickerPack(info)
                }, setPackIdWithRevealedOptions: { current, previous in
                    arguments.setPackIdWithRevealedOptions(current, previous)
                }, addPack: {
                }, removePack: {
                    arguments.removePack(ArchivedStickerPackItem(info: info, topItems: topItem != nil ? [topItem!] : []))
                })
            case let .packsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section, linkAction: { _ in
                    arguments.openStickersBot()
                })
        }
    }
}

private struct InstalledStickerPacksControllerState: Equatable {
    let editing: Bool
    let packIdWithRevealedOptions: ItemCollectionId?
    
    init() {
        self.editing = false
        self.packIdWithRevealedOptions = nil
    }
    
    init(editing: Bool, packIdWithRevealedOptions: ItemCollectionId?) {
        self.editing = editing
        self.packIdWithRevealedOptions = packIdWithRevealedOptions
    }
    
    static func ==(lhs: InstalledStickerPacksControllerState, rhs: InstalledStickerPacksControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.packIdWithRevealedOptions != rhs.packIdWithRevealedOptions {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> InstalledStickerPacksControllerState {
        return InstalledStickerPacksControllerState(editing: editing, packIdWithRevealedOptions: self.packIdWithRevealedOptions)
    }
    
    func withUpdatedPackIdWithRevealedOptions(_ packIdWithRevealedOptions: ItemCollectionId?) -> InstalledStickerPacksControllerState {
        return InstalledStickerPacksControllerState(editing: self.editing, packIdWithRevealedOptions: packIdWithRevealedOptions)
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

private func installedStickerPacksControllerEntries(presentationData: PresentationData, state: InstalledStickerPacksControllerState, mode: InstalledStickerPacksControllerMode, view: CombinedView, featured: [FeaturedStickerPackItem], archived: [ArchivedStickerPackItem]?, stickerSettings: StickerSettings) -> [InstalledStickerPacksEntry] {
    var entries: [InstalledStickerPacksEntry] = []
    
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
            
            if featured.count != 0 {
                var unreadCount: Int32 = 0
                for item in featured {
                    if item.unread {
                        unreadCount += 1
                    }
                }
                entries.append(.trending(presentationData.theme, presentationData.strings.StickerPacksSettings_FeaturedPacks, unreadCount))
            }
            if let archived = archived, !archived.isEmpty  {
                entries.append(.archived(presentationData.theme, presentationData.strings.StickerPacksSettings_ArchivedPacks, Int32(archived.count), archived))
            }
            entries.append(.masks(presentationData.theme, presentationData.strings.MaskStickerSettings_Title))
            
            entries.append(.animatedStickers(presentationData.theme, presentationData.strings.StickerPacksSettings_AnimatedStickers, stickerSettings.loopAnimatedStickers))
            entries.append(.animatedStickersInfo(presentationData.theme, presentationData.strings.StickerPacksSettings_AnimatedStickersInfo))
            
            entries.append(.packsTitle(presentationData.theme, presentationData.strings.StickerPacksSettings_StickerPacksSection))
        case .masks:
            if let archived = archived, !archived.isEmpty  {
                entries.append(.archived(presentationData.theme, presentationData.strings.StickerPacksSettings_ArchivedMasks, Int32(archived.count), archived))
        }
    }
    
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] {
            var index: Int32 = 0
            for entry in packsEntries {
                if let info = entry.info as? StickerPackCollectionInfo {
                    entries.append(.pack(index, presentationData.theme, presentationData.strings, info, entry.firstItem as? StickerPackItem, presentationData.strings.StickerPack_StickerCount(info.count == 0 ? entry.count : info.count), stickerSettings.loopAnimatedStickers, true, ItemListStickerPackItemEditing(editable: true, editing: state.editing, revealed: state.packIdWithRevealedOptions == entry.id, reorderable: true)))
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
    let initialState = InstalledStickerPacksControllerState().withUpdatedEditing(mode == .modal)
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
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
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

                    let _ = removeStickerPackInteractively(postbox: context.account.postbox, id: archivedItem.info.id, option: .archive).start()
                }),
                ActionSheetButtonItem(title: presentationData.strings.Common_Delete, color: .destructive, action: {
                    dismissAction()
                    let _ = removeStickerPackInteractively(postbox: context.account.postbox, id: archivedItem.info.id, option: .delete).start()
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openStickersBot: {
        resolveDisposable.set((resolvePeerByName(account: context.account, name: "stickers") |> deliverOnMainQueue).start(next: { peerId in
            if let peerId = peerId {
                navigateToChatControllerImpl?(peerId)
            }
        }))
    }, openMasks: {
        pushControllerImpl?(installedStickerPacksController(context: context, mode: .masks, archivedPacks: archivedPacks, updatedPacks: { _ in}))
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
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
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
    })
    let stickerPacks = Promise<CombinedView>()
    stickerPacks.set(context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [namespaceForMode(mode)])]))
    
    let featured = Promise<[FeaturedStickerPackItem]>()

    switch mode {
        case .general, .modal:
            featured.set(context.account.viewTracker.featuredStickerPacks())
            archivedPromise.set(.single(archivedPacks) |> then(archivedStickerPacks(account: context.account) |> map(Optional.init)))
        case .masks:
            featured.set(.single([]))
            archivedPromise.set(.single(nil) |> then(archivedStickerPacks(account: context.account, namespace: .masks) |> map(Optional.init)))
    }

    var previousPackCount: Int?
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), stickerPacks.get(), combineLatest(queue: .mainQueue(), featured.get(), archivedPromise.get()), context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings]))
    |> deliverOnMainQueue
    |> map { presentationData, state, view, featuredAndArchived, sharedData -> (ItemListControllerState, (ItemListNodeState<InstalledStickerPacksEntry>, InstalledStickerPacksEntry.ItemGenerationArguments)) in
        var stickerSettings = StickerSettings.defaultSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings] as? StickerSettings {
           stickerSettings = value
        }
        
        var packCount: Int? = nil
        if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView, let entries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] {
            packCount = entries.count
        }
        
        let leftNavigationButton: ItemListNavigationButton? = nil
        var rightNavigationButton: ItemListNavigationButton?
        if let packCount = packCount, packCount != 0 {
            if case .modal = mode {
                rightNavigationButton = nil
            } else {
                if state.editing {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                        updateState {
                            $0.withUpdatedEditing(false)
                        }
                        if case .modal = mode {
                            dismissImpl?()
                        }
                    })
                } else {
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                        updateState {
                            $0.withUpdatedEditing(true)
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
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        
        let listState = ItemListNodeState(entries: installedStickerPacksControllerEntries(presentationData: presentationData, state: state, mode: mode, view: view, featured: featuredAndArchived.0, archived: featuredAndArchived.1, stickerSettings: stickerSettings), style: .blocks, ensureVisibleItemTag: focusOnItemTag, animateChanges: previous != nil && packCount != nil && (previous! != 0 && previous! >= packCount! - 10))
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    controller.reorderEntry = { fromIndex, toIndex, entries in
        let fromEntry = entries[fromIndex]
        guard case let .pack(_, _, _, fromPackInfo, _, _, _, _, _) = fromEntry else {
            return
        }
        var referenceId: ItemCollectionId?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .pack(_, _, _, toPackInfo, _, _, _, _, _):
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
        
        let _ = (context.account.postbox.transaction { transaction -> Void in
            var infos = transaction.getItemCollectionsInfos(namespace: namespaceForMode(mode))
            var reorderInfo: ItemCollectionInfo?
            for i in 0 ..< infos.count {
                if infos[i].0 == fromPackInfo.id {
                    reorderInfo = infos[i].1
                    infos.remove(at: i)
                    break
                }
            }
            if let reorderInfo = reorderInfo {
                if let referenceId = referenceId {
                    var inserted = false
                    for i in 0 ..< infos.count {
                        if infos[i].0 == referenceId {
                            if fromIndex < toIndex {
                                infos.insert((fromPackInfo.id, reorderInfo), at: i + 1)
                            } else {
                                infos.insert((fromPackInfo.id, reorderInfo), at: i)
                            }
                            inserted = true
                            break
                        }
                    }
                    if !inserted {
                        infos.append((fromPackInfo.id, reorderInfo))
                    }
                } else if beforeAll {
                    infos.insert((fromPackInfo.id, reorderInfo), at: 0)
                } else if afterAll {
                    infos.append((fromPackInfo.id, reorderInfo))
                }
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: namespaceForMode(mode), content: .sync)
                transaction.replaceItemCollectionInfos(namespace: namespaceForMode(mode), itemCollectionInfos: infos)
            }
        }).start()
    }
    
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    presentStickerPackController = { [weak controller] info in
        presentControllerImpl?(StickerPackPreviewController(context: context, stickerPack: .id(id: info.id.id, accessHash: info.accessHash), mode: .settings, parentNavigationController: controller?.navigationController as? NavigationController), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    navigateToChatControllerImpl = { [weak controller] peerId in
        if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
        }
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
