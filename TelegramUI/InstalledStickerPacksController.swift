import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class InstalledStickerPacksControllerArguments {
    let account: Account
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let setPackIdWithRevealedOptions: (ItemCollectionId?, ItemCollectionId?) -> Void
    let removePack: (ItemCollectionId) -> Void
    let openStickersBot: () -> Void
    let openMasks: () -> Void
    let openFeatured: () -> Void
    let openArchived: () -> Void
    
    init(account: Account, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, setPackIdWithRevealedOptions: @escaping (ItemCollectionId?, ItemCollectionId?) -> Void, removePack: @escaping (ItemCollectionId) -> Void, openStickersBot: @escaping () -> Void, openMasks: @escaping () -> Void, openFeatured: @escaping () -> Void, openArchived: @escaping () -> Void) {
        self.account = account
        self.openStickerPack = openStickerPack
        self.setPackIdWithRevealedOptions = setPackIdWithRevealedOptions
        self.removePack = removePack
        self.openStickersBot = openStickersBot
        self.openMasks = openMasks
        self.openFeatured = openFeatured
        self.openArchived = openArchived
    }
}

private enum InstalledStickerPacksSection: Int32 {
    case service
    case stickers
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
    case trending(PresentationTheme, String, Int32)
    case archived(PresentationTheme, String)
    case masks(PresentationTheme, String)
    case packsTitle(PresentationTheme, String)
    case pack(Int32, PresentationTheme, PresentationStrings, StickerPackCollectionInfo, StickerPackItem?, String, Bool, ItemListStickerPackItemEditing)
    case packsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .trending, .masks, .archived:
                return InstalledStickerPacksSection.service.rawValue
            case .packsTitle, .pack, .packsInfo:
                return InstalledStickerPacksSection.stickers.rawValue
        }
    }
    
    var stableId: InstalledStickerPacksEntryId {
        switch self {
            case .trending:
                return .index(0)
            case .archived:
                return .index(1)
            case .masks:
                return .index(2)
            case .packsTitle:
                return .index(3)
            case let .pack(_, _, _, info, _, _, _, _):
                return .pack(info.id)
            case .packsInfo:
                return .index(4)
        }
    }
    
    static func ==(lhs: InstalledStickerPacksEntry, rhs: InstalledStickerPacksEntry) -> Bool {
        switch lhs {
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
            case let .archived(lhsTheme, lhsCount):
                if case let .archived(rhsTheme, rhsCount) = rhs, lhsTheme === rhsTheme, lhsCount == rhsCount {
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
            case let .pack(lhsIndex, lhsTheme, lhsStrings, lhsInfo, lhsTopItem, lhsCount, lhsEnabled, lhsEditing):
                if case let .pack(rhsIndex, rhsTheme, rhsStrings, rhsInfo, rhsTopItem, rhsCount, rhsEnabled, rhsEditing) = rhs {
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
            case .trending:
                switch rhs {
                    case .trending:
                        return false
                    default:
                        return true
                }
            case .archived:
                switch rhs {
                    case .trending, .archived:
                        return false
                    default:
                        return true
                }
            case .masks:
                switch rhs {
                    case .trending, .archived, .masks:
                        return false
                    default:
                        return true
                }
            case .packsTitle:
                switch rhs {
                    case .trending, .masks, .archived, .packsTitle:
                        return false
                    default:
                        return true
                }
            case let .pack(lhsIndex, _, _, _, _, _, _, _):
                switch rhs {
                    case let .pack(rhsIndex, _, _, _, _, _, _, _):
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
            case let .trending(theme, text, count):
                return ItemListDisclosureItem(theme: theme, title: text, label: count == 0 ? "" : "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.openFeatured()
                })
            case let .masks(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openMasks()
                })
            case let .archived(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openArchived()
                })
            case let .packsTitle(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .pack(_, theme, strings, info, topItem, count, enabled, editing):
                return ItemListStickerPackItem(theme: theme, strings: strings, account: arguments.account, packInfo: info, itemCount: count, topItem: topItem, unread: false, control: .none, editing: editing, enabled: enabled, sectionId: self.section, action: {
                    arguments.openStickerPack(info)
                }, setPackIdWithRevealedOptions: { current, previous in
                    arguments.setPackIdWithRevealedOptions(current, previous)
                }, addPack: {
                }, removePack: {
                    arguments.removePack(info.id)
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

private func installedStickerPacksControllerEntries(presentationData: PresentationData, state: InstalledStickerPacksControllerState, mode: InstalledStickerPacksControllerMode, view: CombinedView, featured: [FeaturedStickerPackItem]) -> [InstalledStickerPacksEntry] {
    var entries: [InstalledStickerPacksEntry] = []
    
    switch mode {
        case .general, .modal:
            if featured.count != 0 {
                var unreadCount: Int32 = 0
                for item in featured {
                    if item.unread {
                        unreadCount += 1
                    }
                }
                entries.append(.trending(presentationData.theme, presentationData.strings.StickerPacksSettings_FeaturedPacks, unreadCount))
            }
            entries.append(.archived(presentationData.theme, presentationData.strings.StickerPacksSettings_ArchivedPacks))
            entries.append(.masks(presentationData.theme, presentationData.strings.MaskStickerSettings_Title))
            entries.append(.packsTitle(presentationData.theme, presentationData.strings.StickerPacksSettings_StickerPacksSection))
        case .masks:
            break
    }
    
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] {
            var index: Int32 = 0
            for entry in packsEntries {
                if let info = entry.info as? StickerPackCollectionInfo {
                    entries.append(.pack(index, presentationData.theme, presentationData.strings, info, entry.firstItem as? StickerPackItem, presentationData.strings.StickerPack_StickerCount(info.count == 0 ? entry.count : info.count), true, ItemListStickerPackItemEditing(editable: true, editing: state.editing, revealed: state.packIdWithRevealedOptions == entry.id, reorderable: true)))
                    index += 1
                }
            }
        }
    }
    
    switch mode {
        case .general, .modal:
            entries.append(.packsInfo(presentationData.theme, presentationData.strings.StickerPacksSettings_ManagingHelp))
        case .masks:
            entries.append(.packsInfo(presentationData.theme, presentationData.strings.MaskStickerSettings_Info))
    }
    
    return entries
}

public enum InstalledStickerPacksControllerMode {
    case general
    case modal
    case masks
}

public func installedStickerPacksController(account: Account, mode: InstalledStickerPacksControllerMode) -> ViewController {
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
    
    var presentStickerPackController: ((StickerPackCollectionInfo) -> Void)?
    
    let arguments = InstalledStickerPacksControllerArguments(account: account, openStickerPack: { info in
        presentStickerPackController?(info)
    }, setPackIdWithRevealedOptions: { packId, fromPackId in
        updateState { state in
            if (packId == nil && fromPackId == state.packIdWithRevealedOptions) || (packId != nil && fromPackId == nil) {
                return state.withUpdatedPackIdWithRevealedOptions(packId)
            } else {
                return state
            }
        }
    }, removePack: { id in
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Delete, color: .destructive, action: {
                    dismissAction()
                    let _ = removeStickerPackInteractively(postbox: account.postbox, id: id, option: .delete).start()
                }),
                ActionSheetButtonItem(title: presentationData.strings.StickerSettings_ContextHide, color: .destructive, action: {
                    dismissAction()
                    let _ = removeStickerPackInteractively(postbox: account.postbox, id: id, option: .archive).start()
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openStickersBot: {
        resolveDisposable.set((resolvePeerByName(account: account, name: "stickers") |> deliverOnMainQueue).start(next: { peerId in
            if let peerId = peerId {
                navigateToChatControllerImpl?(peerId)
            }
        }))
    }, openMasks: {
        pushControllerImpl?(installedStickerPacksController(account: account, mode: .masks))
    }, openFeatured: {
        pushControllerImpl?(featuredStickerPacksController(account: account))
    }, openArchived: {
        pushControllerImpl?(archivedStickerPacksController(account: account))
    })
    let stickerPacks = Promise<CombinedView>()
    stickerPacks.set(account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [namespaceForMode(mode)])]))
    
    let featured = Promise<[FeaturedStickerPackItem]>()
    switch mode {
        case .general, .modal:
            featured.set(account.viewTracker.featuredStickerPacks())
        case .masks:
            featured.set(.single([]))
    }
    
    var previousPackCount: Int?
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get() |> deliverOnMainQueue, stickerPacks.get() |> deliverOnMainQueue, featured.get() |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { presentationData, state, view, featured -> (ItemListControllerState, (ItemListNodeState<InstalledStickerPacksEntry>, InstalledStickerPacksEntry.ItemGenerationArguments)) in
            var packCount: Int? = nil
            if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView, let entries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] {
                packCount = entries.count
            }
            
            let leftNavigationButton: ItemListNavigationButton? = nil
            /*if case .modal = mode {
                leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                    dismissImpl?()
                })
            }*/
            
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
            
            let listState = ItemListNodeState(entries: installedStickerPacksControllerEntries(presentationData: presentationData, state: state, mode: mode, view: view, featured: featured), style: .blocks, animateChanges: previous != nil && packCount != nil && (previous! != 0 && previous! >= packCount! - 10))
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    
    controller.reorderEntry = { fromIndex, toIndex, entries in
        let fromEntry = entries[fromIndex]
        guard case let .pack(_, _, _, fromPackInfo, _, _, _, _) = fromEntry else {
            return
        }
        var referenceId: ItemCollectionId?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .pack(_, _, _, toPackInfo, _, _, _, _):
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
        
        let _ = (account.postbox.transaction { transaction -> Void in
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
        presentControllerImpl?(StickerPackPreviewController(account: account, stickerPack: .id(id: info.id.id, accessHash: info.accessHash), parentNavigationController: controller?.navigationController as? NavigationController), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    navigateToChatControllerImpl = { [weak controller] peerId in
        if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
            navigateToChatController(navigationController: navigationController, account: account, chatLocation: .peer(peerId))
        }
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
