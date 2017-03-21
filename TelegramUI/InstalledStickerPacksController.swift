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
    case trending(Int32)
    case archived
    case masks
    case packsTitle(String)
    case pack(Int32, StickerPackCollectionInfo, StickerPackItem?, Int32, Bool, ItemListStickerPackItemEditing)
    case packsInfo(String)
    
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
            case let .pack(_, info, _, _, _, _):
                return .pack(info.id)
            case .packsInfo:
                return .index(4)
        }
    }
    
    static func ==(lhs: InstalledStickerPacksEntry, rhs: InstalledStickerPacksEntry) -> Bool {
        switch lhs {
            case let .trending(count):
                if case .trending(count) = rhs {
                    return true
                } else {
                    return false
                }
            case .masks, .archived:
                return lhs.stableId == rhs.stableId
            case let .packsTitle(text):
                if case .packsTitle(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .pack(lhsIndex, lhsInfo, lhsTopItem, lhsCount, lhsEnabled, lhsEditing):
                if case let .pack(rhsIndex, rhsInfo, rhsTopItem, rhsCount, rhsEnabled, rhsEditing) = rhs {
                    if lhsIndex != rhsIndex {
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
            case let .packsInfo(text):
                if case .packsInfo(text) = rhs {
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
            case let .pack(lhsIndex, _, _, _, _, _):
                switch rhs {
                    case let .pack(rhsIndex, _, _, _, _, _):
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
            case let .trending(count):
                return ItemListDisclosureItem(title: "Trending", label: count == 0 ? "" : "\(count)", sectionId: self.section, style: .blocks, action: {
                    arguments.openFeatured()
                })
            case .masks:
                return ItemListDisclosureItem(title: "Masks", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openMasks()
                })
            case .archived:
                return ItemListDisclosureItem(title: "Archived", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openArchived()
                })
            case let .packsTitle(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
            case let .pack(_, info, topItem, count, enabled, editing):
                return ItemListStickerPackItem(account: arguments.account, packInfo: info, itemCount: count, topItem: topItem, unread: false, control: .none, editing: editing, enabled: enabled, sectionId: self.section, action: { _ in
                    arguments.openStickerPack(info)
                }, setPackIdWithRevealedOptions: { current, previous in
                    arguments.setPackIdWithRevealedOptions(current, previous)
                }, addPack: {
                }, removePack: {
                    arguments.removePack(info.id)
                })
            case let .packsInfo(text):
                return ItemListTextItem(text: .markdown(text), sectionId: self.section, linkAction: { _ in
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
        case .general:
            return Namespaces.ItemCollection.CloudStickerPacks
        case .masks:
            return Namespaces.ItemCollection.CloudMaskPacks
    }
}

private func installedStickerPacksControllerEntries(state: InstalledStickerPacksControllerState, mode: InstalledStickerPacksControllerMode, view: CombinedView, featured: [FeaturedStickerPackItem]) -> [InstalledStickerPacksEntry] {
    var entries: [InstalledStickerPacksEntry] = []
    
    switch mode {
        case .general:
            if featured.count != 0 {
                var unreadCount: Int32 = 0
                for item in featured {
                    if item.unread {
                        unreadCount += 1
                    }
                }
                entries.append(.trending(unreadCount))
            }
            entries.append(.archived)
            entries.append(.masks)
            entries.append(.packsTitle("STICKER SETS"))
        case .masks:
            break
    }
    
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView {
        if let packsEntries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] {
            var index: Int32 = 0
            for entry in packsEntries {
                if let info = entry.info as? StickerPackCollectionInfo {
                    entries.append(.pack(index, info, entry.firstItem as? StickerPackItem, info.count == 0 ? entry.count : info.count, true, ItemListStickerPackItemEditing(editable: true, editing: state.editing, revealed: state.packIdWithRevealedOptions == entry.id)))
                    index += 1
                }
            }
        }
    }
    
    switch mode {
        case .general:
            entries.append(.packsInfo("Artists are welcome to add their own sticker sets using our [@stickers]() bot.\n\nTap on a sticker to view and add the whole set."))
        case .masks:
            entries.append(.packsInfo("You can add masks to photos and videos you send. To do this, open the photo editor before sending a photo or video."))
    }
    
    return entries
}

public enum InstalledStickerPacksControllerMode {
    case general
    case masks
}

public func installedStickerPacksController(account: Account, mode: InstalledStickerPacksControllerMode) -> ViewController {
    let statePromise = ValuePromise(InstalledStickerPacksControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: InstalledStickerPacksControllerState())
    let updateState: ((InstalledStickerPacksControllerState) -> InstalledStickerPacksControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var navigateToChatControllerImpl: ((PeerId) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let resolveDisposable = MetaDisposable()
    actionsDisposable.add(resolveDisposable)
    
    let arguments = InstalledStickerPacksControllerArguments(account: account, openStickerPack: { info in
        presentControllerImpl?(StickerPackPreviewController(account: account, stickerPack: .id(id: info.id.id, accessHash: info.accessHash)), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, setPackIdWithRevealedOptions: { packId, fromPackId in
        updateState { state in
            if (packId == nil && fromPackId == state.packIdWithRevealedOptions) || (packId != nil && fromPackId == nil) {
                return state.withUpdatedPackIdWithRevealedOptions(packId)
            } else {
                return state
            }
        }
    }, removePack: { id in
        let controller = ActionSheetController()
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Remove", color: .destructive, action: {
                    dismissAction()
                    let _ = removeStickerPackInteractively(postbox: account.postbox, id: id).start()
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
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
        case .general:
            featured.set(account.viewTracker.featuredStickerPacks())
        case .masks:
            featured.set(.single([]))
    }
    
    var previousPackCount: Int?
    
    let signal = combineLatest(statePromise.get() |> deliverOnMainQueue, stickerPacks.get() |> deliverOnMainQueue, featured.get() |> deliverOnMainQueue)
        |> map { state, view, featured -> (ItemListControllerState, (ItemListNodeState<InstalledStickerPacksEntry>, InstalledStickerPacksEntry.ItemGenerationArguments)) in
            var packCount: Int? = nil
            if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [namespaceForMode(mode)])] as? ItemCollectionInfosView, let entries = stickerPacksView.entriesByNamespace[namespaceForMode(mode)] {
                packCount = entries.count
            }
            
            var rightNavigationButton: ItemListNavigationButton?
            if let packCount = packCount, packCount != 0 {
                if state.editing {
                    rightNavigationButton = ItemListNavigationButton(title: "Done", style: .bold, enabled: true, action: {
                        updateState {
                            $0.withUpdatedEditing(false)
                        }
                    })
                } else {
                    rightNavigationButton = ItemListNavigationButton(title: "Edit", style: .regular, enabled: true, action: {
                        updateState {
                            $0.withUpdatedEditing(true)
                        }
                    })
                }
            }
            
            let previous = previousPackCount
            previousPackCount = packCount
            
            let controllerState = ItemListControllerState(title: mode == .general ? "Stickers" : "Masks", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, animateChanges: true)
            
            let listState = ItemListNodeState(entries: installedStickerPacksControllerEntries(state: state, mode: mode, view: view, featured: featured), style: .blocks, animateChanges: previous != nil && packCount != nil && (previous! != 0 && previous! >= packCount! - 10))
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window, with: p)
        }
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    navigateToChatControllerImpl = { [weak controller] peerId in
        if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
            navigateToChatController(navigationController: navigationController, account: account, peerId: peerId)
        }
    }
    
    return controller
}
