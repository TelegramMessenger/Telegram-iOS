import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ArchivedStickerPacksControllerArguments {
    let account: Account
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let setPackIdWithRevealedOptions: (ItemCollectionId?, ItemCollectionId?) -> Void
    let removePack: (StickerPackCollectionInfo) -> Void
    
    init(account: Account, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, setPackIdWithRevealedOptions: @escaping (ItemCollectionId?, ItemCollectionId?) -> Void, removePack: @escaping (StickerPackCollectionInfo) -> Void) {
        self.account = account
        self.openStickerPack = openStickerPack
        self.setPackIdWithRevealedOptions = setPackIdWithRevealedOptions
        self.removePack = removePack
    }
}

private enum ArchivedStickerPacksSection: Int32 {
    case stickers
}

private enum ArchivedStickerPacksEntryId: Hashable {
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
    
    static func ==(lhs: ArchivedStickerPacksEntryId, rhs: ArchivedStickerPacksEntryId) -> Bool {
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

private enum ArchivedStickerPacksEntry: ItemListNodeEntry {
    case info(String)
    case pack(Int32, StickerPackCollectionInfo, StickerPackItem?, Int32, Bool, ItemListStickerPackItemEditing)
    
    var section: ItemListSectionId {
        switch self {
            case .info, .pack:
                return ArchivedStickerPacksSection.stickers.rawValue
        }
    }
    
    var stableId: ArchivedStickerPacksEntryId {
        switch self {
            case .info:
                return .index(0)
            case let .pack(_, info, _, _, _, _):
                return .pack(info.id)
        }
    }
    
    static func ==(lhs: ArchivedStickerPacksEntry, rhs: ArchivedStickerPacksEntry) -> Bool {
        switch lhs {
            case let .info(text):
                if case .info(text) = rhs {
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
        }
    }
    
    static func <(lhs: ArchivedStickerPacksEntry, rhs: ArchivedStickerPacksEntry) -> Bool {
        switch lhs {
            case .info:
                switch rhs {
                    case .info:
                        return false
                    default:
                        return true
                }
            case let .pack(lhsIndex, _, _, _, _, _):
                switch rhs {
                    case let .pack(rhsIndex, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return false
                }
        }
    }
    
    func item(_ arguments: ArchivedStickerPacksControllerArguments) -> ListViewItem {
        switch self {
            case let .info(text):
                return ItemListTextItem(text: .plain(text), sectionId: self.section)
            case let .pack(_, info, topItem, count, enabled, editing):
                return ItemListStickerPackItem(account: arguments.account, packInfo: info, itemCount: count, topItem: topItem, unread: false, control: .none, editing: editing, enabled: enabled, sectionId: self.section, action: { _ in
                    arguments.openStickerPack(info)
                }, setPackIdWithRevealedOptions: { current, previous in
                    arguments.setPackIdWithRevealedOptions(current, previous)
                }, addPack: {
                }, removePack: {
                    arguments.removePack(info)
                })
        }
    }
}

private struct ArchivedStickerPacksControllerState: Equatable {
    let editing: Bool
    let packIdWithRevealedOptions: ItemCollectionId?
    let removingPackIds: Set<ItemCollectionId>
    
    init() {
        self.editing = false
        self.packIdWithRevealedOptions = nil
        self.removingPackIds = Set()
    }
    
    init(editing: Bool, packIdWithRevealedOptions: ItemCollectionId?, removingPackIds: Set<ItemCollectionId>) {
        self.editing = editing
        self.packIdWithRevealedOptions = packIdWithRevealedOptions
        self.removingPackIds = removingPackIds
    }
    
    static func ==(lhs: ArchivedStickerPacksControllerState, rhs: ArchivedStickerPacksControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.packIdWithRevealedOptions != rhs.packIdWithRevealedOptions {
            return false
        }
        if lhs.removingPackIds != rhs.removingPackIds {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ArchivedStickerPacksControllerState {
        return ArchivedStickerPacksControllerState(editing: editing, packIdWithRevealedOptions: self.packIdWithRevealedOptions, removingPackIds: self.removingPackIds)
    }
    
    func withUpdatedPackIdWithRevealedOptions(_ packIdWithRevealedOptions: ItemCollectionId?) -> ArchivedStickerPacksControllerState {
        return ArchivedStickerPacksControllerState(editing: self.editing, packIdWithRevealedOptions: packIdWithRevealedOptions, removingPackIds: self.removingPackIds)
    }
    
    func withUpdatedRemovingPackIds(_ removingPackIds: Set<ItemCollectionId>) -> ArchivedStickerPacksControllerState {
        return ArchivedStickerPacksControllerState(editing: editing, packIdWithRevealedOptions: self.self.packIdWithRevealedOptions, removingPackIds: removingPackIds)
    }
}

private func archivedStickerPacksControllerEntries(state: ArchivedStickerPacksControllerState, packs: [ArchivedStickerPackItem]?, installedView: CombinedView) -> [ArchivedStickerPacksEntry] {
    var entries: [ArchivedStickerPacksEntry] = []
    
    if let packs = packs {
        entries.append(.info("You can have up to 200 sticker sets installed.\nUnused stickers are archived when you add more.\n\n"))
        
        var installedIds = Set<ItemCollectionId>()
        if let view = installedView.views[.itemCollectionIds(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionIdsView, let ids = view.idsByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
            installedIds = ids
        }
        
        var index: Int32 = 0
        for item in packs {
            if !installedIds.contains(item.info.id) {
                entries.append(.pack(index, item.info, item.topItems.first, item.info.count, !state.removingPackIds.contains(item.info.id), ItemListStickerPackItemEditing(editable: true, editing: state.editing, revealed: state.packIdWithRevealedOptions == item.info.id)))
                index += 1
            }
        }
    }
    
    return entries
}

public func archivedStickerPacksController(account: Account) -> ViewController {
    let statePromise = ValuePromise(ArchivedStickerPacksControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ArchivedStickerPacksControllerState())
    let updateState: ((ArchivedStickerPacksControllerState) -> ArchivedStickerPacksControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let resolveDisposable = MetaDisposable()
    actionsDisposable.add(resolveDisposable)
    
    let removePackDisposables = DisposableDict<ItemCollectionId>()
    actionsDisposable.add(removePackDisposables)
    
    let stickerPacks = Promise<[ArchivedStickerPackItem]?>()
    stickerPacks.set(.single(nil) |> then(archivedStickerPacks(account: account) |> map { Optional($0) }))
    
    let installedStickerPacks = Promise<CombinedView>()
    installedStickerPacks.set(account.postbox.combinedView(keys: [.itemCollectionIds(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])]))
    
    let arguments = ArchivedStickerPacksControllerArguments(account: account, openStickerPack: { info in
        presentControllerImpl?(StickerPackPreviewController(account: account, stickerPack: .id(id: info.id.id, accessHash: info.accessHash)), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, setPackIdWithRevealedOptions: { packId, fromPackId in
        updateState { state in
            if (packId == nil && fromPackId == state.packIdWithRevealedOptions) || (packId != nil && fromPackId == nil) {
                return state.withUpdatedPackIdWithRevealedOptions(packId)
            } else {
                return state
            }
        }
    }, removePack: { info in
        var remove = false
        updateState { state in
            var removingPackIds = state.removingPackIds
            if !removingPackIds.contains(info.id) {
                removingPackIds.insert(info.id)
                remove = true
            }
            return state.withUpdatedRemovingPackIds(removingPackIds)
        }
        if remove {
            let applyPacks: Signal<Void, NoError> = stickerPacks.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { packs -> Signal<Void, NoError> in
                    if let packs = packs {
                        var updatedPacks = packs
                        for i in 0 ..< updatedPacks.count {
                            if updatedPacks[i].info.id == info.id {
                                updatedPacks.remove(at: i)
                                break
                            }
                        }
                        stickerPacks.set(.single(updatedPacks))
                    }
                    
                    return .complete()
            }
            removePackDisposables.set((removeArchivedStickerPack(account: account, info: info) |> then(applyPacks) |> deliverOnMainQueue).start(completed: {
                updateState { state in
                    var removingPackIds = state.removingPackIds
                    removingPackIds.remove(info.id)
                    return state.withUpdatedRemovingPackIds(removingPackIds)
                }
            }), forKey: info.id)
        }
    })
    
    var previousPackCount: Int?
    
    let signal = combineLatest(statePromise.get() |> deliverOnMainQueue, stickerPacks.get() |> deliverOnMainQueue, installedStickerPacks.get() |> deliverOnMainQueue)
        |> map { state, packs, installedView -> (ItemListControllerState, (ItemListNodeState<ArchivedStickerPacksEntry>, ArchivedStickerPacksEntry.ItemGenerationArguments)) in
            var rightNavigationButton: ItemListNavigationButton?
            if let packs = packs, packs.count != 0 {
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
            previousPackCount = packs?.count
            
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if packs == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem()
            }
            
            let controllerState = ItemListControllerState(title: .text("Archived Stickers"), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, animateChanges: true)
            
            let listState = ItemListNodeState(entries: archivedStickerPacksControllerEntries(state: state, packs: packs, installedView: installedView), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && packs != nil && (previous! != 0 && previous! >= packs!.count - 10))
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
    
    return controller
}
